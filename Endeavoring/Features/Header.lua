---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)

local Header = {}
ns.Header = Header

function Header.Create(parent)
	local constants = ns.Constants
	local header = CreateFrame("Frame", nil, parent)
	header:SetPoint("TOPLEFT", 12, -58)
	header:SetPoint("TOPRIGHT", -12, -58)
	header:SetHeight(constants.HEADER_HEIGHT)

	-- Title with description tooltip support
	header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	header.title:SetPoint("TOPLEFT", 6, -4)
	header.title:SetText("Endeavoring")

	-- Info icon for endeavor description tooltip
	header.infoIcon = CreateFrame("Button", nil, header)
	header.infoIcon:SetSize(16, 16)
	header.infoIcon:SetPoint("LEFT", header.title, "RIGHT", 4, 0)
	header.infoIcon:SetNormalAtlas("poi-workorders")
	header.infoIcon:SetHighlightAtlas("poi-workorders")
	header.infoIcon:SetAlpha(0.7)
	header.infoIcon:SetScript("OnEnter", function(self)
		local initiativeInfo = ns.API.GetInitiativeInfo()
		if initiativeInfo and initiativeInfo.description and initiativeInfo.description ~= "" then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip_SetTitle(GameTooltip, initiativeInfo.title or "Endeavor")
			GameTooltip_AddNormalLine(GameTooltip, initiativeInfo.description, true)
			GameTooltip:Show()
		end
	end)
	header.infoIcon:SetScript("OnLeave", GameTooltip_Hide)
	header.infoIcon:Hide() -- Hidden until we have an active endeavor

	header.timeRemaining = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	header.timeRemaining:SetPoint("TOPLEFT", header.title, "BOTTOMLEFT", 0, -6)
	header.timeRemaining:SetText(constants.TIME_REMAINING_FALLBACK)

	-- Progress bar with gradient color
	header.progress = CreateFrame("StatusBar", nil, header, "TextStatusBar")
	header.progress:SetPoint("TOPLEFT", header.timeRemaining, "BOTTOMLEFT", 0, -8)
	header.progress:SetSize(320, 18)
	header.progress:SetMinMaxValues(0, 100)
	header.progress:SetValue(0)
	
	-- Use smooth gradient texture
	local progressTexture = header.progress:CreateTexture(nil, "ARTWORK")
	progressTexture:SetTexture("Interface/TargetingFrame/UI-StatusBar")
	header.progress:SetStatusBarTexture(progressTexture)
	
	-- Green gradient (similar to experience bar)
	progressTexture:SetVertexColor(0.2, 0.8, 0.2) -- Green tint
	
	-- Background texture
	header.progress.bg = header.progress:CreateTexture(nil, "BACKGROUND")
	header.progress.bg:SetAllPoints(header.progress)
	header.progress.bg:SetTexture("Interface/TargetingFrame/UI-StatusBar")
	header.progress.bg:SetVertexColor(0.1, 0.1, 0.1, 0.5)
	
	-- Progress text
	header.progress.text = header.progress:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	header.progress.text:SetPoint("CENTER")
	header.progress.text:SetText("0%")

	-- Value Text
	header.progress.valueText = header.progress:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	header.progress.valueText:SetPoint("RIGHT", header.progress, "RIGHT", -4, 0)
	header.progress.valueText:SetText("0 / 0")
	
	-- Milestone list on the right side (single column with overflow to second column)
	header.milestoneList = CreateFrame("Frame", nil, header)
	header.milestoneList:SetPoint("TOPRIGHT", header, "TOPRIGHT", -10, -4)
	header.milestoneList:SetSize(260, 90) -- Wide enough for overflow column if needed
	
	-- Milestone entries (created dynamically during refresh)
	header.milestones = {}

	return header
end

function Header.Refresh()
	local constants = ns.Constants
	local mainFrame = ns.ui and ns.ui.mainFrame
	if not mainFrame or not mainFrame.header then
		return
	end

	local header = mainFrame.header
	local isInitiativeActive = ns.API.IsInitiativeActive()
	
	if not isInitiativeActive then
		header.title:SetText(constants.NO_ACTIVE_ENDEAVOR)
		header.timeRemaining:SetText(constants.TIME_REMAINING_FALLBACK)
		header.progress:SetMinMaxValues(0, 100)
		header.progress:SetValue(0)
		header.progress.text:SetText("0%")
		header.infoIcon:Hide()
		-- Hide all milestone markers
		for _, milestone in pairs(header.milestones) do
			milestone:Hide()
		end
		return
	end

	local initiativeInfo = ns.API.GetInitiativeInfo()

	if initiativeInfo and initiativeInfo.isLoaded and initiativeInfo.initiativeID ~= 0 then
		header.title:SetText(initiativeInfo.title or "???")
		header.timeRemaining:SetText(ns.API.FormatTimeRemaining(initiativeInfo.duration))

		-- Show info icon if we have a description
		if initiativeInfo.description and initiativeInfo.description ~= "" then
			header.infoIcon:Show()
		else
			header.infoIcon:Hide()
		end

		local maxProgress = initiativeInfo.progressRequired or 0
		if maxProgress <= 0 then
			maxProgress = 1
		end
		local currentProgress = initiativeInfo.currentProgress or 0
		header.progress:SetMinMaxValues(0, maxProgress)
		header.progress:SetValue(currentProgress)
		local percent = math.min((currentProgress / maxProgress), 1)
		header.progress.text:SetText(FormatPercentage(percent))
		header.progress.valueText:SetText(string.format("%.1f / %d", currentProgress, maxProgress))
		
		-- Update milestone markers
		if initiativeInfo.milestones and #initiativeInfo.milestones > 0 then
			Header.UpdateMilestones(header, initiativeInfo.milestones, currentProgress, maxProgress)
		else
			-- Hide all milestones if none exist
			for _, milestone in pairs(header.milestones) do
				milestone:Hide()
			end
		end
	else
		header.title:SetText(constants.NO_TASK_DATA)
		header.timeRemaining:SetText(constants.TIME_REMAINING_FALLBACK)
		header.progress:SetMinMaxValues(0, 100)
		header.progress:SetValue(0)
		header.progress.text:SetText("0%")
		header.infoIcon:Hide()
		for _, milestone in pairs(header.milestones) do
			milestone:Hide()
		end
	end
end

function Header.UpdateMilestones(header, milestones, currentProgress, maxProgress)
	local milestoneList = header.milestoneList
	local lineHeight = 18
	local columnWidth = 130
	local leftColumnX = 0
	local rightColumnX = columnWidth
	
	-- Create or update milestone list entries
	for i, milestoneInfo in ipairs(milestones) do
		local entry = header.milestones[i]
		
		-- Create entry if it doesn't exist
		if not entry then
			entry = CreateFrame("Frame", nil, milestoneList)
			entry:SetSize(columnWidth, lineHeight)
			
			-- Checkmark icon
			entry.checkmark = entry:CreateTexture(nil, "ARTWORK")
			entry.checkmark:SetAtlas("checkmark-minimal")
			entry.checkmark:SetSize(14, 14)
			entry.checkmark:SetPoint("LEFT", entry, "LEFT", 0, 0)
			
			-- Milestone text (name and percentage)
			entry.text = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			entry.text:SetPoint("LEFT", entry.checkmark, "RIGHT", 4, 0)
			entry.text:SetJustifyH("LEFT")
			
			-- Make it hoverable for tooltip
			entry:EnableMouse(true)
			entry:SetScript("OnEnter", function(self)
				if not self.milestoneData then
					return
				end
				
				GameTooltip:SetOwner(self, "ANCHOR_LEFT", -10, 0)
				GameTooltip_SetTitle(GameTooltip, "Milestone " .. self.index)
				GameTooltip_AddNormalLine(GameTooltip, "Progress Required: " .. self.milestoneData.requiredContributionAmount)
				
				if self.milestoneData.rewards and #self.milestoneData.rewards > 0 then
					GameTooltip_AddBlankLineToTooltip(GameTooltip)
					GameTooltip_AddHighlightLine(GameTooltip, "Rewards:")
					for _, reward in ipairs(self.milestoneData.rewards) do
						if reward.title and reward.title ~= "" then
							local rewardText = reward.title
							if reward.description and reward.description ~= "" then
								rewardText = rewardText .. ": " .. reward.description
							end
							GameTooltip_AddColoredLine(GameTooltip, rewardText, GREEN_FONT_COLOR)
						end
					end
				end
				
				GameTooltip:Show()
			end)
			entry:SetScript("OnLeave", GameTooltip_Hide)
			
			header.milestones[i] = entry
		end
		
		-- Stack first 4 milestones in left column, overflow to right column
		local maxLeftColumn = 4
		local isLeftColumn = (i <= maxLeftColumn)
		local xPos, yPos
		
		if isLeftColumn then
			-- Left column: items 1-4
			xPos = leftColumnX
			yPos = -(i - 1) * lineHeight
		else
			-- Right column (overflow): items 5+
			xPos = rightColumnX
			yPos = -(i - maxLeftColumn - 1) * lineHeight
		end
		
		-- Position entry in appropriate column
		entry:ClearAllPoints()
		entry:SetPoint("TOPLEFT", milestoneList, "TOPLEFT", xPos, yPos)
		
		-- Calculate percentage threshold
		local percentThreshold = math.floor((milestoneInfo.requiredContributionAmount / maxProgress) * 100)
		
		-- Check if milestone completed
		local isCompleted = currentProgress >= milestoneInfo.requiredContributionAmount
		
		-- Update text and appearance
		entry.text:SetText(string.format("Milestone %d  %d%%", i, percentThreshold))
		
		if isCompleted then
			entry.checkmark:Show()
			entry.checkmark:SetDesaturated(false)
			entry.checkmark:SetVertexColor(0.2, 1.0, 0.2) -- Green
			entry.text:SetTextColor(0.2, 1.0, 0.2) -- Green text
		else
			entry.checkmark:Show()
			entry.checkmark:SetDesaturated(true)
			entry.checkmark:SetVertexColor(0.5, 0.5, 0.5) -- Gray
			entry.text:SetTextColor(0.8, 0.8, 0.8) -- Light gray text
		end
		
		-- Store milestone data for tooltip
		entry.milestoneData = milestoneInfo
		entry.index = i
		entry:Show()
	end
	
	-- Hide unused entries
	for i = #milestones + 1, #header.milestones do
		header.milestones[i]:Hide()
	end
end
