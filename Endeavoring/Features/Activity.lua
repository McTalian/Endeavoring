---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)

local Activity = {}
ns.Activity = Activity

local DebugPrint = ns.DebugPrint

-- Time range constants (in seconds)
local TIME_RANGE = {
	CURRENT_ENDEAVOR = 0,   -- Entire duration of active endeavor
	SEVEN_DAYS = 604800,    -- 7 days
	ONE_DAY = 86400,        -- 24 hours
	TWELVE_HOURS = 43200,   -- 12 hours
	SIX_HOURS = 21600,      -- 6 hours
	ONE_HOUR = 3600,        -- 1 hour
}

-- Filter order for dropdown
local filterOrder = {
	TIME_RANGE.CURRENT_ENDEAVOR,
	TIME_RANGE.SEVEN_DAYS,
	TIME_RANGE.ONE_DAY,
	TIME_RANGE.TWELVE_HOURS,
	TIME_RANGE.SIX_HOURS,
	TIME_RANGE.ONE_HOUR,
}

-- Current filter and sort state
local state = {
	timeRange = TIME_RANGE.CURRENT_ENDEAVOR,
	sortKey = ns.Constants.ACTIVITY_SORT_TIME,  -- Default sort by time (newest first)
	sortAsc = false,  -- Descending (newest first)
	showMyCharsOnly = false,
}

--- Format time as relative ("5m ago") or absolute ("Feb 10 15:42")
--- @param timestamp number Unix timestamp
--- @return string formatted Formatted time string
local function FormatRelativeTime(timestamp)
	local now = time()
	local diff = now - timestamp
	
	-- Less than 1 minute: "Just now"
	if diff < 60 then
		return "Just now"
	end
	
	-- Less than 1 hour: "Xm ago"
	if diff < 3600 then
		local minutes = math.floor(diff / 60)
		return string.format("%dm ago", minutes)
	end
	
	-- Less than 24 hours: "Xh ago"
	if diff < 86400 then
		local hours = math.floor(diff / 3600)
		return string.format("%dh ago", hours)
	end
	
	-- Less than 7 days: "X days ago"
	if diff < 604800 then
		local days = math.floor(diff / 86400)
		if days == 1 then
			return "1 day ago"
		else
			return string.format("%d days ago", days)
		end
	end
	
	-- Older: absolute date "Feb 10 15:42"
	return date("%b %d %H:%M", timestamp)
end

--- Get display name for time range filter
--- @param range number Time range in seconds (or 0 for current endeavor)
--- @return string name Display name for the filter
local function GetTimeRangeName(range)
	if range == TIME_RANGE.CURRENT_ENDEAVOR then
		return "Current Endeavor"
	elseif range == TIME_RANGE.SEVEN_DAYS then
		return "7 Days"
	elseif range == TIME_RANGE.ONE_DAY then
		return "24 Hours"
	elseif range == TIME_RANGE.TWELVE_HOURS then
		return "12 Hours"
	elseif range == TIME_RANGE.SIX_HOURS then
		return "6 Hours"
	elseif range == TIME_RANGE.ONE_HOUR then
		return "1 Hour"
	end
	return "Unknown"
end

--- Build filtered activity log based on time range and "my chars only"
--- @param activityLog table The activity log from GetInitiativeActivityLogInfo()
--- @return table filtered Array of activity entries matching filters
local function BuildFilteredActivity(activityLog)
	if not activityLog or not activityLog.taskActivity then
		return {}
	end

	local now = time()
	local cutoffTime
	if state.timeRange and state.timeRange > 0 then
		cutoffTime = now - state.timeRange
	else
		cutoffTime = 0
	end

	local filtered = {}
	local myProfile = ns.DB.GetMyProfile()
	local myCharacters = {}
	
	-- Build lookup table for "my characters only" filter
	if state.showMyCharsOnly and myProfile then
		for charName, _ in pairs(myProfile.characters) do
			myCharacters[charName] = true
		end
	end

	for _, entry in ipairs(activityLog.taskActivity) do
		-- Apply time filter
		if entry.completionTime >= cutoffTime then
			-- Apply "my chars only" filter
			if not state.showMyCharsOnly or myCharacters[entry.playerName] then
				table.insert(filtered, entry)
			end
		end
	end

	return filtered
end

--- Build sorted activity log based on sort key and direction
--- @param activities table Filtered activity entries
--- @return table sorted Sorted copy of activities
local function BuildSortedActivity(activities)
	if not activities or #activities == 0 then
		return {}
	end

	-- Create a copy to avoid mutating original
	local sorted = {}
	for _, entry in ipairs(activities) do
		table.insert(sorted, entry)
	end

	local constants = ns.Constants
	local sortKey = state.sortKey or constants.ACTIVITY_SORT_TIME
	local sortAsc = state.sortAsc ~= false

	local function Compare(a, b)
		local aVal, bVal

		if sortKey == constants.ACTIVITY_SORT_TIME then
			-- Sort by completion time
			aVal = a.completionTime
			bVal = b.completionTime
		elseif sortKey == constants.ACTIVITY_SORT_TASK then
			-- Sort by task name (alphabetically)
			aVal = a.taskName:lower()
			bVal = b.taskName:lower()
		elseif sortKey == constants.ACTIVITY_SORT_CHAR then
			-- Sort by character name (alphabetically)
			aVal = a.playerName:lower()
			bVal = b.playerName:lower()
		elseif sortKey == constants.ACTIVITY_SORT_CONTRIB then
			-- Sort by contribution amount
			aVal = a.amount
			bVal = b.amount
		else
			-- Fallback: sort by time
			aVal = a.completionTime
			bVal = b.completionTime
		end

		-- Handle nil values
		if aVal == nil and bVal == nil then
			return false
		elseif aVal == nil then
			return not sortAsc
		elseif bVal == nil then
			return sortAsc
		end

		-- Apply sort direction
		if sortAsc then
			if aVal == bVal then
				-- Tie-breaker: fall back to time (newest first)
				return a.completionTime > b.completionTime
			end
			return aVal < bVal
		else
			if aVal == bVal then
				-- Tie-breaker: fall back to time (newest first)
				return a.completionTime > b.completionTime
			end
			return aVal > bVal
		end
	end

	table.sort(sorted, Compare)
	return sorted
end

--- Update sort header visual indicators
--- @param content table The activity content frame with header references
local function UpdateSortHeader(content)
	local constants = ns.Constants
	local sortKey = state.sortKey or constants.ACTIVITY_SORT_TIME
	local sortAsc = state.sortAsc ~= false

	-- Determine arrow icon
	local arrow = sortAsc and "|A:editmode-up-arrow:16:11|a" or "|A:editmode-down-arrow:16:11|a"

	-- Update all headers
	if sortKey == constants.ACTIVITY_SORT_TIME then
		content.timeHeader.text:SetText("Time " .. arrow)
	else
		content.timeHeader.text:SetText("Time")
	end

	if sortKey == constants.ACTIVITY_SORT_TASK then
		content.taskHeader.text:SetText("Task " .. arrow)
	else
		content.taskHeader.text:SetText("Task")
	end

	if sortKey == constants.ACTIVITY_SORT_CHAR then
		content.charHeader.text:SetText("Character (Account) " .. arrow)
	else
		content.charHeader.text:SetText("Character (Account)")
	end

	if sortKey == constants.ACTIVITY_SORT_CONTRIB then
		content.contribHeader.text:SetText("Contribution " .. arrow)
	else
		content.contribHeader.text:SetText("Contribution")
	end
end

--- Set sort key and direction, then refresh display
--- @param content table The activity content frame
--- @param newSortKey string The sort key constant
local function SetSort(content, newSortKey)
	local constants = ns.Constants
	
	if state.sortKey == newSortKey then
		-- Toggle direction if clicking same column
		state.sortAsc = not state.sortAsc
	else
		-- Set new sort key with smart default direction
		state.sortKey = newSortKey
		
		-- Smart defaults based on column type
		if newSortKey == constants.ACTIVITY_SORT_TIME then
			state.sortAsc = false  -- Newest first
		elseif newSortKey == constants.ACTIVITY_SORT_TASK then
			state.sortAsc = true   -- A-Z
		elseif newSortKey == constants.ACTIVITY_SORT_CHAR then
			state.sortAsc = true   -- A-Z
		elseif newSortKey == constants.ACTIVITY_SORT_CONTRIB then
			state.sortAsc = false  -- Highest first
		end
	end

	UpdateSortHeader(content)
	Activity.Refresh()
end

--- Create a single activity row
--- @param parent Frame The scroll child frame
--- @param index number Row index (for positioning)
--- @return Frame row The created row frame
local function CreateActivityRow(parent, index)
	local constants = ns.Constants
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(constants.FRAME_WIDTH - constants.SCROLLBAR_WIDTH - 40, constants.ACTIVITY_ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * constants.ACTIVITY_ROW_HEIGHT)

	-- Row separator (top divider)
	row.separator = row:CreateTexture(nil, "BACKGROUND")
	row.separator:SetColorTexture(0.2, 0.2, 0.2, 0.5)
	row.separator:SetHeight(1)
	row.separator:SetPoint("TOPLEFT", row, "TOPLEFT", 4, 0)
	row.separator:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, 0)

	-- Time column (smaller font, white color)
	local timeText = row:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall")
	timeText:SetPoint("LEFT", 6, 0)
	timeText:SetSize(constants.ACTIVITY_TIME_WIDTH, constants.ACTIVITY_ROW_HEIGHT)
	timeText:SetJustifyH("LEFT")
	timeText:SetWordWrap(false)
	row.timeText = timeText

	-- Task name column (with tooltip frame)
	local taskFrame = CreateFrame("Frame", nil, row)
	taskFrame:SetPoint("LEFT", timeText, "RIGHT", 4, 0)
	taskFrame:SetSize(constants.ACTIVITY_TASK_WIDTH, constants.ACTIVITY_ROW_HEIGHT)
	
	local taskText = taskFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	taskText:SetAllPoints()
	taskText:SetJustifyH("LEFT")
	taskText:SetWordWrap(false)
	taskFrame.text = taskText
	
	-- Tooltip support for task name
	taskFrame:EnableMouse(true)
	taskFrame:SetScript("OnEnter", function(self)
		if self.fullTaskName then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.fullTaskName, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	taskFrame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	row.taskFrame = taskFrame

	-- Character/Account column (multi-line with icon, using container pattern like Tasks)
	local charContainer = CreateFrame("Frame", nil, row)
	charContainer:SetPoint("TOPLEFT", taskFrame, "TOPRIGHT", 4, -2)
	charContainer:SetPoint("BOTTOMLEFT", taskFrame, "BOTTOMRIGHT", 4, 2)
	charContainer:SetWidth(constants.ACTIVITY_CHAR_WIDTH)
	
	-- Endeavoring icon (shown when profile exists)
	local icon = charContainer:CreateTexture(nil, "OVERLAY")
	icon:SetSize(16, 16)
	icon:SetPoint("RIGHT", charContainer, "RIGHT", 0, 0)
	icon:SetTexture("Interface/AddOns/Endeavoring/Icons/endeavoring.png")
	icon:Hide()  -- Hidden by default
	charContainer.icon = icon
	
	-- Top line: Player name (Alias/BattleTag, white font)
	local playerText = charContainer:CreateFontString(nil, "OVERLAY", "GameFontWhite")
	playerText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
	playerText:SetPoint("RIGHT", charContainer, "RIGHT", 0, 0)
	playerText:SetJustifyH("LEFT")
	playerText:SetWordWrap(false)
	charContainer.playerText = playerText
	
	-- Bottom line: Character name (smaller font, gray)
	local charText = charContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall2")
	charText:SetPoint("TOPLEFT", playerText, "BOTTOMLEFT", 0, -2)
	charText:SetPoint("TOPRIGHT", playerText, "BOTTOMRIGHT", 0, 0)
	charText:SetJustifyH("LEFT")
	charText:SetWordWrap(false)
	charText:SetTextColor(0.7, 0.7, 0.7)
	charContainer.charText = charText
	
	row.charContainer = charContainer

	-- Contribution column
	local contribText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	contribText:SetPoint("LEFT", charContainer, "RIGHT", 0, 0)
	contribText:SetSize(constants.ACTIVITY_CONTRIB_WIDTH, constants.ACTIVITY_ROW_HEIGHT)
	contribText:SetJustifyH("RIGHT")
	contribText:SetWordWrap(false)
	row.contribText = contribText

	return row
end

local function CenterCharText(row, hasProfile)
	-- Center character name vertically if no profile (and thus no player name)
	if hasProfile then
		local charTextHeight = row.charContainer.charText:GetHeight()
		row.charContainer.playerText:ClearAllPoints()
		row.charContainer.charText:ClearAllPoints()
		row.charContainer.playerText:SetPoint("LEFT", row.charContainer, "LEFT", 0, charTextHeight / 2)
		row.charContainer.playerText:SetPoint("RIGHT", row.charContainer, "RIGHT", 0, charTextHeight / 2)
		row.charContainer.charText:SetPoint("TOPLEFT", row.charContainer.playerText, "BOTTOMLEFT", 0, 0)
		row.charContainer.charText:SetPoint("TOPRIGHT", row.charContainer.playerText, "BOTTOMRIGHT", 0, 0)
	else
		row.charContainer.charText:ClearAllPoints()
		row.charContainer.charText:SetPoint("LEFT", row.charContainer, "LEFT", 0, 0)
		row.charContainer.charText:SetPoint("RIGHT", row.charContainer, "RIGHT", 0, 0)
	end
end

--- Update activity display with current filters
local function UpdateActivityDisplay()
	local content = ns.ui.activityContent
	if not content then
		return
	end

	-- Get activity log
	local activityLogInfo = ns.API.GetActivityLogInfo()
	if not activityLogInfo or not activityLogInfo.isLoaded then
		-- Show empty state
		if content.emptyText then
			content.emptyText:SetText("Loading activity log...")
			content.emptyText:Show()
		end
		if content.scrollChild then
			content.scrollChild:Hide()
		end
		return
	end

	-- Build filtered and sorted activity
	local filtered = BuildFilteredActivity(activityLogInfo)
	local sorted = BuildSortedActivity(filtered)

	if #sorted == 0 then
		-- Show empty state
		if content.emptyText then
			if state.showMyCharsOnly then
				content.emptyText:SetText("No activity found for your characters")
			else
				content.emptyText:SetText(ns.Constants.NO_LEADERBOARD_DATA)
			end
			content.emptyText:Show()
		end
		if content.scrollChild then
			content.scrollChild:Hide()
		end
		return
	end

	-- Hide empty state
	if content.emptyText then
		content.emptyText:Hide()
	end
	if content.scrollChild then
		content.scrollChild:Show()
	end

	-- Create or reuse rows
	local rows = content.rows or {}
	for i = 1, #sorted do
		if not rows[i] then
			rows[i] = CreateActivityRow(content.scrollChild, i)
		end
		rows[i]:Show()
	end

	-- Hide excess rows
	for i = #sorted + 1, #rows do
		rows[i]:Hide()
	end

	content.rows = rows

	-- Update row content
	for i, entry in ipairs(sorted) do
		local row = rows[i]
		
		-- Time column
		row.timeText:SetText(FormatRelativeTime(entry.completionTime))
		
		-- Task name column (with tooltip)
		row.taskFrame.text:SetText(entry.taskName)
		row.taskFrame.fullTaskName = entry.taskName  -- Store for tooltip
		
		-- Character/Account column (always show character on bottom)
		local battleTag = ns.CharacterCache.FindBattleTag(entry.playerName)
		local charContainer = row.charContainer
		
		-- Always show character name on bottom line
		charContainer.charText:SetText(entry.playerName)
		local hasProfile = false
		if battleTag then
			local profile = ns.DB.GetProfile(battleTag)
			if profile and profile.alias then
				-- Has profile: show icon + alias on top
				charContainer.icon:Show()
				charContainer.playerText:SetText(profile.alias)
			else
				-- Has BattleTag but no alias: show BattleTag on top, no icon
				charContainer.icon:Show()
				charContainer.playerText:SetText(battleTag)
			end
			hasProfile = true
		else
			-- No profile data: hide top line and icon, show only character
			charContainer.icon:Hide()
			charContainer.playerText:SetText("")
		end

		CenterCharText(row, hasProfile)
		
		-- Contribution column (3 decimal places for fractional values)
		row.contribText:SetText(string.format("+%.3f", entry.amount))
	end

	-- Update scroll child height
	local totalHeight = #sorted * ns.Constants.ACTIVITY_ROW_HEIGHT
	content.scrollChild:SetHeight(totalHeight)
end

--- Public refresh function
function Activity.Refresh()
	UpdateActivityDisplay()
end

--- Create the Activity tab
--- @param parent Frame The parent frame
--- @return Frame content The tab content frame
function Activity.CreateTab(parent)
	local constants = ns.Constants
	local content = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	content:SetPoint("TOPLEFT", parent.TabSystem, "BOTTOMLEFT", -2, 0)
	content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 12)

	-- Time range filter dropdown button
	local filterButton = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
	filterButton:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -4)
	filterButton:SetSize(140, constants.ACTIVITY_FILTER_BUTTON_HEIGHT)
	filterButton:SetDefaultText(GetTimeRangeName(state.timeRange))
	
	filterButton:SetupMenu(function(dropdown, rootDescription)
		local function IsSelected(range)
			return range == state.timeRange
		end
		
		local function SetSelected(range)
			state.timeRange = range
			filterButton:SetDefaultText(GetTimeRangeName(range))
			Activity.Refresh()
		end
		
		for _, range in ipairs(filterOrder) do
			rootDescription:CreateRadio(GetTimeRangeName(range), IsSelected, SetSelected, range)
		end
	end)
	
	content.filterButton = filterButton

	-- "My Characters Only" checkbox
	local myCharsCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
	myCharsCheck:SetPoint("LEFT", filterButton, "RIGHT", 10, 0)
	myCharsCheck:SetSize(24, 24)
	myCharsCheck:SetChecked(state.showMyCharsOnly)
	myCharsCheck:SetScript("OnClick", function(self)
		state.showMyCharsOnly = self:GetChecked()
		Activity.Refresh()
	end)
	
	local myCharsLabel = myCharsCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	myCharsLabel:SetPoint("LEFT", myCharsCheck, "RIGHT", 2, 0)
	myCharsLabel:SetText("My Characters Only")
	content.myCharsCheck = myCharsCheck

	-- Header row with column labels (clickable for sorting)
	local header = CreateFrame("Frame", nil, content)
	header:SetPoint("TOPLEFT", filterButton, "BOTTOMLEFT", -2, -8)
	header:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -8 - constants.ACTIVITY_FILTER_HEIGHT)
	header:SetHeight(constants.ACTIVITY_HEADER_HEIGHT)

	local timeHeader = CreateFrame("Button", nil, header)
	timeHeader:SetPoint("LEFT", 6, 0)
	timeHeader:SetSize(constants.ACTIVITY_TIME_WIDTH, constants.ACTIVITY_HEADER_HEIGHT)
	timeHeader:SetScript("OnClick", function()
		SetSort(content, constants.ACTIVITY_SORT_TIME)
	end)
	timeHeader.text = timeHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	timeHeader.text:SetAllPoints()
	timeHeader.text:SetJustifyH("LEFT")
	timeHeader.text:SetText("Time")

	local taskHeader = CreateFrame("Button", nil, header)
	taskHeader:SetPoint("LEFT", timeHeader, "RIGHT", 4, 0)
	taskHeader:SetSize(constants.ACTIVITY_TASK_WIDTH, constants.ACTIVITY_HEADER_HEIGHT)
	taskHeader:SetScript("OnClick", function()
		SetSort(content, constants.ACTIVITY_SORT_TASK)
	end)
	taskHeader.text = taskHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	taskHeader.text:SetAllPoints()
	taskHeader.text:SetJustifyH("LEFT")
	taskHeader.text:SetText("Task")

	local charHeader = CreateFrame("Button", nil, header)
	charHeader:SetPoint("LEFT", taskHeader, "RIGHT", 4, 0)
	charHeader:SetSize(constants.ACTIVITY_CHAR_WIDTH, constants.ACTIVITY_HEADER_HEIGHT)
	charHeader:SetScript("OnClick", function()
		SetSort(content, constants.ACTIVITY_SORT_CHAR)
	end)
	charHeader.text = charHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	charHeader.text:SetAllPoints()
	charHeader.text:SetJustifyH("LEFT")
	charHeader.text:SetText("Player")

	local contribHeader = CreateFrame("Button", nil, header)
	contribHeader:SetPoint("LEFT", charHeader, "RIGHT", 4, 0)
	contribHeader:SetSize(constants.ACTIVITY_CONTRIB_WIDTH, constants.ACTIVITY_HEADER_HEIGHT)
	contribHeader:SetScript("OnClick", function()
		SetSort(content, constants.ACTIVITY_SORT_CONTRIB)
	end)
	contribHeader.text = contribHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	contribHeader.text:SetAllPoints()
	contribHeader.text:SetJustifyH("RIGHT")
	contribHeader.text:SetText("Contribution")

	-- Store header references for sort indicator updates
	content.timeHeader = timeHeader
	content.taskHeader = taskHeader
	content.charHeader = charHeader
	content.contribHeader = contribHeader

	-- Scroll frame for activity entries
	local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
	scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -26, 5)

	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetWidth(constants.FRAME_WIDTH - constants.SCROLLBAR_WIDTH - 40)
	scrollChild:SetHeight(1)  -- Will be updated dynamically
	scrollFrame:SetScrollChild(scrollChild)
	content.scrollChild = scrollChild
	content.scrollFrame = scrollFrame

	-- Empty state text
	local emptyText = scrollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	emptyText:SetPoint("CENTER", scrollFrame, "CENTER", 0, 0)
	emptyText:SetText(ns.Constants.NO_LEADERBOARD_DATA)
	emptyText:Hide()
	content.emptyText = emptyText

	-- Register for activity log updates
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("INITIATIVE_ACTIVITY_LOG_UPDATED")
	eventFrame:SetScript("OnEvent", function()
		Activity.Refresh()
	end)
	content.eventFrame = eventFrame

	-- Initialize sort indicators
	UpdateSortHeader(content)

	-- Store reference
	ns.ui.activityContent = content

	return content
end
