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

### Phase 3: Addon Communication 🚧

**Status**: Designed (implementation pending)

**Goals**:
- [ ] Design sync protocol (manifest/request/response messages)
- [ ] Implement guild channel broadcasting
- [ ] Handle incoming data + conflict resolution (timestamp wins)
- [ ] Request coalescing (batch responses to avoid spam)
- [ ] Message chunking for large character lists

**Design Complete**:
- See [Sync Protocol](sync-protocol.md) for detailed design
- Message types defined: MANIFEST, REQUEST_ALIAS, REQUEST_CHARS, ALIAS_UPDATE, CHARS_UPDATE
- Delta sync strategy using timestamps
- 255-byte message limit handling

**Next Steps**:
1. Create `Services/Sync.lua` for communication layer
2. Implement MANIFEST broadcast on login
3. Implement REQUEST handling
4. Implement response message parsing
5. Add coalescing/debouncing
6. Test with multiple accounts

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
    ├── NeighborhoodAPI.lua    # Neighborhood/Initiative APIs
    └── PlayerInfo.lua         # ✅ Complete - Player info APIs
```

**Missing Components**:
- `Services/Sync.lua` - Communication/sync service *(Phase 3)*
- `Features/Leaderboard.lua` - Leaderboard UI *(Future)*
- `Features/Settings.lua` - Options panel *(Phase 2)*

## Known Issues & Technical Debt

None currently - Phase 1 is clean and well-architected.

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
