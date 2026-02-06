---@type string
local addonName = select(1, ...)
---@class HDENamespace
local ns = select(2, ...)

local Sync = {}
ns.Sync = Sync

-- Constants
local ADDON_PREFIX = "Ndvrng"
local CHANNEL_GUILD = "GUILD"

-- Message types
local MSG_TYPE = {
	MANIFEST = "MANIFEST",
	REQUEST_ALIAS = "REQUEST_ALIAS",
	REQUEST_CHARS = "REQUEST_CHARS",
	ALIAS_UPDATE = "ALIAS_UPDATE",
	CHARS_UPDATE = "CHARS_UPDATE",
}

-- State
local initialized = false
local lastManifestTime = 0
local manifestDebounceTimer = nil
local guildRosterDebounceTimer = nil

--- Initialize the sync service
function Sync.Init()
	if initialized then
		return
	end
	
	-- Register addon message prefix
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		local success = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
		if not success then
			print("|cffff0000Endeavoring:|r Failed to register addon message prefix")
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
		print("|cffff0000Endeavoring:|r Invalid timestamp")
		return false
	end
	
	-- Reasonable range: 2020-01-01 to 2040-01-01
	local MIN_TIMESTAMP = 1577836800  -- 2020-01-01
	local MAX_TIMESTAMP = 2209032000  -- 2040-01-01
	
	return timestamp >= MIN_TIMESTAMP and timestamp <= MAX_TIMESTAMP
end

--- Send a message via addon communication
--- @param message string The message to send
--- @param channel string The channel to send on (default: GUILD)
--- @param target string|nil The target player for whisper messages
local function SendMessage(message, channel, target)
	if not initialized then
		return
	end
	
	channel = channel or CHANNEL_GUILD
	
	if C_ChatInfo and C_ChatInfo.SendAddonMessage then
		print(string.format("|cff00ff00Endeavoring:|r Sending message `%s` on channel %s", message, channel))
		C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, channel, target)
	end
end

--- Handle incoming MANIFEST message
--- @param sender string The sender's character name
--- @param parts table Message parts: [battleTag, alias, charsUpdatedAt, aliasUpdatedAt]
local function HandleManifest(sender, parts)
	if #parts < 4 then
		return -- Malformed message
	end
	
	local battleTag = parts[1]
	local alias = parts[2]
	local charsUpdatedAt = tonumber(parts[3])
	local aliasUpdatedAt = tonumber(parts[4])
	
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
		-- New player, request characters and update alias directly from manifest
		needsChars = true
		afterTimestamp = 0
		-- Update alias directly from manifest (no need to request it)
		ns.DB.UpdateProfileAlias(battleTag, alias, aliasUpdatedAt)
	else
		-- Check if alias is newer - update directly from manifest
		if aliasUpdatedAt > (cachedProfile.aliasUpdatedAt or 0) then
			ns.DB.UpdateProfileAlias(battleTag, alias, aliasUpdatedAt)
		end
		
		-- Check if characters are newer
		if charsUpdatedAt > (cachedProfile.charsUpdatedAt or 0) then
			needsChars = true
			afterTimestamp = cachedProfile.charsUpdatedAt or 0
		end
	end
	
	-- Request characters if needed (send via WHISPER to reduce guild spam)
	if needsChars then
		local message = string.format("%s|%s|%d", MSG_TYPE.REQUEST_CHARS, battleTag, afterTimestamp)
		print(string.format("|cff00ff00Endeavoring:|r Sending REQUEST_CHARS to %s (after: %d)", battleTag, afterTimestamp))
		SendMessage(message, "WHISPER", sender)
	end
end

--- Handle incoming REQUEST_ALIAS message (DEPRECATED - alias now sent in MANIFEST)
--- @param sender string The sender's character name
--- @param parts table Message parts: [battleTag]
local function HandleRequestAlias(sender, parts)
	-- This handler kept for backwards compatibility but should not be called
	print("|cffff8800Endeavoring:|r Received deprecated REQUEST_ALIAS message")
end

--- Handle incoming REQUEST_CHARS message
--- @param sender string The sender's character name
--- @param parts table Message parts: [battleTag, afterTimestamp]
local function HandleRequestChars(sender, parts)
	if #parts < 2 then
		print("|cffff0000Endeavoring:|r REQUEST_CHARS malformed")
		return
	end
	
	local battleTag = parts[1]
	local afterTimestamp = tonumber(parts[2])
	print(string.format("|cff00ff00Endeavoring:|r Received REQUEST_CHARS from %s for %s (after: %s)", sender, battleTag, tostring(afterTimestamp)))
	
	-- Only respond if they're asking about us
	local myBattleTag = ns.DB.GetMyBattleTag()
	if battleTag ~= myBattleTag then
		print(string.format("|cffff0000Endeavoring:|r Not for us (ours: %s, requested: %s)", myBattleTag or "nil", battleTag))
		return
	end
	
	if not afterTimestamp or (not ValidateTimestamp(afterTimestamp) and afterTimestamp ~= 0) then
		print("|cffff0000Endeavoring:|r Invalid timestamp")
		return
	end
	
	-- Get characters to send (delta or full)
	local characters = ns.DB.GetCharactersAddedAfter(afterTimestamp)
	print(string.format("|cff00ff00Endeavoring:|r Found %d character(s) to send", #characters))
	if #characters == 0 then
		print("|cffff0000Endeavoring:|r No characters to send")
		return -- No characters to send
	end
	
	-- Build character data string: char1:realm1:addedAt,char2:realm2:addedAt,...
	local charParts = {}
	for _, char in ipairs(characters) do
		-- Ensure realm is not nil (use empty string as fallback)
		local realm = char.realm or ""
		table.insert(charParts, string.format("%s:%s:%d", char.name, realm, char.addedAt))
	end
	local charData = table.concat(charParts, ",")
	
	-- Build CHARS_UPDATE message: CHARS_UPDATE|battleTag|charData
	local myProfile = ns.DB.GetMyProfile()
	if not myProfile then
		return
	end
	
	local message = string.format("%s|%s|%s",
		MSG_TYPE.CHARS_UPDATE,
		myProfile.battleTag,
		charData
	)
	
	print(string.format("|cff00ff00Endeavoring:|r Sending CHARS_UPDATE (%d bytes) to %s", #message, sender))
	-- TODO: Handle chunking if message exceeds 255 bytes
	-- For now, just send it (will implement chunking later if needed)
	SendMessage(message, "WHISPER", sender)
end

--- Handle incoming ALIAS_UPDATE message
--- @param sender string The sender's character name
--- @param parts table Message parts: [battleTag, alias, aliasUpdatedAt]
local function HandleAliasUpdate(sender, parts)
	if #parts < 3 then
		return
	end
	
	local battleTag = parts[1]
	local alias = parts[2]
	local aliasUpdatedAt = tonumber(parts[3])
	
	if not ValidateBattleTag(battleTag) or not aliasUpdatedAt or not ValidateTimestamp(aliasUpdatedAt) then
		return
	end
	
	-- Don't allow updates to our own profile
	local myBattleTag = ns.DB.GetMyBattleTag()
	if battleTag == myBattleTag then
		return
	end
	
	-- Update the profile alias
	local success = ns.DB.UpdateProfileAlias(battleTag, alias, aliasUpdatedAt)
	if success then
		print(string.format("|cff00ff00Endeavoring:|r Updated alias for %s to %s", battleTag, alias))
	end
end

--- Handle incoming CHARS_UPDATE message
--- @param sender string The sender's character name
--- @param parts table Message parts: [battleTag, charData] or [chunkInfo, battleTag, charData]
local function HandleCharsUpdate(sender, parts)
	if #parts < 2 then
		return
	end
	
	-- TODO: Handle chunking (parts[1] might be "1/3" etc)
	-- For now, assume single message
	local battleTag = parts[1]
	local charData = parts[2]
	
	if not ValidateBattleTag(battleTag) then
		return
	end
	
	-- Don't allow updates to our own profile
	local myBattleTag = ns.DB.GetMyBattleTag()
	if battleTag == myBattleTag then
		return
	end
	
	-- Parse character data: char1:realm1:addedAt,char2:realm2:addedAt,...
	local characters = {}
	for charInfo in string.gmatch(charData, "[^,]+") do
		local charParts = {strsplit(":", charInfo)}
		if #charParts == 3 then
			local name = charParts[1]
			local realm = charParts[2] or "" -- Allow empty realm
			local addedAt = tonumber(charParts[3])
			
			if name and name ~= "" and addedAt and ValidateTimestamp(addedAt) then
				table.insert(characters, {
					name = name,
					realm = realm,
					addedAt = addedAt,
				})
			end
		end
	end
	
	-- Update profile with characters
	if #characters > 0 then
		local success = ns.DB.AddCharactersToProfile(battleTag, characters)
		if success then
			print(string.format("|cff00ff00Endeavoring:|r Updated %d character(s) for %s", #characters, battleTag))
		end
	end
end

--- Route message to appropriate handler
--- @param messageType string The message type
--- @param sender string The sender's character name
--- @param parts table The message parts
local function RouteMessage(messageType, sender, parts)
	print(string.format("|cff00ff00Endeavoring:|r Received message of type %s from %s", messageType, sender))
	if messageType == MSG_TYPE.MANIFEST then
		HandleManifest(sender, parts)
	elseif messageType == MSG_TYPE.REQUEST_ALIAS then
		HandleRequestAlias(sender, parts)
	elseif messageType == MSG_TYPE.REQUEST_CHARS then
		HandleRequestChars(sender, parts)
	elseif messageType == MSG_TYPE.ALIAS_UPDATE then
		HandleAliasUpdate(sender, parts)
	elseif messageType == MSG_TYPE.CHARS_UPDATE then
		HandleCharsUpdate(sender, parts)
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
	
	-- Build MANIFEST message: MANIFEST|battleTag|alias|charsUpdatedAt|aliasUpdatedAt
	local message = string.format("%s|%s|%s|%d|%d",
		MSG_TYPE.MANIFEST,
		myProfile.battleTag,
		myProfile.alias,
		myProfile.charsUpdatedAt,
		myProfile.aliasUpdatedAt
	)
	
	SendMessage(message, CHANNEL_GUILD)
	lastManifestTime = time()
	
	print("|cff00ff00Endeavoring:|r Broadcast MANIFEST to guild")
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
