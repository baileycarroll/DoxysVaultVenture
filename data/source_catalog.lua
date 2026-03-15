local _, DT                                = ...

DT.SourceCatalog                           = DT.SourceCatalog or {}

local DIFFICULTY_NORMAL                    = 1
local DIFFICULTY_HEROIC                    = 2
local DIFFICULTY_MYTHIC                    = 23
local DIFFICULTY_MYTHIC_KEYSTONE           = 8
local DIFFICULTY_RAID10_NORMAL             = 3
local DIFFICULTY_RAID25_NORMAL             = 4
local DIFFICULTY_RAID10_HEROIC             = 5
local DIFFICULTY_RAID25_HEROIC             = 6
local DIFFICULTY_LFR_LEGACY                = 7
local DIFFICULTY_LFR                       = 17
local DIFFICULTY_RAID_NORMAL               = 14
local DIFFICULTY_RAID_HEROIC               = 15
local DIFFICULTY_RAID_MYTHIC               = 16

local EJ_GetNumTiers                       = _G["EJ_GetNumTiers"]
local EJ_GetTierInfo                       = _G["EJ_GetTierInfo"]
local EJ_SelectTier                        = _G["EJ_SelectTier"]
local EJ_GetInstanceByIndex                = _G["EJ_GetInstanceByIndex"]
local EJ_GetInstanceInfo                   = _G["EJ_GetInstanceInfo"]
local EJ_SelectInstance                    = _G["EJ_SelectInstance"]
local EJ_IsValidInstanceDifficulty         = _G["EJ_IsValidInstanceDifficulty"]
local nowTime                              = _G["time"]
local C_QuestLog                           = _G["C_QuestLog"]
local C_Map                                = _G["C_Map"]
local GetQuestUiMapID                      = _G["GetQuestUiMapID"]
local QuestMapFrame_GetQuestWorldMapAreaID = _G["QuestMapFrame_GetQuestWorldMapAreaID"]

local DUNGEON_GROUPS                       = {
    "dungeons_mplus_rotation",
    "dungeons_midnight_gear",
    "dungeons_midnight_bonus",
}

-- Dungeons that exist in multiple expansions: force their expansion key so
-- the UI filter always shows them under the correct expansion.
local DUNGEON_EXPANSION_OVERRIDES = {
    ["Magisters' Terrace"] = { key = "midnight", label = "Midnight" },
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

local WOWHEAD_RAID_NAMES = {
    "Molten Core",
    "Blackwing Lair",
    "Ruins of Ahn'Qiraj",
    "Temple of Ahn'Qiraj",
    "Naxxramas",
    "Karazhan",
    "Gruul's Lair",
    "Magtheridon's Lair",
    "Serpentshrine Cavern",
    "Tempest Keep",
    "Battle for Mount Hyjal",
    "Black Temple",
    "Sunwell Plateau",
    "Vault of Archavon",
    "The Obsidian Sanctum",
    "The Eye of Eternity",
    "Ulduar",
    "Trial of the Crusader",
    "Icecrown Citadel",
    "Ruby Sanctum",
    "Blackwing Descent",
    "The Bastion of Twilight",
    "Throne of the Four Winds",
    "Baradin Hold",
    "Firelands",
    "Dragon Soul",
    "Mogu'shan Vaults",
    "Heart of Fear",
    "Terrace of Endless Spring",
    "Throne of Thunder",
    "Siege of Orgrimmar",
    "Highmaul",
    "Blackrock Foundry",
    "Hellfire Citadel",
    "The Emerald Nightmare",
    "Trial of Valor",
    "The Nighthold",
    "Tomb of Sargeras",
    "Antorus, the Burning Throne",
    "Uldir",
    "Battle of Dazar'alor",
    "Crucible of Storms",
    "The Eternal Palace",
    "Ny'alotha, the Waking City",
    "Castle Nathria",
    "Sanctum of Domination",
    "Sepulcher of the First Ones",
    "Vault of the Incarnates",
    "Aberrus, the Shadowed Crucible",
    "Amirdrassil, the Dream's Hope",
    "Nerub-ar Palace",
    "Liberation of Undermine",
}

DT.SourceCatalog.dungeonNameAliases = {
    [NormalizeText("Magisters' Terrace")] = "Magisters' Terrace",
    [NormalizeText("Magister's Terrace")] = "Magisters' Terrace",
    [NormalizeText("Maisara Caverns")] = "Maisara Caverns",
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
        knownDailyQuestIDs = {
            -- Intentionally empty: populated dynamically from active daily quests.
        },
    },
    quests_weekly = {
        label = "Weekly Quests",
        status = "confirmed",
        knownWeeklyQuestIDs = {
            -- Optional static weekly quest IDs can be added here.
        },
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
            ["Magisters' Terrace:1"]  = { name = "Magisters' Terrace", difficultyName = "Normal", difficultyID = 1 },
            ["Magisters' Terrace:2"]  = { name = "Magisters' Terrace", difficultyName = "Heroic", difficultyID = 2 },
            ["Magisters' Terrace:23"] = { name = "Magisters' Terrace", difficultyName = "Mythic", difficultyID = 23 },
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
        status = "confirmed",
        hidden = false,
        autoEnable = true,
        autoEnableDate = "2026-03-17",
        instanceType = "raid",
        difficultyIDs = {
            [DIFFICULTY_RAID10_NORMAL] = true,
            [DIFFICULTY_RAID25_NORMAL] = true,
            [DIFFICULTY_RAID10_HEROIC] = true,
            [DIFFICULTY_RAID25_HEROIC] = true,
            [DIFFICULTY_RAID_NORMAL] = true,
            [DIFFICULTY_RAID_HEROIC] = true,
            [DIFFICULTY_RAID_MYTHIC] = true,
        },
        knownRaidNames = WOWHEAD_RAID_NAMES,
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
    db.catalog.questZoneCache = db.catalog.questZoneCache or {}
    db.catalog.questMapCache = db.catalog.questMapCache or {}
    db.catalog.raidExpansionCache = db.catalog.raidExpansionCache or {}
    db.catalog.discoveredDailyQuests = db.catalog.discoveredDailyQuests or {}
    db.catalog.discoveredWeeklyQuests = db.catalog.discoveredWeeklyQuests or {}
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
        for _, entry in ipairs(dbEntries) do
            local override = DUNGEON_EXPANSION_OVERRIDES[entry.name]
            if override then
                entry.expansionKey = override.key
                entry.expansionLabel = override.label
            end
        end
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
        else
            -- Update to the latest tier's expansion so dungeons reworked in a newer
            -- expansion (e.g. Magisters' Terrace in Midnight) get the correct key.
            row.expansionKey = expansionKey
            row.expansionLabel = expansionLabel
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

local function RaidDifficultyLabel(difficultyID)
    local id = tonumber(difficultyID)
    if not id then
        return tostring(difficultyID or "Unknown")
    end

    if _G["GetDifficultyInfo"] then
        local label = _G["GetDifficultyInfo"](id)
        if label and label ~= "" then
            return label
        end
    end

    local labels = {
        [DIFFICULTY_RAID10_NORMAL] = "10N",
        [DIFFICULTY_RAID25_NORMAL] = "25N",
        [DIFFICULTY_RAID10_HEROIC] = "10H",
        [DIFFICULTY_RAID25_HEROIC] = "25H",
        [DIFFICULTY_LFR_LEGACY] = "LFR",
        [DIFFICULTY_RAID_NORMAL] = "Normal",
        [DIFFICULTY_RAID_HEROIC] = "Heroic",
        [DIFFICULTY_RAID_MYTHIC] = "Mythic",
        [DIFFICULTY_LFR] = "LFR",
    }

    return labels[id] or tostring(id)
end

local function ResolveRaidExpansion(self, raidName)
    local name = tostring(raidName or "")
    if name == "" then
        return nil, nil
    end

    local cache = DT.db and DT.db.catalog and DT.db.catalog.raidExpansionCache
    local cached = cache and cache[name]
    if type(cached) == "table" and cached.expansionKey and cached.expansionLabel then
        return cached.expansionKey, cached.expansionLabel
    end

    local wanted = NormalizeText(name)
    local tiers = EJ_GetNumTiers and EJ_GetNumTiers() or 0
    for tierIndex = 1, tiers do
        local tierName = EJ_GetTierInfo and select(2, EJ_GetTierInfo(tierIndex)) or nil
        if EJ_SelectTier then
            EJ_SelectTier(tierIndex)
        end

        local instanceIndex = 1
        while true do
            local instanceID = EJ_GetInstanceByIndex and EJ_GetInstanceByIndex(instanceIndex, true)
            if not instanceID then break end

            local instanceName = EJ_GetInstanceInfo and select(1, EJ_GetInstanceInfo(instanceID))
            if instanceName and NormalizeText(instanceName) == wanted then
                local expansionKey = ExpansionKeyFromTier(tierName or "Unknown")
                local expansionLabel = tostring(tierName or "Unknown")
                if cache then
                    cache[name] = {
                        expansionKey = expansionKey,
                        expansionLabel = expansionLabel,
                    }
                end
                return expansionKey, expansionLabel
            end
            instanceIndex = instanceIndex + 1
        end
    end

    if cache then
        cache[name] = {
            expansionKey = "unknown",
            expansionLabel = "Unknown",
        }
    end
    return "unknown", "Unknown"
end

function DT.SourceCatalog:GetKnownRaidMap()
    local out = {}
    local group = self.groups and self.groups.raids_midnight_s1
    if not group then
        return out
    end

    local difficultyIDs = {}
    if type(group.difficultyIDs) == "table" then
        for id, enabled in pairs(group.difficultyIDs) do
            if enabled then
                difficultyIDs[#difficultyIDs + 1] = tonumber(id)
            end
        end
    end
    table.sort(difficultyIDs)

    local labels = {}
    for _, id in ipairs(difficultyIDs) do
        labels[#labels + 1] = RaidDifficultyLabel(id)
    end

    for _, raidName in ipairs(group.knownRaidNames or {}) do
        local name = tostring(raidName or "")
        if name ~= "" then
            local expansionKey, expansionLabel = ResolveRaidExpansion(self, name)
            out[name] = {
                name = name,
                difficultyIDs = difficultyIDs,
                difficultyLabels = labels,
                expansionKey = expansionKey,
                expansionLabel = expansionLabel,
            }
        end
    end

    return out
end

function DT.SourceCatalog:GetRaidExpansionInfo(name)
    return ResolveRaidExpansion(self, name)
end

function DT.SourceCatalog:GetRaidExpansionOptions()
    local known = self:GetKnownRaidMap()
    local out = {
        { key = "all", label = "All Expansions" }
    }
    local seen = { all = true }
    for _, row in pairs(known) do
        local key = row and row.expansionKey
        local label = row and row.expansionLabel
        if key and key ~= "" and not seen[key] then
            seen[key] = true
            out[#out + 1] = {
                key = key,
                label = label or key,
            }
        end
    end
    table.sort(out, function(a, b)
        if a.key == "all" then return true end
        if b.key == "all" then return false end
        return tostring(a.label) < tostring(b.label)
    end)
    return out
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

function DT.SourceCatalog:IsKnownWeeklyQuest(questID)
    local weeklyGroup = self.groups.quests_weekly
    if weeklyGroup and weeklyGroup.knownWeeklyQuestIDs and weeklyGroup.knownWeeklyQuestIDs[questID] then
        return true
    end

    local discovered = DT.db and DT.db.catalog and DT.db.catalog.discoveredWeeklyQuests
    if discovered and discovered[questID] then
        return true
    end

    return false
end

function DT.SourceCatalog:RecordDiscoveredWeeklyQuest(questID, title, zone, mapID)
    if not questID then
        return false
    end

    local discovered = DT.db and DT.db.catalog and DT.db.catalog.discoveredWeeklyQuests
    if type(discovered) ~= "table" then
        return false
    end

    local now = nowTime and nowTime() or 0
    local existing = discovered[questID]
    if existing then
        existing.lastSeenAt = now
        if title and title ~= "" then
            existing.title = title
        end
        if zone and zone ~= "" then
            existing.zone = zone
        end
        if type(mapID) == "number" and mapID > 0 then
            existing.mapID = mapID
        end
        return false
    end

    discovered[questID] = {
        title = title or ("Quest " .. tostring(questID)),
        zone = zone,
        mapID = mapID,
        firstSeenAt = now,
        lastSeenAt = now,
    }
    return true
end

function DT.SourceCatalog:IsKnownDailyQuest(questID)
    local group = self.groups.quests_daily
    if group and group.knownDailyQuestIDs and group.knownDailyQuestIDs[questID] ~= nil then
        return true
    end

    local discovered = DT.db and DT.db.catalog and DT.db.catalog.discoveredDailyQuests
    if discovered and discovered[questID] then
        return true
    end

    return false
end

function DT.SourceCatalog:GetKnownDailyQuestMap()
    local out = {}
    local group = self.groups.quests_daily
    local known = group and group.knownDailyQuestIDs or {}
    local discovered = DT.db and DT.db.catalog and DT.db.catalog.discoveredDailyQuests or {}

    for questID in pairs(known) do
        local title = nil
        if C_QuestLog and C_QuestLog.GetTitleForQuestID then
            title = C_QuestLog.GetTitleForQuestID(questID)
        end
        local meta = known[questID]
        local mapID = self:GetQuestMapID(questID)
        local zone = self:GetQuestZoneText(questID) or (type(meta) == "table" and meta.zone) or nil
        out[questID] = {
            title = title or ("Quest " .. tostring(questID)),
            zone = zone,
            mapID = mapID,
            npc = type(meta) == "table" and meta.npc or nil,
            x = type(meta) == "table" and meta.x or nil,
            y = type(meta) == "table" and meta.y or nil,
        }
    end

    for questID, meta in pairs(discovered) do
        local title = nil
        if C_QuestLog and C_QuestLog.GetTitleForQuestID then
            title = C_QuestLog.GetTitleForQuestID(questID)
        end

        local mapID = self:GetQuestMapID(questID) or (type(meta) == "table" and meta.mapID) or nil
        local zone = self:GetQuestZoneText(questID) or (type(meta) == "table" and meta.zone) or nil

        out[questID] = {
            title = title or (type(meta) == "table" and meta.title) or ("Quest " .. tostring(questID)),
            zone = zone,
            mapID = mapID,
            npc = type(meta) == "table" and meta.npc or nil,
            x = type(meta) == "table" and meta.x or nil,
            y = type(meta) == "table" and meta.y or nil,
        }
    end

    return out
end

function DT.SourceCatalog:GetKnownWeeklyQuestMap()
    local out = {}
    local group = self.groups.quests_weekly
    local known = group and group.knownWeeklyQuestIDs or {}
    local discovered = DT.db and DT.db.catalog and DT.db.catalog.discoveredWeeklyQuests or {}

    for questID, meta in pairs(known) do
        local title = nil
        if C_QuestLog and C_QuestLog.GetTitleForQuestID then
            title = C_QuestLog.GetTitleForQuestID(questID)
        end
        out[questID] = {
            title = title or (type(meta) == "table" and meta.title) or ("Quest " .. tostring(questID)),
            zone = self:GetQuestZoneText(questID) or (type(meta) == "table" and meta.zone) or nil,
            mapID = self:GetQuestMapID(questID) or (type(meta) == "table" and meta.mapID) or nil,
            npc = type(meta) == "table" and meta.npc or nil,
            x = type(meta) == "table" and meta.x or nil,
            y = type(meta) == "table" and meta.y or nil,
        }
    end

    for questID, meta in pairs(discovered) do
        local title = nil
        if C_QuestLog and C_QuestLog.GetTitleForQuestID then
            title = C_QuestLog.GetTitleForQuestID(questID)
        end
        out[questID] = {
            title = title or (type(meta) == "table" and meta.title) or ("Quest " .. tostring(questID)),
            zone = self:GetQuestZoneText(questID) or (type(meta) == "table" and meta.zone) or nil,
            mapID = self:GetQuestMapID(questID) or (type(meta) == "table" and meta.mapID) or nil,
            npc = type(meta) == "table" and meta.npc or nil,
            x = type(meta) == "table" and meta.x or nil,
            y = type(meta) == "table" and meta.y or nil,
        }
    end

    return out
end

function DT.SourceCatalog:RecordDiscoveredDailyQuest(questID, title, zone, mapID)
    if not questID then
        return false
    end

    local discovered = DT.db and DT.db.catalog and DT.db.catalog.discoveredDailyQuests
    if type(discovered) ~= "table" then
        return false
    end

    local now = nowTime and nowTime() or 0
    local existing = discovered[questID]
    if existing then
        existing.lastSeenAt = now
        if title and title ~= "" then
            existing.title = title
        end
        if zone and zone ~= "" then
            existing.zone = zone
        end
        if type(mapID) == "number" and mapID > 0 then
            existing.mapID = mapID
        end
        return false
    end

    discovered[questID] = {
        title = title or ("Quest " .. tostring(questID)),
        zone = zone,
        mapID = mapID,
        firstSeenAt = now,
        lastSeenAt = now,
    }
    return true
end

function DT.SourceCatalog:RecordDiscoveredDailyQuestMeta(questID, meta)
    if not questID then
        return false
    end

    meta = meta or {}
    local discovered = DT.db and DT.db.catalog and DT.db.catalog.discoveredDailyQuests
    if type(discovered) ~= "table" then
        return false
    end

    local now = nowTime and nowTime() or 0
    local entry = discovered[questID]
    local isNew = false
    if not entry then
        isNew = true
        entry = {
            title = meta.title or ("Quest " .. tostring(questID)),
            firstSeenAt = now,
        }
        discovered[questID] = entry
    end

    entry.lastSeenAt = now
    if meta.title and meta.title ~= "" then entry.title = meta.title end
    if meta.zone and meta.zone ~= "" then entry.zone = meta.zone end
    if type(meta.mapID) == "number" and meta.mapID > 0 then entry.mapID = meta.mapID end
    if meta.npc and meta.npc ~= "" then entry.npc = meta.npc end
    if type(meta.x) == "number" then entry.x = meta.x end
    if type(meta.y) == "number" then entry.y = meta.y end

    return isNew
end

function DT.SourceCatalog:RecordDiscoveredWeeklyQuestMeta(questID, meta)
    if not questID then
        return false
    end

    meta = meta or {}
    local discovered = DT.db and DT.db.catalog and DT.db.catalog.discoveredWeeklyQuests
    if type(discovered) ~= "table" then
        return false
    end

    local now = nowTime and nowTime() or 0
    local entry = discovered[questID]
    local isNew = false
    if not entry then
        isNew = true
        entry = {
            title = meta.title or ("Quest " .. tostring(questID)),
            firstSeenAt = now,
        }
        discovered[questID] = entry
    end

    entry.lastSeenAt = now
    if meta.title and meta.title ~= "" then entry.title = meta.title end
    if meta.zone and meta.zone ~= "" then entry.zone = meta.zone end
    if type(meta.mapID) == "number" and meta.mapID > 0 then entry.mapID = meta.mapID end
    if meta.npc and meta.npc ~= "" then entry.npc = meta.npc end
    if type(meta.x) == "number" then entry.x = meta.x end
    if type(meta.y) == "number" then entry.y = meta.y end

    return isNew
end

function DT.SourceCatalog:GetQuestZoneText(questID)
    local cache = DT.db and DT.db.catalog and DT.db.catalog.questZoneCache
    local cached = cache and cache[questID]
    if type(cached) == "string" and cached ~= "" then
        return cached
    end

    local group = self.groups.quests_daily
    local meta = group and group.knownDailyQuestIDs and group.knownDailyQuestIDs[questID]

    local mapID = self:GetQuestMapID(questID)

    if mapID and mapID ~= 0 and C_Map and C_Map.GetMapInfo then
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.name and mapInfo.name ~= "" then
            if cache then
                cache[questID] = mapInfo.name
            end
            return mapInfo.name
        end
    end

    if type(meta) == "table" and type(meta.zone) == "string" and meta.zone ~= "" then
        return meta.zone
    end

    return nil
end

function DT.SourceCatalog:GetQuestMapID(questID)
    local mapCache = DT.db and DT.db.catalog and DT.db.catalog.questMapCache
    local cachedMapID = mapCache and mapCache[questID]
    if type(cachedMapID) == "number" and cachedMapID > 0 then
        return cachedMapID
    end

    local mapID = nil
    if type(GetQuestUiMapID) == "function" then
        mapID = GetQuestUiMapID(questID)
    end

    if (not mapID or mapID == 0) and type(QuestMapFrame_GetQuestWorldMapAreaID) == "function" then
        mapID = QuestMapFrame_GetQuestWorldMapAreaID(questID)
    end

    if (not mapID or mapID == 0) and C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo then
        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        if logIndex and logIndex > 0 then
            local info = C_QuestLog.GetInfo(logIndex)
            if info then
                mapID = info.questMapID or info.mapID or mapID
            end
        end
    end

    if type(mapID) == "number" and mapID > 0 then
        if mapCache then
            mapCache[questID] = mapID
        end
        return mapID
    end

    return nil
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
