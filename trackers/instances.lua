local _, DT = ...

local InstanceTracker = {}
DT.InstanceTracker = InstanceTracker

local GetInstanceInfo = _G["GetInstanceInfo"]
local RequestRaidInfo = _G["RequestRaidInfo"]
local GetNumSavedInstances = _G["GetNumSavedInstances"]
local GetSavedInstanceInfo = _G["GetSavedInstanceInfo"]
local GetDifficultyInfo = _G["GetDifficultyInfo"]

local function InstanceSignature(name, difficultyID)
    return string.format("%s:%s", tostring(name), tostring(difficultyID))
end

local function FindDungeonGroup(instanceType, name, difficultyID)
    if instanceType ~= "party" then return nil end
    if not DT.SourceCatalog or not DT.SourceCatalog.FindGroupForInstance then return nil end
    return DT.SourceCatalog:FindGroupForInstance(name, difficultyID)
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

    local sig = InstanceSignature(name, difficultyID)
    local payload = {
        name           = name,
        difficultyID   = difficultyID,
        difficultyName = difficultyName,
        mapID          = mapID,
        keyLevel       = keyLevel,
    }

    local dungeonGroup = FindDungeonGroup(instanceType, name, difficultyID)
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
        local name, lockoutID, reset, difficultyID, locked, extended, _, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i)

        if (not difficultyName or difficultyName == "") and GetDifficultyInfo and difficultyID then
            difficultyName = GetDifficultyInfo(difficultyID)
        end

        if locked and name then
            local payload = {
                name = name,
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

            local sig = InstanceSignature(name, difficultyID)
            if isRaid and IsTrackedRaid("raid") then
                RecordKnown("knownRaids",    sig, name, difficultyName, difficultyID)
                DT.CharacterTracker:MarkInstanceCompletion("raidClears", sig, payload)
            elseif not isRaid then
                local dungeonGroup = FindDungeonGroup("party", name, difficultyID)
                if dungeonGroup then
                    RecordKnown("knownDungeons", sig, name, difficultyName, difficultyID)
                    DT.CharacterTracker:MarkInstanceCompletion("dungeonClears", sig, payload)
                end
            end
        end
    end
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
        end
        return
    end

    if event == "CHALLENGE_MODE_COMPLETED" then
        local _, level = ...
        self:RecordCurrentInstanceClear(level)
        return
    end

    if event == "UPDATE_INSTANCE_INFO" then
        self:ScanSavedInstances()
    end
end

DT:RegisterModule("InstanceTracker", InstanceTracker)
