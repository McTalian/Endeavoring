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

### Frame Hierarchy and Storage

**Philosophy**: Use local variables during frame creation/setup for clean code, then establish the frame hierarchy at the end for debugging and testing benefits.

**Pattern**:

```lua
function Tasks.CreateTab(parent)
    local constants = ns.Constants
    
    -- Create frames using locals for clean setup
    local content = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    local header = CreateFrame("Frame", nil, content)
    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    
    -- Configure frames (clean code without long parent.child chains)
    header:SetHeight(constants.TASK_HEADER_HEIGHT)
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    
    -- Establish hierarchy at end for debugging/testing
    parent.tasks = content
    content.header = header
    content.scrollFrame = scrollFrame
    scrollFrame.scrollChild = scrollChild
    content.rows = {}
    
    return content
end
```

**What to store**:
* ✅ Major sections: Tab containers, major UI blocks (parent.tasks, parent.leaderboard)
* ✅ Dynamic elements: Rows, cached frames (parent["row" .. index])
* ✅ Important references: Headers, scroll frames, containers
* ❌ Atomic elements: Individual icons, textures, labels (unless needed for updates)

**Benefits**:
* **Clean setup**: Local variables keep creation code readable
* **Easy debugging**: /dump EndeavoringFrame.tasks.rows[3].name:GetText()
* **Frame reuse**: Access to previously created frames for updates
* **Testing**: Inspect frame state without hunting through code

**Dynamic Row Storage**:

For dynamically created elements (task rows, leaderboard entries), use a dual-storage pattern:

```lua
local function CreateTaskRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    parent["row" .. index] = row  -- Named storage for /fstack debugging
    
    -- Setup continues...
    return row
end

-- Later, create and store rows:
for index, task in ipairs(tasks) do
    local row = tasksUI.rows[index]
    if not row then
        row = CreateTaskRow(tasksUI.scrollChild, index)
        tasksUI.rows[index] = row  -- Numeric array for iteration
    end
    -- Update row with task data
end
```

This pattern enables efficient frame reuse without recreating UI elements on every refresh.

### Guard Clauses

Guards handle **runtime concerns**, not loading order issues.

**TOC Loading**: Files execute only root-level code during load. Function definitions don't execute until called (after all files load). Core.lua loads last and starts the initialization chain.

**Use guards for runtime concerns:**

```lua
-- External APIs (may not exist in all client versions)
if C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetInitiativeInfo then
  return C_NeighborhoodInitiative.GetInitiativeInfo()
end

-- Optional integrations (addon may not be loaded)
local integration = ns.Integrations and ns.Integrations.HousingDashboard
if integration and integration.EnsureLoaded() then
  integration.RegisterButtonHook()
end

-- Lazy UI elements (created on-demand, may not exist yet)
local mainFrame = ns.ui and ns.ui.mainFrame
if not mainFrame then
  return
end
```

**DO NOT guard internal modules (fail fast on bugs):**

```lua
-- ❌ WRONG - hides load order bug
if ns.DB and ns.DB.Init then
  ns.DB.Init()
end

-- ✅ RIGHT - errors immediately during testing
ns.DB.Init()

-- ❌ WRONG - masks TOC ordering issue
if ns.Tasks and ns.Tasks.Refresh then
  ns.Tasks.Refresh()
end

-- ✅ RIGHT - reveals bugs during development
ns.Tasks.Refresh()
```

**Why fail fast**: If internal modules are nil when called, it indicates a bug (wrong TOC order, premature root-level execution, missing module registration). Let it error during testing rather than hiding the problem.

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
