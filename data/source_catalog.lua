local _, DT                        = ...

DT.SourceCatalog                   = DT.SourceCatalog or {}

local DIFFICULTY_NORMAL            = 1
local DIFFICULTY_HEROIC            = 2
local DIFFICULTY_MYTHIC            = 23
local DIFFICULTY_MYTHIC_KEYSTONE   = 8

local EJ_GetNumTiers               = _G["EJ_GetNumTiers"]
local EJ_GetTierInfo               = _G["EJ_GetTierInfo"]
local EJ_SelectTier                = _G["EJ_SelectTier"]
local EJ_GetInstanceByIndex        = _G["EJ_GetInstanceByIndex"]
local EJ_GetInstanceInfo           = _G["EJ_GetInstanceInfo"]
local EJ_SelectInstance            = _G["EJ_SelectInstance"]
local EJ_IsValidInstanceDifficulty = _G["EJ_IsValidInstanceDifficulty"]
local nowTime                      = _G["time"]

local DUNGEON_GROUPS               = {
    "dungeons_mplus_rotation",
    "dungeons_midnight_gear",
    "dungeons_midnight_bonus",
}

local function NormalizeText(value)
    local text = tostring(value or "")
    text = string.lower(text)
    text = text:gsub("’", "'")
    text = text:gsub("`", "'")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    text = text:gsub("%s+", " ")
    return text
end

local function ExpansionKeyFromTier(tierName)
    local key = NormalizeText(tierName)
    key = key:gsub("[^%w]+", "_")
    key = key:gsub("_+", "_")
    key = key:gsub("^_", "")
    key = key:gsub("_$", "")
    if key == "" then
        key = "unknown"
    end

    if key == "war_within" then
        key = "the_war_within"
    end
    return key
end

local function CanonicalInstance(name, difficultyName, difficultyID)
    return {
        name = name,
        difficultyName = difficultyName,
        difficultyID = difficultyID,
    }
end

DT.SourceCatalog.dungeonNameAliases = {
    [NormalizeText("Magisters' Terrace")] = "Magisters' Terrace",
    [NormalizeText("Magister's Terrace")] = "Magisters' Terrace",
    [NormalizeText("Maisara Caverns")] = "Maisara Caverns",
    [NormalizeText("Miasara Caverns")] = "Maisara Caverns",
    [NormalizeText("Nexus-Point Xenas")] = "Nexus-Point Xenas",
    [NormalizeText("Windrunner Spire")] = "Windrunner Spire",
    [NormalizeText("Algeth'ar Academy")] = "Algeth'ar Academy",
    [NormalizeText("The Seat of the Triumvirate")] = "The Seat of the Triumvirate",
    [NormalizeText("Seat of the Triumvirate")] = "The Seat of the Triumvirate",
    [NormalizeText("Skyreach")] = "Skyreach",
    [NormalizeText("Pit of Saron")] = "Pit of Saron",
    [NormalizeText("Den of Nalorakk")] = "Den of Nalorakk",
    [NormalizeText("Murder Row")] = "Murder Row",
    [NormalizeText("The Blinding Vale")] = "The Blinding Vale",
    [NormalizeText("Voidscar Arena")] = "Voidscar Arena",
}

DT.SourceCatalog.groups = {
    quests_daily = {
        label = "Daily Quests",
        status = "confirmed",
    },
    quests_weekly = {
        label = "Weekly Quests",
        status = "confirmed",
    },

    -- ── M+ Weekly Rotation ──────────────────────────────────────────────────
    dungeons_mplus_rotation = {
        label = "M+ Rotation Dungeons",
        expansionKey = "midnight_s1",
        expansionLabel = "Midnight Season 1",
        status = "confirmed",
        instanceType = "party",
        difficultyIDs = {
            [DIFFICULTY_NORMAL]          = true,
            [DIFFICULTY_HEROIC]          = true,
            [DIFFICULTY_MYTHIC]          = true,
            [DIFFICULTY_MYTHIC_KEYSTONE] = true,
        },
        knownInstances = {
            ["Magisters' Terrace:1"]           = CanonicalInstance("Magisters' Terrace", "Normal", DIFFICULTY_NORMAL),
            ["Magisters' Terrace:2"]           = CanonicalInstance("Magisters' Terrace", "Heroic", DIFFICULTY_HEROIC),
            ["Magisters' Terrace:23"]          = CanonicalInstance("Magisters' Terrace", "Mythic", DIFFICULTY_MYTHIC),
            ["Magisters' Terrace:8"]           = CanonicalInstance("Magisters' Terrace", "M+", DIFFICULTY_MYTHIC_KEYSTONE),
            ["Maisara Caverns:1"]              = CanonicalInstance("Maisara Caverns", "Normal", DIFFICULTY_NORMAL),
            ["Maisara Caverns:2"]              = CanonicalInstance("Maisara Caverns", "Heroic", DIFFICULTY_HEROIC),
            ["Maisara Caverns:23"]             = CanonicalInstance("Maisara Caverns", "Mythic", DIFFICULTY_MYTHIC),
            ["Maisara Caverns:8"]              = CanonicalInstance("Maisara Caverns", "M+", DIFFICULTY_MYTHIC_KEYSTONE),
            ["Nexus-Point Xenas:1"]            = { name = "Nexus-Point Xenas", difficultyName = "Normal", difficultyID = 1 },
            ["Nexus-Point Xenas:2"]            = { name = "Nexus-Point Xenas", difficultyName = "Heroic", difficultyID = 2 },
            ["Nexus-Point Xenas:23"]           = { name = "Nexus-Point Xenas", difficultyName = "Mythic", difficultyID = 23 },
            ["Nexus-Point Xenas:8"]            = { name = "Nexus-Point Xenas", difficultyName = "M+", difficultyID = 8 },
            ["Windrunner Spire:1"]             = { name = "Windrunner Spire", difficultyName = "Normal", difficultyID = 1 },
            ["Windrunner Spire:2"]             = { name = "Windrunner Spire", difficultyName = "Heroic", difficultyID = 2 },
            ["Windrunner Spire:23"]            = { name = "Windrunner Spire", difficultyName = "Mythic", difficultyID = 23 },
            ["Windrunner Spire:8"]             = { name = "Windrunner Spire", difficultyName = "M+", difficultyID = 8 },
            ["Algeth'ar Academy:1"]            = CanonicalInstance("Algeth'ar Academy", "Normal", DIFFICULTY_NORMAL),
            ["Algeth'ar Academy:2"]            = CanonicalInstance("Algeth'ar Academy", "Heroic", DIFFICULTY_HEROIC),
            ["Algeth'ar Academy:23"]           = CanonicalInstance("Algeth'ar Academy", "Mythic", DIFFICULTY_MYTHIC),
            ["Algeth'ar Academy:8"]            = CanonicalInstance("Algeth'ar Academy", "M+", DIFFICULTY_MYTHIC_KEYSTONE),
            ["The Seat of the Triumvirate:1"]  = CanonicalInstance("The Seat of the Triumvirate", "Normal",
                DIFFICULTY_NORMAL),
            ["The Seat of the Triumvirate:2"]  = CanonicalInstance("The Seat of the Triumvirate", "Heroic",
                DIFFICULTY_HEROIC),
            ["The Seat of the Triumvirate:23"] = CanonicalInstance("The Seat of the Triumvirate", "Mythic",
                DIFFICULTY_MYTHIC),
            ["The Seat of the Triumvirate:8"]  = CanonicalInstance("The Seat of the Triumvirate", "M+",
                DIFFICULTY_MYTHIC_KEYSTONE),
            ["Skyreach:1"]                     = CanonicalInstance("Skyreach", "Normal", DIFFICULTY_NORMAL),
            ["Skyreach:2"]                     = CanonicalInstance("Skyreach", "Heroic", DIFFICULTY_HEROIC),
            ["Skyreach:23"]                    = CanonicalInstance("Skyreach", "Mythic", DIFFICULTY_MYTHIC),
            ["Skyreach:8"]                     = CanonicalInstance("Skyreach", "M+", DIFFICULTY_MYTHIC_KEYSTONE),
            ["Pit of Saron:1"]                 = CanonicalInstance("Pit of Saron", "Normal", DIFFICULTY_NORMAL),
            ["Pit of Saron:2"]                 = CanonicalInstance("Pit of Saron", "Heroic", DIFFICULTY_HEROIC),
            ["Pit of Saron:23"]                = CanonicalInstance("Pit of Saron", "Mythic", DIFFICULTY_MYTHIC),
            ["Pit of Saron:8"]                 = CanonicalInstance("Pit of Saron", "M+", DIFFICULTY_MYTHIC_KEYSTONE),
        },
    },

    -- ── Other Midnight Gear Dungeons (non-M+ rotation) ───────────────────────
    dungeons_midnight_gear = {
        label = "Midnight Gear Dungeons",
        expansionKey = "midnight",
        expansionLabel = "Midnight",
        status = "confirmed",
        instanceType = "party",
        difficultyIDs = {
            [DIFFICULTY_NORMAL] = true,
            [DIFFICULTY_HEROIC] = true,
            [DIFFICULTY_MYTHIC] = true,
        },
        knownInstances = {
            ["Den of Nalorakk:1"]    = { name = "Den of Nalorakk", difficultyName = "Normal", difficultyID = 1 },
            ["Den of Nalorakk:2"]    = { name = "Den of Nalorakk", difficultyName = "Heroic", difficultyID = 2 },
            ["Den of Nalorakk:23"]   = { name = "Den of Nalorakk", difficultyName = "Mythic", difficultyID = 23 },
            ["Murder Row:1"]         = { name = "Murder Row", difficultyName = "Normal", difficultyID = 1 },
            ["Murder Row:2"]         = { name = "Murder Row", difficultyName = "Heroic", difficultyID = 2 },
            ["Murder Row:23"]        = { name = "Murder Row", difficultyName = "Mythic", difficultyID = 23 },
            ["The Blinding Vale:1"]  = { name = "The Blinding Vale", difficultyName = "Normal", difficultyID = 1 },
            ["The Blinding Vale:2"]  = { name = "The Blinding Vale", difficultyName = "Heroic", difficultyID = 2 },
            ["The Blinding Vale:23"] = { name = "The Blinding Vale", difficultyName = "Mythic", difficultyID = 23 },
            ["Voidscar Arena:1"]     = { name = "Voidscar Arena", difficultyName = "Normal", difficultyID = 1 },
            ["Voidscar Arena:2"]     = { name = "Voidscar Arena", difficultyName = "Heroic", difficultyID = 2 },
            ["Voidscar Arena:23"]    = { name = "Voidscar Arena", difficultyName = "Mythic", difficultyID = 23 },
        },
    },

    -- ── Bonus Dungeons: accessible now, gear unlocks March 17 ────────────────
    dungeons_midnight_bonus = {
        label = "Midnight Bonus Dungeons (Gear: 3/17)",
        expansionKey = "legacy",
        expansionLabel = "Legacy",
        status = "confirmed",
        instanceType = "party",
        difficultyIDs = {
            [DIFFICULTY_NORMAL] = true,
            [DIFFICULTY_HEROIC] = true,
            [DIFFICULTY_MYTHIC] = true,
        },
        knownInstances = {
            ["Algeth'ar Academy:1"]            = { name = "Algeth'ar Academy", difficultyName = "Normal", difficultyID = 1 },
            ["Algeth'ar Academy:2"]            = { name = "Algeth'ar Academy", difficultyName = "Heroic", difficultyID = 2 },
            ["Algeth'ar Academy:23"]           = { name = "Algeth'ar Academy", difficultyName = "Mythic", difficultyID = 23 },
            ["The Seat of the Triumvirate:1"]  = { name = "The Seat of the Triumvirate", difficultyName = "Normal", difficultyID = 1 },
            ["The Seat of the Triumvirate:2"]  = { name = "The Seat of the Triumvirate", difficultyName = "Heroic", difficultyID = 2 },
            ["The Seat of the Triumvirate:23"] = { name = "The Seat of the Triumvirate", difficultyName = "Mythic", difficultyID = 23 },
            ["Skyreach:1"]                     = { name = "Skyreach", difficultyName = "Normal", difficultyID = 1 },
            ["Skyreach:2"]                     = { name = "Skyreach", difficultyName = "Heroic", difficultyID = 2 },
            ["Skyreach:23"]                    = { name = "Skyreach", difficultyName = "Mythic", difficultyID = 23 },
            ["Pit of Saron:1"]                 = { name = "Pit of Saron", difficultyName = "Normal", difficultyID = 1 },
            ["Pit of Saron:2"]                 = { name = "Pit of Saron", difficultyName = "Heroic", difficultyID = 2 },
            ["Pit of Saron:23"]                = { name = "Pit of Saron", difficultyName = "Mythic", difficultyID = 23 },
        },
    },

    raids_midnight_s1 = {
        label = "Midnight S1 Raids",
        status = "possible",
        hidden = true,
        autoEnable = true,
        autoEnableDate = "2026-03-17",
        instanceType = "raid",
    },
    delves_bountiful = {
        label = "Bountiful Delves",
        status = "possible",
        hidden = true,
    },
    knowledge_weekly = {
        label = "Weekly Knowledge",
        status = "confirmed",
        knownWeeklyQuestIDs = {
            -- Add confirmed quest IDs as they are validated.
        },
    },
}

function DT.SourceCatalog:Initialize(db)
    db.catalog = db.catalog or {}
    db.catalog.dungeonEntries = db.catalog.dungeonEntries or {}
    db.catalog.expansionOptions = db.catalog.expansionOptions or {}
    db.catalog.lastDungeonImportAt = db.catalog.lastDungeonImportAt or 0
    db.settings = db.settings or {}
    db.settings.dungeonVisibility = db.settings.dungeonVisibility or {}
    db.settings.dungeonVisibility.expansions = db.settings.dungeonVisibility.expansions or {}
    db.settings.dungeonVisibility.dungeons = db.settings.dungeonVisibility.dungeons or {}

    self:RefreshDungeonCatalogFromJournal(false)
end

-- Ordered list used by FindGroupForInstance for dungeon lookup
DT.SourceCatalog.dungeonGroupOrder = {
    "dungeons_mplus_rotation",
    "dungeons_midnight_gear",
    "dungeons_midnight_bonus",
}

function DT.SourceCatalog:GetCanonicalDungeonName(name)
    local normalized = NormalizeText(name)
    return self.dungeonNameAliases[normalized] or tostring(name or "Unknown")
end

function DT.SourceCatalog:GetDungeonExpansionInfo(name)
    local targetName = self:GetCanonicalDungeonName(name)
    for _, groupKey in ipairs(DUNGEON_GROUPS) do
        local group = self.groups[groupKey]
        if group and group.knownInstances then
            for _, info in pairs(group.knownInstances) do
                if type(info) == "table" and info.name == targetName then
                    return group.expansionKey, group.expansionLabel
                end
            end
        end
    end
    return nil, nil
end

function DT.SourceCatalog:IsDungeonHidden(name)
    local canonical = self:GetCanonicalDungeonName(name)
    local visibility = DT.db and DT.db.settings and DT.db.settings.dungeonVisibility
    local hidden = visibility and visibility.dungeons and visibility.dungeons[canonical]
    return hidden == true
end

function DT.SourceCatalog:SetDungeonHidden(name, hidden)
    local canonical = self:GetCanonicalDungeonName(name)
    local visibility = DT.db and DT.db.settings and DT.db.settings.dungeonVisibility
    if not visibility or not visibility.dungeons then
        return
    end
    visibility.dungeons[canonical] = hidden and true or nil
end

function DT.SourceCatalog:IsExpansionHidden(expansionKey)
    if not expansionKey or expansionKey == "" then
        return false
    end
    local visibility = DT.db and DT.db.settings and DT.db.settings.dungeonVisibility
    local hidden = visibility and visibility.expansions and visibility.expansions[expansionKey]
    return hidden == true
end

function DT.SourceCatalog:SetExpansionHidden(expansionKey, hidden)
    if not expansionKey or expansionKey == "" then
        return
    end
    local visibility = DT.db and DT.db.settings and DT.db.settings.dungeonVisibility
    if not visibility or not visibility.expansions then
        return
    end
    visibility.expansions[expansionKey] = hidden and true or nil
end

function DT.SourceCatalog:IsDungeonVisible(name)
    if self:IsDungeonHidden(name) then
        return false
    end
    local expansionKey = self:GetDungeonExpansionInfo(name)
    if expansionKey and self:IsExpansionHidden(expansionKey) then
        return false
    end
    return true
end

function DT.SourceCatalog:GetAllDungeonEntries()
    self:RefreshDungeonCatalogFromJournal(false)

    local dbEntries = DT.db and DT.db.catalog and DT.db.catalog.dungeonEntries
    if type(dbEntries) == "table" and #dbEntries > 0 then
        return dbEntries
    end

    local byName = {}
    for _, groupKey in ipairs(DUNGEON_GROUPS) do
        local group = self.groups[groupKey]
        if group and group.knownInstances then
            for _, info in pairs(group.knownInstances) do
                if type(info) == "table" and info.name then
                    local canonical = self:GetCanonicalDungeonName(info.name)
                    local row = byName[canonical]
                    if not row then
                        row = {
                            name = canonical,
                            expansionKey = group.expansionKey,
                            expansionLabel = group.expansionLabel,
                            difficulties = {},
                        }
                        byName[canonical] = row
                    end
                    row.difficulties[tonumber(info.difficultyID) or 0] = true
                end
            end
        end
    end

    local fallback = {}
    for _, row in pairs(byName) do
        fallback[#fallback + 1] = row
    end
    table.sort(fallback, function(a, b)
        if tostring(a.expansionLabel) ~= tostring(b.expansionLabel) then
            return tostring(a.expansionLabel) < tostring(b.expansionLabel)
        end
        return tostring(a.name) < tostring(b.name)
    end)
    return fallback
end

function DT.SourceCatalog:GetExpansionOptions()
    self:RefreshDungeonCatalogFromJournal(false)

    local dbExpansions = DT.db and DT.db.catalog and DT.db.catalog.expansionOptions
    if type(dbExpansions) == "table" and #dbExpansions > 0 then
        return dbExpansions
    end

    local expansions = {}
    local seen = {}
    for _, row in ipairs(self:GetAllDungeonEntries()) do
        if row.expansionKey and not seen[row.expansionKey] then
            seen[row.expansionKey] = true
            expansions[#expansions + 1] = {
                key = row.expansionKey,
                label = row.expansionLabel or row.expansionKey,
            }
        end
    end
    table.sort(expansions, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)
    return expansions
end

function DT.SourceCatalog:RefreshDungeonCatalogFromJournal(force)
    if not force and self._catalogReady then
        return
    end

    if type(EJ_GetNumTiers) ~= "function"
        or type(EJ_GetTierInfo) ~= "function"
        or type(EJ_SelectTier) ~= "function"
        or type(EJ_GetInstanceByIndex) ~= "function"
    then
        return
    end

    local tiers = EJ_GetNumTiers() or 0
    if tiers <= 0 then
        return
    end

    local byName = {}

    local function ensureDungeon(name, expansionKey, expansionLabel)
        local canonical = self:GetCanonicalDungeonName(name)
        local row = byName[canonical]
        if not row then
            row = {
                name = canonical,
                expansionKey = expansionKey,
                expansionLabel = expansionLabel,
                difficulties = {},
            }
            byName[canonical] = row
        end
        return row
    end

    for tierIndex = 1, tiers do
        local tierName = EJ_GetTierInfo(tierIndex)
        if tierName then
            local expansionKey = ExpansionKeyFromTier(tierName)
            local expansionLabel = tostring(tierName)

            EJ_SelectTier(tierIndex)

            local index = 1
            while true do
                local instanceID, instanceName = EJ_GetInstanceByIndex(index, false)
                if not instanceID then
                    break
                end

                local resolvedName = instanceName
                if type(EJ_GetInstanceInfo) == "function" then
                    local ejName = EJ_GetInstanceInfo(instanceID)
                    if ejName and ejName ~= "" then
                        resolvedName = ejName
                    end
                end

                if resolvedName and resolvedName ~= "" then
                    local row = ensureDungeon(resolvedName, expansionKey, expansionLabel)

                    if type(EJ_SelectInstance) == "function" then
                        EJ_SelectInstance(instanceID)
                    end

                    local difficultyIDs = {
                        DIFFICULTY_NORMAL,
                        DIFFICULTY_HEROIC,
                        DIFFICULTY_MYTHIC,
                    }

                    local foundAny = false
                    for _, difficultyID in ipairs(difficultyIDs) do
                        local isValid = false
                        if type(EJ_IsValidInstanceDifficulty) == "function" then
                            isValid = EJ_IsValidInstanceDifficulty(difficultyID) == true
                        else
                            isValid = difficultyID == DIFFICULTY_NORMAL
                        end

                        if isValid then
                            row.difficulties[difficultyID] = true
                            foundAny = true
                        end
                    end

                    if not foundAny then
                        row.difficulties[DIFFICULTY_NORMAL] = true
                    end
                end

                index = index + 1
            end
        end
    end

    local entries = {}
    for _, row in pairs(byName) do
        entries[#entries + 1] = row
    end

    table.sort(entries, function(a, b)
        if tostring(a.expansionLabel) ~= tostring(b.expansionLabel) then
            return tostring(a.expansionLabel) < tostring(b.expansionLabel)
        end
        return tostring(a.name) < tostring(b.name)
    end)

    local expansions = {}
    local seenExpansion = {}
    for _, row in ipairs(entries) do
        if row.expansionKey and not seenExpansion[row.expansionKey] then
            seenExpansion[row.expansionKey] = true
            expansions[#expansions + 1] = {
                key = row.expansionKey,
                label = row.expansionLabel or row.expansionKey,
            }
        end
    end
    table.sort(expansions, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)

    if DT.db and DT.db.catalog then
        DT.db.catalog.dungeonEntries = entries
        DT.db.catalog.expansionOptions = expansions
        DT.db.catalog.lastDungeonImportAt = nowTime and nowTime() or 0
    end

    self._catalogReady = true
end

function DT.SourceCatalog:GetSeasonOneDungeonNames()
    local out = {}
    local group = self.groups.dungeons_mplus_rotation
    if not group or not group.knownInstances then
        return out
    end

    local seen = {}
    for _, info in pairs(group.knownInstances) do
        if type(info) == "table" and info.name then
            local canonical = self:GetCanonicalDungeonName(info.name)
            if not seen[canonical] then
                seen[canonical] = true
                out[#out + 1] = canonical
            end
        end
    end
    table.sort(out)
    return out
end

function DT.SourceCatalog:FindGroupForInstance(name, difficultyID)
    local canonicalName = self:GetCanonicalDungeonName(name)
    for _, groupKey in ipairs(self.dungeonGroupOrder) do
        local group = self.groups[groupKey]
        if group and group.knownInstances then
            for _, instance in pairs(group.knownInstances) do
                if type(instance) == "table"
                    and instance.name == canonicalName
                    and tonumber(instance.difficultyID) == tonumber(difficultyID)
                then
                    if DT:IsGroupEnabled(groupKey)
                        and self:IsGroupTrackable(groupKey)
                        and self:IsDungeonVisible(canonicalName)
                    then
                        return groupKey
                    end
                    break
                end
            end
        end
    end
    return nil
end

function DT.SourceCatalog:GetGroup(groupKey)
    return self.groups[groupKey]
end

function DT.SourceCatalog:IsGroupVisible(groupKey)
    local group = self.groups[groupKey]
    if not group then
        return false
    end

    if group.status == "possible" and DT.db and DT.db.settings and DT.db.settings.hidePossibleSources then
        return false
    end

    return true
end

function DT.SourceCatalog:IsGroupTrackable(groupKey)
    local group = self.groups[groupKey]
    if not group then
        return false
    end

    if group.status == "possible" and DT.db and DT.db.settings and not DT.db.settings.allowPossibleSources then
        return false
    end

    return true
end

function DT.SourceCatalog:IsDifficultyAllowed(groupKey, difficultyID)
    local group = self.groups[groupKey]
    if not group or not group.difficultyIDs then
        return false
    end
    return group.difficultyIDs[difficultyID] == true
end

function DT.SourceCatalog:IsMapAllowed(groupKey, mapID)
    local group = self.groups[groupKey]
    if not group then
        return false
    end

    if not group.strictMapFiltering then
        return true
    end

    return group.allowedMapIDs and group.allowedMapIDs[mapID] == true
end

function DT.SourceCatalog:IsKnownWeeklyKnowledgeQuest(questID)
    local group = self.groups.knowledge_weekly
    if not group or not group.knownWeeklyQuestIDs then
        return false
    end
    return group.knownWeeklyQuestIDs[questID] == true
end

function DT.SourceCatalog:MarkGroupConfirmed(groupKey)
    local group = self.groups[groupKey]
    if not group then
        return
    end

    group.status = "confirmed"
    group.hidden = false
end

function DT.SourceCatalog:GetVisibleGroupKeys()
    local keys = {}
    for key in pairs(self.groups) do
        if self:IsGroupVisible(key) then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return keys
end
