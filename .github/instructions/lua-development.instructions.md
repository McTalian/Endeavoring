---
name: Lua Development Conventions
description: Lua coding standards and WoW addon patterns for Endeavoring
applyTo: "**/*.lua"
---

# Lua Development Conventions

## File Path Convention

**Always use forward slashes (`/`)** for file paths regardless of OS. The WoW client correctly interprets them on all platforms.

```lua
-- Good
local path = "Interface/AddOns/Endeavoring/file.lua"

-- Bad (breaks cross-platform)
local path = "Interface\\AddOns\\Endeavoring\\file.lua"
```

## Guard Clause Convention

Use guards strategically to handle **runtime concerns**, not loading order issues.

### TOC Loading Behavior

**Critical Understanding**: TOC files execute only root-level code when loading. Function definitions are just that - definitions. Functions execute later when called, after all TOC files have loaded.

```lua
-- This RUNS during file load (root-level code)
local addonName, ns = ...
local MyModule = {}
ns.MyModule = MyModule

-- This is just DEFINED, doesn't execute until called
function MyModule.DoSomething()
  ns.DB.DoThing()  -- Safe! DB will be loaded when this executes
end

-- This RUNS during file load
MyModule.Init()  -- Could reference ns.DB - load order matters!
```

**Load Order Strategy**:
- Early files (Bootstrap, Services, Data): Define modules and functions
- Mid files (Sync, Features, Integrations): Define modules, may call into earlier modules from functions
- **Core.lua loads LAST**: Executes root-level initialization chain that calls into all modules

### Use Guards For (Runtime Concerns):
- ✅ **External APIs** - Blizzard APIs that may not exist in all client versions
- ✅ **Optional addons** - Other addons that might not be loaded
- ✅ **Lazy UI elements** - Frames created on-demand, may not exist yet
- ✅ **Async data** - Data that loads asynchronously (Blizzard frames, network data)

### Don't Use Guards For (Loading Order):
- ❌ **Our own modules** - If missing, it's a load order bug that should error immediately
- ❌ **Internal dependencies** - Let it error during testing to catch TOC ordering issues
- ❌ **Core initialization** - SavedVariables, database setup - initialize properly instead

### Why Let Internal Dependencies Error?

**Fail fast during testing** - If `ns.DB` is nil when called, it means:
1. TOC file order is wrong (Database.lua should load earlier)
2. Root-level code is calling functions before modules are loaded (move to Core.lua)
3. A module wasn't properly registered

Guarding would **hide the bug** and make it harder to diagnose. Let it error loudly during development.

**Examples:**

```lua
-- ✅ Good - external API guard (runtime concern)
if C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetInitiativeInfo then
  return C_NeighborhoodInitiative.GetInitiativeInfo()
end

-- ✅ Good - lazy UI guard (runtime concern)
if ns.ui and ns.ui.mainFrame then
  ns.ui.mainFrame:Show()
end

-- ✅ Good - no guard for internal modules (fail fast on bugs)
function MyModule.DoWork()
  ns.DB.Init()           -- Let it error if DB isn't loaded
  ns.Tasks.Refresh()     -- Let it error if Tasks isn't loaded
end

-- ❌ Bad - hides loading order bug
function ns.DebugPrint(message)
  if not ns.DB or not ns.DB.IsVerboseDebug then  -- Masks real bug!
    return
  end
  -- ...
end

-- ✅ Good - fail fast if DB isn't loaded yet
function ns.DebugPrint(message)
  if not ns.DB.IsVerboseDebug() then  -- Will error if DB isn't loaded - good!
    return
  end
  -- ...
end
```

### Quick Reference: Runtime vs Loading Checks

| Check | Type | Reasoning |
|-------|------|----------|
| `if not ns.ui.mainFrame then` | ✅ Runtime | Frame created lazily on user demand |
| `if not ns.ui.tasksUI then` | ✅ Runtime | UI element created when tab opened |
| `if C_NeighborhoodInitiative then` | ✅ Runtime | WoW API may not exist in all clients |
| `if integration.EnsureLoaded() then` | ✅ Runtime | External Blizzard addon availability |
| `if not ns.DB then` | ❌ Loading | Database.lua loads before everything |
| `if not ns.Integrations then` | ❌ Loading | HousingDashboard.lua loads before Core.lua |
| `if not ns.ui then` | ❌ Loading | Bootstrap.lua initializes before all files |

**Rule of thumb**: If it's created by us during initialization (Bootstrap, Services, Data, Sync), don't guard it. If it's created lazily, loaded externally, or may not exist, guard it.

## Module Pattern

Endeavoring uses a namespace pattern for module organization:

```lua
local addonName, ns = ...

-- Create module table
local MyModule = {}
ns.MyModule = MyModule

-- Module-local variables
local someState = {}

-- Public API
function MyModule.PublicFunction()
  -- Implementation
end

-- Private helper
local function privateHelper()
  -- Not exposed outside module
end
```

## Accessing Shared Utilities

Common utilities are available in the namespace:

```lua
local addonName, ns = ...

-- Debug printing
ns.DebugPrint("Message", value)

-- Message prefixes
print(ns.Constants.PREFIX_INFO .. "User-facing message")
print(ns.Constants.PREFIX_ERROR .. "Error message")
print(ns.Constants.PREFIX_WARN .. "Warning message")

-- Message types for sync protocol
local msgType = ns.MSG_TYPE.MANIFEST
```

## WoW API Best Practices

### Event Registration

```lua
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_ENTERING_WORLD" then
    -- Handle event
  end
end)
```

### Delayed Execution

```lua
-- Use C_Timer for delayed tasks
C_Timer.After(5, function()
  -- Executes after 5 seconds
end)

-- For recurring tasks
C_Timer.NewTicker(60, function()
  -- Executes every 60 seconds
end)
```

### API Availability Checks

```lua
-- Check namespace exists
if not C_NeighborhoodInitiative then
  return -- API not available in this client version
end

-- Check specific function
if not C_ChatInfo.InChatMessagingLockdown then
  -- Function added in later patch, handle gracefully
end
```

## Error Handling

Always handle potential failures gracefully:

```lua
-- Protect API calls that might fail
local success, result = pcall(C_SomeAPI.MightError)
if success then
  -- Use result
else
  ns.DebugPrint("API call failed:", result)
end

-- Validate data before use
if not data or type(data) ~= "table" then
  return nil, "Invalid data"
end
```

## Performance Considerations

- **Avoid excessive string concatenation** in loops (use table.concat)
- **Cache repeated lookups** (UnitName, GetRealmName, etc.)
- **Throttle expensive operations** (guild roster scans, activity log processing)
- **Use locals** for frequently accessed values

```lua
-- Good - cache lookups
local characterCache = ns.CharacterCache
local battleTag = characterCache.GetBattleTagForCharacter(charName)

-- Bad - repeated table lookups
local battleTag = ns.CharacterCache.GetBattleTagForCharacter(charName)
local another = ns.CharacterCache.GetBattleTagForCharacter(otherName)
```

## Validating Changes

After editing Lua files, validate your changes before testing in-game:

**Quick validation** (syntax and structure):
```bash
make toc_check
```
- Validates TOC file paths match files on disk
- Checks for missing files in TOC tree
- Reports "orphaned" files not referenced in TOC

**Full validation** (build and copy to game):
```bash
make dev
```
- Runs `make toc_check` automatically
- Builds the addon
- Copies to WoW Addons directory
- **Important**: Only copies git-tracked files (run `git add` first for new files)

**Watch mode** (automatic rebuild):
```bash
make watch
```
- Watches for file changes
- Automatically runs `make dev` when changes detected
- Useful for rapid iteration during development

**Best practice**: Run `make toc_check` after adding/removing files or changing imports. Run `make dev` before testing in-game.

## See Also

- [Architecture](../docs/architecture.md) - Full project structure and conventions
- [Resources](../docs/resources.md) - WoW API references and patterns
