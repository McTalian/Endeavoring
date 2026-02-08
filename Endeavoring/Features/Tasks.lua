---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)

local Tasks = {}
ns.Tasks = Tasks

local function BuildSortedTasks(initiativeInfo)
	if not initiativeInfo or not initiativeInfo.tasks then
		return {}
	end

	local tasks = {}
	for _, task in ipairs(initiativeInfo.tasks) do
		table.insert(tasks, task)
	end

	local state = ns.state or {}
	local sortKey = state.tasksSortKey or ns.Constants.TASKS_SORT_POINTS
	local sortAsc = state.tasksSortAsc ~= false

	local function Compare(a, b)
		if sortKey == ns.Constants.TASKS_SORT_NAME then
			local left = a.taskName or ""
			local right = b.taskName or ""
			if left == right then
				return (a.progressContributionAmount or 0) < (b.progressContributionAmount or 0)
			end
			if sortAsc then
				return left < right
			end
			return left > right
		end

		local leftPoints = a.progressContributionAmount or 0
		local rightPoints = b.progressContributionAmount or 0
		if leftPoints == rightPoints then
			local leftName = a.taskName or ""
			local rightName = b.taskName or ""
			return leftName < rightName
		end
		if sortAsc then
			return leftPoints < rightPoints
		end
		return leftPoints > rightPoints
	end

	table.sort(tasks, Compare)
	return tasks
end

local function UpdateSortHeader()
	if not ns.ui.tasksUI then
		return
	end

	local nameSuffix = ""
	local pointsSuffix = ""
	local asc = CreateAtlasMarkup("editmode-up-arrow", 16, 11, 1, 4)
	local desc = CreateAtlasMarkup("editmode-down-arrow", 16, 11, 1, -4)
	local state = ns.state or {}
	if state.tasksSortKey == ns.Constants.TASKS_SORT_NAME then
		nameSuffix = state.tasksSortAsc and asc or desc
	elseif state.tasksSortKey == ns.Constants.TASKS_SORT_POINTS then
		pointsSuffix = state.tasksSortAsc and asc or desc
	end

	ns.ui.tasksUI.nameHeader:SetText("Task" .. nameSuffix)
	ns.ui.tasksUI.pointsHeader:SetText("Contribution Points" .. pointsSuffix)
end

local function SetSort(sortKey)
	local state = ns.state or {}
	if state.tasksSortKey == sortKey then
		state.tasksSortAsc = not state.tasksSortAsc
	else
		state.tasksSortKey = sortKey
		state.tasksSortAsc = true
	end

	ns.state = state
	UpdateSortHeader()
	Tasks.Refresh()
end

local function CreateTaskRow(parent, index)
	local constants = ns.Constants
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(constants.TASK_ROW_HEIGHT)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * constants.TASK_ROW_HEIGHT))
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -((index - 1) * constants.TASK_ROW_HEIGHT))

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.name:SetPoint("LEFT", 6, 0)
	row.name:SetJustifyH("LEFT")

	row.points = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.points:SetWidth(constants.TASK_POINTS_WIDTH)
	row.points:SetJustifyH("RIGHT")
	row.points:SetPoint("RIGHT", row, "RIGHT", -constants.TASK_XP_WIDTH - 12, 0)

	row.xp = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.xp:SetWidth(constants.TASK_XP_WIDTH)
	row.xp:SetJustifyH("RIGHT")
	row.xp:SetPoint("RIGHT", row, "RIGHT", -6, 0)

	row.name:SetPoint("RIGHT", row.points, "LEFT", -8, 0)

	row:SetScript("OnEnter", function(self)
		if not self.data then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, self.data.taskName or "Task")
		if self.data.description and self.data.description ~= "" then
			GameTooltip_AddNormalLine(GameTooltip, self.data.description, true)
		end
		if self.data.requirementsList then
			for _, requirement in ipairs(self.data.requirementsList) do
				if requirement.requirementText then
					local color = requirement.completed and DISABLED_FONT_COLOR or NORMAL_FONT_COLOR
					GameTooltip_AddColoredLine(GameTooltip, requirement.requirementText, color)
				end
			end
		end
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)

	return row
end

local function GetHouseXPText(rewardQuestID)
	local rewardFavor = ns.API.GetQuestRewardHouseXp(rewardQuestID) or nil
	local value = rewardFavor or "--"
	return tostring(value) .. " " .. CreateAtlasMarkup("housing-dashboard-estateXP-icon", 10, 10)
end

function Tasks.Refresh()
	if not ns.ui.tasksUI then
		return
	end

	local constants = ns.Constants
	local tasksUI = ns.ui.tasksUI
	local initiativeInfo = ns.API.GetInitiativeInfo() or nil

	if not initiativeInfo or not initiativeInfo.isLoaded or initiativeInfo.initiativeID == 0 then
		tasksUI.emptyText:SetText(constants.NO_ACTIVE_ENDEAVOR)
		tasksUI.emptyText:Show()
		for _, row in ipairs(tasksUI.rows) do
			row:Hide()
		end
		return
	end

	local tasks = BuildSortedTasks(initiativeInfo)
	if #tasks == 0 then
		tasksUI.emptyText:SetText(constants.NO_TASKS_AVAILABLE)
		tasksUI.emptyText:Show()
		for _, row in ipairs(tasksUI.rows) do
			row:Hide()
		end
		return
	end

	tasksUI.emptyText:Hide()
	local totalHeight = #tasks * constants.TASK_ROW_HEIGHT
	tasksUI.scrollChild:SetHeight(totalHeight)
	local scrollWidth = tasksUI.scrollFrame and tasksUI.scrollFrame:GetWidth() or 1
	if scrollWidth and scrollWidth > 0 then
		tasksUI.scrollChild:SetWidth(scrollWidth)
	end

	for index, task in ipairs(tasks) do
		local row = tasksUI.rows[index]
		if not row then
			row = CreateTaskRow(tasksUI.scrollChild, index)
			tasksUI.rows[index] = row
		end
		row.data = task
		row.name:SetText(task.taskName or "")
		row.points:SetText(task.progressContributionAmount or "--")
		row.xp:SetText(GetHouseXPText(task.rewardQuestID))

		if task.completed then
			row.name:SetTextColor(0.5, 0.5, 0.5)
			row.points:SetTextColor(0.5, 0.5, 0.5)
			row.xp:SetTextColor(0.5, 0.5, 0.5)
		else
			row.name:SetTextColor(1, 0.82, 0)
			row.points:SetTextColor(1, 1, 1)
			row.xp:SetTextColor(1, 1, 1)
		end

		row:Show()
	end

	for index = #tasks + 1, #tasksUI.rows do
		tasksUI.rows[index]:Hide()
	end
end

function Tasks.CreateTab(parent)
	local constants = ns.Constants
	local content = CreateFrame("Frame", nil, parent)
	content:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -120)
	content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 12)

	local header = CreateFrame("Frame", nil, content)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(22)

	local nameHeader = CreateFrame("Button", nil, header)
	nameHeader:SetPoint("LEFT", 4, 0)
	nameHeader:SetSize(140, 18)
	nameHeader:SetScript("OnClick", function()
		SetSort(constants.TASKS_SORT_NAME)
	end)
	nameHeader.text = nameHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	nameHeader.text:SetPoint("LEFT")
	nameHeader.text:SetJustifyH("LEFT")
	nameHeader.text:SetText("Task")

	local pointsHeader = CreateFrame("Button", nil, header)
	pointsHeader:SetPoint("RIGHT", header, "RIGHT", -constants.TASK_XP_WIDTH - 12, 0)
	pointsHeader:SetSize(constants.TASK_POINTS_WIDTH, 18)
	pointsHeader:SetScript("OnClick", function()
		SetSort(constants.TASKS_SORT_POINTS)
	end)
	pointsHeader.text = pointsHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	pointsHeader.text:SetPoint("RIGHT")
	pointsHeader.text:SetJustifyH("RIGHT")
	pointsHeader.text:SetText("Points")

	local xpHeader = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	xpHeader:SetPoint("RIGHT", header, "RIGHT", -6, 0)
	xpHeader:SetWidth(constants.TASK_XP_WIDTH)
	xpHeader:SetJustifyH("RIGHT")
	xpHeader:SetText("House XP")

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

	local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	emptyText:SetPoint("CENTER")
	emptyText:SetText(constants.NO_ACTIVE_ENDEAVOR)
	emptyText:Hide()

	content.header = header
	content.nameHeader = nameHeader.text
	content.pointsHeader = pointsHeader.text
	content.xpHeader = xpHeader
	content.scrollFrame = scrollFrame
	content.scrollChild = scrollChild
	content.emptyText = emptyText
	content.rows = {}

	ns.ui.tasksUI = content
	UpdateSortHeader()

	content:Hide()
	return content
end
