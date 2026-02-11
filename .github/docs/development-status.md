# Development Status

**Last Updated**: February 10, 2026

## Recent Work 🎉

**Leaderboard Column Sorting (Feb 10)** ✅
- **Sortable columns**: All four leaderboard columns (Rank, Player, Total, Tasks Completed) now clickable
- **Sort constants**: Added LEADERBOARD_SORT_RANK, LEADERBOARD_SORT_NAME, LEADERBOARD_SORT_TOTAL, LEADERBOARD_SORT_ENTRIES to Bootstrap.lua
- **Sort logic**: BuildSortedLeaderboard() handles custom column sorting with proper tie-breaking to rank
- **Default sort**: Rank ascending (Rank 1 first) with visual up arrow indicator
- **Smart defaults**: Each column has intuitive default direction (Rank/Name ascending, Total/Entries descending)
- **Visual indicators**: Up/down arrows show active sort column and direction
- **Header conversion**: Converted all headers from FontStrings to clickable Buttons with OnClick handlers
- **Rank preservation**: Rank column shows actual rank from default sort, not display position
- **Refresh function**: Added public Leaderboard.Refresh() wrapper for consistency with Tasks.Refresh()
- **UX clarity**: Renamed "All Time" filter to "Current Endeavor" to eliminate scope confusion
- **In-game validation**: User tested all sorting combinations and confirmed working perfectly

**Header Enhancements & Sortable Columns (Feb 9 - Late)** ✅
- **Sortable columns**: Added House XP and Coupons column sorting to Tasks tab
- **Colored progress bar**: Green gradient progress bar (similar to experience bar) for better visual clarity
- **Milestone display**: Clean single-column list on header right side with overflow support for 5+ milestones
- **Info icon**: Added endeavor description tooltip (poi-workorders icon) next to title
- **Milestone tooltips**: Hover over milestones to see required progress and reward details
- **Visual polish**: Green checkmarks for completed milestones, gray for incomplete
- **Sort constants**: Added TASKS_SORT_XP and TASKS_SORT_COUPONS to Bootstrap.lua
- **UX iteration**: Refined milestone layout through user feedback - settled on single column with overflow
- **In-game validation**: User tested and confirmed good UX for alpha release

**Data Loading & UI Polish (Feb 9 - Early)** ✅
- **Fixed data initialization**: Added PLAYER_HOUSE_LIST_UPDATED event and proper init sequence via C_Housing.GetPlayerOwnedHouses()
- **Removed over-optimization**: Stripped throttling/debouncing from API requests to follow Blizzard's simpler event-driven pattern
- **Activity log loading**: Added isLoaded check, now loads reliably on login without requiring Housing Dashboard
- **Leaderboard icons**: Added addon indicator icon (endeavoring.png) for players using Endeavoring - shows for synced profiles
- **Task row redesign**: Complete table layout overhaul with Task | Contribution | House XP | Coupons columns
- **Coupons integration**: Implemented GetCouponsInfo() using C_QuestLog.GetQuestRewardCurrencyInfo() for reward display
- **Vertical centering**: Added task container frame for proper MIDDLE justification when no description exists
- **Manual polish**: User completed tedious anchoring refinements for pixel-perfect alignment
- **File cleanup**: Removed HousingDashboardHouseInfo.lua (no longer needed after simplification)

**TabSystem Framework Migration (Feb 8)** ✅
- **Refactored tab management**: Migrated from manual tab creation to Blizzard's TabSystemTemplate framework
- **Core.lua rewrite**: Removed ~60 lines of manual logic, added InitializeTabSystem() using TabSystemOwnerMixin
- **Framework integration**: Proper mixin application (TabSystemOwnerMixin + TabSystemMixin) with programmatic frame creation
- **Content anchoring**: Updated Tasks.lua and Leaderboard.lua to anchor relative to TabSystem instead of hardcoded offsets
- **Bug fix**: Corrected initialization order - properties must be set BEFORE OnLoad() to properly initialize frame pool
- **UI Polish**: Tabs now hang below header with proper visual states, hover effects, and keyboard navigation
- **Bootstrap cleanup**: Removed TAB_HEIGHT and TAB_LABELS constants (framework handles sizing/creation)
- **In-game validation**: User confirmed tabs looking great with adjusted header height

**Guard Clause Cleanup & Documentation Enhancement (Feb 7)** ✅
- **Guard review**: Identified and removed 4 unnecessary guards hiding loading order issues
- **Code cleanup**: Tasks.lua and Core.lua now fail fast on internal module issues
- **TOC loading documentation**: Added detailed explanation of when code executes during load
- **Comparison table**: Runtime vs loading checks quick reference guide
- **Validation section**: Added make commands (toc_check, dev, watch) to conditional instructions
- **Maintenance guidelines**: Documented which docs to update for different types of changes
- **In-game validation**: Confirmed no Lua errors with cleaned-up guards

**Workflow Optimization & Documentation Restructuring (Feb 7)** ✅
- **Created `/refactor` workflow**: Comprehensive multi-file refactoring with GPT-5.1-Codex-Max delegation
- **Context optimization**: Reduced main instructions from 252→157 lines (38% reduction)
- **Conditional instructions**: Created lua-development.instructions.md and wow-api.instructions.md (auto-load for Lua files)
- **On-demand docs**: Extracted glossary.md (99 lines) and resources.md (180 lines) for as-needed loading
- **Workflow documentation**: Created comprehensive prompts/README.md documenting all 5 workflows
- **Benefits**: Longer agent sessions, more efficient park/resume, context-aware guidance for Lua development

**MessageCodec Bug - RESOLVED (Feb 7)** ✅
- **Issue**: Raw binary data (compressed CBOR) corrupted during addon message transmission
- **Root Cause**: WoW's addon message API has undocumented quirks with binary data patterns
- **Solution**: Three-step encoding: CBOR → Deflate → Base64 (makes binary safe as ASCII)
- **Result**: Reliable transmission with ~16% size reduction (typical: 115 raw → 96 encoded bytes)
- **Testing**: Validated through multiple approaches (plain CBOR works, compression needs Base64)

---

## Project Vision

Enhance the WoW Endeavors system by aggregating character contributions by player (BattleTag/alias), enabling friendly competition and better awareness of neighborhood progress.

## Phased Development Plan

### Phase 1: Local Storage & Character Registration ✅

**Status**: Complete

**Goals**:
- [x] Set up SavedVariables structure with DB service layer
- [x] On login, detect current character and register to player's BattleTag
- [x] Track timestamps for all changes
- [x] Add simple alias setter (slash command)
- [x] Separate authoritative data (`myProfile`) from synced data (`profiles`)

**Completed Features**:
- `Data/Database.lua` - Complete data access layer
- `Services/PlayerInfo.lua` - WoW API wrappers for player/character info
- `/endeavoring alias <name>` - Set player alias
- `/endeavoring alias` - View current alias
- Automatic character registration on login
- Timestamp tracking: `aliasUpdatedAt` and `charsUpdatedAt`

**Key Decisions Made**:
- Use `global` scope instead of profiles (data shared across all characters)
- Character key is just character name (matches API output)
- Minimal character data (name + realm only)
- Separate timestamps for alias vs character changes (enables delta sync)
- `myProfile` is authoritative and immune to sync tampering

### Phase 2: Options UI 📋

**Status**: Planned (not started)

**Goals**:
- [ ] Create settings panel to view/edit alias
- [ ] Show list of registered characters
- [ ] (Optional) Allow manual character removal
- [ ] (Optional) Reset/clear profile data

**Considerations**:
- Use AceConfig or native Blizzard settings panel?
- Where to hook into WoW settings? (ESC menu or Housing Dashboard?)
- Display character list with timestamps?

### Phase 3: Addon Communication ✅

**Status**: Complete

**Goals**:
- [x] Design sync protocol (manifest/request/response messages)
- [x] Implement guild channel broadcasting
- [x] Handle incoming data + conflict resolution (timestamp wins)
- [x] Guild roster update triggering (debounced with random delay)
- [x] Whisper-based request/response to reduce spam

**Completed Features**:
- `Services/Sync.lua` - Complete communication layer
- MANIFEST broadcast to GUILD on login and guild roster updates
- Alias synced directly from MANIFEST (REQUEST_ALIAS removed)
- REQUEST_CHARS/CHARS_UPDATE via WHISPER channel
- Message parsing with validation (BattleTag format, timestamp ranges)
- Delta sync working (only request characters added after cached timestamp)
- Realm handling with GetNormalizedRealmName() fallback
- Debug commands: `/endeavoring sync status`, `/endeavoring sync broadcast`, `/endeavoring sync purge`
- Verbose debug mode: `/endeavoring sync verbose`

**Key Implementation Details**:
- GUILD_ROSTER_UPDATE triggers manifest after 5s debounce + 2-10s random delay
- Prevents thundering herd on raid nights
- Validates all incoming data (prevents tampering with myProfile)
- Empty realm strings handled gracefully

**Not Yet Implemented** (optional enhancements):
- Message chunking for large character lists (50+ characters)

### Phase 3.5: Gossip Protocol ✅

**Status**: Complete

**Problem Solved**: 
Direct sync only works when both players are online simultaneously. Gossip protocol enables offline update propagation and profile discovery through transitive sharing.

**Goals**:
- [x] Share cached profiles when receiving MANIFEST
- [x] Track gossip by BattleTag (handles alt-swapping)
- [x] Per-session gossip limits (no redundant sharing)
- [x] Rate limiting (bandwidth control)

**Completed Features**:
- **Opportunistic Push**: When receiving MANIFEST, share up to 3 cached profiles
- **BattleTag Tracking**: `lastGossip[senderBattleTag][profileBattleTag] = true`
- **Session-Based**: Tracking resets on reload/relog (not persisted)
- **Smart Selection**: Prioritizes recently updated profiles
- **Gossip Stats**: `/endeavoring sync gossip` shows sharing statistics
- **Alt-Swapping Handled**: Won't re-gossip when player switches characters

**Implementation Notes**:
- Uses existing ALIAS_UPDATE and CHARS_UPDATE messages (no protocol changes)
- Max 3 profiles per MANIFEST received (bandwidth control)
- All gossip via WHISPER (doesn't spam guild chat)
- Natural reset on session boundary

**Benefits**:
- True eventual consistency - profiles spread through network
- New players discover all cached profiles from whoever is online
- Offline updates eventually propagate to everyone
- Network becomes self-healing

### Phase 3.75: Message Codec (CBOR + Compression + Base64) ✅

**Status**: Complete (Bug Fixed Feb 7, 2026)

**Problem Solved**:
Manual string concatenation was inefficient, difficult to extend, and risked exceeding 255-byte message limit with 10+ alts. Needed structured serialization with compression for larger datasets. Additionally, raw binary data (even plain CBOR) has transmission issues through WoW's addon message API.

**Goals**:
- [x] Implement CBOR serialization for structured messages
- [x] Add compression for size reduction
- [x] Ensure reliable transmission through WoW API (Base64 encoding)
- [x] Message type embedded in payload (no string delimiters)
- [x] Comprehensive error handling and validation

**Completed Features**:
- **`Services/MessageCodec.lua`** - Complete codec service
  - Three-step encoding: CBOR serialize → Deflate compress → Base64 encode
  - Three-step decoding: Base64 decode → Deflate decompress → CBOR deserialize
  - Base64 ensures binary data becomes safe ASCII characters
  - `Encode()` and `Decode()` with comprehensive error messages
  - Debug size reporting (verbose mode)
- **Updated `Services/Sync.lua`** - Message type inside CBOR payload
  - Message type stored in `data.type` field (inside CBOR, not as prefix)
  - Single-character message types: M, R, A, C (wire efficiency)
  - Message size validation (255-byte hard limit)
  - Return code checking with detailed error messages
  - Removed `ParsePayload()` helper (single decode path)
  - All V1 pipe-delimited code removed (clean break)

**Size Profile** (typical MANIFEST message):
- Raw (JSON equivalent): ~115 bytes
- After CBOR: ~87 bytes (24% saved)
- After compression: ~70 bytes (39% saved)
- After Base64: ~96 bytes (16% total saved)
- **Headroom**: 96/255 = 38% of limit

**Bug Fix Journey** (Feb 7, 2026):
1. **Original**: String prefix + CBOR binary → Corruption (null bytes treated as terminators)
2. **Attempt**: Message type inside CBOR, no compression → Still corrupted
3. **Attempt**: Always compress with flags byte → Decompression failed
4. **Attempt**: Simplified always-compress pipeline → Decompression failed  
5. **Test**: Plain CBOR only (no compression) → ✅ Worked!
6. **Attempt**: Double-CBOR wrapping around compression → Failed
7. **Solution**: CBOR → Compress → Base64 → ✅ Works!

**Key Insight**: WoW's addon message API has undocumented issues with raw binary data patterns (especially compressed data). Base64 encoding solves this by converting everything to safe ASCII.

**Error Handling (Defense in Depth)**:
1. **Compression** - Reduces message size significantly
2. **Build-time warning** - Alerts during message construction (verbose)
3. **Pre-send validation** - Blocks messages >255 bytes with clear error
4. **Return code checking** - Catches all 12 API failure modes with details

**Key Decisions**:
- **CBOR over JSON**: Smaller, binary-efficient, better compression
- **Always compress**: Deterministic pipeline, no conditional logic
- **Base64 required**: Only way to reliably transmit compressed data
- **Type inside payload**: Avoids all string+binary mixing issues
- **No backward compatibility**: 0 users, clean break acceptable
- **Single-char types**: `MANIFEST` → `M` saves 7 bytes per message

**What's NOT Implemented** (deferred to Phase 4):
- Message chunking for 50+ character profiles (still exceeds limit after compression)
- Conditional compression (would save ~10-20 bytes on tiny messages, not worth complexity)

### Phase 3.8: Leaderboard UI 📊

**Status**: Complete ✅

**Summary**: Full-featured leaderboard UI with BattleTag aggregation, time filters, and proper event handling.

**Completed Features**:
- **BattleTag Aggregation** (`BuildEnriched()`) - Groups all alts under player's alias/BattleTag
  - Uses CharacterCache for O(1) character→BattleTag lookups
  - Falls back to character name for players not in sync network
  - Aggregates contribution totals and entry counts
  - Adds `charNames` array for future tooltip use
- **Complete UI Panel** (`CreateTab()`)
  - Time range filter buttons (All Time, This Week, Today)
  - Sortable by total contribution (descending)
  - Scrollable leaderboard with rank, player name, total, and entry count
  - Local player highlighting (bright green)
  - Header alignment with scrollbar offset (SCROLLBAR_WIDTH constant)
- **Proper Event Handling**
  - Registers `INITIATIVE_ACTIVITY_LOG_UPDATED` event once during tab creation
  - True debounce implementation with timer cancellation (prevents triple-fire)
  - Separates data fetching (`Refresh()`) from display update (`UpdateLeaderboardDisplay()`)
- **CharacterCache Enhancements**
  - Selective invalidation by BattleTag (more efficient than full rebuild)
  - Handles full, selective, and fresh cache states
  - Includes MyProfile in lookups for local player aggregation

**UI Layout**:
- Time filter buttons at top
- Header row with column labels (Rank, Player, Total, Entries)
- Scrollable content area with proper alignment
- Empty state handling

**Testing Status**: ✅ Validated in-game with 2 players, multiple alts

**Completed Enhancements**:
- ✅ **Addon indicator icon for synced players** (Feb 9, 2026 - Early)
- ✅ **Leaderboard character tooltips** (Feb 9, 2026 - Early) - Hover over player to see contributing character names
- ✅ **Column sorting** (Feb 9, 2026 - Late) - House XP and Coupons columns now sortable on Tasks tab
- ✅ **Task row improvements** (Feb 9, 2026 - Early) - Complete table redesign with icons, separators, coupons column
- ✅ **Tab styling polish** (Feb 8, 2026) - Migrated to Blizzard's TabSystemTemplate for better visuals
- ✅ **Header enhancements** (Feb 9, 2026 - Late) - Colored progress bar, milestone list with tooltips, endeavor description icon
- ✅ **Leaderboard column sorting** (Feb 10, 2026) - All four columns (Rank, Player, Total, Tasks Completed) clickable with smart defaults

**Remaining Enhancements** (documented as TODOs):
- [ ] Additional time ranges ("This Month", custom date selector)
- [ ] Activity/History tab (separate from leaderboard, shows raw activity log entries)

### Phase 4: Testing & Polish + Code Quality 🔬

**Status**: In Progress (Active Testing & Refactoring)

**Completed** (Feb 7-8, 2026):
- [x] Multi-account testing (2 accounts, 9 characters)
- [x] Message size limit handling (chunking implemented)
- [x] Restricted zone messaging (lockdown detection)
- [x] Backward compatibility validation
- [x] Gossip protocol verification
- [x] **Major code refactoring** (see Phase 4.5 & 4.6 below)
- [x] TabSystem framework migration (see Phase 4.6 below)

**In Progress**:
- [ ] Large character list testing (15+ characters)
- [ ] Instance lockdown detection testing
- [ ] Edge case handling (offline sync, partial data)
- [ ] Performance testing (large guilds, many characters)

**Goals**:
- [x] Comprehensive multi-account testing across various scenarios
- [ ] Performance testing (large guilds, many characters)
- [ ] Edge case handling (offline sync, partial data, etc.)
- [ ] Debug commands for troubleshooting

### Phase 4.5: Code Quality - Sync Module Refactoring ✅

**Status**: Complete (Feb 7, 2026)

**Problem**: Services/Sync.lua had grown to 858 lines with mixed responsibilities (WoW API, protocol handling, orchestration, gossip logic, caching).

**Goals**:
- [x] Extract distinct responsibilities into focused modules
- [x] Improve testability and maintainability
- [x] Create reusable components (character cache for leaderboard)
- [x] Clear architectural boundaries

**Completed Work**:

1. **Protocol.lua Extraction** (404 lines → 386 after gossip extraction)
   - Message parsing (ParseMessage, ValidateBattleTag, ValidateTimestamp)
   - Message routing (RouteMessage)
   - All handlers: HandleManifest, HandleRequestChars, HandleAliasUpdate, HandleCharsUpdate
   - Database updates and character cache invalidation
   - Public API: `Protocol.OnAddonMessage(prefix, message, channel, sender)`

2. **CharacterCache.lua** (79 lines)
   - O(1) character name → BattleTag lookups
   - Lazy cache rebuilding when stale
   - Reusable for leaderboard feature
   - Public API: `FindBattleTag()`, `Invalidate()`, `GetStats()`

3. **Coordinator.lua** (199 lines)
   - Orchestration and timing logic
   - Heartbeat timer (5-minute idle manifests)
   - Roster event throttling (max 1 per minute)
   - Character list chunking (5 per message)
   - Manifest debouncing and scheduling
   - Public API: `Init()`, `SendManifest()`, `SendCharsUpdate()`, `GetSyncStats()`

4. **Gossip.lua** (196 → 227 lines)
   - Opportunistic profile propagation
   - Profile selection algorithm
   - Per-session gossip tracking
   - **Bidirectional correction**: `CorrectStaleAlias()`, `CorrectStaleChars()`
   - Public API: `MarkKnownProfile()`, `SendProfilesToPlayer()`, `CorrectStaleAlias()`, `CorrectStaleChars()`, `GetStats()`

5. **Sync → AddonMessages Rename** (162 lines, 81% reduction!)
   - Services/Sync.lua → Services/AddonMessages.lua
   - Reflects true responsibility: WoW addon message API abstraction
   - Pure WoW API layer: Init, BuildMessage, SendMessage, RegisterListener

6. **MSG_TYPE Enum** (Bootstrap.lua)
   - Shared constant across all modules
   - Type annotation: `---@enum MessageType`
   - Single source of truth for message types
   - No more duplication across files

**Benefits**:
- **Single Responsibility**: Each module has one clear purpose
- **Easier Testing**: 79-227 line modules vs 858-line monolith
- **Better Maintainability**: Clear boundaries reduce cognitive load
- **Reusability**: CharacterCache usable for leaderboard feature
- **Type Safety**: MSG_TYPE enum enables IDE autocomplete
- **Clear Layering**: Bootstrap → Services → Data → Sync → Features

**Metrics**:
- Original: 858 lines (monolithic Sync.lua)
- Final: 162 lines (AddonMessages.lua) + 878 lines (4 Sync modules)
- Protocol handlers: 81% reduction in AddonMessages.lua
- Documentation: All module headers updated to reflect new architecture

### Phase 4.6: TabSystem Framework Migration ✅

**Status**: Complete (Feb 8, 2026)

**Problem**: Manual tab creation and state management led to verbose code (~60 lines), required manual layout positioning, and didn't provide proper Blizzard UI behavior (hover states, keyboard navigation, etc.).

**Goals**:
- [x] Migrate to Blizzard's TabSystemTemplate framework
- [x] Use TabSystemOwnerMixin for automatic state management
- [x] Apply TabSystemMixin with HorizontalLayoutFrame for automatic layout
- [x] Position tabs below header (hanging off top) like Housing Dashboard
- [x] Update content area anchoring to be relative to TabSystem

**Completed Work**:

1. **Core.lua - Complete Rewrite**
   - **Removed**: `SetActiveTab()`, `CreateTabContent()`, `CreateTabs()` (~60 lines)
   - **Added**: `InitializeTabSystem()` function
     - Applies `TabSystemOwnerMixin` to main frame
     - Creates TabSystem child frame programmatically (HorizontalLayoutFrame + TabSystemMixin)
     - Configures properties: `minTabWidth`, `maxTabWidth`, `tabTemplate`, `spacing`, `tabSelectSound`
     - Positions tabs below header: `SetPoint("BOTTOMLEFT", frame.header, "BOTTOMLEFT", 8, -2)`
     - Uses `AddNamedTab()` to register tabs with content frames
     - Sets initial tab with `SetTab()`

2. **Bootstrap.lua - Cleanup**
   - **Removed**: `TAB_HEIGHT` constant (framework handles sizing)
   - **Removed**: `TAB_LABELS` array (tabs registered directly in code)

3. **Tasks.lua - Anchor Update**
   - **Changed**: Content anchoring from hardcoded `(12, -152)` to `TabSystem` relative `(4, -8)`
   - Positions content below tabs instead of at fixed offset

4. **Leaderboard.lua - Anchor Update**
   - **Changed**: Same anchoring pattern as Tasks.lua
   - Content now follows TabSystem position dynamically

**Bug Fix** (Initialization Order):
- **Issue**: `tabTemplate` property set AFTER `OnLoad()` caused nil mixin error
- **Root Cause**: `OnLoad()` creates frame pool using `self.tabTemplate` - must be set beforehand
- **Solution**: Reordered code to set all properties BEFORE calling `tabSystem:OnLoad()`

**Technical Details**:
- TabSystem uses `CreateFramePool("BUTTON", self, self.tabTemplate)` internally
- Template must exist when pool is created, not after
- Properties configured before initialization: template, widths, spacing, sound

**Benefits**:
- **Framework Integration**: Uses Blizzard's tested TabSystemTemplate
- **Cleaner Code**: Removed ~60 lines of manual tab management
- **Auto Layout**: HorizontalLayoutFrame handles tab spacing/positioning
- **Better UX**: Proper hover states, active/inactive visuals, keyboard navigation
- **Accessibility**: Inherits Blizzard's sound effects and accessibility features
- **Maintainability**: Follows same pattern as Housing Dashboard

**Testing**: ✅ Validated in-game, user adjusted header height, tabs looking great

**Key Learnings**:
- TabSystemMixin properties must be set BEFORE OnLoad()
- Content frames anchor to `parent.TabSystem` (not `parent.tabSystem`)
- TabSystemTopButtonTemplate designed for tabs hanging off top of frame
- Framework handles all tab state management (no manual SetEnabled needed)

## Current Architecture

```
Endeavoring/
├── Bootstrap.lua          # Constants, enums (MSG_TYPE), namespace init, DebugPrint
├── Commands.lua          # ✅ Slash command handlers
├── Core.lua              # Main frame, events, initialization
├── Data/
│   └── Database.lua      # ✅ Complete - Data access layer (483 lines)
├── Features/
│   ├── Header.lua        # Endeavor info display
│   ├── Leaderboard.lua   # ✅ CLI leaderboard (untested)
│   └── Tasks.lua         # Task list
├── Integrations/
│   └── HousingDashboard.lua  # Blizzard frame integration
├── Services/
│   ├── AddonMessages.lua     # ✅ WoW addon message API (162 lines, was Sync.lua)
│   ├── MessageCodec.lua      # ✅ CBOR + compression + Base64
│   ├── NeighborhoodAPI.lua   # Neighborhood/Initiative APIs
│   └── PlayerInfo.lua        # ✅ Player info APIs
└── Sync/
    ├── CharacterCache.lua    # ✅ O(1) character→BattleTag lookups (79 lines)
    ├── Coordinator.lua       # ✅ Orchestration, timing, throttling (199 lines)
    ├── Gossip.lua           # ✅ Profile propagation + correction (227 lines)
    └── Protocol.lua         # ✅ Message handlers and routing (386 lines)
```

**Architecture Principles**:
- **Bootstrap.lua** - Shared constants and utilities
- **Services/** - WoW API abstractions (change between patches)
- **Sync/** - Protocol components (business logic, stable)
- **Data/** - Persistence layer (SavedVariables)
- **Features/** - UI and user-facing functionality
- **Integrations/** - Hooks into Blizzard/other addon frames

**Missing Components**:
- `Features/Settings.lua` - Options panel *(Phase 2)*
- `Features/Leaderboard.lua` - Leaderboard UI *(Future)*

## Known Issues & Technical Debt

### Current Limitations

**Profile Discovery**: Gossip protocol provides eventual consistency, but there's no "catalog exchange" to discover profiles we've completely missed. A future enhancement could add periodic BattleTag list comparison to find gaps.

**Message Chunking**: ✅ Implemented (Feb 7, 2026). Testing revealed the 255-byte limit is hit around 9 characters (~260 bytes). Implemented automatic chunking at 5 characters per CHARS_UPDATE message. Chunking is transparent to receivers (leverages delta sync) and backward compatible.

**In-Game Testing**: All code compiles successfully, but hasn't been tested in-game yet. Need multi-account testing to validate:
- Compression is working correctly
- Size estimates are accurate
- Error handling catches edge cases
- Gossip protocol spreads updates as expected

### Clean Architecture

Codebase is clean and well-organized:
- Clear separation between Services/ (WoW APIs) and Data/ (persistence)
- MessageCodec provides reusable CBOR + compression abstraction
- Commands.lua provides discrete handlers for slash commands
- Message prefix constants eliminate magic strings
- Verbose debug mode for production-ready logging
- Defense-in-depth error handling (compression → validation → return codes)

## Recent Architectural Decisions

### Message Codec - CBOR Over JSON (2026-02-06)

- **Decision**: Use CBOR serialization instead of JSON or manual string concatenation
- **Rationale**: 
  - Binary format is more compact and compresses better
  - Type preservation (numbers stay numbers, no string conversion)
  - Native WoW API support via `C_EncodingUtil`
  - Structured data easier to extend than pipe-delimited strings
- **Trade-off**: Not human-readable on the wire, but debug output handles this
- **Impact**: 40-60% size reduction with compression, supports 20+ character profiles

### Single-Character Message Types (2026-02-06)

- **Decision**: Use single-character message type identifiers (M, R, A, C)
- **Rationale**: Saves 7-12 bytes per message vs full names like "MANIFEST"
- **Implementation**: Enum keys remain readable (`MSG_TYPE.MANIFEST`), values are wire format
- **Impact**: 4 bytes total overhead per message (type + delimiter + protocol bytes)

### Protocol Versioning (2026-02-06)

- **Decision**: Include version + flags bytes in every message
- **Format**: `[version:1][flags:1][compressed CBOR payload]`
- **Rationale**: Enables future protocol evolution without breaking changes
- **Flags**: Bit 0 = compressed, bits 1-7 reserved (encryption, delta encoding, signatures)
- **Cost**: 2 bytes per message, worthwhile for long-term flexibility

### No Backward Compatibility (2026-02-06)

- **Decision**: Full V1 removal, CBOR-only with no fallback
- **Rationale**: 0 users in alpha phase, clean break keeps codebase simple
- **Alternative Rejected**: Dual V1/V2 transmission would add complexity for no benefit
- **Impact**: All users must update simultaneously, acceptable during alpha

### Directory Structure (2026-02-06)

- **Decision**: Split `Database.lua` into `Data/` (data layer) and extracted WoW API calls to `Services/PlayerInfo.lua`
- **Rationale**: Cleaner separation of concerns, easier testing, clear dependency boundaries
- **Impact**: All future WoW API wrappers go in `Services/`, data access in `Data/`

### Guard Clauses (2026-02-06, updated 2026-02-07)

- **Decision**: Only use guards for external/optional dependencies, not our own code
- **Rationale**: TOC loading only executes root-level code; functions are just defined (don't execute until called after all files load). Load order bugs should fail loudly during testing, not be hidden by guards.
- **Rule**: Guard `C_*` APIs and optional integrations; don't guard `ns.DB`, `ns.API`, etc.
- **Why fail fast**: If internal modules are nil when called, it's a bug (wrong TOC order, premature root-level execution). Let it error immediately rather than masking the problem.
- **Update (2026-02-07)**: Documented TOC loading behavior in lua-development.instructions.md and architecture.md

### Timestamp Strategy (2026-02-06)

- **Decision**: Separate `aliasUpdatedAt` and `charsUpdatedAt` instead of single `updatedAt`
- **Rationale**: Enables efficient delta sync - receivers know exactly what changed
- **Benefit**: Minimizes data transfer over 255-byte message limit

### Authoritative Data Model (2026-02-06)

- **Decision**: `myProfile` separate from `profiles`, never synced
- **Rationale**: Prevents tampering, clear source of truth, simpler sync logic
- **Security**: All sync methods explicitly reject attempts to modify `myProfile`

## Upcoming Decisions

### Phase 3 Implementation Choices

**Communication Channel**:
- GUILD (primary) - most relevant for neighborhood members
- INSTANCE (fallback) - may work for neighborhood area?
- Custom channel - future consideration

**Encoding Strategy**:
- Start simple: pipe-delimited strings
- Future: LibSerialize + LibDeflate if needed

**Request Coalescing**:
- 2-3 second buffer after receiving requests?
- Batch multiple requests from same sender?

**Retry Strategy**:
- Retry once after 5 seconds if no response?
- How to handle permanently offline players?

### Phase 2 UI Choices

**Settings Integration**:
- Blizzard settings panel (native, requires more boilerplate)
- AceConfig (easier, requires library dependency)
- Custom frame (most flexible, most work)

**Character List Display**:
- Show addedAt timestamps?
- Allow manual removal of old characters?
- Display realm for all characters?

## Next Steps

### Immediate Priority: In-Game Testing (Phase 4)

**Goal**: Validate complete sync protocol with real data across multiple accounts

**Testing Plan**:
1. Enable verbose debug mode: `/endeavoring sync verbose`
2. Test message encoding/decoding with real profiles
3. Verify Base64 encoding prevents transmission corruption
4. Test with multiple characters per account (1, 5, 10, 20)
5. Monitor message sizes and compression effectiveness
6. Test gossip propagation with multiple accounts
7. Verify sync works across guild members
8. Test edge cases (special characters in names, multiple realms, etc.)

**Success Criteria**:
- ✅ Messages encode/decode successfully (Base64 fix working)
- Messages stay well under 255-byte limit
- Compression provides meaningful size reduction
- Clear error messages for any failures
- Gossip spreads profiles to all online players
- No Lua errors or stack traces
- Size reporting in verbose mode shows accurate stats

### Secondary Priority: Options UI (Phase 2)

**Goal**: Provide user-friendly interface for alias management

**Components**:
- Settings panel accessible from ESC menu or Housing Dashboard
- View/edit alias
- List registered characters with timestamps
- Manual character removal option
- Verbose debug mode toggle (GUI alternative to slash command)

### Future Enhancements

**Task Grouping & Smart Filtering** (Requested Feb 10):
- Group/filter tasks by location type: "In the Neighborhood", "In the Related Zone", "End Game"
- Help players find relevant tasks efficiently based on where they want to play
- Identify overlapping tasks for combined completion
- Example: Raid boss kills may count toward multiple tasks

**Personal Activity Log** (Requested Feb 10):
- Per-character activity tracking and statistics
- Show which activities you favor and on which characters
- Complement the aggregated leaderboard view with individual character insights
- Help players understand their play patterns across alts

**Housing XP Cap Progress Bar** (Requested Feb 10):
- Display progress toward housing XP cap (2250 from activities + 250 from chest)
- Visual indicator of how much more XP you can earn this period
- Helps players optimize their time and avoid wasting effort on capped rewards

**Endeavor Completion Alert** (Requested Feb 10):
- Alert/notification if endeavor is complete but chest hasn't been looted
- Reminder for easy 250 housing XP that players might forget
- Prevent missing out on reward before endeavor period ends

**True "All Time" Tracking** (Idea - Feb 10):
- Currently "Current Endeavor" filter shows data for active endeavor only (Blizzard API limitation)
- Could support true all-time tracking across multiple endeavor periods by storing final activity snapshots
- Would require: someone with addon to capture final state + data propagation mechanism
- Alternative: Companion desktop app + web app that uploads to central database
- **Status**: Interesting concept but complex - low priority unless strong user demand
- **Note**: Renamed filter from "All Time" → "Current Endeavor" (Feb 10) to eliminate confusion about scope

**Catalog Exchange (Phase 3.6):**
- Exchange BattleTag lists to discover completely missed profiles
- Request specific missing profiles
- Fills gaps that gossip alone can't handle


## Testing Status

**Manual Testing**: Active - user testing with guild members

**Automated Testing**: Not yet implemented

**Test Coverage**: N/A

### Known Issues

**Coupon Display Quirk** (Feb 10):
- Occasionally coupons show as "-" on first login to a character
- Does not persist after relog/reload
- Suspected Blizzard API timing issue - data not fully loaded when queried
- No Lua errors generated
- **Status**: Monitoring - may self-resolve as Blizzard polishes Endeavors system

**Fixed Issues** (Feb 10):
- ✅ Debug message when logging into non-guild characters - Added channel validation in AddonMessages.lua
- ✅ Alias updates not refreshing leaderboard - Added RequestActivityLog() calls after profile changes
- ✅ First click on Rank column appearing to do nothing - Fixed state initialization to explicitly set default sort key

## Dependencies

**Current**:
- None (vanilla WoW addon)
- Uses native `C_EncodingUtil` API for CBOR serialization and compression

**Considered for Future**:
- AceConfig (settings UI)

**Not Needed** (using native APIs instead):
- ~~LibSerialize~~ - Using `C_EncodingUtil.SerializeCBOR`
- ~~LibDeflate~~ - Using `C_EncodingUtil.CompressString`

## Development Workflows

The project includes custom prompt files to streamline complex development tasks. These leverage different AI models for their strengths.

### Available Prompts

**`/refactor [description]`** - Complex code refactoring
- **Use for**: Multi-file refactoring, architectural restructuring, large-scale renaming
- **How it works**: Claude Sonnet 4.5 orchestrates planning and validation, delegates actual code changes to GPT-5.1-Codex-Max subagent
- **Why**: GPT-5.1-Codex-Max excels at preserving exact whitespace, updating all call sites, and handling complex multi-line replacements
- **Process**: Git checkpoint → Plan → Execute (via subagent) → Validate each step → Recovery if needed
- **Example**: `/refactor Extract Protocol module from Sync.lua`

**`/plan [feature]`** - Feature planning session
- **Use for**: Designing new features, architectural decisions, scoping complex work
- **How it works**: Collaborative planning with technical analysis, dependency identification, and implementation roadmap
- **Example**: `/plan Leaderboard UI panel`

**`/park`** - Save session progress
- **Use for**: Ending a development session and handing off context
- **How it works**: Updates documentation with session accomplishments, generates comprehensive handoff summary
- **Output**: Copy/paste-ready handoff for `/resume` in next session

**`/resume [handoff]`** - Restore context from parked session
- **Use for**: Starting work after a `/park` handoff
- **How it works**: Parses handoff, validates current state, confirms next steps, proceeds with work
- **Example**: `/resume [paste handoff summary here]`

**`/review [scope]`** - Code review
- **Use for**: Getting feedback on code quality, identifying issues, suggesting improvements
- **How it works**: WoW addon development best practices, Lua patterns, architectural review

### Model Selection Guidelines

Different AI models excel at different tasks:

**GPT-5.1-Codex-Max**:
- Multi-file refactoring (superior accuracy)
- Complex code restructuring
- Precise multi-line replacements
- Finding and updating ALL references

**Claude Sonnet 4.5** (default):
- General development and feature implementation
- High-level planning and architecture
- Code review and analysis
- User communication and collaboration
- Workflow orchestration

**When refactoring**:
- Simple (single file, small scope): Claude can handle directly
- Complex (multi-file, large scale): Use `/refactor` to leverage GPT-5.1-Codex-Max
- **Golden Rule**: If struggling with multi-line replacements or worried about missed references, use `/refactor`

See [copilot-instructions.md](../.github/copilot-instructions.md#agent--model-selection) for full guidelines.

## Performance Metrics

*To be measured in Phase 4*

**Target Goals**:
- Memory footprint: < 1 MB
- Message frequency: < 5 messages per player per minute
- Sync latency: < 10 seconds for new player data

## See Also

- [Database Schema](database-schema.md) - Data structure and access patterns
- [Sync Protocol](sync-protocol.md) - Communication protocol design
- [Architecture](architecture.md) - Project structure and conventions
- [Message Codec](message-codec.md) - CBOR encoding and compression
- [Glossary](glossary.md) - WoW and addon terminology
- [Resources](resources.md) - WoW API documentation and references
