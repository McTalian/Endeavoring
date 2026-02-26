--- Busted suite-wide helper — loaded once before any spec runs.
---
--- Establishes global polyfills and WoW API stubs that every spec needs,
--- so individual spec files don't have to repeat common setup.

-- Lua 5.1 compatibility shims (unpack, format globals).
require("Endeavoring_spec._mocks.LuaCompat")

-- Core WoW global stubs (issecretvalue, time, print, etc.)
require("Endeavoring_spec._mocks.WoWGlobals")

-- _G.Enum table stubs used by the addon
require("Endeavoring_spec._mocks.WoWGlobals.Enum")
