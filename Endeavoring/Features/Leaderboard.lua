---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)

local Leaderboard = {}
ns.Leaderboard = Leaderboard

local DebugPrint = ns.DebugPrint

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
			if a.entries == b.entries then
				-- Tie-breaker: alphabetical by player name
				return a.player < b.player
			end
			-- Tie-breaker: more entries ranks higher
			return a.entries > b.entries
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

	local myBattleTag = ns.PlayerInfo.GetBattleTag()

	local battleTagLeaderboard = {}
	local enrichedLeaderboard = {}
	for _, entry in ipairs(leaderboard) do
		local battleTag = ns.CharacterCache.FindBattleTag(entry.player)
		if battleTag then
			local profile = ns.DB.GetProfile(battleTag)
			local displayName = profile and profile.alias or battleTag
			battleTagLeaderboard[battleTag] = battleTagLeaderboard[battleTag] or {
				displayName = displayName,
				total = 0,
				entries = 0,
				charNames = {},
				isLocalPlayer = (battleTag == myBattleTag),
			}
			battleTagLeaderboard[battleTag].total = battleTagLeaderboard[battleTag].total + entry.total
			battleTagLeaderboard[battleTag].entries = battleTagLeaderboard[battleTag].entries + entry.entries
			table.insert(battleTagLeaderboard[battleTag].charNames, entry.player)
		else
			table.insert(enrichedLeaderboard, {
				displayName = entry.player,
				total = entry.total,
				entries = entry.entries,
				charNames = {},
				isLocalPlayer = (entry.player == UnitName("player")),
			})
		end
	end

	-- Add BattleTag entries to enriched leaderboard
	for _, data in pairs(battleTagLeaderboard) do
		table.insert(enrichedLeaderboard, data)
	end

	-- Sort enriched leaderboard by total contribution (descending)
	table.sort(enrichedLeaderboard, function(a, b)
		if a.total == b.total then
			if a.entries == b.entries then
				-- Tie-breaker: alphabetical by display name
				return a.displayName < b.displayName
			end
			-- Tie-breaker: more entries ranks higher
			return a.entries > b.entries
		end
		return a.total > b.total
	end)

	return enrichedLeaderboard
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

--- Create a single leaderboard row
--- @param parent Frame The parent frame (scrollChild)
--- @param index number The row index
--- @return Frame row The created row
local function CreateLeaderboardRow(parent, index)
	-- TODO: Add indicator icon for players using Endeavoring addon (show synced profiles)
	-- TODO: Make rows sortable by clicking headers (Rank, Player, Total, Entries)
	
	local constants = ns.Constants
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(constants.LEADERBOARD_ROW_HEIGHT)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * constants.LEADERBOARD_ROW_HEIGHT))
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -((index - 1) * constants.LEADERBOARD_ROW_HEIGHT))
	
	-- Enable mouse events for tooltips
	row:EnableMouse(true)

	-- Rank number
	row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.rank:SetPoint("LEFT", 6, 0)
	row.rank:SetWidth(30)
	row.rank:SetJustifyH("LEFT")

	-- Display name
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.name:SetPoint("LEFT", row.rank, "RIGHT", 8, 0)
	row.name:SetJustifyH("LEFT")

	-- Total contribution
	row.total = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.total:SetWidth(constants.LEADERBOARD_TOTAL_WIDTH)
	row.total:SetJustifyH("RIGHT")
	row.total:SetPoint("RIGHT", row, "RIGHT", -constants.LEADERBOARD_ENTRIES_WIDTH - 12, 0)

	-- Number of entries
	row.entries = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.entries:SetWidth(constants.LEADERBOARD_ENTRIES_WIDTH)
	row.entries:SetJustifyH("RIGHT")
	row.entries:SetPoint("RIGHT", row, "RIGHT", -6, 0)

	-- Connect name width
	row.name:SetPoint("RIGHT", row.total, "LEFT", -8, 0)
	
	-- Tooltip handlers
	row:SetScript("OnEnter", function(self)
		if not self.data or not self.data.charNames or #self.data.charNames == 0 then
			return
		end
		
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:SetText(self.data.displayName, 1, 1, 1, 1, true)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Contributing Characters:", 0.5, 0.5, 0.5)
		
		for _, charName in ipairs(self.data.charNames) do
			GameTooltip:AddLine(charName, 1, 0.82, 0)
		end
		
		GameTooltip:Show()
	end)
	
	row:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

	return row
end

--- Update the time range filter button highlights
local function UpdateFilterButtons()
	if not ns.ui.leaderboardUI then
		return
	end

	local leaderboardUI = ns.ui.leaderboardUI
	local currentRange = state.timeRange

	for range, button in pairs(leaderboardUI.filterButtons) do
		if range == currentRange then
			button:Disable()
			button:SetAlpha(1.0)
		else
			button:Enable()
			button:SetAlpha(0.7)
		end
	end
end

--- Set the time range filter and refresh
--- @param range number One of TIME_RANGE constants
local function SetTimeRangeFilter(range)
	Leaderboard.SetTimeRange(range)
	ns.API.RequestActivityLog() -- Trigger refresh with new time range
	UpdateFilterButtons()
end

--- Internal function to update leaderboard display with current data
local function UpdateLeaderboardDisplay()
	if not ns.ui.leaderboardUI then
		return
	end

	local leaderboardUI = ns.ui.leaderboardUI
	local constants = ns.Constants
	local activityLog = ns.API.GetActivityLogInfo()

	-- Check if activity log is loaded (follows Blizzard's pattern)
	if not activityLog or not activityLog.isLoaded then
		leaderboardUI.emptyText:SetText("Loading activity data...")
		leaderboardUI.emptyText:Show()
		for _, row in ipairs(leaderboardUI.rows) do
			row:Hide()
		end
		return
	end

	if not activityLog.taskActivity or #activityLog.taskActivity == 0 then
		leaderboardUI.emptyText:SetText(constants.NO_LEADERBOARD_DATA)
		leaderboardUI.emptyText:Show()
		for _, row in ipairs(leaderboardUI.rows) do
			row:Hide()
		end
		return
	end

	local leaderboard = Leaderboard.BuildEnriched(activityLog, state.timeRange)
	if #leaderboard == 0 then
		leaderboardUI.emptyText:SetText(constants.NO_LEADERBOARD_DATA)
		leaderboardUI.emptyText:Show()
		for _, row in ipairs(leaderboardUI.rows) do
			row:Hide()
		end
		return
	end

	leaderboardUI.emptyText:Hide()
	local totalHeight = #leaderboard * constants.LEADERBOARD_ROW_HEIGHT
	leaderboardUI.scrollChild:SetHeight(totalHeight)
	local scrollWidth = leaderboardUI.scrollFrame and leaderboardUI.scrollFrame:GetWidth() or 1
	if scrollWidth and scrollWidth > 0 then
		leaderboardUI.scrollChild:SetWidth(scrollWidth)
	end

	for index, entry in ipairs(leaderboard) do
		local row = leaderboardUI.rows[index]
		if not row then
			row = CreateLeaderboardRow(leaderboardUI.scrollChild, index)
			leaderboardUI.rows[index] = row
		end

		row.data = entry
		row.rank:SetText(tostring(index))
		row.name:SetText(entry.displayName or "Unknown")
		row.total:SetText(string.format("%.3f", entry.total or 0))
		row.entries:SetText(tostring(entry.entries or 0))

		-- Highlight local player
		if entry.isLocalPlayer then
			row.rank:SetTextColor(0.1, 1.0, 0.1)
			row.name:SetTextColor(0.1, 1.0, 0.1)
			row.total:SetTextColor(0.1, 1.0, 0.1)
			row.entries:SetTextColor(0.1, 1.0, 0.1)
		else
			row.rank:SetTextColor(1, 0.82, 0)
			row.name:SetTextColor(1, 1, 1)
			row.total:SetTextColor(1, 1, 1)
			row.entries:SetTextColor(1, 1, 1)
		end

		row:Show()
	end

	-- Hide unused rows
	for index = #leaderboard + 1, #leaderboardUI.rows do
		leaderboardUI.rows[index]:Hide()
	end
end

--- Create the leaderboard tab UI
--- @param parent Frame The parent frame
--- @return Frame content The leaderboard tab content
function Leaderboard.CreateTab(parent)
	local constants = ns.Constants
	local content = CreateFrame("Frame", nil, parent)
	content:SetPoint("TOPLEFT", parent.TabSystem, "BOTTOMLEFT", 4, -8)
	content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 12)

	-- Time range filter buttons
	local filterContainer = CreateFrame("Frame", nil, content)
	filterContainer:SetPoint("TOPLEFT", 4, -4)
	filterContainer:SetPoint("TOPRIGHT", -4, -4)
	filterContainer:SetHeight(30)

	local filterButtons = {}
	local filterOrder = {TIME_RANGE.ALL_TIME, TIME_RANGE.THIS_WEEK, TIME_RANGE.TODAY}
	for i, range in ipairs(filterOrder) do
		local button = CreateFrame("Button", nil, filterContainer, "UIPanelButtonTemplate")
		button:SetSize(90, 22)
		button:SetText(Leaderboard.GetTimeRangeName(range))
		button:SetScript("OnClick", function()
			SetTimeRangeFilter(range)
		end)

		if i == 1 then
			button:SetPoint("LEFT", 4, 0)
		else
			button:SetPoint("LEFT", filterButtons[filterOrder[i-1]], "RIGHT", 4, 0)
		end

		filterButtons[range] = button
	end

	-- Header row
	local header = CreateFrame("Frame", nil, content)
	header:SetPoint("TOPLEFT", filterContainer, "BOTTOMLEFT", 0, -8)
	header:SetPoint("TOPRIGHT", filterContainer, "BOTTOMRIGHT", 0, -8)
	header:SetHeight(22)

	local rankHeader = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	rankHeader:SetPoint("LEFT", 6, 0)
	rankHeader:SetWidth(30)
	rankHeader:SetJustifyH("LEFT")
	rankHeader:SetText("Rank")

	local nameHeader = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	nameHeader:SetPoint("LEFT", rankHeader, "RIGHT", 8, 0)
	nameHeader:SetJustifyH("LEFT")
	nameHeader:SetText("Player")

	-- Account for scrollbar width from UIPanelScrollFrameTemplate
	local scrollbarOffset = constants.SCROLLBAR_WIDTH
	
	local totalHeader = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	totalHeader:SetPoint("RIGHT", header, "RIGHT", -constants.LEADERBOARD_ENTRIES_WIDTH - 12 - scrollbarOffset, 0)
	totalHeader:SetWidth(constants.LEADERBOARD_TOTAL_WIDTH)
	totalHeader:SetJustifyH("RIGHT")
	totalHeader:SetText("Total")

	local entriesHeader = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	entriesHeader:SetPoint("RIGHT", header, "RIGHT", -6 - scrollbarOffset, 0)
	entriesHeader:SetWidth(constants.LEADERBOARD_ENTRIES_WIDTH)
	entriesHeader:SetJustifyH("RIGHT")
	entriesHeader:SetText("Entries")

	-- Scroll frame
	local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
	scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -24, 0)

	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetPoint("TOPLEFT")
	scrollChild:SetPoint("TOPRIGHT")
	scrollChild:SetHeight(1)
	scrollChild:SetWidth(1)
	scrollFrame:SetScrollChild(scrollChild)
	scrollFrame:HookScript("OnSizeChanged", function(_, width)
		scrollChild:SetWidth(width)
	end)

	-- Empty state text
	local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	emptyText:SetPoint("CENTER", scrollFrame, "CENTER")
	emptyText:SetText(constants.NO_LEADERBOARD_DATA)
	emptyText:Hide()

	-- Register event handler for activity log updates
	content:RegisterEvent("INITIATIVE_ACTIVITY_LOG_UPDATED")
	content:SetScript("OnEvent", function(self, event)
		if event == "INITIATIVE_ACTIVITY_LOG_UPDATED" then
			UpdateLeaderboardDisplay()
		end
	end)

	-- Store references
	content.filterButtons = filterButtons
	content.header = header
	content.scrollFrame = scrollFrame
	content.scrollChild = scrollChild
	content.emptyText = emptyText
	content.rows = {}

	ns.ui.leaderboardUI = content
	UpdateFilterButtons()

	content:Hide()
	return content
end

-- Export constants
Leaderboard.TIME_RANGE = TIME_RANGE
