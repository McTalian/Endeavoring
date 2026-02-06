# Database Schema

## Overview

The Endeavoring addon uses a global SavedVariable `EndeavoringDB` to store player profiles and character associations. The schema is designed to support cross-character aggregation and eventual consistency through addon communication.

## Core Design Principles

1. **Authoritative vs Synced Data**: Player's own data (`myProfile`) is separate from synced data from other players (`profiles`)
2. **Timestamp-Based Sync**: Uses `aliasUpdatedAt` and `charsUpdatedAt` to enable delta synchronization
3. **Character-Centric**: Characters are keyed by name (matching WoW API outputs) with realm stored for future compatibility

## Complete Schema

```lua
EndeavoringDB = {
  global = {
    -- Player's authoritative data (never overwritten by sync)
    myProfile = {
      battleTag = "BattleTag#1234",      -- Player's BattleTag (from BNGetInfo)
      alias = "MyNickname",               -- Display name (defaults to BattleTag)
      aliasUpdatedAt = 1738800000,       -- Timestamp of last alias change
      characters = {
        ["CharacterName"] = {
          name = "CharacterName",         -- Character name
          realm = "RealmName",            -- Realm name (for future compatibility)
          addedAt = 1738800000            -- When this char was registered
        },
        ["AnotherChar"] = {
          name = "AnotherChar",
          realm = "RealmName",
          addedAt = 1738801000
        }
      },
      charsUpdatedAt = 1738801000        -- max(character.addedAt) - tracks character additions
    },
    
    -- Synced data from OTHER players only
    profiles = {
      ["BattleTag#5678"] = {
        battleTag = "BattleTag#5678",
        alias = "TheirNickname",
        aliasUpdatedAt = 1738795000,
        characters = {
          ["TheirChar"] = {
            name = "TheirChar",
            realm = "RealmName",
            addedAt = 1738795000
          }
        },
        charsUpdatedAt = 1738795000
      }
    },
    
    version = 1                          -- Schema version for migrations
  }
}
```

## Timestamp Strategy

The schema uses **separate timestamps** for different types of updates to enable efficient delta synchronization:

### `aliasUpdatedAt`
- **Purpose**: Tracks when the player's display name was last changed
- **Updated**: Only when `SetPlayerAlias()` is called
- **Sync Use**: Receivers can detect alias changes without checking character data

### `charsUpdatedAt`
- **Purpose**: Tracks when characters were last added (max of all `character.addedAt`)
- **Updated**: Only when a new character is registered
- **Sync Use**: Receivers can request only characters added after their cached timestamp

### `character.addedAt`
- **Purpose**: Tracks when a specific character was registered
- **Updated**: Once when character is first registered
- **Sync Use**: Enables filtering characters by timestamp for delta sync

## Why Separate Timestamps?

This design allows receivers to determine what data they need:

```lua
-- Receiving manifest: { battleTag, alias, charsUpdatedAt, aliasUpdatedAt }

if aliasUpdatedAt > cached.aliasUpdatedAt then
  -- Request only the alias
end

if charsUpdatedAt > cached.charsUpdatedAt then
  -- Request only characters added after cached.charsUpdatedAt
end
```

This minimizes data transfer over the 255-byte addon message limit.

## Data Access Patterns

### Local Operations (myProfile)
- `RegisterCurrentCharacter()` - Add current character, update `charsUpdatedAt`
- `SetPlayerAlias(alias)` - Update alias, update `aliasUpdatedAt`
- `GetManifest()` - Get broadcast data: `{ battleTag, alias, charsUpdatedAt, aliasUpdatedAt }`
- `GetCharactersAddedAfter(timestamp)` - Get characters for delta sync

### Sync Operations (profiles)
- `UpdateProfileAlias(battleTag, alias, aliasUpdatedAt)` - Update another player's alias
- `AddCharactersToProfile(battleTag, characters)` - Add/update characters for another player
- `IsDataNewer(battleTag, timestamp)` - Check if incoming data is newer than cached

### Query Operations
- `GetAlias(battleTag)` - Get alias for any player (checks myProfile first, then profiles)
- `GetCharacters(battleTag)` - Get characters for any player
- `GetAllProfiles()` - Get all synced profiles (excludes myProfile)

## Security Model

**Authoritative Data Protection:**
- `myProfile` can ONLY be modified through local operations (`RegisterCurrentCharacter`, `SetPlayerAlias`)
- All sync methods (`UpdateProfile`, `AddCharactersToProfile`, `UpdateProfileAlias`) explicitly check and reject attempts to modify `myProfile`
- This prevents tampering via incoming sync messages

**Conflict Resolution:**
- Newest timestamp always wins
- No merging - complete replacement of stale data
- Per-character timestamps enable granular updates

## Migration Strategy

The `version` field supports future schema changes:

```lua
function DB.Init()
  -- Current version = 1
  if not EndeavoringDB.global.version then
    EndeavoringDB.global.version = 1
  end
  
  -- Future migrations would go here:
  -- if EndeavoringDB.global.version < 2 then
  --   MigrateToV2()
  -- end
end
```

## See Also

- [Sync Protocol](sync-protocol.md) - How profiles are synchronized between players
- [Architecture](architecture.md) - Overall addon structure and conventions
