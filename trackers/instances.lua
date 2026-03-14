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

    if shortSender ~= "" and me ~= "" then
        return shortSender == me
    end

    local lower = string.lower(msg)
    if string.find(lower, "^you receive") or string.find(lower, "you receive") then
        return true
    end

    if string.find(lower, " receives loot") or string.find(lower, " receives item") then
        return false
    end

    return false
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

local function IsTrackedRaid(instanceType)
    if instanceType ~= "raid" then
        return false
    end

    if not DT:IsGroupEnabled("raids_midnight_s1") then
        return false
    end

    return DT.SourceCatalog:IsGroupTrackable("raids_midnight_s1")
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
        return
    end

    if event == "ENCOUNTER_END" then
        local _, _, difficultyID, _, success = ...
        if success == 1 and difficultyID then
            self:RecordCurrentInstanceClear()
            local name, instanceType = GetInstanceInfo()
            if instanceType == "party" and name then
                BeginLootCapture(self, {
                    name = CanonicalDungeonName(name)
                })
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
        MaybeCaptureLoot(self, lootMessage, sender)
        return
    end

    if event == "UPDATE_INSTANCE_INFO" then
        self:ScanSavedInstances()
    end
end

DT:RegisterModule("InstanceTracker", InstanceTracker)
