---@type string
local addonName = select(1, ...)
---@class Ndvrng_NS
local ns = select(2, ...)

local API = {}
ns.API = API

local DebugPrint = ns.DebugPrint

function API.GetInitiativeInfo()
	if C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo then
		return C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
	end

	return nil
end

local RequestInitiativeInfoThrottled = false

function API.RequestInitiativeInfo()
	if RequestInitiativeInfoThrottled then
		DebugPrint("RequestInitiativeInfo is currently throttled, skipping request to prevent spamming")
		return
	end
	RequestInitiativeInfoThrottled = true
	C_Timer.After(10, function()
		RequestInitiativeInfoThrottled = false
	end)
	if C_NeighborhoodInitiative and C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo then
		C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
	end
end

function API.GetQuestRewardHouseXp(rewardQuestID)
	if not rewardQuestID or rewardQuestID == 0 then
		return nil
	end

	if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestLogRewardFavor then
		local ok, favor = pcall(C_QuestInfoSystem.GetQuestLogRewardFavor, rewardQuestID, 1)
		if ok and favor then
			return favor
		end
		ok, favor = pcall(C_QuestInfoSystem.GetQuestLogRewardFavor, rewardQuestID)
		if ok and favor then
			return favor
		end
	end

	return nil
end

function API.FormatTimeRemaining(durationSeconds)
	local fallback = ns.Constants.TIME_REMAINING_FALLBACK or "Time Remaining: --"
	if durationSeconds and durationSeconds > 0 then
		local timeLeftStr = SecondsToTime(durationSeconds, false, true, 1)
		if HOUSING_DASHBOARD_TIME_REMAINING then
			return HOUSING_DASHBOARD_TIME_REMAINING:format(timeLeftStr)
		end
		return "Time Remaining: " .. timeLeftStr
	end

	return fallback
end

function API.GetActivityLogInfo()
	if C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetInitiativeActivityLogInfo then
		return C_NeighborhoodInitiative.GetInitiativeActivityLogInfo()
	end

	return nil
end

local RequestActivityLogThrottled = false

function API.RequestActivityLog()
	if RequestActivityLogThrottled then
		DebugPrint("RequestActivityLog is currently throttled, skipping request to prevent spamming")
		return
	end
	RequestActivityLogThrottled = true
	C_Timer.After(10, function()
		RequestActivityLogThrottled = false
	end)
	if C_NeighborhoodInitiative and C_NeighborhoodInitiative.RequestInitiativeActivityLog then
		C_NeighborhoodInitiative.RequestInitiativeActivityLog()
		ns.Integrations.HousingDashboardHouseContent.TryForceActivityLoad()
	end
end
