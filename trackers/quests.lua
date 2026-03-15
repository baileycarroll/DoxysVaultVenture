local _, DT              = ...

local QuestTracker       = {}
DT.QuestTracker          = QuestTracker

local C_QuestLog         = _G["C_QuestLog"]
local C_Map              = _G["C_Map"]
local EnumTable          = _G["Enum"]
local UnitName           = _G["UnitName"]
local GetRealZoneText    = _G["GetRealZoneText"]
local DAILY_FREQUENCY    = _G["LE_QUEST_FREQUENCY_DAILY"] or
(EnumTable and EnumTable.QuestFrequency and EnumTable.QuestFrequency.Daily)
local WEEKLY_FREQUENCY   = _G["LE_QUEST_FREQUENCY_WEEKLY"] or
(EnumTable and EnumTable.QuestFrequency and EnumTable.QuestFrequency.Weekly)

QuestTracker.knownDaily  = {}
QuestTracker.knownWeekly = {}

local scanPending        = false
local C_Timer            = _G["C_Timer"]

local function PlayerLocationSnapshot()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then
        return nil, nil, nil, nil
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return nil, nil, nil, nil
    end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y
    if pos and pos.GetXY then
        x, y = pos:GetXY()
    end

    return mapID, x, y, (GetRealZoneText and GetRealZoneText() or nil)
end

local function QuestWaypointSnapshot(questID)
    if C_QuestLog and C_QuestLog.GetNextWaypoint then
        local mapID, x, y = C_QuestLog.GetNextWaypoint(questID)
        if type(mapID) == "number" and mapID > 0 and type(x) == "number" and type(y) == "number" then
            return mapID, x, y
        end
    end

    return nil, nil, nil
end

function QuestTracker:ScanQuestLog()
    self.knownDaily  = (DT.SourceCatalog and DT.SourceCatalog.GetKnownDailyQuestMap and DT.SourceCatalog:GetKnownDailyQuestMap()) or
    {}
    self.knownWeekly = (DT.SourceCatalog and DT.SourceCatalog.GetKnownWeeklyQuestMap and DT.SourceCatalog:GetKnownWeeklyQuestMap()) or {}

    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then
        return
    end

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and info.questID > 0 then
            if info.frequency == DAILY_FREQUENCY or (DT.SourceCatalog and DT.SourceCatalog.IsKnownDailyQuest and DT.SourceCatalog:IsKnownDailyQuest(info.questID)) then
                local zone = DT.SourceCatalog and DT.SourceCatalog.GetQuestZoneText and DT.SourceCatalog:GetQuestZoneText(info.questID)
                local mapID = info.questMapID or info.mapID or
                    (DT.SourceCatalog and DT.SourceCatalog.GetQuestMapID and DT.SourceCatalog:GetQuestMapID(info.questID))
                local wpMapID, wpX, wpY = QuestWaypointSnapshot(info.questID)
                if not mapID then
                    mapID = wpMapID
                end
                self.knownDaily[info.questID] = {
                    title = info.title or ("Quest " .. info.questID),
                    zone = zone,
                    mapID = mapID,
                    x = wpX,
                    y = wpY,
                }

                local npc = self.pendingQuestGiver and self.pendingQuestGiver.name or nil
                local pMapID, pX, pY, pZone = PlayerLocationSnapshot()
                if not zone then zone = pZone end
                if not mapID then mapID = pMapID end

                if DT.SourceCatalog and DT.SourceCatalog.RecordDiscoveredDailyQuestMeta then
                    local isNew = DT.SourceCatalog:RecordDiscoveredDailyQuestMeta(info.questID, {
                        title = info.title,
                        zone = zone,
                        mapID = mapID,
                        npc = npc,
                        x = wpX or pX,
                        y = wpY or pY,
                    })
                    if isNew and DT.Print then
                        DT:Print(string.format("Discovered daily quest: %s (%d)", info.title or ("Quest " .. info.questID), info.questID))
                    end
                end
            elseif info.frequency == WEEKLY_FREQUENCY then
                local zone = DT.SourceCatalog and DT.SourceCatalog.GetQuestZoneText and DT.SourceCatalog:GetQuestZoneText(info.questID)
                local mapID = info.questMapID or info.mapID or
                    (DT.SourceCatalog and DT.SourceCatalog.GetQuestMapID and DT.SourceCatalog:GetQuestMapID(info.questID))
                local wpMapID, wpX, wpY = QuestWaypointSnapshot(info.questID)
                if not mapID then
                    mapID = wpMapID
                end

                self.knownWeekly[info.questID] = {
                    title = info.title or ("Quest " .. info.questID),
                    zone = zone,
                    mapID = mapID,
                    x = wpX,
                    y = wpY,
                }

                local npc = self.pendingQuestGiver and self.pendingQuestGiver.name or nil
                local pMapID, pX, pY, pZone = PlayerLocationSnapshot()
                if not zone then zone = pZone end
                if not mapID then mapID = pMapID end

                if DT.SourceCatalog and DT.SourceCatalog.RecordDiscoveredWeeklyQuestMeta then
                    local isNew = DT.SourceCatalog:RecordDiscoveredWeeklyQuestMeta(info.questID, {
                        title = info.title,
                        zone = zone,
                        mapID = mapID,
                        npc = npc,
                        x = wpX or pX,
                        y = wpY or pY,
                    })
                    if isNew and DT.Print then
                        DT:Print(string.format("Discovered weekly quest: %s (%d)", info.title or ("Quest " .. info.questID), info.questID))
                    end
                end
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
    if DT.SourceCatalog and DT.SourceCatalog.IsKnownDailyQuest and DT.SourceCatalog:IsKnownDailyQuest(questID) then
        return true
    end
    return QuestFrequency(questID) == DAILY_FREQUENCY
end

local function IsWeekly(questID)
    if DT.SourceCatalog and DT.SourceCatalog:IsKnownWeeklyKnowledgeQuest(questID) then
        return true
    end
    if DT.SourceCatalog and DT.SourceCatalog.IsKnownWeeklyQuest and DT.SourceCatalog:IsKnownWeeklyQuest(questID) then
        return true
    end
    return QuestFrequency(questID) == WEEKLY_FREQUENCY
end

function QuestTracker:HandleQuestDiscovered(questID)
    if not questID then
        return
    end

    local title = QuestTitle(questID)
    local zone = DT.SourceCatalog and DT.SourceCatalog.GetQuestZoneText and DT.SourceCatalog:GetQuestZoneText(questID)
    local mapID = DT.SourceCatalog and DT.SourceCatalog.GetQuestMapID and DT.SourceCatalog:GetQuestMapID(questID)
    local wpMapID, wpX, wpY = QuestWaypointSnapshot(questID)
    if not mapID then
        mapID = wpMapID
    end

    local pMapID, pX, pY, pZone = PlayerLocationSnapshot()
    local pending = self.pendingQuestGiver or {}
    local npc = pending.name
    if not zone then zone = pending.zone or pZone end
    if not mapID then mapID = pending.mapID or pMapID end

    if (IsDaily(questID) or (DT.SourceCatalog and DT.SourceCatalog.IsKnownDailyQuest and DT.SourceCatalog:IsKnownDailyQuest(questID))) then
        self.knownDaily = self.knownDaily or {}
        self.knownDaily[questID] = self.knownDaily[questID] or {}
        self.knownDaily[questID].title = title or self.knownDaily[questID].title or ("Quest " .. tostring(questID))
        self.knownDaily[questID].zone = zone or self.knownDaily[questID].zone
        self.knownDaily[questID].mapID = mapID or self.knownDaily[questID].mapID
        self.knownDaily[questID].npc = npc or self.knownDaily[questID].npc
        self.knownDaily[questID].x = wpX or pending.x or pX or self.knownDaily[questID].x
        self.knownDaily[questID].y = wpY or pending.y or pY or self.knownDaily[questID].y

        if DT.SourceCatalog and DT.SourceCatalog.RecordDiscoveredDailyQuestMeta then
            DT.SourceCatalog:RecordDiscoveredDailyQuestMeta(questID, {
                title = title,
                zone = zone,
                mapID = mapID,
                npc = npc,
                x = wpX or pending.x or pX,
                y = wpY or pending.y or pY,
            })
        end
    end

    if IsWeekly(questID) then
        self.knownWeekly = self.knownWeekly or {}
        self.knownWeekly[questID] = self.knownWeekly[questID] or {}
        self.knownWeekly[questID].title = title or self.knownWeekly[questID].title or ("Quest " .. tostring(questID))
        self.knownWeekly[questID].zone = zone or self.knownWeekly[questID].zone
        self.knownWeekly[questID].mapID = mapID or self.knownWeekly[questID].mapID
        self.knownWeekly[questID].npc = npc or self.knownWeekly[questID].npc
        self.knownWeekly[questID].x = wpX or pending.x or pX or self.knownWeekly[questID].x
        self.knownWeekly[questID].y = wpY or pending.y or pY or self.knownWeekly[questID].y

        if DT.SourceCatalog and DT.SourceCatalog.RecordDiscoveredWeeklyQuestMeta then
            DT.SourceCatalog:RecordDiscoveredWeeklyQuestMeta(questID, {
                title = title,
                zone = zone,
                mapID = mapID,
                npc = npc,
                x = wpX or pending.x or pX,
                y = wpY or pending.y or pY,
            })
        end
    end

    if DT.TrackerFrame then
        DT.TrackerFrame:Refresh()
    end
end

function QuestTracker:HandleQuestTurnIn(questID)
    if not questID or not DT.CharacterTracker then
        return
    end

    local title = QuestTitle(questID)
    local zone = DT.SourceCatalog and DT.SourceCatalog.GetQuestZoneText and DT.SourceCatalog:GetQuestZoneText(questID)
    local mapID = DT.SourceCatalog and DT.SourceCatalog.GetQuestMapID and DT.SourceCatalog:GetQuestMapID(questID)
    local wpMapID, wpX, wpY = QuestWaypointSnapshot(questID)
    if not mapID then
        mapID = wpMapID
    end
    local pMapID, pX, pY, pZone = PlayerLocationSnapshot()
    local npc = self.pendingQuestGiver and self.pendingQuestGiver.name or nil
    if not zone then zone = pZone end
    if not mapID then mapID = pMapID end

    if DT:IsGroupEnabled("quests_daily") and DT.SourceCatalog:IsGroupTrackable("quests_daily") and IsDaily(questID) then
        DT.CharacterTracker:MarkQuestCompletion("dailyQuests", questID, title)
        local store = self.knownDaily or {}
        store[questID] = store[questID] or {}
        store[questID].title = title or store[questID].title or ("Quest " .. tostring(questID))
        store[questID].zone = zone or store[questID].zone
        store[questID].mapID = mapID or store[questID].mapID
        self.knownDaily = store

        if DT.SourceCatalog and DT.SourceCatalog.RecordDiscoveredDailyQuestMeta then
            local isNew = DT.SourceCatalog:RecordDiscoveredDailyQuestMeta(questID, {
                title = title,
                zone = zone,
                mapID = mapID,
                npc = npc,
                x = wpX or pX,
                y = wpY or pY,
            })
            if isNew and DT.Print then
                DT:Print(string.format("Discovered daily quest: %s (%d)", title or ("Quest " .. questID), questID))
            end
        end
    end

    if DT:IsGroupEnabled("quests_weekly") and DT.SourceCatalog:IsGroupTrackable("quests_weekly") and IsWeekly(questID) then
        DT.CharacterTracker:MarkQuestCompletion("weeklyQuests", questID, title)

        if DT.SourceCatalog and DT.SourceCatalog.RecordDiscoveredWeeklyQuestMeta then
            local isNew = DT.SourceCatalog:RecordDiscoveredWeeklyQuestMeta(questID, {
                title = title,
                zone = zone,
                mapID = mapID,
                npc = npc,
                x = wpX or pX,
                y = wpY or pY,
            })
            if isNew and DT.Print then
                DT:Print(string.format("Discovered weekly quest: %s (%d)", title or ("Quest " .. questID), questID))
            end
        end
    end

    if DT:IsGroupEnabled("knowledge_weekly") and DT.SourceCatalog:IsGroupTrackable("knowledge_weekly") and DT.SourceCatalog:IsKnownWeeklyKnowledgeQuest(questID) then
        DT.CharacterTracker:MarkQuestCompletion("weeklyKnowledge", questID, title)
    end
end

function QuestTracker:OnEvent(event, ...)
    if event == "QUEST_DETAIL" then
        local pMapID, pX, pY, pZone = PlayerLocationSnapshot()
        self.pendingQuestGiver = {
            name = UnitName and UnitName("npc") or nil,
            mapID = pMapID,
            x = pX,
            y = pY,
            zone = pZone,
        }
        return
    end

    if event == "QUEST_ACCEPTED" then
        local _, questID = ...
        if questID then
            self:HandleQuestDiscovered(questID)
        end
        self.pendingQuestGiver = nil
        return
    end

    if event == "QUEST_TURNED_IN" then
        local questID = ...
        self:HandleQuestTurnIn(questID)
        self.pendingQuestGiver = nil
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
