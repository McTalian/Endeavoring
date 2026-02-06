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

**Key Implementation Details**:
- GUILD_ROSTER_UPDATE triggers manifest after 5s debounce + 2-10s random delay
- Prevents thundering herd on raid nights
- Validates all incoming data (prevents tampering with myProfile)
- Empty realm strings handled gracefully

**Not Yet Implemented** (optional enhancements):
- Message chunking for large character lists (50+ characters)
- Verbose/debug logging toggle

### Phase 3.5: Cached Profile Propagation 📋

**Status**: Planned (builds on Phase 3)

**Problem**: 
Currently, sync only works when both players are online simultaneously. If Player A updates their alias while Player B is offline, Player B won't receive the update until they both happen to be online at the same time again. This breaks eventual consistency.

**Goal**: Ensure all cached profiles eventually reach consistency even when players are offline

**Approach**:
When receiving a MANIFEST, compare against ALL cached profiles (not just the sender's):
- If we have Player C's cached profile and their timestamps are older than ours
- We can send Player C's data to the MANIFEST sender
- The sender caches it and will eventually propagate it to Player C
- Result: Profiles spread through the network transitively

**Implementation Steps**:
- [ ] On MANIFEST receipt, iterate through cached profiles
- [ ] For each cached profile with newer timestamps than sender has
- [ ] Send ALIAS_UPDATE/CHARS_UPDATE to inform sender
- [ ] Sender caches the data and propagates on their next MANIFEST broadcast
- [ ] Add "gossip protocol" to gradually sync all cached data across network

**Challenges**:
- Bandwidth: Could generate many messages if profiles are very outdated
- Rate limiting: Need to spread gossip messages over time
- Loops: Need to ensure we don't create infinite propagation loops
- Privacy: Consider if players want to opt out of profile propagation

**Benefits**:
- True eventual consistency
- Network becomes self-healing
- New player joining guild gets all cached profiles quickly
- Offline updates eventually propagate to everyone

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
├── Bootstrap.lua          # Constants, namespace init
├── Core.lua              # Main frame, events, slash commands
├── Data/
│   └── Database.lua      # ✅ Complete - Data access layer
├── Features/
│   ├── Header.lua        # Endeavor info display
│   └── Tasks.lua         # Task list
├── Integrations/
│   └── HousingDashboard.lua  # Blizzard frame integration
└── Services/
    ├── NeighborhoodAPI.lua   # Neighborhood/Initiative APIs
    ├── PlayerInfo.lua        # ✅ Complete - Player info APIs
    └── Sync.lua              # ✅ Complete - Communication layer
```

**Missing Components**:
- `Features/Settings.lua` - Options panel *(Phase 2)*
- `Features/Leaderboard.lua` - Leaderboard UI *(Future)*

## Known Issues & Technical Debt

### Current Limitations

**Eventual Consistency**: Profiles only sync when both players are online simultaneously. See Phase 3.5 for planned gossip protocol to address this.

**Debug Logging**: All sync messages currently print to chat. Need verbose/debug mode toggle.

### Clean Architecture

No technical debt - Phase 1-3 implementation is clean and well-architected.

## Recent Architectural Decisions

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

## Testing Status

**Manual Testing**: In progress during development

**Automated Testing**: Not yet implemented

**Test Coverage**: N/A

## Dependencies

**Current**:
- None (vanilla WoW addon)

**Considered for Future**:
- LibSerialize (data encoding)
- LibDeflate (compression)
- AceConfig (settings UI)

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
