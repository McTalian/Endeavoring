---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)

local Integration = {}
ns.Integrations = ns.Integrations or {}
ns.Integrations.HousingDashboardHouseContent = Integration

function Integration.EnsureLoaded()
  if _G.HousingDashboardFrame and _G.HousingDashboardFrame.HouseInfoContent then
    return true
  end

  return ns.Integrations.HousingDashboard.EnsureLoaded() and _G.HousingDashboardFrame and _G.HousingDashboardFrame.HouseInfoContent ~= nil
end

function Integration.TryForceActivityLoad()
  if not Integration.EnsureLoaded() then
    return false
  end

  local housingDash = _G.HousingDashboardFrame
  local content = housingDash and housingDash.HouseInfoContent
  local contentFrame = content and content.ContentFrame
  local endeavorTabID = contentFrame and contentFrame.endeavorTabID
  if endeavorTabID then
    if housingDash:IsShown() then
      local tab = contentFrame:GetTab()
      contentFrame:SetTab(endeavorTabID)
      contentFrame:SetTab(tab)
    else
      housingDash:Show()
      contentFrame:SetTab(endeavorTabID)
      housingDash:Hide()
    end
  end

  return false
end

