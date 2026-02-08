---
name: WoW API & Endeavors Context
description: WoW API usage, terminology, and Endeavors-specific context
applyTo: "**/*.lua"
---

# WoW API & Endeavors Context

## Initiative vs Endeavor Naming

**Important:** While we refer to the feature as "Endeavors" (the in-game player-facing name), all Blizzard API documentation and code uses the term "**Initiatives**".

**What this means:**
- API functions: `C_NeighborhoodInitiative.*`
- Events: `NEIGHBORHOOD_INITIATIVE_*`
- Documentation: References "Initiatives," not "Endeavors"
- Our code: Uses "Endeavor" in user-facing strings and comments, but calls the Initiative APIs

**When searching `wow-ui-source`:**
- Search for "Initiative" to find API documentation
- Search for "Endeavor" occasionally appears in UI strings
- Entry points typically use "Initiative" terminology

## Key WoW APIs for Endeavoring

### C_NeighborhoodInitiative

Primary API for Endeavors system (see [resources](../docs/resources.md#neighborhood-endeavors-api-documentation) for details).

**Common Functions:**
```lua
-- Get current initiative info
local info = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
-- Returns: { name, description, progressValue, progressMax, ... }

-- Get activity log (completed tasks)
local activities = C_NeighborhoodInitiative.GetInitiativeActivityLog()
-- Returns: array of { taskName, playerName, taskID, amount, completionTime }

-- Get available tasks
local tasks = C_NeighborhoodInitiative.GetInitiativeTasks()
-- Returns: array of task info
```

**Key Events:**
- `NEIGHBORHOOD_INITIATIVE_STARTED` - New initiative began
- `NEIGHBORHOOD_INITIATIVE_TASK_COMPLETED` - Task was completed
- `NEIGHBORHOOD_INITIATIVE_PROGRESS_UPDATED` - Progress changed

### C_ChatInfo (Addon Messages)

Used for sync protocol communication.

```lua
-- Register prefix (once at load)
C_ChatInfo.RegisterAddonMessagePrefix("Endeavoring")

-- Check lockdown before sending
if C_ChatInfo.InChatMessagingLockdown() then
  return -- Can't send in instances/restricted zones
end

-- Send message
C_ChatInfo.SendAddonMessage("Endeavoring", message, "GUILD")

-- Receive messages
frame:RegisterEvent("CHAT_MSG_ADDON")
```

### C_EncodingUtil (Encoding/Compression)

Used for message codec.

```lua
-- CBOR serialization
local encoded = C_EncodingUtil.SerializeCBOR(data)
local decoded = C_EncodingUtil.DeserializeCBOR(encoded)

-- Compression
local compressed = C_EncodingUtil.CompressString(str)
local decompressed = C_EncodingUtil.DecompressString(compressed)

-- Base64 (for safe binary transmission)
local b64 = C_EncodingUtil.EncodeBase64(binary)
local binary = C_EncodingUtil.DecodeBase64(b64)
```

## Terminology Quick Reference

See [Glossary](../docs/glossary.md) for complete terminology reference.

**Key Terms:**
- **BattleTag**: Blizzard account identifier (e.g., `McTalian#1234`)
- **Alias**: User-set display name for their BattleTag
- **Profile**: Player data (BattleTag + alias + characters + timestamps)
- **Character Cache**: O(1) lookup from character name → BattleTag
- **Gossip**: Opportunistic profile propagation
- **Delta Sync**: Only sending changed data based on timestamps
- **Chunking**: Splitting large messages to avoid size limits

## Common Patterns in This Codebase

### Namespace Access
```lua
local addonName, ns = ...

-- Access constants
ns.Constants.PREFIX_INFO

-- Access enums
ns.MSG_TYPE.MANIFEST

-- Access modules
ns.DB.GetProfile(battleTag)
ns.CharacterCache.GetBattleTagForCharacter(name)
```

### Module Structure
```lua
-- Services/ - WoW API wrappers
ns.AddonMessages  -- C_ChatInfo abstraction
ns.PlayerInfo     -- Player/character info
ns.NeighborhoodAPI -- C_NeighborhoodInitiative wrapper

-- Sync/ - Protocol components
ns.CharacterCache  -- Character→BattleTag lookup
ns.Coordinator     -- Timing and orchestration
ns.Gossip         -- Profile propagation
ns.Protocol       -- Message handling

-- Data/ - Persistence
ns.DB             -- SavedVariables access

-- Features/ - UI and functionality
ns.Tasks          -- Task list frame
ns.Leaderboard    -- Contribution leaderboard
```

### Error Handling
```lua
-- Always validate external data
if not battleTag or not battleTag:match("^[^#]+#%d+$") then
  return nil, "Invalid BattleTag format"
end

-- Check API availability
if not C_NeighborhoodInitiative then
  ns.DebugPrint("Initiative API not available")
  return
end
```

## See Also

- [Glossary](../docs/glossary.md) - Complete terminology reference
- [Resources](../docs/resources.md) - WoW API documentation and references
- [Sync Protocol](../docs/sync-protocol.md) - Communication protocol details
