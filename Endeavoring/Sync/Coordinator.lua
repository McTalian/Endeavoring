---@type string
local addonName = select(1, ...)
---@class HDENamespace
local ns = select(2, ...)

local Coordinator = {}
ns.Coordinator = Coordinator

-- Shortcuts
local DebugPrint = ns.DebugPrint

--[[
Sync Coordinator - Orchestration & Timing

PURPOSE:
Manages the timing and orchestration of sync operations, including:
- Heartbeat manifests (periodic sync when idle)
- Roster event throttling (prevent spam)
- Debouncing logic (coalesce rapid events)
- Character list chunking (respect message size limits)

TIMING STRATEGY:
- Time-based sampling for roster events (max 1 per minute)
- Heartbeat ensures ongoing sync even when idle (every 5 minutes)
- Debouncing prevents rapid-fire events from spamming guild chat
- Random delays stagger manifests across guild members

DEPENDENCIES:
Coordinator depends on Services/Sync for actual message transmission
and protocol details (BuildMessage, SendMessage). This maintains proper
layering: Coordinator orchestrates, Sync handles low-level messaging.
--]]

-- Configuration
local GUILD_ROSTER_MIN_INTERVAL = 60  -- Min seconds between roster-triggered manifests
local MANIFEST_HEARTBEAT_INTERVAL = 300  -- Send manifest every 5 minutes if no other activity
local CHARS_PER_MESSAGE = 5  -- Max characters to send in one CHARS_UPDATE message

-- State
local lastManifestTime = 0
local lastRosterManifestTime = 0
local manifestDebounceTimer = nil
local guildRosterDebounceTimer = nil
local guildRosterManifestTimer = nil
local heartbeatTimer = nil

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
			Coordinator.SendManifest()
		end
	end)
end

--- Initialize the coordinator
function Coordinator.Init()
	StartHeartbeat()
end

--- Send a character list update with automatic chunking
--- Respects message size limits by sending characters in chunks
--- @param battleTag string The BattleTag of the profile
--- @param characters table Array of character objects
--- @param charsUpdatedAt number Timestamp of the character list
--- @param channel string The channel to send on (WHISPER, GUILD)
--- @param target string|nil The target player (for WHISPER channel)
--- @return boolean success Whether all messages were sent successfully
function Coordinator.SendCharsUpdate(battleTag, characters, charsUpdatedAt, channel, target)
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
		
		local message = ns.Sync.BuildMessage("C", charsData)  -- MSG_TYPE.CHARS_UPDATE = "C"
		if not message then
			print(ns.Constants.PREFIX_ERROR .. " Failed to build CHARS_UPDATE message")
			return false
		end
		
		local chunkNum = math.floor((i - 1) / CHARS_PER_MESSAGE) + 1
		local totalChunks = math.ceil(totalChars / CHARS_PER_MESSAGE)
		DebugPrint(string.format("Sending CHARS_UPDATE chunk %d/%d (%d bytes, %d chars)", chunkNum, totalChunks, #message, #chunk))
		
		if not ns.Sync.SendMessage(message, channel, target) then
			return false
		end
	end
	
	return true
end

--- Build and send MANIFEST to guild
function Coordinator.SendManifest()
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
	
	local message = ns.Sync.BuildMessage("M", data)  -- MSG_TYPE.MANIFEST = "M"
	if not message then
		print(ns.Constants.PREFIX_ERROR .. " Failed to build MANIFEST message")
		return
	end
	
	ns.Sync.SendMessage(message, "GUILD")
	lastManifestTime = time()
	
	DebugPrint("Broadcast MANIFEST to guild")
end

--- Debounced manifest broadcast (waits a few seconds before sending)
function Coordinator.SendManifestDebounced()
	-- Cancel any pending manifest
	if manifestDebounceTimer then
		manifestDebounceTimer:Cancel()
	end
	
	-- Schedule new manifest in 2 seconds
	manifestDebounceTimer = C_Timer.NewTimer(2, function()
		Coordinator.SendManifest()
		manifestDebounceTimer = nil
	end)
end

--- Handle guild roster update with time-based sampling and debouncing
function Coordinator.OnGuildRosterUpdate()
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
			Coordinator.SendManifest()
			lastRosterManifestTime = time()  -- Update roster manifest timestamp
			guildRosterManifestTimer = nil
		end)
		guildRosterDebounceTimer = nil
	end)
end

--- Get sync timing statistics for debugging
--- @return table stats Timing statistics for manifest broadcasts
function Coordinator.GetSyncStats()
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
