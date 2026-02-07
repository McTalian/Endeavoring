# Development Status

**Last Updated**: February 7, 2026

## Recent Fix 🎉

**MessageCodec Bug - RESOLVED** (Feb 7, 2026)
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

### Phase 3.8: Leaderboard POC 📊

**Status**: Code Complete (Untested)

**Summary**: CLI-based contribution leaderboard aggregates activity log by player.

**Implementation**:
- **Features/Leaderboard.lua** (114 lines)
  - `BuildFromActivityLog()` - Aggregates tasks by player name
  - `BuildEnriched()` - Adds BattleTag/alias mapping (stub for now)
  - Time range filtering: All Time, Today (24h), This Week (7d)
  - Sorting by total contribution (desc) with alphabetical tie-breaker
- **Commands.lua** - Added `/endeavoring leaderboard [all|today|week]` (alias: `/endeavoring lb`)
- **NeighborhoodAPI.lua** - Added `GetActivityLogInfo()` and `RequestActivityLog()` wrappers

**Key Pattern**: Async event-driven data fetching
```lua
-- Register one-shot event handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("INITIATIVE_ACTIVITY_LOG_UPDATED")
frame:SetScript("OnEvent", function(self, event)
  self:UnregisterEvent("INITIATIVE_ACTIVITY_LOG_UPDATED")
  DisplayLeaderboard(timeRange)
end)
-- Request data
ns.API.RequestActivityLog()
```

**Testing Status**: ❌ Not tested in-game (requires active Endeavor)

**Next Steps**:
1. Test CLI leaderboard with real activity data
2. Integrate BattleTag mapping from sync profiles
3. Create UI panel using same pattern (event-driven + loading spinner)

### Phase 4: Testing & Polish 📅

**Status**: Test Plan Documented

**Goals**:
- [ ] Test with multiple accounts/characters
- [ ] Add safeguards (data validation, size limits)
- [ ] Performance testing (large guilds, many characters)
- [ ] Edge case handling (offline sync, partial data, etc.)
- [ ] Debug commands for troubleshooting

## Current Architecture

```
Endeavoring/
├── Bootstrap.lua          # Constants (including message prefixes), namespace init
├── Commands.lua          # ✅ Slash command handlers
├── Core.lua              # Main frame, events, initialization
├── Data/
│   └── Database.lua      # ✅ Complete - Data access layer (verbose mode toggle)
├── Features/
│   ├── Header.lua        # Endeavor info display
│   └── Tasks.lua         # Task list
├── Integrations/
│   └── HousingDashboard.lua  # Blizzard frame integration
└── Services/
    ├── MessageCodec.lua      # ✅ Complete - CBOR + compression codec
    ├── NeighborhoodAPI.lua   # Neighborhood/Initiative APIs
    ├── PlayerInfo.lua        # ✅ Complete - Player info APIs
    └── Sync.lua              # ✅ Complete - Communication + gossip layer
```

**Missing Components**:
- `Features/Settings.lua` - Options panel *(Phase 2)*
- `Features/Leaderboard.lua` - Leaderboard UI *(Future)*

## Known Issues & Technical Debt

### Current Limitations

**Profile Discovery**: Gossip protocol provides eventual consistency, but there's no "catalog exchange" to discover profiles we've completely missed. A future enhancement could add periodic BattleTag list comparison to find gaps.

**Message Chunking**: CBOR + compression handles up to ~20 character profiles comfortably within the 255-byte limit. Profiles with 50+ characters would still exceed the limit and need chunking. Most players won't hit this, so chunking is deferred as an optional enhancement (Phase 4).

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

### Guard Clauses (2026-02-06)

- **Decision**: Only use guards for external/optional dependencies, not our own code
- **Rationale**: Load order bugs should fail loudly in testing, not silently skip functionality
- **Rule**: Guard `C_*` APIs and optional integrations; don't guard `ns.DB`, `ns.API`, etc.

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

**Catalog Exchange (Phase 3.6)**:
- Exchange BattleTag lists to discover completely missed profiles
- Request specific missing profiles
- Fills gaps that gossip alone can't handle

**Message Chunking (Phase 4)**:
- Handle profiles with 50+ characters
- Split CHARS_UPDATE into numbered chunks
- Reassemble with 30-second timeout
- Only if real-world testing shows it's needed

## Testing Status

**Manual Testing**: In progress during development

**Automated Testing**: Not yet implemented

**Test Coverage**: N/A

## Dependencies

**Current**:
- None (vanilla WoW addon)
- Uses native `C_EncodingUtil` API for CBOR serialization and compression

**Considered for Future**:
- AceConfig (settings UI)

**Not Needed** (using native APIs instead):
- ~~LibSerialize~~ - Using `C_EncodingUtil.SerializeCBOR`
- ~~LibDeflate~~ - Using `C_EncodingUtil.CompressString`

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
