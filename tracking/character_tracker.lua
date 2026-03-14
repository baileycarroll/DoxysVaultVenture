local _, DT = ...

DT.CharacterTracker = DT.CharacterTracker or {}

local UnitName = _G["UnitName"]
local GetRealmName = _G["GetRealmName"]
local UnitClass = _G["UnitClass"]
local GetServerTime = _G["GetServerTime"]
local fallbackTime = _G["time"]
local C_DateAndTime = _G["C_DateAndTime"]
local C_QuestLog = _G["C_QuestLog"]

local function NormalizeLootText(text)
    local value = tostring(text or "")
    value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
    value = value:gsub("|r", "")
    value = value:gsub("|Hitem:[^|]+|h%[([^%]]+)%]|h", "%1")
    value = value:gsub("|Hcurrency:[^|]+|h%[([^%]]+)%]|h", "%1")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    value = value:gsub("%s+", " ")
    return value
end

local function CharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    return string.format("%s-%s", name, realm)
end

local function ResetAt(secondsUntilReset)
    local now = GetServerTime and GetServerTime() or fallbackTime()
    return now + math.max(0, secondsUntilReset or 0)
end

function DT.CharacterTracker:Initialize(db)
    db.characters = db.characters or {}

    self.charKey = CharacterKey()
    db.characters[self.charKey] = db.characters[self.charKey] or {
        meta = {
            name = UnitName("player"),
            realm = GetRealmName(),
            class = select(2, UnitClass("player")),
            lastSeen = 0,
        },
        tracking = {
            dailyQuests       = {},
            weeklyQuests      = {},
            weeklyKnowledge   = {},
            dungeonClears     = {},
            raidClears        = {},
            mplusRuns         = {},
            weeklyDungeonLoot = {},
            knownDungeons     = {}, -- persists: every dungeon ever seen
            knownRaids        = {}, -- persists: every raid ever seen
            resetWindows      = {
                dailyAt = 0,
                weeklyAt = 0,
            },
        },
    }

    self.character = db.characters[self.charKey]
    self:Touch()
    self:RefreshResets(true)
end

function DT.CharacterTracker:Touch()
    if self.character and self.character.meta then
        self.character.meta.lastSeen = GetServerTime and GetServerTime() or fallbackTime()
    end
end

function DT.CharacterTracker:RefreshResets(force)
    if not self.character then
        return
    end

    local windows = self.character.tracking.resetWindows
    local now = GetServerTime and GetServerTime() or fallbackTime()

    local dailyRemaining = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset and
    C_DateAndTime.GetSecondsUntilDailyReset() or 0
    local weeklyRemaining = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and
    C_DateAndTime.GetSecondsUntilWeeklyReset() or 0

    if force or now >= (windows.dailyAt or 0) then
        self.character.tracking.dailyQuests = {}
        windows.dailyAt = ResetAt(dailyRemaining)
    end

    if force or now >= (windows.weeklyAt or 0) then
        self.character.tracking.weeklyQuests = {}
        self.character.tracking.weeklyKnowledge = {}
        self.character.tracking.dungeonClears = {}
        self.character.tracking.raidClears = {}
        self.character.tracking.mplusRuns = {}
        self.character.tracking.weeklyDungeonLoot = {}
        windows.weeklyAt = ResetAt(weeklyRemaining)
    end
end

function DT.CharacterTracker:MarkQuestCompletion(bucket, questID, title)
    self:RefreshResets(false)

    local store = self.character and self.character.tracking and self.character.tracking[bucket]
    if not store then
        return
    end

    local now = GetServerTime and GetServerTime() or fallbackTime()
    store[questID] = {
        title = title or (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)) or
        ("Quest " .. tostring(questID)),
        completedAt = now,
    }
end

function DT.CharacterTracker:MarkInstanceCompletion(bucket, instanceKey, payload)
    self:RefreshResets(false)

    local store = self.character and self.character.tracking and self.character.tracking[bucket]
    if not store then
        return
    end

    payload = payload or {}
    payload.completedAt = GetServerTime and GetServerTime() or fallbackTime()
    local existing = store[instanceKey]
    if existing then
        for k, v in pairs(existing) do
            if payload[k] == nil then
                payload[k] = v
            end
        end

        if payload.keyLevel and existing.keyLevel then
            payload.keyLevel = math.max(existing.keyLevel, payload.keyLevel)
        elseif existing.keyLevel and not payload.keyLevel then
            payload.keyLevel = existing.keyLevel
        end
    end

    store[instanceKey] = payload
end

function DT.CharacterTracker:GetCharacterData()
    return self.character
end

function DT.CharacterTracker:AddMPlusRun(dungeonName, payload)
    self:RefreshResets(false)
    if not self.character or not self.character.tracking then
        return nil
    end

    local canonicalName = dungeonName
    if DT.SourceCatalog and DT.SourceCatalog.GetCanonicalDungeonName then
        canonicalName = DT.SourceCatalog:GetCanonicalDungeonName(dungeonName)
    end

    local runsByDungeon = self.character.tracking.mplusRuns
    runsByDungeon[canonicalName] = runsByDungeon[canonicalName] or {}

    local run = payload or {}
    run.name = canonicalName
    run.completedAt = run.completedAt or (GetServerTime and GetServerTime() or fallbackTime())
    run.loot = run.loot or {}

    table.insert(runsByDungeon[canonicalName], run)
    return run
end

function DT.CharacterTracker:AddDungeonLoot(dungeonName, lootText, meta)
    local normalized = NormalizeLootText(lootText)
    if normalized == "" then
        return
    end

    self:RefreshResets(false)
    if not self.character or not self.character.tracking then
        return
    end

    local canonicalName = dungeonName
    if DT.SourceCatalog and DT.SourceCatalog.GetCanonicalDungeonName then
        canonicalName = DT.SourceCatalog:GetCanonicalDungeonName(dungeonName)
    end

    local bucket = self.character.tracking.weeklyDungeonLoot
    bucket[canonicalName] = bucket[canonicalName] or {}
    local existing = bucket[canonicalName]
    if #existing > 0 then
        local last = existing[#existing]
        if type(last) == "table" and last.text == normalized then
            return
        end
    end

    bucket[canonicalName][#bucket[canonicalName] + 1] = {
        text = normalized,
        addedAt = GetServerTime and GetServerTime() or fallbackTime(),
        source = meta,
    }
end

function DT.CharacterTracker:AddLootToRun(run, lootText)
    local normalized = NormalizeLootText(lootText)
    if not run or type(run) ~= "table" or normalized == "" then
        return
    end

    run.loot = run.loot or {}
    if #run.loot > 0 and run.loot[#run.loot] == normalized then
        return
    end

    run.loot[#run.loot + 1] = normalized

    local name = run.name
    if name then
        self:AddDungeonLoot(name, lootText, "mplus")
    end
end
