---@type string
local addonName = select(1, ...)
---@class HDENamespace
local ns = select(2, ...)

local Sync = {}
ns.Sync = Sync

-- Shortcuts
local ERROR = ns.Constants.PREFIX_ERROR
local DebugPrint = ns.DebugPrint

-- Constants
local ADDON_PREFIX = "Ndvrng"
local CHANNEL_GUILD = "GUILD"
local MESSAGE_SIZE_LIMIT = 255  -- WoW API hard limit for addon messages

-- Message types (CBOR + compression protocol)
-- Values are intentionally short to minimize wire overhead
local MSG_TYPE = {
	MANIFEST = "M",
	REQUEST_CHARS = "R",
	ALIAS_UPDATE = "A",
	CHARS_UPDATE = "C",
}

-- State
local initialized = false

--- Initialize the sync service
function Sync.Init()
	if initialized then
		return
	end
	
	-- Register addon message prefix
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		local success = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
		if not success then
			print(ERROR .. " Failed to register addon message prefix")
			return
		end
	end
	
	-- Initialize coordinator for timing and orchestration
	ns.Coordinator.Init()
	
	initialized = true
end

--- Build a message with CBOR-encoded payload
--- Message type is included in the CBOR payload to avoid string+binary mixing
--- @param messageType string The message type (e.g., MSG_TYPE.MANIFEST)
--- @param data table The data to encode
--- @return string|nil message The complete encoded message, or nil on encoding failure
--- Build a message for transmission (exposed for Coordinator)
--- @param messageType string The message type
--- @param data table The message data
--- @return string|nil encoded The encoded message or nil on failure
function Sync.BuildMessage(messageType, data)
	-- Include message type in the payload
	data.type = messageType
	
	local encoded, err = ns.MessageCodec.Encode(data)
	if not encoded then
		DebugPrint(string.format("Failed to encode message: %s", err or "unknown error"), "ff0000")
		return nil
	end

	-- Warn if message is approaching or exceeding size limit
	if #encoded > MESSAGE_SIZE_LIMIT then
		DebugPrint(string.format("WARNING: Built message size (%d bytes) exceeds limit (%d bytes)!", #encoded, MESSAGE_SIZE_LIMIT), "ff0000")
	elseif #encoded > (MESSAGE_SIZE_LIMIT * 0.9) then
		-- Warn if within 10% of limit
		DebugPrint(string.format("WARNING: Built message size (%d bytes) is close to limit (%d bytes)", #encoded, MESSAGE_SIZE_LIMIT), "ff8800")
	end
	
	return encoded
end



--- Send a message via addon communication (exposed for Coordinator)
--- @param message string The message to send
--- @param channel string The channel to send on (default: GUILD)
--- @param target string|nil The target player for whisper messages
--- @return boolean success Whether the message was sent successfully
function Sync.SendMessage(message, channel, target)
	if not initialized then
		return false
	end
	
	channel = channel or CHANNEL_GUILD
	
	-- Pre-flight validation: check for chat messaging lockdown (instances, restricted zones)
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		local isRestricted, reason = C_ChatInfo.InChatMessagingLockdown()
		if isRestricted then
			DebugPrint(string.format("Skipping message send - chat messaging lockdown active (reason: %s)", tostring(reason or "unknown")), "ff8800")
			return false
		end
	end
	
	-- Pre-flight validation: check message size
	if #message > MESSAGE_SIZE_LIMIT then
		print(ERROR .. string.format(" Message size (%d bytes) exceeds API limit (%d bytes)! Message NOT sent.", #message, MESSAGE_SIZE_LIMIT))
		print(ERROR .. " This likely means you have too many characters. Please report this issue!")
		return false
	end
	
	if C_ChatInfo and C_ChatInfo.SendAddonMessage then
		DebugPrint(string.format("Sending %d byte message on channel %s", #message, channel))
		
		-- Send and check return code
		local result = C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, channel, target)
		
		-- Check for errors (Enum.SendAddonMessageResult)
		if result ~= Enum.SendAddonMessageResult.Success then
			local errorNames = {
				[Enum.SendAddonMessageResult.InvalidPrefix] = "InvalidPrefix",
				[Enum.SendAddonMessageResult.InvalidMessage] = "InvalidMessage",
				[Enum.SendAddonMessageResult.AddonMessageThrottle] = "AddonMessageThrottle",
				[Enum.SendAddonMessageResult.InvalidChatType] = "InvalidChatType",
				[Enum.SendAddonMessageResult.NotInGroup] = "NotInGroup",
				[Enum.SendAddonMessageResult.TargetRequired] = "TargetRequired",
				[Enum.SendAddonMessageResult.InvalidChannel] = "InvalidChannel",
				[Enum.SendAddonMessageResult.ChannelThrottle] = "ChannelThrottle",
				[Enum.SendAddonMessageResult.GeneralError] = "GeneralError",
				[Enum.SendAddonMessageResult.NotInGuild] = "NotInGuild",
				[Enum.SendAddonMessageResult.AddOnMessageLockdown] = "AddOnMessageLockdown",
				[Enum.SendAddonMessageResult.TargetOffline] = "TargetOffline",
			}
			local errorName = errorNames[result] or "Unknown"
			
			print(ERROR .. string.format(" Failed to send message: %s (code %d)", errorName, result or -1))
			print(ERROR .. string.format(" Channel: %s, Size: %d bytes", channel, #message))
			if target then
				print(ERROR .. string.format(" Target: %s", target))
			end
			return false
		end
		
		return true
	end
	
	return false
end

--- Register event listener for addon messages
function Sync.RegisterListener()
	if not initialized then
		Sync.Init()
	end
	
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("CHAT_MSG_ADDON")
	frame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
		if event == "CHAT_MSG_ADDON" then
			ns.Protocol.OnAddonMessage(prefix, message, channel, sender)
		end
	end)
end
