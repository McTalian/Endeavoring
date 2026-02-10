---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)

local Integration = {}
ns.Integrations = ns.Integrations or {}
ns.Integrations.HousingDashboard = Integration

local ADDON_NAME = "Blizzard_HousingDashboard"

function Integration.GetAddonName()
	return ADDON_NAME
end

function Integration.EnsureLoaded()
	if _G.HousingDashboardFrame then
		return true
	end

	if C_AddOns and C_AddOns.LoadAddOn then
		C_AddOns.LoadAddOn(ADDON_NAME)
	end

	return _G.HousingDashboardFrame ~= nil
end

local function TryAddButton()
	if ns.ui.housingButton then
		return
	end

	local parent = _G.HousingDashboardFrame
	if not parent then
		return
	end

	local initiativesFrame = parent.HouseInfoContent
		and parent.HouseInfoContent.ContentFrame
		and parent.HouseInfoContent.ContentFrame.InitiativesFrame

	local timerAnchor = initiativesFrame
		and initiativesFrame.InitiativeSetFrame
		and initiativesFrame.InitiativeSetFrame.InitiativeTimer
	local buttonParent = initiativesFrame or parent
	local button = CreateFrame("Button", "EndeavoringButton", buttonParent, "UIPanelButtonTemplate")
	button:SetFrameLevel(200)
	button:SetSize(140, 22)
	button:SetText("Endeavoring")
	button:SetScript("OnClick", function()
		if ns.ToggleMainFrame then
			ns.ToggleMainFrame()
		end
	end)

	if timerAnchor then
		button:SetPoint("RIGHT", timerAnchor, "LEFT", -8, 0)
	else
		button:SetPoint("TOPRIGHT", buttonParent, "TOPRIGHT", -40, -42)
	end

	ns.ui.housingButton = button
end

function Integration.RegisterButtonHook()
	local attempt = 0
	local function TryAttach()
		attempt = attempt + 1
		TryAddButton()
		if ns.ui.housingButton then
			return
		end
		if attempt < 10 then
			C_Timer.After(1, TryAttach)
		end
	end

	TryAttach()
end
