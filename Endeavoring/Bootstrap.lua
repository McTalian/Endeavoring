---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)

ns.Constants = ns.Constants or {
	FRAME_WIDTH = 620,
	FRAME_HEIGHT = 480,
	TASK_ROW_HEIGHT = 24,
	TASK_POINTS_WIDTH = 80,
	TASK_XP_WIDTH = 70,
	LEADERBOARD_ROW_HEIGHT = 24,
	LEADERBOARD_TOTAL_WIDTH = 80,
	LEADERBOARD_ENTRIES_WIDTH = 70,
	SCROLLBAR_WIDTH = 20,
	NO_ACTIVE_ENDEAVOR = "No active endeavor",
	NO_TASK_DATA = "No task data, try opening the housing dashboard",
	TIME_REMAINING_FALLBACK = "Time Remaining: --",
	NO_TASKS_AVAILABLE = "No tasks available",
	NO_LEADERBOARD_DATA = "No activity recorded",
	TASKS_SORT_NAME = "name",
	TASKS_SORT_POINTS = "points",
	-- Message prefixes
	PREFIX_INFO = "|cff00ff00Endeavoring:|r",
	PREFIX_ERROR = "|cffff0000Endeavoring:|r",
	PREFIX_WARN = "|cffff8800Endeavoring:|r",
}

--- Message types for sync protocol (CBOR + compression)
--- Values are intentionally short to minimize wire overhead
---@enum MessageType
ns.MSG_TYPE = {
	MANIFEST = "M",
	REQUEST_CHARS = "R",
	ALIAS_UPDATE = "A",
	CHARS_UPDATE = "C",
}

ns.state = ns.state or {
	tasksSortKey = ns.Constants.TASKS_SORT_POINTS,
	tasksSortAsc = false,
}

ns.ui = ns.ui or {}

--- Print debug message if verbose debug mode is enabled
--- @param message string The message to print
--- @param color string|nil Optional color code (default: green)
function ns.DebugPrint(message, color)
	if not ns.DB.IsVerboseDebug() then
		return
	end
	
	color = color or "00ff00" -- Green by default
	print(string.format("|cff%sEndeavoring:|r %s", color, message))
end
