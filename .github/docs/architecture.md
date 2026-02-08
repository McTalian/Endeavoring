# Architecture

## Project Structure

```
Endeavoring/
├── Bootstrap.lua             # Namespace initialization, constants
├── Core.lua                  # Main frame, event handling, slash commands
├── Data/                     # Data access layer
│   └── Database.lua          # SavedVariables management
├── Features/                 # UI features and functionality
│   ├── Header.lua            # Endeavor header display
│   └── Tasks.lua             # Task list display
├── Integrations/             # External addon integrations
│   └── HousingDashboard.lua  # Blizzard Housing Dashboard hooks
└── Services/                 # WoW API abstractions
    ├── GlobalStrings.lua     # (Future) Blizzard global strings
    ├── NeighborhoodAPI.lua   # Neighborhood/Initiative APIs
    └── PlayerInfo.lua        # Player/character info APIs
```

## Directory Conventions

### `/Data`
**Purpose**: Data persistence and access layer

**Contains**:
- SavedVariables management
- Database CRUD operations
- Data schemas and migrations

**Does NOT contain**:
- WoW API calls (use Services instead)
- UI logic (use Features instead)
- External integrations

**Example**: `Database.lua` manages `EndeavoringDB` and provides methods like `GetAlias()`, `RegisterCurrentCharacter()`

### `/Services`
**Purpose**: WoW API abstractions and external dependencies

**Contains**:
- Wrappers around Blizzard APIs (`C_NeighborhoodInitiative`, `UnitName`, etc.)
- Blizzard global string access
- Anything that could change between WoW patches

**Does NOT contain**:
- Business logic
- Data persistence
- UI components

**Why**: Isolates external dependencies. When a new patch drops, check Services/ first.

**Example**: `PlayerInfo.lua` wraps `UnitName("player")` and `BNGetInfo()`

### `/Features`
**Purpose**: UI components and feature implementations

**Contains**:
- Frame creation and management
- User interaction logic
- Display formatting
- Feature-specific business logic

**Can use**: Data/ for state, Services/ for WoW APIs

**Example**: `Tasks.lua` creates and manages the task list UI

### `/Integrations`
**Purpose**: Hooks into other addons or Blizzard frames

**Contains**:
- Optional modifications to external frames
- Compatibility layers
- Feature detection for external addons

**Must**: Gracefully handle missing dependencies

**Example**: `HousingDashboard.lua` adds a button to Blizzard's Housing Dashboard

## Coding Conventions

### Namespace Usage

All addon code uses the shared namespace:

```lua
---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)
```

Access components via namespace:
- `ns.DB` - Database access
- `ns.API` - Neighborhood APIs
- `ns.PlayerInfo` - Player info
- `ns.Tasks`, `ns.Header` - Features
- `ns.Constants` - Shared constants
- `ns.ui` - UI state (runtime only)

### Guard Clauses

**Use guards for external/optional dependencies:**

```lua
-- Blizzard APIs (may not exist in all versions)
if C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo then
  return C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
end

-- Optional integrations (addon may not be loaded)
local integration = ns.Integrations and ns.Integrations.HousingDashboard
if integration and integration.EnsureLoaded() then
  integration.RegisterButtonHook()
end

-- Runtime state (created only when needed)
local mainFrame = ns.ui and ns.ui.mainFrame
if not mainFrame then
  return
end
```

**DO NOT use guards for our own code:**

```lua
-- WRONG - unnecessary guard
if ns.DB and ns.DB.Init then
  ns.DB.Init()
end

-- RIGHT - fail fast if load order is broken
ns.DB.Init()

-- WRONG - unnecessary guard
if ns.Tasks and ns.Tasks.Refresh then
  ns.Tasks.Refresh()
end

-- RIGHT - fail fast
ns.Tasks.Refresh()
```

**Why**: If our own services don't exist, that's a load order bug. We want it to fail loudly during testing, not silently skip functionality.

### File Load Order (TOC)

Load order matters! Files are loaded sequentially:

```
Bootstrap.lua          # 1. Namespace and constants
Services/PlayerInfo.lua    # 2. WoW API wrappers (no dependencies)
Data/Database.lua      # 3. Data layer (uses Services/)
Services/NeighborhoodAPI.lua  # 4. More services
Features/Header.lua    # 5. Features (use Services/ and Data/)
Features/Tasks.lua
Integrations/HousingDashboard.lua  # 6. Optional integrations
Core.lua              # 7. Main frame and event handling
```

**Dependency Rules**:
- Services can have no addon dependencies (only WoW APIs)
- Data can use Services
- Features can use Services and Data
- Core comes last (uses everything)

### Error Handling Philosophy

**Fail Fast in Development**:
- Don't catch errors from our own code
- Let Lua errors surface immediately during testing
- Use assertions for invariants

**Fail Gracefully in Production**:
- Guard external APIs (they might not exist)
- Check optional integrations
- Validate user input
- Handle nil returns from WoW APIs

**Example**:
```lua
-- Internal call - fail fast
ns.DB.RegisterCurrentCharacter()  -- Let it error if DB is nil

-- External API - guard
local battleTag = select(1, BNGetInfo())
if not battleTag then
  print("Unable to get BattleTag")
  return false
end
```

### Naming Conventions

**Files**: PascalCase (`Database.lua`, `PlayerInfo.lua`)

**Directories**: PascalCase (`Services/`, `Features/`)

**Functions**: 
- Public API: PascalCase (`DB.GetAlias()`)
- Private/local: camelCase (`local function formatPercent()`)

**Variables**:
- Constants: UPPER_SNAKE_CASE (`ns.Constants.FRAME_WIDTH`)
- Local: camelCase (`local myProfile`)
- Namespace tables: PascalCase (`ns.DB`, `ns.API`)

### Path Conventions

Always use forward slashes `/` for file paths, regardless of OS. The WoW client interprets them correctly on all platforms.

```lua
-- Good
"Services/Database.lua"
"Features/Tasks.lua"

-- Bad (but WoW handles it)
"Services\\Database.lua"
```

## Testing Strategy

*To be developed*

Current approach: Manual testing in-game during development.

Future considerations:
- Mock WoW API for unit tests
- Integration tests with WoW client
- Automated UI testing

## See Also

- [Database Schema](database-schema.md) - Data structure and access patterns
- [Sync Protocol](sync-protocol.md) - Communication between addon instances
- [Development Status](development-status.md) - Current progress and roadmap
