--- Core WoW global stubs for the test environment.
---
--- Provides minimal stubs for WoW globals that addon source files
--- reference at load time or at runtime. Specs can override/spy on
--- these as needed.

-- issecretvalue: WoW API that checks if a value is a "secret" (hardware-protected).
-- In tests, nothing is ever a secret value.
_G.issecretvalue = _G.issecretvalue or function()
	return false
end

-- time(): WoW inherits Lua's os.time but exposes it as a global.
-- Already available in standard Lua, but ensure it's in _G explicitly.
_G.time = _G.time or os.time

-- UnitName: returns the player's character name
_G.UnitName = _G.UnitName or function()
	return "TestPlayer"
end

-- C_ChatInfo stub (minimal — specs that test messaging will flesh this out)
_G.C_ChatInfo = _G.C_ChatInfo or {}
_G.C_ChatInfo.RegisterAddonMessagePrefix = _G.C_ChatInfo.RegisterAddonMessagePrefix or function()
	return true
end
_G.C_ChatInfo.SendAddonMessage = _G.C_ChatInfo.SendAddonMessage or function()
	return 0  -- Success
end
_G.C_ChatInfo.InChatMessagingLockdown = _G.C_ChatInfo.InChatMessagingLockdown or function()
	return false
end

-- C_Timer stub
_G.C_Timer = _G.C_Timer or {}
_G.C_Timer.NewTimer = _G.C_Timer.NewTimer or function(_, callback)
	return { Cancel = function() end }
end
_G.C_Timer.NewTicker = _G.C_Timer.NewTicker or function(_, callback)
	return { Cancel = function() end }
end
