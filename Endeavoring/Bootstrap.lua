---@type string
local addonName = select(1, ...)
---@class HDENamespace
local ns = select(2, ...)

ns.Constants = ns.Constants or {
	FRAME_WIDTH = 620,
	FRAME_HEIGHT = 440,
	TAB_LABELS = {
		"Tasks",
		"Activity",
		"Leaderboard",
	},
	TASK_ROW_HEIGHT = 24,
	TASK_POINTS_WIDTH = 80,
	TASK_XP_WIDTH = 70,
	NO_ACTIVE_ENDEAVOR = "No active endeavor",
	TIME_REMAINING_FALLBACK = "Time Remaining: --",
	NO_TASKS_AVAILABLE = "No tasks available",
	TASKS_SORT_NAME = "name",
	TASKS_SORT_POINTS = "points",
	-- Message prefixes
	PREFIX_INFO = "|cff00ff00Endeavoring:|r",
	PREFIX_ERROR = "|cffff0000Endeavoring:|r",
	PREFIX_WARN = "|cffff8800Endeavoring:|r",
}

ns.state = ns.state or {
	tasksSortKey = ns.Constants.TASKS_SORT_POINTS,
	tasksSortAsc = false,
}

ns.ui = ns.ui or {}
