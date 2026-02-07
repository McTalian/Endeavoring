---@type string
local addonName = select(1, ...)
---@class HDENamespace
local ns = select(2, ...)

local Leaderboard = {}
ns.Leaderboard = Leaderboard

-- Time range constants (in seconds)
local TIME_RANGE = {
	ALL_TIME = 0,
	TODAY = 86400,        -- 24 hours
	THIS_WEEK = 604800,   -- 7 days
}

-- Current filter state
local state = {
	timeRange = TIME_RANGE.ALL_TIME,
}

--- Build leaderboard from activity log
--- @param activityLog table The activity log from GetInitiativeActivityLogInfo()
--- @param timeRange number|nil Filter entries within this many seconds (nil = all time)
--- @return table leaderboard Sorted array of {player, total, entries}
function Leaderboard.BuildFromActivityLog(activityLog, timeRange)
	if not activityLog or not activityLog.taskActivity then
		return {}
	end

	local now = time()
	local cutoffTime
	if timeRange and timeRange > 0 then
		cutoffTime = now - timeRange
	else
		cutoffTime = 0
	end
	local playerSum = {}

	-- Aggregate by player name
	for _, entry in ipairs(activityLog.taskActivity) do
		-- Filter by time range if specified
		if not timeRange or entry.completionTime >= cutoffTime then
			if not playerSum[entry.playerName] then
				playerSum[entry.playerName] = {
					player = entry.playerName,
					total = 0,
					entries = 0,
				}
			end
			
			playerSum[entry.playerName].total = playerSum[entry.playerName].total + entry.amount
			playerSum[entry.playerName].entries = playerSum[entry.playerName].entries + 1
		end
	end

	-- Convert to array for sorting
	local leaderboard = {}
	for _, data in pairs(playerSum) do
		table.insert(leaderboard, data)
	end

	-- Sort by total contribution (descending)
	table.sort(leaderboard, function(a, b)
		if a.total == b.total then
			-- Tie-breaker: alphabetical by player name
			return a.player < b.player
		end
		return a.total > b.total
	end)

	return leaderboard
end

--- Get enriched leaderboard with BattleTag/Alias mapping
--- @param activityLog table The activity log from GetInitiativeActivityLogInfo()
--- @param timeRange number|nil Filter entries within this many seconds (nil = all time)
--- @return table leaderboard Sorted array with alias field added
function Leaderboard.BuildEnriched(activityLog, timeRange)
	local leaderboard = Leaderboard.BuildFromActivityLog(activityLog, timeRange)
	
	-- TODO: Map player names to BattleTag/Alias using ns.DB profiles
	-- For now, just use player name as-is
	for _, entry in ipairs(leaderboard) do
		entry.displayName = entry.player
		entry.isLocalPlayer = (entry.player == UnitName("player"))
	end

	return leaderboard
end

--- Set the current time range filter
--- @param range number One of TIME_RANGE constants
function Leaderboard.SetTimeRange(range)
	state.timeRange = range
end

--- Get the current time range filter
--- @return number timeRange Current time range filter
function Leaderboard.GetTimeRange()
	return state.timeRange
end

--- Get time range name for display
--- @param range number One of TIME_RANGE constants
--- @return string name Display name for the time range
function Leaderboard.GetTimeRangeName(range)
	if range == TIME_RANGE.TODAY then
		return "Today"
	elseif range == TIME_RANGE.THIS_WEEK then
		return "This Week"
	else
		return "All Time"
	end
end

-- Export constants
Leaderboard.TIME_RANGE = TIME_RANGE
