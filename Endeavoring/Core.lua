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
	ns.Leaderboard.Refresh()
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
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 8, 0)
	frame.title:SetText("Endeavoring")

	frame.header = ns.Header.Create(frame)
	InitializeTabSystem(frame)
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
