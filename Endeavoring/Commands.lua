---@type string
local addonName = select(1, ...)
---@class HDENamespace
local ns = select(2, ...)

local Commands = {}
ns.Commands = Commands

-- Shortcuts
local INFO = ns.Constants.PREFIX_INFO
local ERROR = ns.Constants.PREFIX_ERROR

-- Command Handlers

--- Handle alias command - set or show player alias
--- @param args string The alias to set, or empty to show current
local function HandleAlias(args)
	if args and args ~= "" then
		-- Set alias
		if ns.DB.SetPlayerAlias(args) then
			print(INFO .. " Alias set to: " .. args)
			-- Broadcast updated manifest
			ns.Sync.SendManifestDebounced()
		else
			print(ERROR .. " Failed to set alias. Make sure you're logged in.")
		end
	else
		-- Show current alias
		local alias = ns.DB.GetPlayerAlias()
		if alias then
			print(INFO .. " Your current alias is: " .. alias)
		else
			print(ERROR .. " No alias set.")
		end
	end
end

--- Handle sync broadcast command - force MANIFEST broadcast
local function HandleSyncBroadcast()
	ns.Sync.SendManifest()
	print(INFO .. " Manually triggered MANIFEST broadcast")
end

--- Handle sync status command - show profile information
local function HandleSyncStatus()
	-- Show my profile
	local myProfile = ns.DB.GetMyProfile()
	if myProfile then
		print(INFO .. " === My Profile ===")
		print(string.format("  BattleTag: %s", myProfile.battleTag))
		print(string.format("  Alias: %s", myProfile.alias))
		print(string.format("  Alias Updated: %s", date("%Y-%m-%d %H:%M:%S", myProfile.aliasUpdatedAt)))
		print(string.format("  Chars Updated: %s", date("%Y-%m-%d %H:%M:%S", myProfile.charsUpdatedAt)))
		print(string.format("  Characters: %d", ns.DB.GetCharacterCount(myProfile)))
	else
		print(ERROR .. " No profile found")
	end
	
	-- Show cached profiles
	local profiles = ns.DB.GetAllProfiles()
	local count = 0
	for _ in pairs(profiles) do
		count = count + 1
	end
	print(string.format(INFO .. " === Cached Profiles: %d ===", count))
	for battleTag, profile in pairs(profiles) do
		print(string.format("  %s (%s) - %d chars", battleTag, profile.alias, ns.DB.GetCharacterCount(profile)))
	end
end

--- Handle sync purge command - clear all synced profiles
local function HandleSyncPurge()
	local count = ns.DB.PurgeSyncedProfiles()
	print(string.format(INFO .. " Purged %d synced profile(s). Your profile was preserved.", count))
end

--- Handle sync verbose command - toggle verbose debug mode
local function HandleSyncVerbose()
	local current = ns.DB.IsVerboseDebug()
	ns.DB.SetVerboseDebug(not current)
	if not current then
		print(INFO .. " Verbose debug mode enabled")
	else
		print(INFO .. " Verbose debug mode disabled")
	end
end

--- Handle sync gossip command - show gossip statistics
local function HandleSyncGossip()
	local stats = ns.Sync.GetGossipStats()
	print(INFO .. " === Gossip Statistics ===")
	print(string.format("  Total players gossiped to: %d", stats.totalPlayers))
	print(string.format("  Total gossips sent: %d", stats.totalGossips))
	
	if stats.totalPlayers > 0 then
		print("  Profiles gossiped by player:")
		for battleTag, profiles in pairs(stats.gossipByPlayer) do
			print(string.format("    %s: %d profile(s)", battleTag, profiles))
		end
	end
end

--- Handle sync help - show available sync commands
local function HandleSyncHelp()
	print(INFO .. " Sync commands:")
	print("  /endeavoring sync broadcast - Force MANIFEST broadcast")
	print("  /endeavoring sync status - Show profile status")
	print("  /endeavoring sync purge - Clear all synced profiles")
	print("  /endeavoring sync verbose - Toggle verbose debug output")
	print("  /endeavoring sync gossip - Show gossip statistics")
end

--- Handle sync command routing
--- @param args string The sync subcommand and arguments
local function HandleSync(args)
	if args == "broadcast" then
		HandleSyncBroadcast()
	elseif args == "status" then
		HandleSyncStatus()
	elseif args == "purge" then
		HandleSyncPurge()
	elseif args == "verbose" then
		HandleSyncVerbose()
	elseif args == "gossip" then
		HandleSyncGossip()
	else
		HandleSyncHelp()
	end
end

--- Handle default command - toggle main frame
local function HandleDefault()
	ns.ToggleMainFrame()
end

-- Command Router

--- Route slash command to appropriate handler
--- @param msg string The full command message
local function RouteCommand(msg)
	-- Parse command and arguments
	local command, args = msg:match("^(%S*)%s*(.-)$")
	command = command:lower()
	
	if command == "alias" then
		HandleAlias(args)
	elseif command == "sync" then
		HandleSync(args)
	else
		HandleDefault()
	end
end

-- Public API

--- Register slash commands
function Commands.Register()
	SLASH_ENDEAVORING1 = "/endeavoring"
	SLASH_ENDEAVORING2 = "/ndvr"
	SlashCmdList.ENDEAVORING = RouteCommand
end
