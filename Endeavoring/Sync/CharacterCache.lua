---@type string
local addonName = select(1, ...)
---@class HDENamespace
local ns = select(2, ...)

local CharacterCache = {}
ns.CharacterCache = CharacterCache

--[[
Character-to-BattleTag Reverse Lookup Cache

PURPOSE:
Efficient O(1) character name → BattleTag lookups, avoiding expensive
O(profiles * characters) nested loops.

USAGE:
- Identify senders in gossip protocol (map character name to BattleTag)
- Leaderboard BattleTag resolution (map activity log character to BattleTag)
- Any feature that needs to resolve character → player mapping

INVALIDATION:
Cache is marked stale when profile data changes, and rebuilt lazily on next lookup.

FUTURE OPTIMIZATION:
Currently invalidates entire cache on any character update. Could be improved
with per-profile timestamp tracking for selective invalidation at scale (50+ profiles).
--]]

-- State
local cache = {}
local isStale = true

--- Rebuild the character-to-BattleTag cache from all profiles
--- Called automatically when cache is stale
local function Rebuild()
	cache = {}
	local allProfiles = ns.DB.GetAllProfiles()
	
	for battleTag, profile in pairs(allProfiles) do
		if profile.characters then
			for _, char in pairs(profile.characters) do
				cache[char.name] = battleTag
			end
		end
	end
	
	isStale = false
end

--- Look up a player's BattleTag by character name
--- @param characterName string The character name to search for
--- @return string|nil battleTag The BattleTag if found, nil otherwise
function CharacterCache.FindBattleTag(characterName)
	if isStale then
		Rebuild()
	end
	
	return cache[characterName]
end

--- Mark cache as stale (call when profile data changes)
--- Cache will be rebuilt on next lookup
function CharacterCache.Invalidate()
	isStale = true
end

--- Get cache statistics for debugging
--- @return table stats Cache statistics
function CharacterCache.GetStats()
	local characterCount = 0
	for _ in pairs(cache) do
		characterCount = characterCount + 1
	end
	
	return {
		characterCount = characterCount,
		isStale = isStale,
	}
end
