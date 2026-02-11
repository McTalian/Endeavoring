---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)

local constants = ns.Constants

local DebugPrint = ns.DebugPrint

local function InitializeTabSystem(frame)
	-- Apply TabSystemOwnerMixin to main frame
	Mixin(frame, TabSystemOwnerMixin)
	TabSystemOwnerMixin.OnLoad(frame)
	
	-- Create TabSystem child frame programmatically
	local tabSystem = CreateFrame("Frame", nil, frame, "HorizontalLayoutFrame")
	Mixin(tabSystem, TabSystemMixin)
	
	-- Configure TabSystem properties BEFORE OnLoad (used during initialization)
	tabSystem.minTabWidth = 100
	tabSystem.maxTabWidth = 150
	tabSystem.tabTemplate = "TabSystemTopButtonTemplate"
	tabSystem.spacing = 1
	tabSystem.tabSelectSound = SOUNDKIT.IG_CHARACTER_INFO_TAB
	
	-- Initialize TabSystem (creates frame pool with tabTemplate)
	tabSystem:OnLoad()
	
	-- Position TabSystem below header (hanging off top)
	tabSystem:SetPoint("BOTTOMLEFT", frame.header, "BOTTOMLEFT", 8, -2)
	
	-- Link TabSystem to frame
	frame.TabSystem = tabSystem
	frame:SetTabSystem(tabSystem)
	
	-- Register tabs with their content frames
	frame.tasksTabID = frame:AddNamedTab("Tasks", ns.Tasks.CreateTab(frame))
	frame.leaderboardTabID = frame:AddNamedTab("Leaderboard", ns.Leaderboard.CreateTab(frame))
	
	-- Set initial tab
	frame:SetTab(frame.tasksTabID, false)
end

local function RefreshInitiativeUI()
	ns.Header.Refresh()
	ns.Tasks.Refresh()
end

local function CreateMainFrame()
	-- TODO: Use PortraitFrameTemplate

	local frame = CreateFrame("Frame", "EndeavoringFrame", UIParent, "PortraitFrameTemplate")
	frame.TitleContainer.TitleText:SetText(addonName)
	frame:SetPortraitToAsset("Interface/AddOns/Endeavoring/Icons/endeavoring_panel_portrait.png")
	frame:SetSize(constants.FRAME_WIDTH, constants.FRAME_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)

	frame.header = ns.Header.Create(frame)
	InitializeTabSystem(frame)
	frame:SetScript("OnShow", function()
		ns.API.RequestInitiativeInfo()
		ns.API.RequestActivityLog()
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
eventFrame:RegisterEvent("PLAYER_HOUSE_LIST_UPDATED")
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
		local housingDash = ns.Integrations.HousingDashboard
		if housingDash.EnsureLoaded() then
			housingDash.RegisterButtonHook()
		end
		
		-- Request housing data first (required for initiative system)
		ns.API.RequestPlayerHouses()
		return
	end

	if event == "ADDON_LOADED" then
		local housingDash = ns.Integrations.HousingDashboard
		local addonNameLoaded = ...
		if addonNameLoaded == housingDash.GetAddonName() and housingDash.EnsureLoaded() then
			housingDash.RegisterButtonHook()
		end
		return
	end

	if event == "PLAYER_HOUSE_LIST_UPDATED" then
		-- House list loaded, now request initiative info
		ns.API.RequestInitiativeInfo()
		return
	end

	if event == "NEIGHBORHOOD_INITIATIVE_UPDATED" then
		-- Initiative data has loaded/updated, refresh UI
		RefreshInitiativeUI()
		return
	end

	if event == "INITIATIVE_COMPLETED" or event == "INITIATIVE_TASK_COMPLETED" then
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
