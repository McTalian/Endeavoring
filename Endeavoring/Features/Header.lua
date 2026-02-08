---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)

local Header = {}
ns.Header = Header

function Header.Create(parent)
	-- TODO: Add color gradient to progress bar (similar to experience bar)
	-- TODO: Display milestone markers at progress bar positions (checkmarks when completed)
	-- TODO: Add tooltip/description icon for endeavor flavor text
	
	local constants = ns.Constants
	local header = CreateFrame("Frame", nil, parent)
	header:SetPoint("TOPLEFT", 12, -32)
	header:SetPoint("TOPRIGHT", -12, -32)
	header:SetHeight(88)

	header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	header.title:SetPoint("TOPLEFT", 6, -4)
	header.title:SetText("Endeavoring")

	header.timeRemaining = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	header.timeRemaining:SetPoint("TOPLEFT", header.title, "BOTTOMLEFT", 0, -6)
	header.timeRemaining:SetText(constants.TIME_REMAINING_FALLBACK)

	header.progress = CreateFrame("StatusBar", nil, header, "TextStatusBar")
	header.progress:SetPoint("TOPLEFT", header.timeRemaining, "BOTTOMLEFT", 0, -8)
	header.progress:SetSize(320, 14)
	header.progress:SetMinMaxValues(0, 100)
	header.progress:SetValue(0)
	header.progress:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
	header.progress.text = header.progress:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	header.progress.text:SetPoint("CENTER")
	header.progress.text:SetText("0%")

	return header
end

function Header.Refresh()
	local constants = ns.Constants
	local mainFrame = ns.ui and ns.ui.mainFrame
	if not mainFrame or not mainFrame.header then
		return
	end

	local header = mainFrame.header
	local initiativeInfo = ns.API.GetInitiativeInfo()

	if initiativeInfo and initiativeInfo.isLoaded and initiativeInfo.initiativeID ~= 0 then
		header.title:SetText(initiativeInfo.title or "Endeavoring")
		header.timeRemaining:SetText(ns.API.FormatTimeRemaining(initiativeInfo.duration))

		local maxProgress = initiativeInfo.progressRequired or 0
		if maxProgress <= 0 then
			maxProgress = 1
		end
		local currentProgress = initiativeInfo.currentProgress or 0
		header.progress:SetMinMaxValues(0, maxProgress)
		header.progress:SetValue(currentProgress)
		local percent = math.min((currentProgress / maxProgress), 1)
		header.progress.text:SetText(FormatPercentage(percent))
	else
		header.title:SetText(constants.NO_ACTIVE_ENDEAVOR)
		header.timeRemaining:SetText(constants.TIME_REMAINING_FALLBACK)
		header.progress:SetMinMaxValues(0, 100)
		header.progress:SetValue(0)
		header.progress.text:SetText("0%")
	end
end
