---@type string
local addonName = select(1, ...)
---@class HDENamespace
local ns = select(2, ...)

---@class Character
---@field name string Character name
---@field realm string Realm name
---@field addedAt number Unix timestamp when character was registered

---@class Profile
---@field battleTag string Player's BattleTag
---@field alias string Display name (defaults to BattleTag)
---@field aliasUpdatedAt number Timestamp of last alias change
---@field characters table<string, Character> Characters keyed by character name
---@field charsUpdatedAt number Timestamp of most recent character addition (max of character.addedAt)

---@class EndeavoringDB
---@field global table Global scope data
---@field global.myProfile Profile|nil Player's authoritative data (never synced from others)
---@field global.profiles table<string, Profile> Synced profiles from other players (keyed by BattleTag)
---@field global.version number Schema version for migrations

-- See .github/docs/database-schema.md for detailed schema documentation

local DB = {}
ns.DB = DB

local ERROR = ns.Constants.PREFIX_ERROR
local INFO = ns.Constants.PREFIX_INFO

local DEFAULT_DB = {
	global = {
		myProfile = nil,
		profiles = {},
		verboseDebug = false,
		version = 1
	}
}

--- Initialize the database
function DB.Init()
	if not EndeavoringDB then
		EndeavoringDB = CopyTable(DEFAULT_DB)
	end
	
	-- Ensure global structure exists
	if not EndeavoringDB.global then
		EndeavoringDB.global = {}
	end
	
	-- Migration logic can go here in the future
	if not EndeavoringDB.global.version then
		EndeavoringDB.global.version = 1
	end
	
	if not EndeavoringDB.global.profiles then
		EndeavoringDB.global.profiles = {}
	end
	
	if EndeavoringDB.global.verboseDebug == nil then
		EndeavoringDB.global.verboseDebug = false
	end
	
	-- myProfile will be initialized on first character login
end

--- Register the current character to the player's BattleTag
--- @return boolean success Whether the registration was successful
function DB.RegisterCurrentCharacter()
	local battleTag = ns.PlayerInfo.GetBattleTag()
	if not battleTag then
		print(ERROR .. " Unable to register character: BattleTag not found. Make sure you're logged in to Battle.net.")
		return false
	end
	
	local characterInfo = ns.PlayerInfo.GetCharacterInfo()
	local timestamp = time()
	
	-- Initialize myProfile if it doesn't exist
	if not EndeavoringDB.global.myProfile then
		EndeavoringDB.global.myProfile = {
			battleTag = battleTag,
			alias = battleTag, -- Default to BattleTag
			aliasUpdatedAt = timestamp,
			characters = {},
			charsUpdatedAt = timestamp
		}
	end
	
	local myProfile = EndeavoringDB.global.myProfile
	
	-- Check if character already exists
	local isNewCharacter = not myProfile.characters[characterInfo.name]
	
	-- Register character with addedAt timestamp
	if isNewCharacter then
		myProfile.characters[characterInfo.name] = {
			name = characterInfo.name,
			realm = characterInfo.realm,
			addedAt = timestamp,
		}
		-- Update profileʼs characters timestamp
		myProfile.charsUpdatedAt = timestamp
		print(INFO .. " New Character registered: " .. characterInfo.name .. " (" .. characterInfo.realm .. ")")
	end
	
	return true
end

--- Set an alias for the current player's BattleTag
--- @param alias string The alias to set
--- @return boolean success Whether the alias was set successfully
function DB.SetPlayerAlias(alias)
	local battleTag = ns.PlayerInfo.GetBattleTag()
	if not battleTag then
		print(ERROR .. " Unable to set alias: BattleTag not found. Make sure you're logged in to Battle.net.")
		return false
	end
	
	if not EndeavoringDB.global.myProfile then
		-- Initialize profile if it doesn't exist
		DB.RegisterCurrentCharacter()
	end
	
	local myProfile = EndeavoringDB.global.myProfile
	local timestamp = time()
	
	myProfile.alias = alias
	myProfile.aliasUpdatedAt = timestamp

	return true
end

--- Get the alias for a given BattleTag
--- @param battleTag string The BattleTag to look up
--- @return string|nil alias The alias or nil if not found
function DB.GetAlias(battleTag)
	if not battleTag then
		print(ERROR .. " Unable to get alias: BattleTag not provided.")
		return nil
	end
	
	-- Check if it's the player's own BattleTag
	if EndeavoringDB.global.myProfile and EndeavoringDB.global.myProfile.battleTag == battleTag then
		return EndeavoringDB.global.myProfile.alias
	end
	
	-- Check synced profiles
	local profile = EndeavoringDB.global.profiles[battleTag]
	if profile then
		return profile.alias
	end
	
	return nil
end

--- Get the current player's alias
--- @return string|nil alias The current player's alias or nil if not found
function DB.GetPlayerAlias()
	if EndeavoringDB.global.myProfile then
		return EndeavoringDB.global.myProfile.alias
	end
	return nil
end

--- Get all characters for a given BattleTag
--- @param battleTag string The BattleTag to look up
--- @return table|nil characters Table of characters or nil if not found
function DB.GetCharacters(battleTag)
	if not battleTag then
		print(ERROR .. " Unable to get characters: BattleTag not provided.")
		return nil
	end
	
	-- Check if it's the player's own BattleTag
	if EndeavoringDB.global.myProfile and EndeavoringDB.global.myProfile.battleTag == battleTag then
		return EndeavoringDB.global.myProfile.characters
	end
	
	-- Check synced profiles
	local profile = EndeavoringDB.global.profiles[battleTag]
	if profile then
		return profile.characters
	end
	
	return nil
end

--- Get the current player's profile
--- @return Profile|nil profile The current player's profile or nil if not found
function DB.GetPlayerProfile()
	return EndeavoringDB.global.myProfile
end

--- Alias for GetPlayerProfile (for consistency with Sync service naming)
--- @return Profile|nil profile The current player's profile or nil if not found
function DB.GetMyProfile()
	return EndeavoringDB.global.myProfile
end

--- Get the current player's BattleTag
--- @return string|nil battleTag The current player's BattleTag or nil if not found
function DB.GetMyBattleTag()
	if EndeavoringDB.global.myProfile then
		return EndeavoringDB.global.myProfile.battleTag
	end
	return nil
end

--- Count the number of characters in a profile
--- @param profile Profile The profile to count characters for
--- @return number count The number of characters
function DB.GetCharacterCount(profile)
	if not profile or not profile.characters then
		return 0
	end
	
	local count = 0
	for _ in pairs(profile.characters) do
		count = count + 1
	end
	return count
end

--- Get all profiles (synced profiles only, excludes myProfile)
--- @return table<string, Profile> profiles All synced profiles in the database
function DB.GetAllProfiles()
	return EndeavoringDB.global.profiles or {}
end

--- Get a specific profile by BattleTag (synced profiles only, excludes myProfile)
--- @param battleTag string The BattleTag to look up
--- @return Profile|nil profile The profile if found, nil otherwise
function DB.GetProfile(battleTag)
	if not battleTag then
		return nil
	end
	
	return EndeavoringDB.global.profiles[battleTag]
end

--- Get the player's profile for broadcasting (authoritative data)
--- @return Profile|nil myProfile The player's profile to broadcast, or nil if not initialized
function DB.GetMyProfileForBroadcast()
	return EndeavoringDB.global.myProfile
end

--- Update a profile with new data (for sync purposes)
--- WARNING: This should NEVER update myProfile, only synced profiles from other players
--- @param battleTag string The BattleTag of the profile
--- @param profileData table The profile data to merge
--- @return boolean success Whether the update was successful
function DB.UpdateProfile(battleTag, profileData)
	if not battleTag or not profileData then
		return false
	end
	
	-- NEVER update myProfile via sync - it's always authoritative
	if EndeavoringDB.global.myProfile and EndeavoringDB.global.myProfile.battleTag == battleTag then
		return false
	end
	
	-- If we don't have this profile, or if the incoming data is newer, update it
	local existingProfile = EndeavoringDB.global.profiles[battleTag]
	
	if not existingProfile or (profileData.charsUpdatedAt and profileData.charsUpdatedAt > (existingProfile.charsUpdatedAt or 0)) then
		EndeavoringDB.global.profiles[battleTag] = profileData
		return true
	end
	
	return false
end

--- Check if incoming data is newer than existing data (only checks synced profiles)
--- @param battleTag string The BattleTag to check
--- @param incomingTimestamp number The timestamp of incoming data
--- @return boolean isNewer Whether the incoming data is newer
function DB.IsDataNewer(battleTag, incomingTimestamp)
	if not battleTag or not incomingTimestamp then
		return false
	end
	
	-- Don't check myProfile - it's never synced
	if EndeavoringDB.global.myProfile and EndeavoringDB.global.myProfile.battleTag == battleTag then
		return false
	end
	
	local existingProfile = EndeavoringDB.global.profiles[battleTag]
	if not existingProfile then
		return true -- No existing data, so incoming is "newer"
	end
	
	return incomingTimestamp > (existingProfile.charsUpdatedAt or 0)
end

--- Get manifest data for broadcasting (BattleTag, alias, timestamps)
--- @return { battleTag: string, alias: string, charsUpdatedAt: number, aliasUpdatedAt: number }|nil manifest The manifest data or nil if not initialized
function DB.GetManifest()
	if not EndeavoringDB.global.myProfile then
		return nil
	end
	
	local myProfile = EndeavoringDB.global.myProfile
	return {
		battleTag = myProfile.battleTag,
		alias = myProfile.alias,
		charsUpdatedAt = myProfile.charsUpdatedAt,
		aliasUpdatedAt = myProfile.aliasUpdatedAt,
	}
end

--- Get characters added after a specific timestamp
--- @param afterTimestamp number Only return characters with addedAt > this timestamp
--- @return Character[] characters Array of character data with addedAt timestamps
function DB.GetCharactersAddedAfter(afterTimestamp)
	if not EndeavoringDB.global.myProfile then
		return {}
	end
	
	local result = {}
	local myProfile = EndeavoringDB.global.myProfile
	
	for _, character in pairs(myProfile.characters) do
		if character.addedAt and character.addedAt > afterTimestamp then
			table.insert(result, {
				name = character.name,
				realm = character.realm,
				addedAt = character.addedAt,
			})
		end
	end
	
	return result
end

--- Get characters from any profile added after a specific timestamp
--- @param battleTag string The BattleTag of the profile
--- @param afterTimestamp number The timestamp to compare against
--- @return Character[] Array of characters added after the timestamp
function DB.GetProfileCharactersAddedAfter(battleTag, afterTimestamp)
	local profile = DB.GetProfile(battleTag)
	if not profile or not profile.characters then
		return {}
	end
	
	local result = {}
	for _, character in pairs(profile.characters) do
		if character.addedAt and character.addedAt > afterTimestamp then
			table.insert(result, {
				name = character.name,
				realm = character.realm,
				addedAt = character.addedAt,
			})
		end
	end
	
	return result
end

--- Add or update characters in a synced profile
--- @param battleTag string The BattleTag of the profile
--- @param characters Character[] Array of character data with addedAt timestamps
--- @return boolean success Whether the update was successful
function DB.AddCharactersToProfile(battleTag, characters)
	if not battleTag or not characters then
		return false
	end
	
	-- NEVER update myProfile via sync
	if EndeavoringDB.global.myProfile and EndeavoringDB.global.myProfile.battleTag == battleTag then
		return false
	end
	
	-- Initialize profile if it doesn't exist
	if not EndeavoringDB.global.profiles[battleTag] then
		EndeavoringDB.global.profiles[battleTag] = {
			battleTag = battleTag,
			alias = battleTag,
			aliasUpdatedAt = 0,
			characters = {},
			charsUpdatedAt = 0,
		}
	end
	
	local profile = EndeavoringDB.global.profiles[battleTag]
	local maxTimestamp = profile.charsUpdatedAt or 0
	
	for _, character in ipairs(characters) do
		if character.name then
			-- Only update if this is newer data
			local existing = profile.characters[character.name]
			if not existing or (character.addedAt and character.addedAt > (existing.addedAt or 0)) then
				profile.characters[character.name] = {
					name = character.name,
					realm = character.realm,
					addedAt = character.addedAt,
				}
				if character.addedAt and character.addedAt > maxTimestamp then
					maxTimestamp = character.addedAt
				end
			end
		end
	end
	
	-- Update profile's characters timestamp if we added newer characters
	if maxTimestamp > profile.charsUpdatedAt then
		profile.charsUpdatedAt = maxTimestamp
	end
	
	return true
end

--- Update alias for a synced profile
--- @param battleTag string The BattleTag of the profile
--- @param alias string The new alias
--- @param aliasUpdatedAt number The timestamp of when the alias was updated
--- @return boolean success Whether the update was successful
function DB.UpdateProfileAlias(battleTag, alias, aliasUpdatedAt)
	if not battleTag or not alias or not aliasUpdatedAt then
		return false
	end
	
	-- NEVER update myProfile via sync
	if EndeavoringDB.global.myProfile and EndeavoringDB.global.myProfile.battleTag == battleTag then
		return false
	end
	
	-- Initialize profile if it doesn't exist
	if not EndeavoringDB.global.profiles[battleTag] then
		EndeavoringDB.global.profiles[battleTag] = {
			battleTag = battleTag,
			alias = alias,
			aliasUpdatedAt = aliasUpdatedAt,
			characters = {},
			charsUpdatedAt = 0,
		}
		return true
	end
	
	local profile = EndeavoringDB.global.profiles[battleTag]
	
	-- Only update if this is newer
	if aliasUpdatedAt > (profile.aliasUpdatedAt or 0) then
		profile.alias = alias
		profile.aliasUpdatedAt = aliasUpdatedAt
		-- Don't update charsUpdatedAt - that's only for character changes
		
		return true
	end
	
	return false
end

--- Purge all synced profiles (keeps myProfile)
--- @return number count The number of profiles purged
function DB.PurgeSyncedProfiles()
	local count = 0
	for _ in pairs(EndeavoringDB.global.profiles) do
		count = count + 1
	end
	
	EndeavoringDB.global.profiles = {}
	
	return count
end

--- Get verbose debug mode status
--- @return boolean enabled Whether verbose debug mode is enabled
function DB.IsVerboseDebug()
	return EndeavoringDB and EndeavoringDB.global and EndeavoringDB.global.verboseDebug or false
end

--- Set verbose debug mode
--- @param enabled boolean Whether to enable verbose debug mode
function DB.SetVerboseDebug(enabled)
	if not EndeavoringDB or not EndeavoringDB.global then
		return
	end
	
	EndeavoringDB.global.verboseDebug = enabled
end

