---@type string
local addonName = select(1, ...)
---@class HDENamespace
local ns = select(2, ...)

local Sync = {}
ns.Sync = Sync

-- Shortcuts
local ERROR = ns.Constants.PREFIX_ERROR

-- Constants
local ADDON_PREFIX = "Ndvrng"
local CHANNEL_GUILD = "GUILD"
local MESSAGE_SIZE_LIMIT = 255  -- WoW API hard limit for addon messages

-- Gossip configuration
local GOSSIP_MAX_PROFILES_PER_MANIFEST = 3  -- Max profiles to gossip per MANIFEST received

-- Message types (CBOR + compression protocol)
-- Values are intentionally short to minimize wire overhead
local MSG_TYPE = {
	MANIFEST = "M",
	REQUEST_CHARS = "R",
	ALIAS_UPDATE = "A",
	CHARS_UPDATE = "C",
}

-- State
local initialized = false
local lastManifestTime = 0
local manifestDebounceTimer = nil
local guildRosterDebounceTimer = nil
-- Gossip tracking: lastGossip[senderBattleTag][profileBattleTag] = true
-- Tracks which profiles we've gossiped to which players THIS SESSION
-- Per-session only (not persisted) - resets on reload/relog
local lastGossip = {}

--- Print debug message if verbose debug mode is enabled
--- @param message string The message to print
--- @param color string|nil Optional color code (default: green)
local function DebugPrint(message, color)
	if not ns.DB.IsVerboseDebug() then
		return
	end
	
	color = color or "00ff00" -- Green by default
	print(string.format("|cff%sEndeavoring:|r %s", color, message))
end

--- Initialize the sync service
function Sync.Init()
	if initialized then
		return
	end
	
	-- Register addon message prefix
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		local success = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
		if not success then
			print(ERROR .. " Failed to register addon message prefix")
			return
		end
	end
	
	initialized = true
end

--- Parse a pipe-delimited message
--- @param message string The raw message string
--- @return string|nil messageType The message type (e.g., "MANIFEST")
--- @return table|nil parts The message parts (excluding message type)
local function ParseMessage(message)
---@diagnostic disable-next-line: param-type-mismatch
	if issecretvalue(message) or not message or message == "" then
		return nil, nil
	end
	
	-- Use WoW's strsplit to parse pipe-delimited message
	local parts = strsplittable("|", message)
	
	if #parts < 1 then
		return nil, nil
	end
	
	local messageType = table.remove(parts, 1)
	return messageType, parts
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

--- Build a message with CBOR-encoded payload
--- @param messageType string The message type (e.g., MSG_TYPE.MANIFEST)
--- @param data table The data to encode
--- @return string|nil message The complete message, or nil on encoding failure
local function BuildMessage(messageType, data)
	local encoded, err = ns.MessageCodec.Encode(data)
	if not encoded then
		DebugPrint(string.format("Failed to encode message: %s", err or "unknown error"), "ff0000")
		return nil
	end
	
	local message = messageType .. "|" .. encoded
	
	-- Warn if message is approaching or exceeding size limit
	if #message > MESSAGE_SIZE_LIMIT then
		DebugPrint(string.format("WARNING: Built message size (%d bytes) exceeds limit (%d bytes)!", #message, MESSAGE_SIZE_LIMIT), "ff0000")
	elseif #message > (MESSAGE_SIZE_LIMIT * 0.9) then
		-- Warn if within 10% of limit
		DebugPrint(string.format("WARNING: Built message size (%d bytes) is close to limit (%d bytes)", #message, MESSAGE_SIZE_LIMIT), "ff8800")
	end
	
	return message
end

--- Parse a message and decode the CBOR payload
--- @param encoded string The encoded payload (after message type)
--- @return table|nil data The decoded data, or nil on failure
local function ParsePayload(encoded)
	local data, err = ns.MessageCodec.Decode(encoded)
	if not data then
		DebugPrint(string.format("Failed to decode message: %s", err or "unknown error"), "ff0000")
		return nil
	end
	
	return data
end

--- Send a message via addon communication
--- @param message string The message to send
--- @param channel string The channel to send on (default: GUILD)
--- @param target string|nil The target player for whisper messages
--- @return boolean success Whether the message was sent successfully
local function SendMessage(message, channel, target)
	if not initialized then
		return false
	end
	
	channel = channel or CHANNEL_GUILD
	
	-- Pre-flight validation: check message size
	if #message > MESSAGE_SIZE_LIMIT then
		print(ERROR .. string.format(" Message size (%d bytes) exceeds API limit (%d bytes)! Message NOT sent.", #message, MESSAGE_SIZE_LIMIT))
		print(ERROR .. " This likely means you have too many characters. Please report this issue!")
		return false
	end
	
	if C_ChatInfo and C_ChatInfo.SendAddonMessage then
		DebugPrint(string.format("Sending %d byte message on channel %s", #message, channel))
		
		-- Send and check return code
		local result = C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, channel, target)
		
		-- Check for errors (Enum.SendAddonMessageResult)
		if result ~= Enum.SendAddonMessageResult.Success then
			local errorNames = {
				[Enum.SendAddonMessageResult.InvalidPrefix] = "InvalidPrefix",
				[Enum.SendAddonMessageResult.InvalidMessage] = "InvalidMessage",
				[Enum.SendAddonMessageResult.AddonMessageThrottle] = "AddonMessageThrottle",
				[Enum.SendAddonMessageResult.InvalidChatType] = "InvalidChatType",
				[Enum.SendAddonMessageResult.NotInGroup] = "NotInGroup",
				[Enum.SendAddonMessageResult.TargetRequired] = "TargetRequired",
				[Enum.SendAddonMessageResult.InvalidChannel] = "InvalidChannel",
				[Enum.SendAddonMessageResult.ChannelThrottle] = "ChannelThrottle",
				[Enum.SendAddonMessageResult.GeneralError] = "GeneralError",
				[Enum.SendAddonMessageResult.NotInGuild] = "NotInGuild",
				[Enum.SendAddonMessageResult.TargetOffline] = "TargetOffline",
			}
			local errorName = errorNames[result] or "Unknown"
			
			print(ERROR .. string.format(" Failed to send message: %s (code %d)", errorName, result or -1))
			print(ERROR .. string.format(" Channel: %s, Size: %d bytes", channel, #message))
			if target then
				print(ERROR .. string.format(" Target: %s", target))
			end
			return false
		end
		
		return true
	end
	
	return false
end

--- Select profiles to gossip to a player
--- @param targetBattleTag string The BattleTag to gossip to
--- @param maxCount number Maximum number of profiles to return
--- @return table profiles Array of {battleTag, profile} to gossip
local function SelectProfilesForGossip(targetBattleTag, maxCount)
	local myBattleTag = ns.DB.GetMyBattleTag()
	local allProfiles = ns.DB.GetAllProfiles()
	local candidates = {}
	
	-- Initialize gossip tracking for this player if needed
	if not lastGossip[targetBattleTag] then
		lastGossip[targetBattleTag] = {}
	end
	
	-- Build list of profiles eligible for gossip
	for battleTag, profile in pairs(allProfiles) do
		-- Skip our own profile (already sent in MANIFEST)
		if battleTag ~= myBattleTag then
			-- Only gossip if we haven't gossiped this profile to this player this session
			if not lastGossip[targetBattleTag][battleTag] then
				table.insert(candidates, {
					battleTag = battleTag,
					profile = profile,
					lastUpdate = math.max(profile.aliasUpdatedAt or 0, profile.charsUpdatedAt or 0)
				})
			end
		end
	end
	
	-- Sort by most recently updated first
	table.sort(candidates, function(a, b)
		return a.lastUpdate > b.lastUpdate
	end)
	
	-- Return top N candidates
	local selected = {}
	for i = 1, math.min(maxCount, #candidates) do
		table.insert(selected, {
			battleTag = candidates[i].battleTag,
			profile = candidates[i].profile
		})
	end
	
	return selected
end

--- Gossip cached profiles to a player
--- @param targetBattleTag string The BattleTag to gossip to
--- @param targetCharacter string The character name to send whispers to
local function GossipProfilesToPlayer(targetBattleTag, targetCharacter)
	local profiles = SelectProfilesForGossip(targetBattleTag, GOSSIP_MAX_PROFILES_PER_MANIFEST)
	
	if #profiles == 0 then
		return
	end
	
	DebugPrint(string.format("Gossiping %d profile(s) to %s (%s)", #profiles, targetBattleTag, targetCharacter))
	
	for _, entry in ipairs(profiles) do
		local battleTag = entry.battleTag
		local profile = entry.profile
		
		-- Send alias update
		local aliasData = {
			battleTag = battleTag,
			alias = profile.alias,
			aliasUpdatedAt = profile.aliasUpdatedAt,
		}
		local aliasMessage = BuildMessage(MSG_TYPE.ALIAS_UPDATE, aliasData)
		if aliasMessage then
			SendMessage(aliasMessage, "WHISPER", targetCharacter)
		end
		
		-- Send characters update
		local characters = {}
		if profile.characters then
			for _, char in pairs(profile.characters) do
				table.insert(characters, {
					name = char.name,
					realm = char.realm or "",
					addedAt = char.addedAt,
				})
			end
		end
		
		if #characters > 0 then
			local charsData = {
				battleTag = battleTag,
				characters = characters,
			}
			local charsMessage = BuildMessage(MSG_TYPE.CHARS_UPDATE, charsData)
			if charsMessage then
				SendMessage(charsMessage, "WHISPER", targetCharacter)
			end
		end
		
		-- Update gossip tracking (mark as gossiped to this BattleTag)
		lastGossip[targetBattleTag][battleTag] = true
		
		DebugPrint(string.format("  Gossiped %s (%s) with %d chars", battleTag, profile.alias, #characters))
	end
end

--- Handle incoming MANIFEST message (CBOR format)
--- @param sender string The sender's character name
--- @param encoded string The CBOR-encoded payload
local function HandleManifest(sender, encoded)
	local data = ParsePayload(encoded)
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
	local cachedProfile = EndeavoringDB.global.profiles[battleTag]
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
		local message = BuildMessage(MSG_TYPE.REQUEST_CHARS, requestData)
		if message then
			DebugPrint(string.format("Sending REQUEST_CHARS to %s (after: %d)", battleTag, afterTimestamp))
			SendMessage(message, "WHISPER", sender)
		end
	end
	
	-- Gossip Protocol
	GossipProfilesToPlayer(battleTag, sender)
end

--- Handle incoming REQUEST_CHARS message (CBOR format)
--- @param sender string The sender's character name
--- @param encoded string The CBOR-encoded payload
local function HandleRequestChars(sender, encoded)
	local data = ParsePayload(encoded)
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
	
	-- Send CHARS_UPDATE
	local myProfile = ns.DB.GetMyProfile()
	if not myProfile then
		return
	end
	
	local responseData = {
		battleTag = myProfile.battleTag,
		characters = chars,
	}
	
	local message = BuildMessage(MSG_TYPE.CHARS_UPDATE, responseData)
	if not message then
		print(ERROR .. " Failed to build CHARS_UPDATE message")
		return
	end
	
	DebugPrint(string.format("Sending CHARS_UPDATE (%d bytes, %d chars) to %s", #message, #chars, sender))
	SendMessage(message, "WHISPER", sender)
end

--- Handle incoming ALIAS_UPDATE message (CBOR format)
--- @param sender string The sender's character name
--- @param encoded string The CBOR-encoded payload  
local function HandleAliasUpdate(sender, encoded)
	local data = ParsePayload(encoded)
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
	
	-- Update alias in database
	local success = ns.DB.UpdateProfileAlias(battleTag, alias, aliasUpdatedAt)
	if success then
		DebugPrint(string.format("Updated alias for %s to '%s'", battleTag, alias))
	end
end

--- Handle incoming CHARS_UPDATE message (CBOR format)
--- @param sender string The sender's character name
--- @param encoded string The CBOR-encoded payload
local function HandleCharsUpdate(sender, encoded)
	local data = ParsePayload(encoded)
	if not data then
		return
	end
	
	local battleTag = data.battleTag
	local characters = data.characters or {}
	
	if not ValidateBattleTag(battleTag) then
		return
	end
	
	-- Don't allow updates to our own profile
	local myBattleTag = ns.DB.GetMyBattleTag()
	if battleTag == myBattleTag then
		return
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
		end
	end
end

--- Route message to appropriate handler
--- @param messageType string The message type
--- @param sender string The sender's character name
--- @param parts table The message parts
local function RouteMessage(messageType, sender, parts)
	DebugPrint(string.format("Received message of type %s from %s", messageType, sender))
	
	-- All handlers use CBOR format
	if messageType == MSG_TYPE.MANIFEST then
		HandleManifest(sender, parts[1])
	elseif messageType == MSG_TYPE.REQUEST_CHARS then
		HandleRequestChars(sender, parts[1])
	elseif messageType == MSG_TYPE.ALIAS_UPDATE then
		HandleAliasUpdate(sender, parts[1])
	elseif messageType == MSG_TYPE.CHARS_UPDATE then
		HandleCharsUpdate(sender, parts[1])
	end
end

--- Handle incoming addon message
--- @param prefix string The addon prefix
--- @param message string The message content
--- @param channel string The channel the message was sent on
--- @param sender string The sender's character name
local function OnAddonMessage(prefix, message, channel, sender)
	if prefix ~= ADDON_PREFIX then
		return
	end
	
	local messageType, parts = ParseMessage(message)
	if not messageType or not parts then
		return
	end
	
	RouteMessage(messageType, sender, parts)
end

--- Broadcast MANIFEST to guild
function Sync.SendManifest()
	local myProfile = ns.DB.GetMyProfile()
	if not myProfile then
		return
	end
	
	-- Build MANIFEST message with CBOR payload
	local data = {
		battleTag = myProfile.battleTag,
		alias = myProfile.alias,
		charsUpdatedAt = myProfile.charsUpdatedAt,
		aliasUpdatedAt = myProfile.aliasUpdatedAt,
	}
	
	local message = BuildMessage(MSG_TYPE.MANIFEST, data)
	if not message then
		print(ERROR .. " Failed to build MANIFEST message")
		return
	end
	
	SendMessage(message, CHANNEL_GUILD)
	lastManifestTime = time()
	
	DebugPrint("Broadcast MANIFEST to guild")
end

--- Debounced manifest broadcast (waits a few seconds before sending)
function Sync.SendManifestDebounced()
	-- Cancel any pending manifest
	if manifestDebounceTimer then
		manifestDebounceTimer:Cancel()
	end
	
	-- Schedule new manifest in 2 seconds
	manifestDebounceTimer = C_Timer.NewTimer(2, function()
		Sync.SendManifest()
		manifestDebounceTimer = nil
	end)
end

--- Handle guild roster update with debouncing and random delay
function Sync.OnGuildRosterUpdate()
	-- Cancel any pending roster update
	if guildRosterDebounceTimer then
		guildRosterDebounceTimer:Cancel()
	end
	
	-- Debounce for 5 seconds, then schedule manifest with random delay
	guildRosterDebounceTimer = C_Timer.NewTimer(5, function()
		-- Schedule manifest broadcast with random delay (2-10 seconds)
		local randomDelay = math.random(2, 10)
		C_Timer.NewTimer(randomDelay, function()
			Sync.SendManifest()
		end)
		guildRosterDebounceTimer = nil
	end)
end

--- Get gossip statistics for debugging
--- @return table stats Gossip statistics including player count and gossip details
function Sync.GetGossipStats()
	local totalPlayers = 0
	local totalGossips = 0
	local gossipByPlayer = {}
	
	for playerBattleTag, profiles in pairs(lastGossip) do
		local profileCount = 0
		for _ in pairs(profiles) do
			profileCount = profileCount + 1
			totalGossips = totalGossips + 1
		end
		if profileCount > 0 then
			totalPlayers = totalPlayers + 1
			gossipByPlayer[playerBattleTag] = profileCount
		end
	end
	
	return {
		totalPlayers = totalPlayers,
		totalGossips = totalGossips,
		gossipByPlayer = gossipByPlayer,
	}
end

--- Register event listener for addon messages
function Sync.RegisterListener()
	if not initialized then
		Sync.Init()
	end
	
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("CHAT_MSG_ADDON")
	frame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
		if event == "CHAT_MSG_ADDON" then
			OnAddonMessage(prefix, message, channel, sender)
		end
	end)
end
