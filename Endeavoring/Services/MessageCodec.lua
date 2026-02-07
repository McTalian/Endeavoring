---@type string
local addonName = select(1, ...)
---@class HDENamespace
local ns = select(2, ...)

local MessageCodec = {}
ns.MessageCodec = MessageCodec

-- Protocol version (increment when making breaking changes)
local PROTOCOL_VERSION = 1

-- Compression threshold: only compress if serialized data exceeds this size
local COMPRESSION_THRESHOLD = 100

-- Message format flags
local FLAG_COMPRESSED = 0x01
local FLAG_RESERVED1 = 0x02
local FLAG_RESERVED2 = 0x04
local FLAG_RESERVED3 = 0x08

--- Encode a Lua table/value into a wire-format string
--- Automatically compresses large payloads
--- @param data any The data to encode (table, string, number, etc.)
--- @return string|nil encoded The encoded message, or nil on failure
--- @return string|nil error Error message if encoding failed
function MessageCodec.Encode(data)
	-- Guard: Check if CBOR API is available
	if not C_EncodingUtil or not C_EncodingUtil.SerializeCBOR then
		return nil, "C_EncodingUtil.SerializeCBOR not available"
	end
	
	-- Serialize to CBOR
	local serialized = C_EncodingUtil.SerializeCBOR(data)
	if not serialized or serialized == "" then
		return nil, "CBOR serialization failed"
	end
	
	-- Determine if compression is beneficial
	local flags = 0
	local payload = serialized
	
	if #serialized > COMPRESSION_THRESHOLD then
		-- Guard: Check if compression API is available
		if C_EncodingUtil.CompressString then
			local compressed = C_EncodingUtil.CompressString(
				serialized,
				Enum.CompressionMethod.Deflate,
				Enum.CompressionLevel.Default
			)
			
			if compressed and #compressed < #serialized then
				-- Compression was beneficial
				payload = compressed
				flags = bit.bor(flags, FLAG_COMPRESSED)
			end
			-- If compression failed or made it larger, use uncompressed
		end
	end
	
	-- Build final message: [version:1][flags:1][payload:N]
	local encoded = string.char(PROTOCOL_VERSION) .. string.char(flags) .. payload
	
	return encoded, nil
end

--- Decode a wire-format string back into a Lua value
--- Automatically decompresses if needed
--- @param encoded string The encoded message
--- @return any|nil data The decoded data, or nil on failure
--- @return string|nil error Error message if decoding failed
function MessageCodec.Decode(encoded)
	-- Guard: Check if CBOR API is available
	if not C_EncodingUtil or not C_EncodingUtil.DeserializeCBOR then
		return nil, "C_EncodingUtil.DeserializeCBOR not available"
	end
	
	-- Validate minimum message size (version + flags)
	if not encoded or #encoded < 2 then
		return nil, "Message too short (minimum 2 bytes)"
	end
	
	-- Extract version and flags
	local version = string.byte(encoded, 1)
	local flags = string.byte(encoded, 2)
	local payload = string.sub(encoded, 3)
	
	-- Check protocol version
	if version ~= PROTOCOL_VERSION then
		return nil, string.format("Unsupported protocol version %d (expected %d)", version, PROTOCOL_VERSION)
	end
	
	-- Decompress if needed
	local serialized = payload
	if bit.band(flags, FLAG_COMPRESSED) ~= 0 then
		-- Guard: Check if decompression API is available
		if not C_EncodingUtil.DecompressString then
			return nil, "C_EncodingUtil.DecompressString not available"
		end
		
		local decompressed = C_EncodingUtil.DecompressString(
			payload,
			Enum.CompressionMethod.Deflate
		)
		
		if not decompressed then
			return nil, "Decompression failed"
		end
		
		serialized = decompressed
	end
	
	-- Deserialize from CBOR
	local data = C_EncodingUtil.DeserializeCBOR(serialized)
	if data == nil then
		return nil, "CBOR deserialization failed"
	end
	
	return data, nil
end

--- Get codec statistics for debugging
--- @return table stats Statistics about encoding/decoding
function MessageCodec.GetStats()
	return {
		protocolVersion = PROTOCOL_VERSION,
		compressionThreshold = COMPRESSION_THRESHOLD,
		features = {
			cbor = (C_EncodingUtil and C_EncodingUtil.SerializeCBOR) ~= nil,
			compression = (C_EncodingUtil and C_EncodingUtil.CompressString) ~= nil,
		}
	}
end

--- Estimate encoded size without actually encoding
--- Useful for detecting potential message size issues
--- @param data any The data to estimate
--- @return number|nil estimatedSize Size estimate in bytes, or nil if unavailable
function MessageCodec.EstimateSize(data)
	-- We can't get exact size without encoding, but we can provide a rough estimate
	-- For testing/debug purposes, just encode and return actual size
	local encoded, err = MessageCodec.Encode(data)
	if not encoded then
		return nil
	end
	return #encoded
end
