---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)

--- Protocol Module
--- Handles incoming addon messages and routes them to appropriate handlers.
--- 
--- Responsibilities:
--- - Parse and validate incoming messages
--- - Route messages to type-specific handlers
--- - Process MANIFEST, REQUEST_CHARS, ALIAS_UPDATE, CHARS_UPDATE messages
--- - Implement bidirectional gossip correction (detect and fix stale data)
--- - Update database and character cache based on received data
--- 
--- Public API:
--- - Protocol.OnAddonMessage(prefix, message, channel, sender) - Entry point for incoming messages
--- 
--- Dependencies:
--- - ns.MessageCodec - Message encoding/decoding
--- - ns.AddonMessages - Low-level message building and sending (BuildMessage, SendMessage)
--- - ns.DB - Database access for profiles and characters
--- - ns.CharacterCache - Character name → BattleTag lookups
--- - ns.Coordinator - Character list chunking (SendCharsUpdate)
--- - ns.Gossip - Opportunistic profile propagation
--- 
--- Usage:
---   -- In AddonMessages.RegisterListener():
---   frame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
---     if event == "CHAT_MSG_ADDON" then
---       ns.Protocol.OnAddonMessage(prefix, message, channel, sender)
---     end
---   end)

local Protocol = {}
ns.Protocol = Protocol

-- Shortcuts
local DebugPrint = ns.DebugPrint
local ChatType = ns.AddonMessages.ChatType
local ERROR = ns.Constants.PREFIX_ERROR

-- Constants
local ADDON_PREFIX = "Ndvrng"
local MSG_TYPE = ns.MSG_TYPE  -- Shared message type enum

--- Parse an encoded message and extract message type
--- Message type is embedded in the CBOR payload
--- @param encoded string The encoded message
--- @return MessageType|nil messageType The message type
--- @return table|nil data The decoded message data (including type field)
local function ParseMessage(encoded)
---@diagnostic disable-next-line: param-type-mismatch
	if issecretvalue(encoded) or not encoded or encoded == "" then
		return nil, nil
	end
	
	-- Decode the CBOR payload
	local data, err = ns.MessageCodec.Decode(encoded)
	if not data then
		DebugPrint(string.format("Failed to decode message: %s", err or "unknown error"), "ff0000")
		return nil, nil
	end
	
	-- Extract message type from decoded data
	local messageType = data.type
	if not messageType or messageType == "" then
		DebugPrint("Message missing type field", "ff0000")
		return nil, nil
	end
	
	return messageType, data
end

--- Validate a BattleTag format
--- @param battleTag string The BattleTag to validate
--- @return boolean valid Whether the BattleTag is valid
local function ValidateBattleTag(battleTag)
	if not battleTag or battleTag == "" then
		return false
	end
	
	-- BattleTag format: Name#1234 (name can have spaces in some regions)
	return string.match(battleTag, ".+#%d+") ~= nil
end

--- Validate a timestamp is reasonable
--- @param timestamp number The timestamp to validate
--- @return boolean valid Whether the timestamp is valid
local function ValidateTimestamp(timestamp)
	if not timestamp or type(timestamp) ~= "number" then
		print(ERROR .. " Invalid timestamp")
		return false
	end
	
	-- Reasonable range: 2020-01-01 to 2040-01-01
	local MIN_TIMESTAMP = 1577836800  -- 2020-01-01
	local MAX_TIMESTAMP = 2209032000  -- 2040-01-01
	
	return timestamp >= MIN_TIMESTAMP and timestamp <= MAX_TIMESTAMP
end

--- Handle incoming MANIFEST message (CBOR format)
--- @param sender string The sender's character name
--- @param data table The decoded message data
local function HandleManifest(sender, data)
	if not data then
		return
	end
	
	local battleTag = data.battleTag
	local alias = data.alias
	local charsUpdatedAt = data.charsUpdatedAt
	local aliasUpdatedAt = data.aliasUpdatedAt
	
	-- Validate message data
	if not ValidateBattleTag(battleTag) then
		return
	end
	
	if not charsUpdatedAt or not aliasUpdatedAt or not ValidateTimestamp(charsUpdatedAt) or not ValidateTimestamp(aliasUpdatedAt) then
		return
	end
	
	-- Ignore our own manifests
	local myBattleTag = ns.DB.GetMyBattleTag()
	if battleTag == myBattleTag then
		return
	end
	
	-- Get cached profile to compare timestamps
	local cachedProfile = ns.DB.GetProfile(battleTag)
	local needsChars = false
	local afterTimestamp = 0
	
	if not cachedProfile then
		-- New player, request characters and update alias
		needsChars = true
		afterTimestamp = 0
		ns.DB.UpdateProfileAlias(battleTag, alias, aliasUpdatedAt)
	else
		-- Check if alias is newer
		if aliasUpdatedAt > (cachedProfile.aliasUpdatedAt or 0) then
			ns.DB.UpdateProfileAlias(battleTag, alias, aliasUpdatedAt)
		end
		
		-- Check if characters are newer
		if charsUpdatedAt > (cachedProfile.charsUpdatedAt or 0) then
			needsChars = true
			afterTimestamp = cachedProfile.charsUpdatedAt or 0
		end
	end
	
	-- Request characters if needed
	if needsChars then
		local requestData = {
			battleTag = battleTag,
			afterTimestamp = afterTimestamp,
		}
		local message = ns.AddonMessages.BuildMessage(MSG_TYPE.REQUEST_CHARS, requestData)
		if message then
			DebugPrint(string.format("Sending REQUEST_CHARS to %s (after: %d)", battleTag, afterTimestamp))
			ns.AddonMessages.SendMessage(message, ChatType.Whisper, sender)
		end
	end
	
	-- Gossip Protocol
	ns.Gossip.SendProfilesToPlayer(battleTag, sender)
end

--- Handle incoming REQUEST_CHARS message (CBOR format)
--- @param sender string The sender's character name
--- @param data table The decoded message data
local function HandleRequestChars(sender, data)
	if not data then
		return
	end
	
	local battleTag = data.battleTag
	local afterTimestamp = data.afterTimestamp
	
	DebugPrint(string.format("Received REQUEST_CHARS from %s for %s (after: %d)", sender, battleTag, afterTimestamp))
	
	-- Only respond if they're asking about us
	local myBattleTag = ns.DB.GetMyBattleTag()
	if battleTag ~= myBattleTag then
		DebugPrint(string.format("REQUEST_CHARS not for us (ours: %s, requested: %s)", myBattleTag or "nil", battleTag), "ff8800")
		return
	end
	
	if not afterTimestamp or (not ValidateTimestamp(afterTimestamp) and afterTimestamp ~= 0) then
		print(ERROR .. " Invalid timestamp")
		return
	end
	
	-- Get characters to send
	local characters = ns.DB.GetCharactersAddedAfter(afterTimestamp)
	if #characters == 0 then
		DebugPrint("No characters to send", "ff0000")
		return
	end
	
	-- Build characters array
	local chars = {}
	for _, char in ipairs(characters) do
		table.insert(chars, {
			name = char.name,
			realm = char.realm or "",
			addedAt = char.addedAt,
		})
	end
	
	-- Send CHARS_UPDATE (with chunking if needed)
	local myProfile = ns.DB.GetMyProfile()
	if not myProfile then
		return
	end
	
	DebugPrint(string.format("Sending CHARS_UPDATE (%d chars total) to %s", #chars, sender))
	ns.Coordinator.SendCharsUpdate(myProfile.battleTag, chars, myProfile.charsUpdatedAt, ChatType.Whisper, sender)
end

--- Handle incoming ALIAS_UPDATE message (CBOR format)
--- @param sender string The sender's character name
--- @param data table The decoded message data
local function HandleAliasUpdate(sender, data)
	if not data then
		return
	end
	
	local battleTag = data.battleTag
	local alias = data.alias
	local aliasUpdatedAt = data.aliasUpdatedAt
	
	if not ValidateBattleTag(battleTag) or not alias or not aliasUpdatedAt or not ValidateTimestamp(aliasUpdatedAt) then
		return
	end
	
	-- Don't allow updates to our own profile
	local myBattleTag = ns.DB.GetMyBattleTag()
	if battleTag == myBattleTag then
		return
	end
	
	-- Try to identify sender's BattleTag for gossip tracking
	local senderBattleTag = ns.CharacterCache.FindBattleTag(sender)
	
	-- Check if we have this profile and if it's stale
	local existingProfile = ns.DB.GetProfile(battleTag)
	if existingProfile then
		-- Track that sender knows about this profile
		if senderBattleTag then
			ns.Gossip.MarkKnownProfile(senderBattleTag, battleTag)
			DebugPrint(string.format("Tracked: %s knows about %s", senderBattleTag, battleTag))
		end
		
		-- Bidirectional correction: if sender has stale data, gossip back the correct version
		if existingProfile.aliasUpdatedAt and existingProfile.aliasUpdatedAt > aliasUpdatedAt then
			DebugPrint(string.format("Sender has stale alias for %s (theirs: %d, ours: %d), gossiping back", 
				battleTag, aliasUpdatedAt, existingProfile.aliasUpdatedAt))
			
			if senderBattleTag then
				ns.Gossip.CorrectStaleAlias(sender, battleTag, existingProfile.alias, existingProfile.aliasUpdatedAt)
			end
			return  -- Don't update with stale data
		end
	end
	
	-- Update alias in database
	local success = ns.DB.UpdateProfileAlias(battleTag, alias, aliasUpdatedAt)
	if success then
		DebugPrint(string.format("Updated alias for %s to '%s'", battleTag, alias))
		ns.API.RequestActivityLog()  -- Refresh activity log to show updated alias
	end
end

--- Handle incoming CHARS_UPDATE message (CBOR format)
--- @param sender string The sender's character name
--- @param data table The decoded message data
local function HandleCharsUpdate(sender, data)
	if not data then
		return
	end
	
	local battleTag = data.battleTag
	local characters = data.characters or {}
	local senderCharsUpdatedAt = data.charsUpdatedAt or 0
	
	if not ValidateBattleTag(battleTag) then
		return
	end
	
	-- Don't allow updates to our own profile
	local myBattleTag = ns.DB.GetMyBattleTag()
	if battleTag == myBattleTag then
		return
	end
	
	-- Try to identify sender's BattleTag for gossip tracking
	local senderBattleTag = ns.CharacterCache.FindBattleTag(sender)
	
	-- Check if we have this profile
	local existingProfile = ns.DB.GetProfile(battleTag)
	if existingProfile then
		-- Track that sender knows about this profile
		if senderBattleTag then
			ns.Gossip.MarkKnownProfile(senderBattleTag, battleTag)
			DebugPrint(string.format("Tracked: %s knows about %s", senderBattleTag, battleTag))
		end
		
		-- Bidirectional correction: if sender has stale data, gossip back the correct version
		if existingProfile.charsUpdatedAt and existingProfile.charsUpdatedAt > senderCharsUpdatedAt then
			DebugPrint(string.format("Sender has stale characters for %s (theirs: %d, ours: %d), gossiping back",
				battleTag, senderCharsUpdatedAt, existingProfile.charsUpdatedAt))
			
			if senderBattleTag then
				ns.Gossip.CorrectStaleChars(sender, battleTag, existingProfile.charsUpdatedAt, senderCharsUpdatedAt)
			end
		end
	end
	
	-- Validate and add characters
	local validChars = {}
	for _, char in ipairs(characters) do
		if char.name and char.name ~= "" and char.addedAt and ValidateTimestamp(char.addedAt) then
			table.insert(validChars, {
				name = char.name,
				realm = char.realm or "",
				addedAt = char.addedAt,
			})
		end
	end
	
	if #validChars > 0 then
		local success = ns.DB.AddCharactersToProfile(battleTag, validChars)
		if success then
			DebugPrint(string.format("Updated %d character(s) for %s", #validChars, battleTag))
			-- Invalidate cache since we added characters
			ns.CharacterCache.Invalidate(battleTag)
			ns.API.RequestActivityLog()  -- Refresh activity log to show updated characters
		end
	end
end

--- Route message to appropriate handler
--- @param messageType MessageType The message type
--- @param sender string The sender's character name
--- @param data table The decoded message data
local function RouteMessage(messageType, sender, data)
	DebugPrint(string.format("Received message of type %s from %s", messageType, sender))
	
	-- Route to appropriate handler
	if messageType == MSG_TYPE.MANIFEST then
		HandleManifest(sender, data)
	elseif messageType == MSG_TYPE.REQUEST_CHARS then
		HandleRequestChars(sender, data)
	elseif messageType == MSG_TYPE.ALIAS_UPDATE then
		HandleAliasUpdate(sender, data)
	elseif messageType == MSG_TYPE.CHARS_UPDATE then
		HandleCharsUpdate(sender, data)
	end
end

--- Handle incoming addon message (public API)
--- Entry point for all incoming addon messages. Parses, validates, and routes
--- messages to appropriate handlers.
--- @param prefix string The addon prefix
--- @param message string The encoded message content
--- @param channel string The channel the message was sent on
--- @param sender string The sender's character name
function Protocol.OnAddonMessage(prefix, message, channel, sender)
	if prefix ~= ADDON_PREFIX then
		return
	end

	-- TODO: We can probably short circuit on our own messages here
	-- but they are helpful for early testing.
	-- Consider setting a "senderMe" var at early lifecycle of the
	-- addon so that we can compare here and ignore our own messages.
	-- Probably wrap it in an @alpha@ block to aid with future testing.
	
	local messageType, data = ParseMessage(message)
	if not messageType or not data then
		return
	end
	
	RouteMessage(messageType, sender, data)
end
