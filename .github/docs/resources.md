# Development Resources

Essential references for developing the Endeavoring addon.

## WoW UI Source Repository

**Location**: `../wow-ui-source` (relative to project root, or in workspace)

The `wow-ui-source` repository contains WoW client-generated UI source code. This is **the most valuable resource** for understanding the underlying API and functionality of the WoW UI.

**When to Reference:**
- Understanding how Blizzard implements similar features
- Finding undocumented API functions
- Learning proper usage patterns for WoW APIs
- Ensuring compatibility with WoW client expectations
- Following best practices for WoW addon development

**Always reference this repository** when working on the addon to ensure changes are compatible with the WoW client and follow best practices.

## Key Files in wow-ui-source

### Neighborhood/Endeavors API Documentation

**File**: `Interface/AddOns/Blizzard_APIDocumentationGenerated/NeighborhoodInitiativeDocumentation.lua`

Documents the C_NeighborhoodInitiative API - the core API for the Endeavors feature.

**Contains:**
- `GetNeighborhoodInitiativeInfo()` - Get current Endeavor details
- `GetInitiativeActivityLog()` - Get completed task history
- `GetInitiativeTasks()` - Get available tasks
- Event definitions (NEIGHBORHOOD_INITIATIVE_*)

**Remember:** API uses "Initiative" terminology, not "Endeavor"

### Housing Dashboard Frame

**Main Frame**: `Interface/AddOns/Blizzard_HousingDashboard/Blizzard_HousingDashboard.lua`

Creates the mixin for HousingDashboardFrame - the main UI frame for housing features.

**Useful for:**
- Understanding frame lifecycle and events
- Finding integration points for our addon
- Learning Blizzard's UI patterns and conventions

### Dashboard Content Frames

**File**: `Interface/AddOns/Blizzard_HousingDashboard/Blizzard_HousingDashboardHouseInfoContent.lua`

Main logic for the various subframes of the HousingDashboardFrame.

**Contains:**
- Tab handling and content switching
- Endeavors list rendering
- Task list implementation
- Activity log display

**XML**: `Interface/AddOns/Blizzard_HousingDashboard/Blizzard_HousingDashboardHouseInfoContent.xml`

FrameXML definitions for Housing UI components - helpful for understanding frame hierarchy and template usage.

## Common WoW API Patterns

### Accessing Neighborhood Initiative Data

```lua
-- Check if API is available (guard clause for compatibility)
if not C_NeighborhoodInitiative then
  return
end

-- Get current initiative info
local initiativeInfo = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
if initiativeInfo then
  -- initiativeInfo.name, initiativeInfo.description, etc.
end

-- Get activity log
local activities = C_NeighborhoodInitiative.GetInitiativeActivityLog()
for _, activity in ipairs(activities) do
  -- activity.taskName, activity.playerName, activity.amount, activity.completionTime
end
```

### Encoding/Decoding

```lua
-- CBOR serialization (WoW 12.x+)
local serialized = C_EncodingUtil.SerializeCBOR(data)
local deserialized = C_EncodingUtil.DeserializeCBOR(serialized)

-- Compression
local compressed = C_EncodingUtil.CompressString(str)
local decompressed = C_EncodingUtil.DecompressString(compressed)

-- Base64 encoding (for safe transmission)
local encoded = C_EncodingUtil.EncodeBase64(binaryData)
local decoded = C_EncodingUtil.DecodeBase64(encoded)
```

### Addon Messages

```lua
-- Register prefix (once, at addon load)
C_ChatInfo.RegisterAddonMessagePrefix("YourPrefix")

-- Send message
C_ChatInfo.SendAddonMessage("YourPrefix", message, "GUILD")

-- Receive message (register callback)
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
  if prefix == "YourPrefix" then
    -- Handle message
  end
end)

-- Check for lockdown (instances/restricted zones)
if C_ChatInfo.InChatMessagingLockdown() then
  -- Can't send messages right now
  return
end
```

## Lua Development Tools

### wow-build-tools

**Repository**: Custom build tooling for WoW addon development

**Common Commands:**
- `make dev` - Build and copy to WoW Addons directory
- `make toc_check` - Validate TOC imports match disk files
- `make watch` - Auto-build on file changes

**Important Nuance:** Build commands only copy files tracked by git. Use `git add` before building if you've created new files.

### TOC File Validation

The `wow-build-tools toc check` command validates:
1. All files referenced in TOC exist on disk
2. All XML imports and their nested imports exist
3. Reports "orphaned" files (on disk but not in TOC)

**Best Practice:** Run `make toc_check` before committing to catch missing or misspelled file paths.

## External Documentation

### Wowpedia
[https://wowpedia.fandom.com](https://wowpedia.fandom.com)

Community-maintained WoW API documentation. Sometimes more detailed than Blizzard's official docs.

### WoW API Documentation (Official)
Available in-game via `/api` command or through UI source repository.

### AddOn Development Forum
[https://us.forums.blizzard.com/en/wow/c/development](https://us.forums.blizzard.com/en/wow/c/development)

Official Blizzard forum for addon developers - useful for asking questions about undocumented APIs or breaking changes.

## File Path Conventions

**Always use forward slashes (`/`)** for file paths regardless of OS. The WoW client correctly interprets them on all platforms.

**Examples:**
```lua
-- Good
local path = "Interface/AddOns/Endeavoring/Assets/icon.tga"

-- Bad (breaks on non-Windows)
local path = "Interface\\AddOns\\Endeavoring\\Assets\\icon.tga"
```

## See Also

- [Glossary](glossary.md) - WoW and addon terminology reference
- [Architecture](architecture.md) - Project structure and conventions
- [Development Status](development-status.md) - Current progress and roadmap
