---@type string
local addonName = select(1, ...)
---@class HDENamespace
local ns = select(2, ...)

local Sync = {}
ns.Sync = Sync

-- Shortcuts
local ERROR = ns.Constants.PREFIX_ERROR
local DebugPrint = ns.DebugPrint

-- Constants
local ADDON_PREFIX = "Ndvrng"
local CHANNEL_GUILD = "GUILD"
local MESSAGE_SIZE_LIMIT = 255  -- WoW API hard limit for addon messages
local CHARS_PER_MESSAGE = 5     -- Max characters to send in one CHARS_UPDATE message

-- Guild roster manifest throttling
local GUILD_ROSTER_MIN_INTERVAL = 60  -- Min seconds between roster-triggered manifests
local MANIFEST_HEARTBEAT_INTERVAL = 300  -- Send manifest every 5 minutes if no other activity

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
local lastRosterManifestTime = 0  -- Track roster-triggered manifests separately
local manifestDebounceTimer = nil
local guildRosterDebounceTimer = nil
local guildRosterManifestTimer = nil
local heartbeatTimer = nil
-- Gossip tracking: lastGossip[senderBattleTag][profileBattleTag] = true
-- Tracks which profiles we've gossiped to which players THIS SESSION
-- Per-session only (not persisted) - resets on reload/relog
local lastGossip = {}
-- Character-to-BattleTag reverse lookup cache for O(1) lookups
-- Cache is rebuilt on demand when stale
local characterToBattleTagCache = {}
local cacheIsStale = true

--- Rebuild character-to-BattleTag cache
local function RebuildCharacterCache()
	characterToBattleTagCache = {}
	local allProfiles = ns.DB.GetAllProfiles()
	
	for battleTag, profile in pairs(allProfiles) do
		if profile.characters then
			for _, char in pairs(profile.characters) do
				characterToBattleTagCache[char.name] = battleTag
			end
		end
	end
	
	cacheIsStale = false
end

--- Look up a player's BattleTag by character name (cached)
--- @param characterName string The character name to search for
--- @return string|nil battleTag The BattleTag if found, nil otherwise
local function FindBattleTagByCharacter(characterName)
	if cacheIsStale then
		RebuildCharacterCache()
	end
	
	return characterToBattleTagCache[characterName]
end

--- Mark cache as stale (call when profile data changes)
local function InvalidateCharacterCache()
	cacheIsStale = true
end

--- Initialize gossip tracking for a player
--- @param battleTag string The BattleTag to initialize tracking for
local function InitializeGossipTracking(battleTag)
	if not lastGossip[battleTag] then
		lastGossip[battleTag] = {}
	end
end

--- Mark that a player knows about a profile
--- @param knowerBattleTag string The BattleTag of the player who knows
--- @param profileBattleTag string The BattleTag of the profile they know about
local function MarkProfileAsKnownBy(knowerBattleTag, profileBattleTag)
	InitializeGossipTracking(knowerBattleTag)
	lastGossip[knowerBattleTag][profileBattleTag] = true
end

--- Check if we've already gossiped a profile to a player
--- @param targetBattleTag string The BattleTag we might gossip to
--- @param profileBattleTag string The profile BattleTag we might gossip
--- @return boolean hasGossiped Whether we've already gossiped this profile
local function HasGossipedProfile(targetBattleTag, profileBattleTag)
	return lastGossip[targetBattleTag] and lastGossip[targetBattleTag][profileBattleTag] or false
end

--- Start heartbeat timer for periodic manifests
local function StartHeartbeat()
	if heartbeatTimer then
		return
	end
	
	-- Check every minute if we need to send a heartbeat manifest
	heartbeatTimer = C_Timer.NewTicker(60, function()
		local now = time()
		if now - lastManifestTime >= MANIFEST_HEARTBEAT_INTERVAL then
			DebugPrint(string.format("Heartbeat: No manifest in %d seconds, sending one", now - lastManifestTime))
			Sync.SendManifest()
		end
	end)
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
	
	-- Start heartbeat timer for periodic sync
	StartHeartbeat()
	
	initialized = true
end

--- Parse an encoded message and extract message type
--- Message type is embedded in the CBOR payload
--- @param encoded string The encoded message
--- @return string|nil messageType The message type (e.g., MSG_TYPE.MANIFEST)
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

--- Build a message with CBOR-encoded payload
--- Message type is included in the CBOR payload to avoid string+binary mixing
--- @param messageType string The message type (e.g., MSG_TYPE.MANIFEST)
--- @param data table The data to encode
--- @return string|nil message The complete encoded message, or nil on encoding failure
local function BuildMessage(messageType, data)
	-- Include message type in the payload
	data.type = messageType
	
	local encoded, err = ns.MessageCodec.Encode(data)
	if not encoded then
		DebugPrint(string.format("Failed to encode message: %s", err or "unknown error"), "ff0000")
		return nil
	end

	-- Warn if message is approaching or exceeding size limit
	if #encoded > MESSAGE_SIZE_LIMIT then
		DebugPrint(string.format("WARNING: Built message size (%d bytes) exceeds limit (%d bytes)!", #encoded, MESSAGE_SIZE_LIMIT), "ff0000")
	elseif #encoded > (MESSAGE_SIZE_LIMIT * 0.9) then
		-- Warn if within 10% of limit
		DebugPrint(string.format("WARNING: Built message size (%d bytes) is close to limit (%d bytes)", #encoded, MESSAGE_SIZE_LIMIT), "ff8800")
	end
	
	return encoded
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
	
	-- Pre-flight validation: check for chat messaging lockdown (instances, restricted zones)
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		local isRestricted, reason = C_ChatInfo.InChatMessagingLockdown()
		if isRestricted then
			DebugPrint(string.format("Skipping message send - chat messaging lockdown active (reason: %s)", tostring(reason or "unknown")), "ff8800")
			return false
		end
	end
	
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
				[Enum.SendAddonMessageResult.AddOnMessageLockdown] = "AddOnMessageLockdown",
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
	InitializeGossipTracking(targetBattleTag)
	
	-- Build list of profiles eligible for gossip
	for battleTag, profile in pairs(allProfiles) do
		if
			-- Skip our own profile (already sent in MANIFEST)
			battleTag ~= myBattleTag and
			-- Skip the recipient's profile (they already know their own data)
			battleTag ~= targetBattleTag and
			-- Only gossip if we haven't gossiped this profile to this player this session
			not HasGossipedProfile(targetBattleTag, battleTag)
		then 
			table.insert(candidates, {
				battleTag = battleTag,
				profile = profile,
				lastUpdate = math.max(profile.aliasUpdatedAt or 0, profile.charsUpdatedAt or 0)
			})
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

--- Send CHARS_UPDATE message(s), chunking if necessary
--- @param battleTag string The BattleTag of the profile
--- @param characters table Array of characters to send
--- @param charsUpdatedAt number The charsUpdatedAt timestamp for this profile
--- @param channel string Channel to send on
--- @param target string|nil Target player (for whispers)
--- @return boolean success Whether all messages were sent successfully
local function SendCharsUpdate(battleTag, characters, charsUpdatedAt, channel, target)
	local totalChars = #characters
	if totalChars == 0 then
		return true
	end
	
	-- Chunk characters into manageable pieces
	for i = 1, totalChars, CHARS_PER_MESSAGE do
		local chunk = {}
		for j = i, math.min(i + CHARS_PER_MESSAGE - 1, totalChars) do
			table.insert(chunk, characters[j])
		end
		
		local charsData = {
			battleTag = battleTag,
			characters = chunk,
			charsUpdatedAt = charsUpdatedAt,
		}
		
		local message = BuildMessage(MSG_TYPE.CHARS_UPDATE, charsData)
		if not message then
			print(ERROR .. " Failed to build CHARS_UPDATE message")
			return false
		end
		
		local chunkNum = math.floor((i - 1) / CHARS_PER_MESSAGE) + 1
		local totalChunks = math.ceil(totalChars / CHARS_PER_MESSAGE)
		DebugPrint(string.format("Sending CHARS_UPDATE chunk %d/%d (%d bytes, %d chars)", chunkNum, totalChunks, #message, #chunk))
		
		if not SendMessage(message, channel, target) then
			return false
		end
	end
	
	return true
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
		---@type Profile
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
		
		-- Send characters update (with chunking if needed)
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
			SendCharsUpdate(battleTag, characters, profile.charsUpdatedAt or 0, "WHISPER", targetCharacter)
		end
		
		-- Update gossip tracking (mark as gossiped to this BattleTag)
		MarkProfileAsKnownBy(targetBattleTag, battleTag)
		
		DebugPrint(string.format("  Gossiped %s (%s) with %d chars", battleTag, profile.alias, #characters))
	end
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
		DebugPrint("Silly goose! Received our own MANIFEST, ignoring", "ff8800")
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
	SendCharsUpdate(myProfile.battleTag, chars, myProfile.charsUpdatedAt, "WHISPER", sender)
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
	local senderBattleTag = FindBattleTagByCharacter(sender)
	
	-- Check if we have this profile and if it's stale
	local existingProfile = ns.DB.GetProfile(battleTag)
	if existingProfile then
		-- Track that sender knows about this profile
		if senderBattleTag then
			MarkProfileAsKnownBy(senderBattleTag, battleTag)
			DebugPrint(string.format("Tracked: %s knows about %s", senderBattleTag, battleTag))
		end
		
		-- Check if sender has stale data
		if existingProfile.aliasUpdatedAt and existingProfile.aliasUpdatedAt > aliasUpdatedAt then
			DebugPrint(string.format("Sender has stale alias for %s (theirs: %d, ours: %d), gossiping back", 
				battleTag, aliasUpdatedAt, existingProfile.aliasUpdatedAt))
			
			-- Gossip back the newer version
			if senderBattleTag then
				local aliasData = {
					battleTag = battleTag,
					alias = existingProfile.alias,
					aliasUpdatedAt = existingProfile.aliasUpdatedAt,
				}
				local message = BuildMessage(MSG_TYPE.ALIAS_UPDATE, aliasData)
				if message then
					SendMessage(message, "WHISPER", sender)
					DebugPrint(string.format("Sent updated alias for %s back to %s", battleTag, sender))
				end
			end
			return  -- Don't update with stale data
		end
	end
	
	-- Update alias in database
	local success = ns.DB.UpdateProfileAlias(battleTag, alias, aliasUpdatedAt)
	if success then
		DebugPrint(string.format("Updated alias for %s to '%s'", battleTag, alias))
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
	local senderBattleTag = FindBattleTagByCharacter(sender)
	
	-- Check if we have this profile
	local existingProfile = ns.DB.GetProfile(battleTag)
	if existingProfile then
		-- Track that sender knows about this profile
		if senderBattleTag then
			MarkProfileAsKnownBy(senderBattleTag, battleTag)
			DebugPrint(string.format("Tracked: %s knows about %s", senderBattleTag, battleTag))
		end
		
		-- Check if sender has stale data by comparing charsUpdatedAt timestamps
		if existingProfile.charsUpdatedAt and existingProfile.charsUpdatedAt > senderCharsUpdatedAt then
			DebugPrint(string.format("Sender has stale characters for %s (theirs: %d, ours: %d), gossiping back",
				battleTag, senderCharsUpdatedAt, existingProfile.charsUpdatedAt))
			
			if senderBattleTag then
				-- Send all characters added after their timestamp
				local newerChars = ns.DB.GetProfileCharactersAddedAfter(battleTag, senderCharsUpdatedAt)
				
				if #newerChars > 0 then
					SendCharsUpdate(battleTag, newerChars, existingProfile.charsUpdatedAt, "WHISPER", sender)
					DebugPrint(string.format("Sent %d updated character(s) for %s back to %s", #newerChars, battleTag, sender))
				end
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
			InvalidateCharacterCache()
		end
	end
end

--- Route message to appropriate handler
--- @param messageType string The message type
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

--- Handle incoming addon message
--- @param prefix string The addon prefix
--- @param message string The encoded message content
--- @param channel string The channel the message was sent on
--- @param sender string The sender's character name
local function OnAddonMessage(prefix, message, channel, sender)
	if prefix ~= ADDON_PREFIX then
		return
	end
	
	local messageType, data = ParseMessage(message)
	if not messageType or not data then
		return
	end
	
	RouteMessage(messageType, sender, data)
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

--- Handle guild roster update with time-based sampling and debouncing
function Sync.OnGuildRosterUpdate()
	-- Time-based sampling: Only allow roster events to trigger manifest once per interval
	local now = time()
	if now - lastRosterManifestTime < GUILD_ROSTER_MIN_INTERVAL then
		DebugPrint(string.format("Roster event ignored (last roster manifest %ds ago, min interval %ds)", now - lastRosterManifestTime, GUILD_ROSTER_MIN_INTERVAL))
		return
	end
	
	-- Cancel any pending roster update
	if guildRosterDebounceTimer then
		guildRosterDebounceTimer:Cancel()
	end

	if guildRosterManifestTimer then
		guildRosterManifestTimer:Cancel()
	end
	
	-- Debounce for 5 seconds, then schedule manifest with random delay
	guildRosterDebounceTimer = C_Timer.NewTimer(5, function()
		-- Schedule manifest broadcast with random delay (2-10 seconds)
		local randomDelay = math.random(2, 10)
		guildRosterManifestTimer = C_Timer.NewTimer(randomDelay, function()
			Sync.SendManifest()
			lastRosterManifestTime = time()  -- Update roster manifest timestamp
			guildRosterManifestTimer = nil
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

--- Get sync timing statistics for debugging
--- @return table stats Timing statistics for manifest broadcasts
function Sync.GetSyncStats()
	local now = time()
	return {
		lastManifestTime = lastManifestTime,
		timeSinceLastManifest = now - lastManifestTime,
		lastRosterManifestTime = lastRosterManifestTime,
		timeSinceLastRosterManifest = now - lastRosterManifestTime,
		rosterMinInterval = GUILD_ROSTER_MIN_INTERVAL,
		heartbeatInterval = MANIFEST_HEARTBEAT_INTERVAL,
		nextHeartbeatIn = math.max(0, MANIFEST_HEARTBEAT_INTERVAL - (now - lastManifestTime)),
		nextRosterWindowIn = math.max(0, GUILD_ROSTER_MIN_INTERVAL - (now - lastRosterManifestTime)),
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
