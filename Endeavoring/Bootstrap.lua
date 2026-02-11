---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)

ns.Constants = ns.Constants or {
	FRAME_WIDTH = 640,
	FRAME_HEIGHT = 520,
	SCROLLBAR_WIDTH = 20,

	HEADER_HEIGHT = 100,

	TASK_HEADER_HEIGHT = 16,
	TASK_ROW_HEIGHT = 60,
	TASK_TASK_WIDTH = 280,
	TASK_CONTRIBUTION_WIDTH = 100,
	TASK_XP_WIDTH = 100,
	TASK_COUPONS_WIDTH = 100,
	TASKS_SORT_NAME = "name",
	TASKS_SORT_POINTS = "points",
	TASKS_SORT_XP = "xp",
	TASKS_SORT_COUPONS = "coupons",

	LEADERBOARD_FILTER_HEIGHT = 30,
	LEADERBOARD_HEADER_HEIGHT = 22,
	LEADERBOARD_ROW_HEIGHT = 24,
	LEADERBOARD_RANK_WIDTH = 50,
	LEADERBOARD_NAME_WIDTH = 240,
	LEADERBOARD_TOTAL_WIDTH = 160,
	LEADERBOARD_ENTRIES_WIDTH = 120,

	NO_ACTIVE_ENDEAVOR = "No active endeavor",
	NO_TASK_DATA = "No task data, try opening the housing dashboard",
	TIME_REMAINING_FALLBACK = "Time Remaining: --",
	NO_TASKS_AVAILABLE = "No tasks available",
	NO_LEADERBOARD_DATA = "No activity recorded",
	-- Message prefixes
	PREFIX_INFO = "|cff00ff00" .. addonName .. ":|r",
	PREFIX_ERROR = "|cffff0000" .. addonName .. ":|r",
	PREFIX_WARN = "|cffff8800" .. addonName .. ":|r",
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
	print(string.format("|cff%s%s:|r %s", color, addonName, message))
end
