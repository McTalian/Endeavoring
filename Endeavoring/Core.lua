---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)

local constants = ns.Constants

local DebugPrint = ns.DebugPrint

local function CreateTabContent(parent, label)
	local content = CreateFrame("Frame", nil, parent)
	content:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -120)
	content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 12)

	local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("TOPLEFT")
	text:SetText(label .. " content coming soon.")

	content:Hide()
	return content
end

local function SetActiveTab(parent, tabIndex)
	parent.activeTab = tabIndex
	for index, tab in ipairs(parent.tabs) do
		local isActive = index == tabIndex
		tab:SetEnabled(not isActive)
		if isActive then
			parent.tabContents[index]:Show()
		else
			parent.tabContents[index]:Hide()
		end
	end
end

local function CreateTabs(parent)
	parent.tabs = {}
	parent.tabContents = {}

	for index, label in ipairs(constants.TAB_LABELS) do
		local tab = CreateFrame("Button", nil, parent, "TabSystemTopButtonTemplate")
		tab:SetText(label)
		tab:SetSize(110, 22)
		tab:SetID(index)
		tab:SetScript("OnClick", function(self)
			SetActiveTab(parent, self:GetID())
		end)

		if index == 1 then
			tab:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 8, 6)
		else
			tab:SetPoint("LEFT", parent.tabs[index - 1], "RIGHT", 6, 0)
		end

		parent.tabs[index] = tab
		if label == "Tasks" then
			parent.tabContents[index] = ns.Tasks.CreateTab(parent)
		else
			parent.tabContents[index] = CreateTabContent(parent, label)
		end
	end

	SetActiveTab(parent, 1)
end

local function RefreshInitiativeUI()
	ns.Header.Refresh()
	ns.Tasks.Refresh()
end

local function CreateMainFrame()
	local frame = CreateFrame("Frame", "EndeavoringFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(constants.FRAME_WIDTH, constants.FRAME_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetClampedToScreen(true)

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 8, 0)
	frame.title:SetText("Endeavoring")

	frame.header = ns.Header.Create(frame)
	CreateTabs(frame)
	frame:SetScript("OnShow", function()
		ns.API.RequestInitiativeInfo()
		RefreshInitiativeUI()
	end)

	frame:Hide()
	ns.ui.mainFrame = frame
	return frame
end

local function ToggleMainFrame()
	if not ns.ui.mainFrame then
		ns.ui.mainFrame = CreateMainFrame()
	end

	if ns.ui.mainFrame:IsShown() then
		ns.ui.mainFrame:Hide()
	else
		ns.ui.mainFrame:Show()
	end
end

ns.ToggleMainFrame = ToggleMainFrame
ns.RefreshInitiativeUI = RefreshInitiativeUI

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("NEIGHBORHOOD_INITIATIVE_UPDATED")
eventFrame:RegisterEvent("INITIATIVE_COMPLETED")
eventFrame:RegisterEvent("INITIATIVE_TASK_COMPLETED")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		local isLogin, isReload = ...
		
		-- Initialize database
		ns.DB.Init()
		
		-- Initialize sync service
		ns.AddonMessages.Init()
		ns.AddonMessages.RegisterListener()
		
		-- Register current character
		local success = ns.DB.RegisterCurrentCharacter()
		if success then
			-- Broadcast manifest on true login (not reload)
			if isLogin then
				ns.Coordinator.SendManifestDebounced()
			end
		end
		
		ns.Commands.Register()
		local integration = ns.Integrations.HousingDashboard
		if integration.EnsureLoaded() then
			integration.RegisterButtonHook()
		end
		return
	end

	if event == "ADDON_LOADED" then
		local integration = ns.Integrations.HousingDashboard
		local addonNameLoaded = ...
		if addonNameLoaded == integration.GetAddonName() and integration.EnsureLoaded() then
			integration.RegisterButtonHook()
		end
		return
	end

	if event == "NEIGHBORHOOD_INITIATIVE_UPDATED" or event == "INITIATIVE_COMPLETED" or event == "INITIATIVE_TASK_COMPLETED" then
		RefreshInitiativeUI()
	end
	
	if event == "GUILD_ROSTER_UPDATE" then
		-- Debounced broadcast on guild roster changes (with random delay)
		ns.Coordinator.OnGuildRosterUpdate()
	end
end)

--@alpha@
if not NDVRNG then
	NDVRNG = ns
else
	error("Namespace conflict: NDVRNG is already defined. Please ensure only one addon is using the NDVRNG namespace.")
end
--@end-alpha@
