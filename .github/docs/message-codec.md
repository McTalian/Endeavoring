# Message Codec

## Overview

The MessageCodec service provides CBOR serialization and automatic compression for addon communication messages. This reduces bandwidth usage, handles larger datasets, and provides a path for protocol evolution.

## Implementation

**Location**: `Services/MessageCodec.lua`

**Load Order**: Early (after PlayerInfo, before Database)

## Features

### 1. CBOR Serialization

Messages use **Concise Binary Object Representation** instead of manual string concatenation:

**Before (Pipe-Delimited)**:
```lua
-- Manual string building
local message = string.format("C|%s|%s:%s:%d,%s:%s:%d",
    battleTag, char1, realm1, time1, char2, realm2, time2)
```

**After (CBOR)**:
```lua
-- Structured data
local data = {
    battleTag = battleTag,
    characters = {
        {name = char1, realm = realm1, addedAt = time1},
        {name = char2, realm = realm2, addedAt = time2},
    }
}
local encoded = ns.MessageCodec.Encode(data)
```

**Benefits**:
- Type preservation (numbers stay numbers)
- Structured data (easier to extend)
- Slightly smaller than string concatenation
- No manual parsing/escaping needed

### 2. Automatic Compression

Messages exceeding 100 bytes are automatically compressed using Deflate:

```lua
-- Compression happens automatically
local encoded = ns.MessageCodec.Encode(largeData)
-- Compressed if beneficial, uncompressed if not
```

**Expected savings**: 40-60% reduction for typical character lists + ~10 bytes from shorter message type

**Examples** (vs pipe-delimited equivalents):
- 10 characters: ~350 bytes → ~140-210 bytes ✅
- 20 characters: ~700 bytes → ~280-420 bytes ✅ (still within 255 limit)
- 50 characters: ~1750 bytes → ~700-1050 bytes ⚠️ (needs chunking - Phase 4)

### 3. Protocol Versioning

Messages include a version byte for protocol evolution:

```
[version:1][flags:1][payload:N]
```

- **Version byte**: Currently `0x01`, increment for breaking changes
- **Flags byte**: Bit 0 = compressed, bits 1-7 reserved for future use
- **Payload**: CBOR data (compressed or uncompressed)

## API

### Encode

```lua
local encoded, err = ns.MessageCodec.Encode(data)
if not encoded then
    print("Encoding failed: " .. err)
    return
end
```

**Parameters**:
- `data` (any): Lua value to encode (table, string, number, etc.)

**Returns**:
- `encoded` (string|nil): Wire-format message, or nil on failure
- `err` (string|nil): Error message if encoding failed

### Decode

```lua
local data, err = ns.MessageCodec.Decode(encoded)
if not data then
    print("Decoding failed: " .. err)
    return
end
```

**Parameters**:
- `encoded` (string): Wire-format message

**Returns**:
- `data` (any|nil): Decoded Lua value, or nil on failure
- `err` (string|nil): Error message if decoding failed

### GetStats

```lua
local stats = ns.MessageCodec.GetStats()
-- {
--   protocolVersion = 1,
--   compressionThreshold = 100,
--   features = {
--     cbor = true,
--     compression = true,
--   }
-- }
```

### EstimateSize

```lua
local size = ns.MessageCodec.EstimateSize(data)
if size and size > 255 then
    print("Warning: Message may exceed SendAddonMessage limit")
end
```

## Message Types

All messages use single-character type identifiers to minimize wire overhead:

- `M` (MANIFEST): Player profile metadata
- `R` (REQUEST_CHARS): Request character list
- `A` (ALIAS_UPDATE): Update player alias (gossip)
- `C` (CHARS_UPDATE): Character list update

**Wire format**: `M|<CBOR payload>` (3 bytes overhead minimum)

**Note**: All V1 legacy code has been removed. The addon uses CBOR exclusively.

## Wire Format Details

### Uncompressed Message

```
[0x01][0x00][CBOR data...]
 ^^^^  ^^^^
 ver   flags (no compression)
```

### Compressed Message

```
[0x01][0x01][Deflate(CBOR data)...]
 ^^^^  ^^^^
 ver   flags (bit 0 set = compressed)
```

## Size Limits

- **SendAddonMessage limit**: 255 bytes per message
- **Compression threshold**: 100 bytes (configurable)
- **Typical overhead**: 2 bytes (version + flags)
- **Safety margin**: Aim for <250 bytes to be safe

## Error Handling

### Graceful Degradation

```lua
-- Guard: Check if C_EncodingUtil is available
if not C_EncodingUtil or not C_EncodingUtil.SerializeCBOR then
    return nil, "C_EncodingUtil.SerializeCBOR not available"
end
```

### Common Errors

**"Message too short"**: Corrupted/truncated message  
**"Unsupported protocol version"**: Sender using newer protocol  
**"Decompression failed"**: Corrupted compressed data  
**"CBOR deserialization failed"**: Invalid CBOR structure

## Performance

### Benchmarks (Estimated)

**Small message** (3 characters):
- V1 (string): ~90 bytes, no compression
- V2 (CBOR): ~75 bytes, no compression
- **Savings**: ~17%

**Medium message** (10 characters):
- V1 (string): ~350 bytes (exceeds limit!)
- V2 (CBOR + compress): ~140-210 bytes
- **Savings**: ~40-60%

**Large message** (20 characters):
- V1 (string): ~700 bytes (exceeds limit!)
- V2 (CBOR + compress): ~280-420 bytes
- **Savings**: ~40-60%

### Overhead

- **Serialization**: < 1ms for typical messages
- **Compression**: 1-3ms for 100-500 byte payloads
- **Total**: Negligible compared to network latency

## Future Enhancements

### Phase 4: Message Chunking

For messages still exceeding 255 bytes after compression (e.g., 50+ alts):

```lua
CHARS_UPDATE_CHUNK|1/3|<data>
CHARS_UPDATE_CHUNK|2/3|<data>
CHARS_UPDATE_CHUNK|3/3|<data>
```

**Implementation**: Deferred until real-world usage shows it's needed.

### Protocol Evolution

**Version 2** (future):
- Add encryption support (flag bit 1)
- Add delta encoding (flag bit 2)
- Add message signatures (flag bit 3)

**Version change handling**:
```lua
if version ~= PROTOCOL_VERSION then
    return nil, string.format("Unsupported protocol version %d", version)
end
```

## Testing

### In-Game Testing Checklist

- [ ] Profile with 1 character syncs correctly
- [ ] Profile with 10 characters syncs correctly
- [ ] Profile with 20 characters syncs correctly
- [ ] Profile with 50+ characters (test chunking need)
- [ ] Verbose debug shows compression status
- [ ] Messages are smaller than estimated pipe-delimited equivalents
- [ ] Compression triggers at expected threshold

### Debug Commands

**View codec stats**:
```lua
/run print(tostringall(ns.MessageCodec.GetStats()))
```

**Test encoding**:
```lua
/run local d = {test="hello", num=123}; local e = ns.MessageCodec.Encode(d); print("Size:", #e)
```

**Enable verbose to see compression**:
```
/endeavoring sync verbose
```

## Migration Notes

**Breaking Change**: This addon uses CBOR exclusively with no backward compatibility.

**Why**: With 0 users during alpha development, a clean break to CBOR-only keeps the codebase simple and maintainable. All V1 pipe-delimited code has been removed.

**Deployment**: All addon users must update simultaneously. Messages from clients using different protocol versions will be silently dropped (message type won't match).

## References

- **CBOR Spec**: RFC 7049
- **Deflate Compression**: RFC 1951
- **WoW API**: `C_EncodingUtil` (Blizzard_APIDocumentationGenerated/EncodingUtilDocumentation.lua)
- **Message Size Limits**: warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage
