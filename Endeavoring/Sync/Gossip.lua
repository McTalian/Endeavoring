---@type string
local addonName = select(1, ...)
---@class HDENamespace
local ns = select(2, ...)

local Gossip = {}
ns.Gossip = Gossip

-- Shortcuts
local DebugPrint = ns.DebugPrint

--[[
Gossip Protocol - Opportunistic Profile Propagation

PURPOSE:
Implements gossip-based profile propagation to spread player information across
the guild without requiring direct REQUEST/RESPONSE cycles. When Alice tells Bob
about her profile, Bob can gossip cached profiles (Carol, Dave) back to Alice.

BENEFITS:
- Transitive propagation: A→B→C spreads profiles without A contacting C directly
- Handles alt-swapping elegantly via BattleTag tracking
- Reduces latency for newly joined guild members
- Self-healing via bidirectional correction (stale data triggers back-gossip)

RATE LIMITING:
- Max 3 profiles per MANIFEST received (conservative to avoid spam)
- Per-session tracking (resets on reload) prevents repeated gossip

TRACKING:
lastGossip[senderBattleTag][profileBattleTag] = true
Tracks which profiles we've gossiped to which players this session.
Future enhancement could prioritize profiles sender doesn't know.
--]]

-- Configuration
local MAX_PROFILES_PER_MANIFEST = 3  -- Max profiles to gossip per MANIFEST received

-- Message types (must match protocol constants)
local MSG_TYPE = {
	ALIAS_UPDATE = "A",
	CHARS_UPDATE = "C",
}

-- State
-- Gossip tracking: lastGossip[senderBattleTag][profileBattleTag] = true
-- Tracks which profiles we've gossiped to which players THIS SESSION
-- Per-session only (not persisted) - resets on reload/relog
local lastGossip = {}

--- Initialize gossip tracking for a player
--- @param battleTag string The BattleTag to initialize tracking for
local function InitializeTracking(battleTag)
	if not lastGossip[battleTag] then
		lastGossip[battleTag] = {}
	end
end

--- Mark that a player knows about a profile (for gossip tracking)
--- @param knowerBattleTag string The BattleTag of the player who knows
--- @param profileBattleTag string The BattleTag of the profile they know about
function Gossip.MarkKnownProfile(knowerBattleTag, profileBattleTag)
	InitializeTracking(knowerBattleTag)
	lastGossip[knowerBattleTag][profileBattleTag] = true
end

--- Check if we've already gossiped a profile to a player
--- @param targetBattleTag string The BattleTag we might gossip to
--- @param profileBattleTag string The profile BattleTag we might gossip
--- @return boolean hasGossiped Whether we've already gossiped this profile
function Gossip.HasGossipedProfile(targetBattleTag, profileBattleTag)
	return lastGossip[targetBattleTag] and lastGossip[targetBattleTag][profileBattleTag] or false
end

--- Select profiles to gossip to a player
--- Prioritizes recently updated profiles that haven't been gossiped yet
--- @param targetBattleTag string The BattleTag to gossip to
--- @param maxCount number Maximum number of profiles to return
--- @return table profiles Array of {battleTag, profile} to gossip
local function SelectProfilesForGossip(targetBattleTag, maxCount)
	local myBattleTag = ns.DB.GetMyBattleTag()
	local allProfiles = ns.DB.GetAllProfiles()
	
	local candidates = {}
	for battleTag, profile in pairs(allProfiles) do
		-- Only gossip profiles that are:
		-- 1. Not our own profile
		-- 2. Not the target player's profile (don't tell them about themselves)
		-- 3. Haven't been gossiped to this player yet this session
		if 
			battleTag ~= myBattleTag and
			battleTag ~= targetBattleTag and
			not Gossip.HasGossipedProfile(targetBattleTag, battleTag)
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

--- Gossip cached profiles to a player
--- Sends ALIAS_UPDATE and CHARS_UPDATE messages for selected profiles
--- @param targetBattleTag string The BattleTag to gossip to
--- @param targetCharacter string The character name to send whispers to
function Gossip.SendProfilesToPlayer(targetBattleTag, targetCharacter)
	local profiles = SelectProfilesForGossip(targetBattleTag, MAX_PROFILES_PER_MANIFEST)
	
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
		local aliasMessage = ns.Sync.BuildMessage(MSG_TYPE.ALIAS_UPDATE, aliasData)
		if aliasMessage then
			ns.Sync.SendMessage(aliasMessage, "WHISPER", targetCharacter)
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
			ns.Coordinator.SendCharsUpdate(battleTag, characters, profile.charsUpdatedAt or 0, "WHISPER", targetCharacter)
		end
		
		-- Update gossip tracking (mark as gossiped to this BattleTag)
		Gossip.MarkKnownProfile(targetBattleTag, battleTag)
		
		DebugPrint(string.format("  Gossiped %s (%s) with %d chars", battleTag, profile.alias, #characters))
	end
end

--- Get gossip statistics for debugging
--- @return table stats Gossip statistics including player count and gossip details
function Gossip.GetStats()
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
