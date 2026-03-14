local _, DT = ...

local QuestTracker = {}
DT.QuestTracker = QuestTracker

local C_QuestLog = _G["C_QuestLog"]
local EnumTable = _G["Enum"]
local DAILY_FREQUENCY = _G["LE_QUEST_FREQUENCY_DAILY"] or (EnumTable and EnumTable.QuestFrequency and EnumTable.QuestFrequency.Daily)
local WEEKLY_FREQUENCY = _G["LE_QUEST_FREQUENCY_WEEKLY"] or (EnumTable and EnumTable.QuestFrequency and EnumTable.QuestFrequency.Weekly)

QuestTracker.knownDaily  = {}
QuestTracker.knownWeekly = {}

local scanPending = false
local C_Timer = _G["C_Timer"]

function QuestTracker:ScanQuestLog()
    self.knownDaily  = {}
    self.knownWeekly = {}

    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then
        return
    end

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and info.questID > 0 then
            if info.frequency == DAILY_FREQUENCY then
                self.knownDaily[info.questID]  = { title = info.title or ("Quest " .. info.questID) }
            elseif info.frequency == WEEKLY_FREQUENCY then
                self.knownWeekly[info.questID] = { title = info.title or ("Quest " .. info.questID) }
            end
        end
    end

    if DT.TrackerFrame then
        DT.TrackerFrame:Refresh()
    end
end

function QuestTracker:RequestScan()
    if scanPending then return end
    scanPending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            scanPending = false
            QuestTracker:ScanQuestLog()
        end)
    else
        scanPending = false
        self:ScanQuestLog()
    end
end

local function QuestTitle(questID)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        return C_QuestLog.GetTitleForQuestID(questID)
    end
    return nil
end

local function QuestFrequency(questID)
    if not C_QuestLog or not C_QuestLog.GetLogIndexForQuestID or not C_QuestLog.GetInfo then
        return nil
    end

    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    if not logIndex or logIndex <= 0 then
        return nil
    end

    local info = C_QuestLog.GetInfo(logIndex)
    return info and info.frequency or nil
end

local function IsDaily(questID)
    return QuestFrequency(questID) == DAILY_FREQUENCY
end

local function IsWeekly(questID)
    if DT.SourceCatalog and DT.SourceCatalog:IsKnownWeeklyKnowledgeQuest(questID) then
        return true
    end
    return QuestFrequency(questID) == WEEKLY_FREQUENCY
end

function QuestTracker:HandleQuestTurnIn(questID)
    if not questID or not DT.CharacterTracker then
        return
    end

    local title = QuestTitle(questID)

    if DT:IsGroupEnabled("quests_daily") and DT.SourceCatalog:IsGroupTrackable("quests_daily") and IsDaily(questID) then
        DT.CharacterTracker:MarkQuestCompletion("dailyQuests", questID, title)
    end

    if DT:IsGroupEnabled("quests_weekly") and DT.SourceCatalog:IsGroupTrackable("quests_weekly") and IsWeekly(questID) then
        DT.CharacterTracker:MarkQuestCompletion("weeklyQuests", questID, title)
    end

    if DT:IsGroupEnabled("knowledge_weekly") and DT.SourceCatalog:IsGroupTrackable("knowledge_weekly") and DT.SourceCatalog:IsKnownWeeklyKnowledgeQuest(questID) then
        DT.CharacterTracker:MarkQuestCompletion("weeklyKnowledge", questID, title)
    end
end

function QuestTracker:OnEvent(event, ...)
    if event == "QUEST_TURNED_IN" then
        local questID = ...
        self:HandleQuestTurnIn(questID)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "QUEST_LOG_UPDATE" then
        self:RequestScan()
        return
    end

    if event == "PLAYER_LOGIN" and DT.CharacterTracker then
        DT.CharacterTracker:RefreshResets(false)
    end
end

DT:RegisterModule("QuestTracker", QuestTracker)
