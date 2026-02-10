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
	ns.ui.tasksUI.contributionHeader:SetText("Contribution" .. pointsSuffix)
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
	-- TODO: Make columns sortable (Contribution, House XP, Coupons)
	
	local constants = ns.Constants
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(constants.TASK_ROW_HEIGHT)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * constants.TASK_ROW_HEIGHT))
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -((index - 1) * constants.TASK_ROW_HEIGHT))

	-- Row separator (top divider)
	row.separator = row:CreateTexture(nil, "BACKGROUND")
	row.separator:SetColorTexture(0.2, 0.2, 0.2, 0.5)
	row.separator:SetHeight(1)
	row.separator:SetPoint("TOPLEFT", row, "TOPLEFT", 4, 0)
	row.separator:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, 0)

	-- Task column container (for vertical justification)
	row.taskContainer = CreateFrame("Frame", nil, row)
	row.taskContainer:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -2)
	row.taskContainer:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, -2)
	row.taskContainer:SetWidth(constants.TASK_TASK_WIDTH) -- Task column width

	-- Task name (bold, gold) - inside container
	row.name = row.taskContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.name:SetPoint("LEFT", row.taskContainer, "LEFT", 0, 0)
	row.name:SetPoint("RIGHT", row.taskContainer, "RIGHT", 0, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetMaxLines(1)

	-- Task description (smaller, gray, below name) - inside container
	row.description = row.taskContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall2")
	row.description:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
	row.description:SetPoint("TOPRIGHT", row.name, "BOTTOMRIGHT", 0, -2)
	row.description:SetJustifyH("LEFT")
	row.description:SetTextColor(0.7, 0.7, 0.7)
	row.description:SetWidth(constants.TASK_TASK_WIDTH - 4) -- Account for padding
	row.description:SetMaxLines(2)

	row.contributionContainer = CreateFrame("Frame", nil, row)
	row.contributionContainer:SetPoint("TOPLEFT", row.taskContainer, "TOPRIGHT", 0, 0)
	row.contributionContainer:SetPoint("BOTTOMLEFT", row.taskContainer, "BOTTOMRIGHT", 0, 0)
	row.contributionContainer:SetWidth(constants.TASK_CONTRIBUTION_WIDTH)

	-- Contribution column: icon then value anchored to right of task column
	row.contributionIcon = row.contributionContainer:CreateTexture(nil, "ARTWORK")
	row.contributionIcon:SetAtlas("housing-dashboard-tasks-listitem-flag")
	row.contributionIcon:SetSize(32, 32)
	row.contributionIcon:SetPoint("CENTER", row.contributionContainer, "CENTER", 0, 0)
	
	-- Contribution value overlaid on icon (centered)
	row.contribution = row.contributionContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.contribution:SetPoint("CENTER", row.contributionIcon, "CENTER", 0, 2)

	row.xpContainer = CreateFrame("Frame", nil, row)
	row.xpContainer:SetPoint("TOPLEFT", row.contributionContainer, "TOPRIGHT", constants.SCROLLBAR_WIDTH, 0)
	row.xpContainer:SetPoint("BOTTOMLEFT", row.contributionContainer, "BOTTOMRIGHT", constants.SCROLLBAR_WIDTH, 0)
	row.xpContainer:SetWidth(constants.TASK_XP_WIDTH - constants.SCROLLBAR_WIDTH)

	-- House XP column: value anchored right of coupons, icon to its left
	row.xp = row.xpContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.xp:SetPoint("CENTER", row.xpContainer, "CENTER", 0, 0)
	row.xp:SetJustifyH("CENTER")
	
	row.xpIcon = row.xpContainer:CreateTexture(nil, "ARTWORK")
	row.xpIcon:SetAtlas("housing-dashboard-estateXP-icon")
	row.xpIcon:SetSize(16, 16)
	row.xpIcon:SetPoint("CENTER", row.xp, "CENTER", -20, 0)

	row.couponsContainer = CreateFrame("Frame", nil, row)
	row.couponsContainer:SetPoint("TOPLEFT", row.xpContainer, "TOPRIGHT", 0, 0)
	row.couponsContainer:SetPoint("BOTTOMLEFT", row.xpContainer, "BOTTOMRIGHT", 0, 0)
	row.couponsContainer:SetWidth(constants.TASK_COUPONS_WIDTH)

	-- Coupons column: value anchored to right edge, icon to its left
	row.coupons = row.couponsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.coupons:SetPoint("CENTER", row.couponsContainer, "CENTER", 0, 0)
	row.coupons:SetJustifyH("CENTER")
	row.coupons:SetWidth(constants.TASK_COUPONS_WIDTH) -- Account for scrollbar width
	
	row.couponsIcon = row.couponsContainer:CreateTexture(nil, "ARTWORK")
	row.couponsIcon:SetSize(16, 16)
	row.couponsIcon:SetPoint("CENTER", row.coupons, "CENTER", -20, 0)

	row:SetScript("OnEnter", function(self)
		if not self.data then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 8, 0)
		GameTooltip_SetTitle(GameTooltip, self.data.taskName or "Task")
		
		-- Show full description if available
		if self.data.description and self.data.description ~= "" then
			GameTooltip_AddNormalLine(GameTooltip, self.data.description, true)
			GameTooltip_AddBlankLineToTooltip(GameTooltip)
		end
		
		-- Show requirements
		if self.data.requirementsList then
			for _, requirement in ipairs(self.data.requirementsList) do
				if requirement.requirementText then
					local color = requirement.completed and DISABLED_FONT_COLOR or NORMAL_FONT_COLOR
					GameTooltip_AddColoredLine(GameTooltip, requirement.requirementText, color)
				end
			end
		end
		
		-- Show detailed rewards
		if self.data.rewardQuestID then
			GameTooltip_AddBlankLineToTooltip(GameTooltip)
			GameTooltip_AddQuestRewardsToTooltip(GameTooltip, self.data.rewardQuestID, TOOLTIP_QUEST_REWARDS_STYLE_INITIATIVE_TASK)
		end
		
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)

	return row
end

local function GetCouponsInfo(rewardQuestID)
	if not rewardQuestID or rewardQuestID == 0 then
		return "--", nil
	end
	
	local currencyInfo = C_QuestLog.GetQuestRewardCurrencyInfo(rewardQuestID, 1, false)
	if currencyInfo then
		return tostring(currencyInfo.totalRewardAmount or 0), currencyInfo.texture
	end
	
	return "--", nil
end

local function GetHouseXPValue(rewardQuestID)
	local rewardFavor = ns.API.GetQuestRewardHouseXp(rewardQuestID) or nil
	return tostring(rewardFavor or "--")
end

-- Center task name/description vertically based on whether description exists
local function CenterTaskText(row, hasDescription)
	if hasDescription then
		-- Two-line layout: start at top of container
		local descHeight = row.description:GetHeight() or 0
		print("Description height:", descHeight)
		row.name:ClearAllPoints()
		row.name:SetPoint("LEFT", row.taskContainer, "LEFT", 0, descHeight / 2)
		row.name:SetPoint("RIGHT", row.taskContainer, "RIGHT", 0, descHeight / 2)
		row.name:SetJustifyV("MIDDLE")
	else
		-- Single-line layout: center name vertically in container
		row.name:ClearAllPoints()
		row.name:SetPoint("LEFT", row.taskContainer, "LEFT", 0, 0)
		row.name:SetPoint("RIGHT", row.taskContainer, "RIGHT", 0, 0)
		row.name:SetJustifyV("MIDDLE")
	end
end

function Tasks.Refresh()
	if not ns.ui.tasksUI then
		return
	end

	local constants = ns.Constants
	local tasksUI = ns.ui.tasksUI
	local initiativeInfo = ns.API.GetInitiativeInfo() or nil

	if not initiativeInfo or not initiativeInfo.isLoaded or initiativeInfo.initiativeID == 0 then
		tasksUI.emptyText:SetText(constants.NO_TASK_DATA)
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
		
		-- Set description and handle vertical centering
		local hasDescription = task.description and task.description ~= ""
		if hasDescription then
			row.description:SetText(task.description)
			row.description:Show()
		else
			row.description:Hide()
		end
		CenterTaskText(row, hasDescription)
		
		-- Set contribution value
		row.contribution:SetText(task.progressContributionAmount or "--")
		
		-- Set House XP value
		row.xp:SetText(GetHouseXPValue(task.rewardQuestID))
		
		-- Set coupons value and icon
		local couponsValue, couponsTexture = GetCouponsInfo(task.rewardQuestID)
		row.coupons:SetText(couponsValue)
		if couponsTexture then
			row.couponsIcon:SetTexture(couponsTexture)
			row.couponsIcon:Show()
		else
			row.couponsIcon:Hide()
		end

		if task.completed then
			row.name:SetTextColor(0.5, 0.5, 0.5)
			row.description:SetTextColor(0.4, 0.4, 0.4)
			row.contribution:SetTextColor(0.5, 0.5, 0.5)
			row.xp:SetTextColor(0.5, 0.5, 0.5)
			row.coupons:SetTextColor(0.5, 0.5, 0.5)
			row.contributionIcon:SetDesaturated(true)
			row.contributionIcon:SetAlpha(0.5)
			row.xpIcon:SetDesaturated(true)
			row.xpIcon:SetAlpha(0.5)
			row.couponsIcon:SetDesaturated(true)
			row.couponsIcon:SetAlpha(0.5)
		else
			row.name:SetTextColor(1, 0.82, 0)
			row.description:SetTextColor(0.7, 0.7, 0.7)
			row.contribution:SetTextColor(1, 1, 1)
			row.xp:SetTextColor(1, 1, 1)
			row.coupons:SetTextColor(1, 1, 1)
			row.contributionIcon:SetDesaturated(false)
			row.contributionIcon:SetAlpha(1.0)
			row.xpIcon:SetDesaturated(false)
			row.xpIcon:SetAlpha(1.0)
			row.couponsIcon:SetDesaturated(false)
			row.couponsIcon:SetAlpha(1.0)
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
	content:SetPoint("TOPLEFT", parent.TabSystem, "BOTTOMLEFT", 4, -8)
	content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 12)

	local header = CreateFrame("Frame", nil, content)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(22)

	-- Account for scrollbar width from UIPanelScrollFrameTemplate
	local scrollbarOffset = constants.SCROLLBAR_WIDTH

	local nameHeader = CreateFrame("Button", nil, header)
	nameHeader:SetPoint("LEFT", 8, 0)
	nameHeader:SetSize(constants.TASK_TASK_WIDTH, 18)
	nameHeader:SetScript("OnClick", function()
		SetSort(constants.TASKS_SORT_NAME)
	end)
	nameHeader.text = nameHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	nameHeader.text:SetPoint("LEFT")
	nameHeader.text:SetJustifyH("LEFT")
	nameHeader.text:SetText("Task")

	local contributionHeader = CreateFrame("Button", nil, header)
	contributionHeader:SetPoint("LEFT", nameHeader, "RIGHT", 0, 0)
	contributionHeader:SetSize(constants.TASK_CONTRIBUTION_WIDTH, 18)
	contributionHeader:SetScript("OnClick", function()
		SetSort(constants.TASKS_SORT_POINTS)
	end)
	contributionHeader.text = contributionHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	contributionHeader.text:SetPoint("CENTER")
	contributionHeader.text:SetJustifyH("CENTER")
	contributionHeader.text:SetText("Contribution")

	local xpHeader = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	xpHeader:SetPoint("LEFT", contributionHeader, "RIGHT", 0, 0)
	xpHeader:SetWidth(constants.TASK_XP_WIDTH)
	xpHeader:SetJustifyH("CENTER")
	xpHeader:SetText("House XP")
	
	local couponsHeader = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	couponsHeader:SetPoint("LEFT", xpHeader, "RIGHT", 0, 0)
	couponsHeader:SetWidth(constants.TASK_COUPONS_WIDTH - scrollbarOffset)
	couponsHeader:SetJustifyH("CENTER")
	couponsHeader:SetText("Coupons")

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
	emptyText:SetText(constants.NO_TASK_DATA)
	emptyText:Hide()

	content.header = header
	content.nameHeader = nameHeader.text
	content.contributionHeader = contributionHeader.text
	content.xpHeader = xpHeader
	content.couponsHeader = couponsHeader
	content.scrollFrame = scrollFrame
	content.scrollChild = scrollChild
	content.emptyText = emptyText
	content.rows = {}

	ns.ui.tasksUI = content
	UpdateSortHeader()

	content:Hide()
	return content
end
