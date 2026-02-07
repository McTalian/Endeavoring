# Development Status

**Last Updated**: February 6, 2026

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

### Phase 3.75: Message Codec (CBOR + Compression) ✅

**Status**: Complete

**Problem Solved**:
Manual string concatenation was inefficient, difficult to extend, and risked exceeding 255-byte message limit with 10+ alts. Needed structured serialization with compression for larger datasets.

**Goals**:
- [x] Implement CBOR serialization for structured messages
- [x] Add automatic compression for large payloads
- [x] Protocol versioning for future evolution
- [x] Minimize wire overhead with short message types
- [x] Comprehensive error handling and validation

**Completed Features**:
- **`Services/MessageCodec.lua`** - Complete codec service
  - CBOR serialization via `C_EncodingUtil.SerializeCBOR`
  - Automatic Deflate compression for messages >100 bytes
  - Protocol format: `[version:1][flags:1][payload:N]`
  - Compression flag (bit 0) + 7 reserved flags for future use
  - `Encode()` and `Decode()` with comprehensive error messages
- **Updated `Services/Sync.lua`** - CBOR-only protocol
  - Single-character message types: M, R, A, C (saves 7-12 bytes per message)
  - Message size validation (255-byte hard limit)
  - Return code checking with detailed error messages
  - 90% threshold warning for verbose debug
  - All V1 pipe-delimited code removed (clean break)
- **Documentation**: [message-codec.md](../docs/message-codec.md)

**Size Improvements**:
- **Overhead**: 4 bytes total (type + delimiter + version + flags)
- **10 characters**: ~350 bytes → ~140-210 bytes (40-60% reduction)
- **20 characters**: ~700 bytes → ~280-420 bytes (fits in limit!)
- **Type identifiers**: ~10 bytes saved per message vs full names

**Error Handling (Defense in Depth)**:
1. **Compression** - Prevents most size issues automatically
2. **Build-time warning** - Alerts during message construction (verbose)
3. **Pre-send validation** - Blocks messages >255 bytes with clear error
4. **Return code checking** - Catches all 12 API failure modes with details

**Key Decisions**:
- **CBOR over JSON**: Smaller, binary-efficient, better compression
- **Auto-compression**: Transparent, triggered at 100-byte threshold
- **No backward compatibility**: 0 users, clean break acceptable
- **Single-char types**: `MANIFEST` → `M` saves 7 bytes per message
- **Version byte**: Enables future protocol evolution without breaking changes

**What's NOT Implemented** (deferred to Phase 4):
- Message chunking for 50+ character profiles (still exceeds limit after compression)

### Phase 4: Testing & Polish 📅

**Status**: Future

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

**Goal**: Validate message codec and gossip protocol with real data

**Testing Plan**:
1. Enable verbose debug mode: `/endeavoring sync verbose`
2. Test with multiple characters per account (1, 5, 10, 20)
3. Monitor message sizes and compression effectiveness
4. Validate error messages appear correctly
5. Test gossip propagation with multiple accounts
6. Verify sync works across guild members

**Success Criteria**:
- Messages stay well under 255-byte limit
- Compression triggers appropriately
- Clear error messages for any failures
- Gossip spreads profiles to all online players
- No Lua errors or stack traces

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
