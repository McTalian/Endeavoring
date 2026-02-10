---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)

local PlayerInfo = {}
ns.PlayerInfo = PlayerInfo

--- Get the current player's BattleTag
--- @return string|nil battleTag The player's BattleTag or nil if not available
function PlayerInfo.GetBattleTag()
	local battleTag = select(2, BNGetInfo())
	return battleTag
end

--- Get the current character's name
--- @return string characterName The character name
function PlayerInfo.GetCharacterName()
  return PlayerInfo.GetCharacterInfo().name
end

--- Get the current player's name (simple wrapper for UnitName)
--- @return string playerName The player's name
function PlayerInfo.GetPlayerName()
	return UnitName("player")
end

--- Check if a player name matches the current player
--- @param playerName string The player name to check
--- @return boolean isLocalPlayer True if the name matches the current player
function PlayerInfo.IsLocalPlayer(playerName)
	return playerName == UnitName("player")
end

--- Get character info for the current player
--- @return table characterInfo Character information table with name and realm
function PlayerInfo.GetCharacterInfo()
	local name, realm = UnitNameUnmodified("player")
	-- Fallback to GetNormalizedRealmName if realm is nil
	if not realm or realm == "" then
		realm = GetNormalizedRealmName()
	end
	return {
		name = name,
		realm = realm,
	}
end
