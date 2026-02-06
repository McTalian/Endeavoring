# Sync Protocol

## Overview

The Endeavoring addon synchronizes player profiles (BattleTags, aliases, and character lists) across guild members using WoW's addon communication system. The protocol is designed for the **255-byte message limit** of `C_ChatInfo.SendAddonMessage`.

## Status

**Phase 1**: ✅ Complete - Local database and character registration  
**Phase 2**: 📋 Planned - Options UI  
**Phase 3**: 🚧 In Design - Communication layer (this document)

## Design Goals

1. **Minimal bandwidth**: Only send necessary data (delta sync)
2. **Eventual consistency**: No ACKs required, let data propagate naturally
3. **Tamper-proof**: Players cannot modify others' data
4. **Message size**: Stay well under 255-byte limit per message

## Message Types

### MANIFEST (Broadcast)

**Purpose**: Announce presence and current data version

**Format**: `MANIFEST|battleTag|alias|charsUpdatedAt|aliasUpdatedAt`

**Example**: `MANIFEST|BattleTag#1234|McTalian|1738801000|1738800000`

**Sent**:
- On login (after character registration)
- On alias change
- Periodically (every 10 minutes?) for reliability

**Received**:
- Compare timestamps against cached profile
- Determine if alias and/or character data is outdated
- Send REQUEST message(s) if needed

### REQUEST_ALIAS (Direct Message)

**Purpose**: Request updated alias from another player

**Format**: `REQUEST_ALIAS|battleTag`

**Example**: `REQUEST_ALIAS|BattleTag#1234`

**Sent**: When receiver's `aliasUpdatedAt` is older than MANIFEST

**Response**: ALIAS_UPDATE message

### REQUEST_CHARS (Direct Message)

**Purpose**: Request characters added after a specific timestamp

**Format**: `REQUEST_CHARS|battleTag|afterTimestamp`

**Example**: `REQUEST_CHARS|BattleTag#1234|1738800000`

**Sent**: When receiver's `charsUpdatedAt` is older than MANIFEST

**Special case**: `afterTimestamp=0` means "send all characters"

**Response**: CHARS_UPDATE message(s) (may be chunked)

### ALIAS_UPDATE (Direct Message)

**Purpose**: Send updated alias to requester

**Format**: `ALIAS_UPDATE|battleTag|alias|aliasUpdatedAt`

**Example**: `ALIAS_UPDATE|BattleTag#1234|McTalian|1738800000`

**Sent**: In response to REQUEST_ALIAS

**Received**: Call `DB.UpdateProfileAlias()`

### CHARS_UPDATE (Direct Message)

**Purpose**: Send character list (delta or full)

**Format**: `CHARS_UPDATE|battleTag|char1:realm1:addedAt,char2:realm2:addedAt,...`

**Example**: `CHARS_UPDATE|BattleTag#1234|Warrior:RealmName:1738800000,Mage:RealmName:1738801000`

**Sent**: In response to REQUEST_CHARS

**Chunking**: If character list exceeds ~200 bytes, split across multiple messages:
- `CHARS_UPDATE|1/3|battleTag|char1:realm1:addedAt,...`
- `CHARS_UPDATE|2/3|battleTag|char5:realm5:addedAt,...`
- `CHARS_UPDATE|3/3|battleTag|char10:realm10:addedAt`

**Received**: 
- Buffer chunks if multi-part
- Call `DB.AddCharactersToProfile()` when complete

## Communication Flow

### Login Flow

```
Player A logs in
  ↓
Register character locally
  ↓
Broadcast MANIFEST to GUILD
  ↓
Player B receives MANIFEST
  ↓
Compare timestamps:
  - aliasUpdatedAt newer? → Send REQUEST_ALIAS
  - charsUpdatedAt newer? → Send REQUEST_CHARS with cached timestamp
  - Both newer? → Send both requests
  - Neither newer? → Already up to date
  ↓
Player A receives REQUEST(s)
  ↓
Send ALIAS_UPDATE and/or CHARS_UPDATE
  ↓
Player B receives updates
  ↓
Update profile in database
```

### Alias Change Flow

```
Player A changes alias via /endeavoring alias NewName
  ↓
Update myProfile.alias and myProfile.aliasUpdatedAt
  ↓
Broadcast MANIFEST to GUILD
  ↓
Others receive MANIFEST
  ↓
See aliasUpdatedAt is newer
  ↓
Send REQUEST_ALIAS
  ↓
Player A responds with ALIAS_UPDATE
```

### Multi-Player Sync Example

```
3 players online:
- Alice (has Bob v1, Carol v2)
- Bob (has Alice v2, Carol v1)
- Carol (just logged in, has no one)

Carol broadcasts MANIFEST
  ↓
Alice compares: doesn't have Carol → REQUEST_CHARS|Carol|0
Bob compares: doesn't have Carol → REQUEST_CHARS|Carol|0
  ↓
Carol receives 2 requests
  ↓
Carol sends CHARS_UPDATE to Alice
Carol sends CHARS_UPDATE to Bob
  ↓
Alice and Bob now have Carol v2
  ↓
(Alice and Bob don't re-broadcast since they didn't change)
```

## Channel Strategy

### Primary: GUILD

**Pros**:
- Most relevant (neighborhood members likely in same guild)
- Persistent (always available)
- Good reach

**Cons**:
- Not everyone in a neighborhood is in the same guild
- Spam concerns with large guilds

### Fallback: INSTANCE or PARTY

**Instance**: May work for neighborhood area?  
**Party**: Limited reach but relevant for grouped content

### Future Consideration: Custom Channel

Create a neighborhood-specific channel that players auto-join when in the neighborhood.

## Encoding Strategy

**Current Plan**: Simple pipe-delimited strings

**Pros**:
- Human-readable for debugging
- No library dependencies
- Efficient for small messages

**Future**: If we need more complex data, consider:
- LibSerialize + LibDeflate (compression)
- Binary encoding for timestamps

## Anti-Spam Measures

1. **Rate limiting**: Don't broadcast MANIFEST more than once per minute
2. **Request coalescing**: Buffer multiple REQUESTs and respond once
3. **Debouncing**: Wait 2-3 seconds after login before first broadcast
4. **Smart requests**: Only request what's actually missing (delta sync)

## Error Handling

### Malformed Messages

- Ignore and log warning
- Don't crash or pollute UI

### Missing Data

- If REQUEST_CHARS receives no response, retry once after 5 seconds
- After 2 failures, mark profile as "partial" and retry on next MANIFEST

### Duplicate Messages

- Timestamp comparison naturally handles duplicates
- Redundant updates are no-ops

## Security Considerations

### Tampering Prevention

**Problem**: Malicious player could send fake ALIAS_UPDATE or CHARS_UPDATE

**Mitigation**:
1. Each player's `myProfile` is authoritative and never updated via sync
2. Only accept updates for OTHER players' BattleTags
3. Conflict resolution: newest timestamp wins
4. Players can only modify their own data (broadcast from their client)

**Limitation**: A malicious player COULD send fake data about a third player. This is acceptable for a leaderboard feature (low stakes). For high-stakes features, would need cryptographic signatures.

### Data Validation

Before accepting any update:
- Validate BattleTag format
- Validate timestamp is reasonable (not year 1970 or 2099)
- Validate character name is non-empty string
- Reject messages that attempt to modify `myProfile`

## Performance Considerations

### Message Frequency

- MANIFEST on login: ~1 per player per session
- Periodic MANIFEST: ~1 per player per 10 minutes
- REQUEST messages: ~1-2 per new player encountered
- UPDATE messages: ~1-2 per REQUEST

**With 40 players online**: ~200 messages per hour (negligible)

### Memory Usage

- Each profile: ~100 bytes
- 100 profiles: ~10 KB
- Negligible impact on addon memory

### Network Usage

- Each message: ~50-200 bytes
- With compression (future): ~30-100 bytes
- Minimal impact on network

## Testing Strategy

### Phase 3 Testing Plan

1. **Single player**: Verify MANIFEST broadcast on login
2. **Two players, same guild**: Verify REQUEST/RESPONSE flow
3. **Player offline scenario**: Player A logs out, Player B changes alias, Player A logs in → verify sync
4. **Many characters**: Test chunking with 50+ characters
5. **Malformed messages**: Test error handling

### Debug Commands

```lua
/endeavoring sync debug     -- Enable verbose logging
/endeavoring sync status    -- Show cached profiles and timestamps
/endeavoring sync broadcast -- Force MANIFEST broadcast
/endeavoring sync request BattleTag#1234  -- Force request for specific player
```

## Future Enhancements

1. **Rich presence**: Include "last seen" timestamp
2. **Achievement tracking**: Sync endeavor completions per character
3. **Statistics**: Track contribution per character for leaderboard
4. **Cross-guild sync**: Support multiple guilds or custom channels
5. **Compression**: LibDeflate for large character lists

## See Also

- [Database Schema](database-schema.md) - Data structure supporting this protocol
- [Architecture](architecture.md) - Where sync code fits in the addon structure
- [Development Status](development-status.md) - Current implementation status
