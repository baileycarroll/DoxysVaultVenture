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

local function ExtractLootMeta(rawText, normalizedText)
    local raw = tostring(rawText or "")
    local normalized = tostring(normalizedText or "")

    local itemString = raw:match("|H(item:[^|]+)|h")
    local itemName = raw:match("|h%[([^%]]+)%]|h") or normalized:match("%[([^%]]+)%]")
    local quantity = tonumber(raw:match("[xX](%d+)%f[^%d]"))
        or tonumber(normalized:match("[xX](%d+)%f[^%d]"))
        or tonumber(raw:match("(%d+)%s*[xX]%f[^%a]"))
        or tonumber(normalized:match("(%d+)%s*[xX]%f[^%a]"))
        or 1

    local itemLink
    if itemString and itemName then
        itemLink = string.format("|H%s|h[%s]|h", itemString, itemName)
    end

    return {
        itemName = itemName,
        itemLink = itemLink,
        quantity = quantity,
        rawText = raw,
    }
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
            dailyQuests         = {},
            weeklyQuests        = {},
            weeklyKnowledge     = {},
            dungeonClears       = {},
            raidClears          = {},
            weeklyRaidBossKills = {},
            weeklyRaidLoot      = {},
            mplusRuns           = {},
            weeklyDungeonLoot   = {},
            knownDungeons       = {}, -- persists: every dungeon ever seen
            knownRaids          = {}, -- persists: every raid ever seen
            resetWindows        = {
                dailyAt = 0,
                weeklyAt = 0,
            },
        },
    }

    self.character = db.characters[self.charKey]
    self:Touch()
    self:RefreshResets(false)
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
        self.character.tracking.weeklyRaidBossKills = {}
        self.character.tracking.weeklyRaidLoot = {}
        self.character.tracking.mplusRuns = {}
        self.character.tracking.weeklyDungeonLoot = {}
        windows.weeklyAt = ResetAt(weeklyRemaining)
    end
end

local function RaidSessionKey(sessionOrName, difficultyID)
    if type(sessionOrName) == "table" then
        local name = tostring(sessionOrName.name or "Unknown Raid")
        local diff = tonumber(sessionOrName.difficultyID) or 0
        return string.format("%s:%d", name, diff)
    end

    return string.format("%s:%d", tostring(sessionOrName or "Unknown Raid"), tonumber(difficultyID) or 0)
end

function DT.CharacterTracker:AddRaidBossKill(session, payload)
    self:RefreshResets(false)
    if not self.character or not self.character.tracking or type(session) ~= "table" then
        return
    end

    local bucket = self.character.tracking.weeklyRaidBossKills
    if not bucket then
        return
    end

    local key = RaidSessionKey(session)
    local list = bucket[key] or {}
    bucket[key] = list

    payload = payload or {}
    local bossID = tonumber(payload.encounterID) or 0
    local bossName = tostring(payload.encounterName or "Unknown Boss")
    local now = GetServerTime and GetServerTime() or fallbackTime()

    for _, row in ipairs(list) do
        if type(row) == "table" and tonumber(row.encounterID) == bossID and bossID > 0 then
            row.killedAt = row.killedAt or now
            row.encounterName = row.encounterName or bossName
            return
        end
    end

    list[#list + 1] = {
        encounterID = bossID,
        encounterName = bossName,
        killedAt = now,
        difficultyID = tonumber(session.difficultyID) or 0,
        difficultyName = session.difficultyName,
        mapID = tonumber(session.mapID) or nil,
    }
end

function DT.CharacterTracker:AddRaidLoot(session, lootText, source)
    local normalized = NormalizeLootText(lootText)
    if normalized == "" then
        return
    end

    local meta = ExtractLootMeta(lootText, normalized)

    self:RefreshResets(false)
    if not self.character or not self.character.tracking or type(session) ~= "table" then
        return
    end

    local bucket = self.character.tracking.weeklyRaidLoot
    if not bucket then
        return
    end

    local key = RaidSessionKey(session)
    local list = bucket[key] or {}
    bucket[key] = list

    if #list > 0 and type(list[#list]) == "table" and list[#list].text == normalized then
        return
    end

    list[#list + 1] = {
        text = normalized,
        rawText = meta.rawText,
        itemName = meta.itemName,
        itemLink = meta.itemLink,
        quantity = meta.quantity,
        addedAt = GetServerTime and GetServerTime() or fallbackTime(),
        source = source or "raid",
    }
end

function DT.CharacterTracker:RemoveRaidLootByText(session, lootText)
    local normalized = NormalizeLootText(lootText)
    if normalized == "" then
        return false
    end

    self:RefreshResets(false)
    if not self.character or not self.character.tracking or type(session) ~= "table" then
        return false
    end

    local bucket = self.character.tracking.weeklyRaidLoot
    if not bucket then
        return false
    end

    local key = RaidSessionKey(session)
    local list = bucket[key]
    if type(list) ~= "table" or #list == 0 then
        return false
    end

    for i = #list, 1, -1 do
        local row = list[i]
        if type(row) == "table" and type(row.text) == "string" then
            if row.text == normalized
                or string.find(string.lower(row.text), string.lower(normalized), 1, true)
                or string.find(string.lower(normalized), string.lower(row.text), 1, true)
            then
                table.remove(list, i)
                return true
            end
        end
    end

    return false
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

    local lootMeta = ExtractLootMeta(lootText, normalized)

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

    local source = meta
    local difficultyID, difficultyName
    if type(meta) == "table" then
        source = meta.source
        difficultyID = tonumber(meta.difficultyID)
        difficultyName = meta.difficultyName
    end

    bucket[canonicalName][#bucket[canonicalName] + 1] = {
        text = normalized,
        rawText = lootMeta.rawText,
        itemName = lootMeta.itemName,
        itemLink = lootMeta.itemLink,
        quantity = lootMeta.quantity,
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        addedAt = GetServerTime and GetServerTime() or fallbackTime(),
        source = source,
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
        self:AddDungeonLoot(name, lootText, {
            source = (tonumber(run.keyLevel) or 0) > 0 and "mplus" or "dungeon",
            difficultyID = run.difficultyID,
            difficultyName = run.difficultyName,
            keyLevel = run.keyLevel,
        })
    end
end

function DT.CharacterTracker:ClearRecordedLoot()
    self:RefreshResets(false)
    if not self.character or not self.character.tracking then
        return
    end

    self.character.tracking.weeklyDungeonLoot = {}
    self.character.tracking.weeklyRaidLoot = {}

    local runsByDungeon = self.character.tracking.mplusRuns or {}
    for _, runs in pairs(runsByDungeon) do
        if type(runs) == "table" then
            for _, run in ipairs(runs) do
                if type(run) == "table" then
                    run.loot = {}
                end
            end
        end
    end
end

function DT.CharacterTracker:ClearResettableLootOnInstanceReset()
    self:RefreshResets(false)
    if not self.character or not self.character.tracking then
        return 0, 0
    end

    local tracking = self.character.tracking
    local dungeonClears = tracking.dungeonClears or {}
    local raidClears = tracking.raidClears or {}
    local raidBossKills = tracking.weeklyRaidBossKills or {}

    local clearedDungeonBuckets = 0
    local clearedRaidBuckets = 0

    local function splitInstanceKey(key)
        local text = tostring(key or "")
        local name, diff = text:match("^(.*):(%-?%d+)$")
        return name, tonumber(diff)
    end

    local hasDungeonBossClearByName = {}
    for sig, _ in pairs(dungeonClears) do
        local name = splitInstanceKey(sig)
        if name and name ~= "" then
            hasDungeonBossClearByName[name] = true
        end
    end

    for dungeonName, lootList in pairs(tracking.weeklyDungeonLoot or {}) do
        if type(lootList) == "table" and #lootList > 0 then
            if not hasDungeonBossClearByName[dungeonName] then
                tracking.weeklyDungeonLoot[dungeonName] = nil
                clearedDungeonBuckets = clearedDungeonBuckets + 1
            end
        end
    end

    for raidSig, lootList in pairs(tracking.weeklyRaidLoot or {}) do
        if type(lootList) == "table" and #lootList > 0 then
            local hasBoss = false

            local kills = raidBossKills[raidSig]
            if type(kills) == "table" and #kills > 0 then
                hasBoss = true
            end

            if not hasBoss then
                local clear = raidClears[raidSig]
                if type(clear) == "table" and (tonumber(clear.encounterProgress) or 0) > 0 then
                    hasBoss = true
                end
            end

            if not hasBoss then
                tracking.weeklyRaidLoot[raidSig] = nil
                clearedRaidBuckets = clearedRaidBuckets + 1
            end
        end
    end

    return clearedDungeonBuckets, clearedRaidBuckets
end
