local _, DT = ...

local InstanceTracker = {}
DT.InstanceTracker = InstanceTracker

local GetInstanceInfo = _G["GetInstanceInfo"]
local RequestRaidInfo = _G["RequestRaidInfo"]
local GetNumSavedInstances = _G["GetNumSavedInstances"]
local GetSavedInstanceInfo = _G["GetSavedInstanceInfo"]
local GetDifficultyInfo = _G["GetDifficultyInfo"]
local GetServerTime = _G["GetServerTime"]
local fallbackTime = _G["time"]
local UnitName = _G["UnitName"]
local GetNumLootItems = _G["GetNumLootItems"]
local GetLootSlotType = _G["GetLootSlotType"]
local GetLootSlotLink = _G["GetLootSlotLink"]
local GetLootSlotInfo = _G["GetLootSlotInfo"]
local LOOT_SLOT_MONEY = _G["LOOT_SLOT_MONEY"]

local function InstanceSignature(name, difficultyID)
    return string.format("%s:%s", tostring(name), tostring(difficultyID))
end

local function FindDungeonGroup(instanceType, name, difficultyID)
    if instanceType ~= "party" then return nil end
    if not DT.SourceCatalog or not DT.SourceCatalog.FindGroupForInstance then return nil end
    return DT.SourceCatalog:FindGroupForInstance(name, difficultyID)
end

local function CanonicalDungeonName(name)
    if DT.SourceCatalog and DT.SourceCatalog.GetCanonicalDungeonName then
        return DT.SourceCatalog:GetCanonicalDungeonName(name)
    end
    return tostring(name or "Unknown")
end

local function Now()
    return GetServerTime and GetServerTime() or fallbackTime()
end

local function BeginLootCapture(self, run)
    if not run then
        self.activeLootRun = nil
        return
    end

    self.activeLootRun = {
        run = run,
        expiresAt = Now() + 120,
    }
end

local function IsLikelyPersonalLoot(message, sender)
    local msg = tostring(message or "")
    if msg == "" then
        return false
    end

    local me = tostring(UnitName and UnitName("player") or "")
    local shortSender = tostring(sender or "")
    shortSender = shortSender:gsub("%-.*$", "")

    if shortSender ~= "" and me ~= "" and shortSender == me then
        return true
    end

    local lower = string.lower(msg)
    if string.find(lower, "^you receive", 1, true)
        or string.find(lower, "^you loot", 1, true)
        or string.find(lower, "you receive", 1, true)
        or string.find(lower, "you loot", 1, true)
    then
        return true
    end

    if string.find(lower, " receives loot") or string.find(lower, " receives item") then
        return false
    end

    return false
end

local function IsLikelyPersonalMoney(message)
    local lower = string.lower(tostring(message or ""))
    if lower == "" then
        return false
    end

    return string.find(lower, "^you loot", 1, true) ~= nil
        or string.find(lower, "^you receive", 1, true) ~= nil
        or string.find(lower, "^you gain", 1, true) ~= nil
end

local function MaybeCaptureLoot(self, message, sender)
    if not self.activeLootRun or not self.activeLootRun.run then
        return
    end

    if not message or message == "" then
        return
    end

    if Now() > (self.activeLootRun.expiresAt or 0) then
        self.activeLootRun = nil
        return
    end

    if not IsLikelyPersonalLoot(message, sender) then
        return
    end

    if DT.CharacterTracker and DT.CharacterTracker.AddLootToRun then
        DT.CharacterTracker:AddLootToRun(self.activeLootRun.run, message)
    end
end

local function IsInLootContext(self)
    return (self and self.activeRaidSession) or (self and self.activeLootRun and self.activeLootRun.run)
end

local function CaptureLootText(self, text, source)
    local message = tostring(text or "")
    if message == "" then
        return
    end

    self.recentLootFingerprints = self.recentLootFingerprints or {}
    local contextKey = "none"
    if self.activeRaidSession and self.activeRaidSession.signature then
        contextKey = "raid:" .. tostring(self.activeRaidSession.signature)
    elseif self.activeLootRun and self.activeLootRun.run and self.activeLootRun.run.name then
        contextKey = "run:" .. tostring(self.activeLootRun.run.name)
    end

    local stamp = Now()
    local fingerprint = contextKey .. "|" .. message
    local lastAt = self.recentLootFingerprints[fingerprint]
    if lastAt and (stamp - lastAt) <= 2 then
        return
    end
    self.recentLootFingerprints[fingerprint] = stamp

    if self.activeRaidSession and DT.CharacterTracker and DT.CharacterTracker.AddRaidLoot then
        DT.CharacterTracker:AddRaidLoot(self.activeRaidSession, message, source or "raid")
        return
    end

    if self.activeLootRun and self.activeLootRun.run and DT.CharacterTracker and DT.CharacterTracker.AddLootToRun then
        DT.CharacterTracker:AddLootToRun(self.activeLootRun.run, message)
    end
end

local function CaptureLootFromSlots(self)
    if not IsInLootContext(self) then
        return
    end

    if not GetNumLootItems or not GetLootSlotType then
        return
    end

    local numSlots = tonumber(GetNumLootItems()) or 0
    if numSlots <= 0 then
        return
    end

    for slot = 1, numSlots do
        local slotType = GetLootSlotType(slot)
        if slotType == LOOT_SLOT_MONEY then
            local itemName, quantity
            if GetLootSlotInfo then
                local _, n, q = GetLootSlotInfo(slot)
                itemName = n
                quantity = q
            end
            local moneyText = tostring(itemName or "")
            if moneyText == "" and tonumber(quantity) and tonumber(quantity) > 0 then
                moneyText = string.format("You loot %dc", tonumber(quantity))
            end
            if moneyText ~= "" then
                CaptureLootText(self, moneyText, "loot_api_money")
            end
        else
            local link = GetLootSlotLink and GetLootSlotLink(slot)
            local itemName, quantity
            if GetLootSlotInfo then
                local _, n, q = GetLootSlotInfo(slot)
                itemName = n
                quantity = q
            end
            local text = tostring(link or itemName or "")
            local count = tonumber(quantity) or 1
            if text ~= "" then
                if count > 1 then
                    text = string.format("%s x%d", text, count)
                end
                CaptureLootText(self, text, "loot_api_item")
            end
        end
    end
end

local function IsTradeSystemMessage(message)
    local text = string.lower(tostring(message or ""))
    if text == "" then
        return false
    end
    return string.find(text, "you traded", 1, true) ~= nil
        or string.find(text, "you trade", 1, true) ~= nil
end

local function ExtractItemName(text)
    local s = tostring(text or "")
    local bracket = s:match("%[([^%]]+)%]")
    if bracket and bracket ~= "" then
        return bracket
    end
    return s
end

local function IsInstanceResetSystemMessage(message)
    local text = string.lower(tostring(message or ""))
    if text == "" then
        return false
    end

    return string.find(text, "has been reset", 1, true) ~= nil
        or string.find(text, "have been reset", 1, true) ~= nil
end

local function IsTrackedRaid(instanceType)
    if instanceType ~= "raid" then
        return false
    end

    return DT.SourceCatalog and DT.SourceCatalog.IsGroupTrackable and DT.SourceCatalog:IsGroupTrackable("raids_midnight_s1")
end

function InstanceTracker:RefreshRaidSession()
    local name, instanceType, difficultyID, difficultyName, _, _, _, mapID = GetInstanceInfo()
    if instanceType == "raid" and name and IsTrackedRaid("raid") then
        local sig = InstanceSignature(name, difficultyID)
        local existing = self.activeRaidSession
        if existing and existing.signature == sig then
            existing.mapID = mapID or existing.mapID
            existing.difficultyName = difficultyName or existing.difficultyName
            return
        end

        self.activeRaidSession = {
            signature = sig,
            name = name,
            difficultyID = difficultyID,
            difficultyName = difficultyName,
            mapID = mapID,
            startedAt = Now(),
        }
        return
    end

    self.activeRaidSession = nil
end

local function RecordKnown(knownBucket, sig, name, difficultyName, difficultyID)
    local char = DT.CharacterTracker:GetCharacterData()
    if not char then return end
    local store = char.tracking[knownBucket]
    if store and not store[sig] then
        store[sig] = { name = name, difficultyName = difficultyName, difficultyID = difficultyID }
    end
end

function InstanceTracker:RecordCurrentInstanceClear(keyLevel)
    if not DT.CharacterTracker then
        return
    end

    -- GetInstanceInfo: name, instanceType, difficultyID, difficultyName, maxPlayers, ..., instanceMapID
    local name, instanceType, difficultyID, difficultyName, _, _, _, mapID = GetInstanceInfo()
    if not name then
        return
    end

    local canonicalName = CanonicalDungeonName(name)
    local sig = InstanceSignature(canonicalName, difficultyID)
    local payload = {
        name           = canonicalName,
        difficultyID   = difficultyID,
        difficultyName = difficultyName,
        mapID          = mapID,
        keyLevel       = keyLevel,
    }

    local dungeonGroup = FindDungeonGroup(instanceType, canonicalName, difficultyID)
    if dungeonGroup then
        DT.CharacterTracker:MarkInstanceCompletion("dungeonClears", sig, payload)
        return
    end

    if IsTrackedRaid(instanceType) then
        RecordKnown("knownRaids", sig, name, difficultyName, difficultyID)
        DT.CharacterTracker:MarkInstanceCompletion("raidClears", sig, payload)
    end
end

function InstanceTracker:RequestSavedInstancesUpdate()
    if RequestRaidInfo then
        RequestRaidInfo()
    end
end

function InstanceTracker:ScanSavedInstances()
    if not DT.CharacterTracker then
        return
    end

    if not GetNumSavedInstances or not GetSavedInstanceInfo then
        return
    end

    local count = GetNumSavedInstances() or 0
    for i = 1, count do
        local name, lockoutID, reset, difficultyID, locked, extended, _, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress =
        GetSavedInstanceInfo(i)

        if (not difficultyName or difficultyName == "") and GetDifficultyInfo and difficultyID then
            difficultyName = GetDifficultyInfo(difficultyID)
        end

        if locked and name then
            local canonicalName = CanonicalDungeonName(name)
            local payload = {
                name = canonicalName,
                lockoutID = lockoutID,
                reset = reset,
                difficultyID = difficultyID,
                difficultyName = difficultyName,
                maxPlayers = maxPlayers,
                numEncounters = numEncounters,
                encounterProgress = encounterProgress,
                extended = extended,
                locked = locked,
                isRaid = isRaid,
            }

            local sig = InstanceSignature(canonicalName, difficultyID)
            if isRaid and IsTrackedRaid("raid") then
                RecordKnown("knownRaids", sig, canonicalName, difficultyName, difficultyID)
                DT.CharacterTracker:MarkInstanceCompletion("raidClears", sig, payload)
            elseif not isRaid then
                local dungeonGroup = FindDungeonGroup("party", canonicalName, difficultyID)
                if dungeonGroup then
                    RecordKnown("knownDungeons", sig, canonicalName, difficultyName, difficultyID)
                    DT.CharacterTracker:MarkInstanceCompletion("dungeonClears", sig, payload)
                end
            end
        end
    end
end

function InstanceTracker:RecordMPlusCompletion(level, completionTimeMS, timed)
    if not DT.CharacterTracker then
        return
    end

    local name, instanceType, difficultyID, difficultyName, _, _, _, mapID = GetInstanceInfo()
    if not name or instanceType ~= "party" then
        return
    end

    local canonicalName = CanonicalDungeonName(name)
    if not FindDungeonGroup("party", canonicalName, difficultyID) then
        return
    end

    local keyLevel = tonumber(level) or 0
    local timeMS = tonumber(completionTimeMS) or 0
    local wasTimed = (timed == true or timed == 1)

    local payload = {
        name = canonicalName,
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        mapID = mapID,
        keyLevel = keyLevel,
        completionTimeMS = timeMS,
        timed = wasTimed,
    }

    local sig = InstanceSignature(canonicalName, difficultyID)
    DT.CharacterTracker:MarkInstanceCompletion("dungeonClears", sig, payload)

    local run
    if DT.CharacterTracker.AddMPlusRun then
        run = DT.CharacterTracker:AddMPlusRun(canonicalName, {
            keyLevel = keyLevel,
            completionTimeMS = timeMS,
            timed = wasTimed,
            mapID = mapID,
            difficultyID = difficultyID,
            difficultyName = difficultyName,
        })
    end
    BeginLootCapture(self, run)
end

function InstanceTracker:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        self:RequestSavedInstancesUpdate()
        self:RefreshRaidSession()
        return
    end

    if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        self:RefreshRaidSession()
        return
    end

    if event == "ENCOUNTER_END" then
        local encounterID, encounterName, difficultyID, _, success = ...
        if success == 1 and difficultyID then
            self:RecordCurrentInstanceClear()
            local name, instanceType = GetInstanceInfo()
            if instanceType == "party" and name then
                BeginLootCapture(self, {
                    name = CanonicalDungeonName(name)
                })
            elseif instanceType == "raid" then
                self:RefreshRaidSession()
                if self.activeRaidSession and DT.CharacterTracker and DT.CharacterTracker.AddRaidBossKill then
                    DT.CharacterTracker:AddRaidBossKill(self.activeRaidSession, {
                        encounterID = encounterID,
                        encounterName = encounterName,
                    })
                end
            else
                BeginLootCapture(self, nil)
            end
        end
        return
    end

    if event == "CHALLENGE_MODE_COMPLETED" then
        local _, level, completionTimeMS, timed = ...
        self:RecordCurrentInstanceClear(level)
        self:RecordMPlusCompletion(level, completionTimeMS, timed)
        return
    end

    if event == "CHAT_MSG_LOOT" then
        local lootMessage, sender = ...
        if self.activeRaidSession then
            if IsLikelyPersonalLoot(lootMessage, sender)
                and not IsTradeSystemMessage(lootMessage)
                and DT.CharacterTracker
                and DT.CharacterTracker.AddRaidLoot
            then
                CaptureLootText(self, lootMessage, "raid_chat")
            end
            return
        end

        MaybeCaptureLoot(self, lootMessage, sender)
        return
    end

    if event == "CHAT_MSG_MONEY" then
        local moneyMessage = ...
        if not IsLikelyPersonalMoney(moneyMessage) then
            return
        end

        if self.activeRaidSession and DT.CharacterTracker and DT.CharacterTracker.AddRaidLoot then
            CaptureLootText(self, moneyMessage, "raid_money_chat")
            return
        end

        MaybeCaptureLoot(self, moneyMessage, UnitName and UnitName("player") or nil)
        return
    end

    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        self:RefreshRaidSession()
        CaptureLootFromSlots(self)
        return
    end

    if event == "CHAT_MSG_SYSTEM" then
        local text = ...
        local shouldClearLoot = DT and DT.db and DT.db.settings and DT.db.settings.clearLootOnInstanceReset == true
        if shouldClearLoot and IsInstanceResetSystemMessage(text)
            and DT.CharacterTracker
            and DT.CharacterTracker.ClearRecordedLoot
        then
            DT.CharacterTracker:ClearRecordedLoot()
            if DT.Print then
                DT:Print("Recorded loot cleared due to instance reset.")
            end
            if DT.TrackerFrame and DT.TrackerFrame.Refresh then
                DT.TrackerFrame:Refresh()
            end
        end

        if self.activeRaidSession and IsTradeSystemMessage(text)
            and DT.CharacterTracker
            and DT.CharacterTracker.RemoveRaidLootByText
        then
            local itemText = ExtractItemName(text)
            DT.CharacterTracker:RemoveRaidLootByText(self.activeRaidSession, itemText)
        end
        return
    end

    if event == "UPDATE_INSTANCE_INFO" then
        self:ScanSavedInstances()
    end
end

DT:RegisterModule("InstanceTracker", InstanceTracker)
