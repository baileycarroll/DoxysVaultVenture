local _, DT = ...

DT.SourceCatalog = DT.SourceCatalog or {}

local DIFFICULTY_NORMAL          = 1
local DIFFICULTY_HEROIC          = 2
local DIFFICULTY_MYTHIC          = 23
local DIFFICULTY_MYTHIC_KEYSTONE = 8

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
        status = "confirmed",
        instanceType = "party",
        difficultyIDs = {
            [DIFFICULTY_NORMAL]          = true,
            [DIFFICULTY_HEROIC]          = true,
            [DIFFICULTY_MYTHIC]          = true,
            [DIFFICULTY_MYTHIC_KEYSTONE] = true,
        },
        knownInstances = {
            ["Magister's Terrace:1"]  = { name = "Magister's Terrace", difficultyName = "Normal", difficultyID = 1  },
            ["Magister's Terrace:2"]  = { name = "Magister's Terrace", difficultyName = "Heroic", difficultyID = 2  },
            ["Magister's Terrace:23"] = { name = "Magister's Terrace", difficultyName = "Mythic", difficultyID = 23 },
            ["Magister's Terrace:8"]  = { name = "Magister's Terrace", difficultyName = "M+",     difficultyID = 8  },
            ["Miasara Caverns:1"]  = { name = "Miasara Caverns", difficultyName = "Normal", difficultyID = 1  },
            ["Miasara Caverns:2"]  = { name = "Miasara Caverns", difficultyName = "Heroic", difficultyID = 2  },
            ["Miasara Caverns:23"] = { name = "Miasara Caverns", difficultyName = "Mythic", difficultyID = 23 },
            ["Miasara Caverns:8"]  = { name = "Miasara Caverns", difficultyName = "M+",     difficultyID = 8  },
            ["Nexus-Point Xenas:1"]  = { name = "Nexus-Point Xenas", difficultyName = "Normal", difficultyID = 1  },
            ["Nexus-Point Xenas:2"]  = { name = "Nexus-Point Xenas", difficultyName = "Heroic", difficultyID = 2  },
            ["Nexus-Point Xenas:23"] = { name = "Nexus-Point Xenas", difficultyName = "Mythic", difficultyID = 23 },
            ["Nexus-Point Xenas:8"]  = { name = "Nexus-Point Xenas", difficultyName = "M+",     difficultyID = 8  },
            ["Windrunner Spire:1"]  = { name = "Windrunner Spire", difficultyName = "Normal", difficultyID = 1  },
            ["Windrunner Spire:2"]  = { name = "Windrunner Spire", difficultyName = "Heroic", difficultyID = 2  },
            ["Windrunner Spire:23"] = { name = "Windrunner Spire", difficultyName = "Mythic", difficultyID = 23 },
            ["Windrunner Spire:8"]  = { name = "Windrunner Spire", difficultyName = "M+",     difficultyID = 8  },
        },
    },

    -- ── Other Midnight Gear Dungeons (non-M+ rotation) ───────────────────────
    dungeons_midnight_gear = {
        label = "Midnight Gear Dungeons",
        status = "confirmed",
        instanceType = "party",
        difficultyIDs = {
            [DIFFICULTY_NORMAL] = true,
            [DIFFICULTY_HEROIC] = true,
            [DIFFICULTY_MYTHIC] = true,
        },
        knownInstances = {
            ["Den of Nalorakk:1"]  = { name = "Den of Nalorakk", difficultyName = "Normal", difficultyID = 1  },
            ["Den of Nalorakk:2"]  = { name = "Den of Nalorakk", difficultyName = "Heroic", difficultyID = 2  },
            ["Den of Nalorakk:23"] = { name = "Den of Nalorakk", difficultyName = "Mythic", difficultyID = 23 },
            ["Murder Row:1"]  = { name = "Murder Row", difficultyName = "Normal", difficultyID = 1  },
            ["Murder Row:2"]  = { name = "Murder Row", difficultyName = "Heroic", difficultyID = 2  },
            ["Murder Row:23"] = { name = "Murder Row", difficultyName = "Mythic", difficultyID = 23 },
            ["The Blinding Vale:1"]  = { name = "The Blinding Vale", difficultyName = "Normal", difficultyID = 1  },
            ["The Blinding Vale:2"]  = { name = "The Blinding Vale", difficultyName = "Heroic", difficultyID = 2  },
            ["The Blinding Vale:23"] = { name = "The Blinding Vale", difficultyName = "Mythic", difficultyID = 23 },
            ["Voidscar Arena:1"]  = { name = "Voidscar Arena", difficultyName = "Normal", difficultyID = 1  },
            ["Voidscar Arena:2"]  = { name = "Voidscar Arena", difficultyName = "Heroic", difficultyID = 2  },
            ["Voidscar Arena:23"] = { name = "Voidscar Arena", difficultyName = "Mythic", difficultyID = 23 },
        },
    },

    -- ── Bonus Dungeons: accessible now, gear unlocks March 17 ────────────────
    dungeons_midnight_bonus = {
        label = "Midnight Bonus Dungeons (Gear: 3/17)",
        status = "confirmed",
        instanceType = "party",
        difficultyIDs = {
            [DIFFICULTY_NORMAL] = true,
            [DIFFICULTY_HEROIC] = true,
            [DIFFICULTY_MYTHIC] = true,
        },
        knownInstances = {
            ["Algeth'ar Academy:1"]  = { name = "Algeth'ar Academy", difficultyName = "Normal", difficultyID = 1  },
            ["Algeth'ar Academy:2"]  = { name = "Algeth'ar Academy", difficultyName = "Heroic", difficultyID = 2  },
            ["Algeth'ar Academy:23"] = { name = "Algeth'ar Academy", difficultyName = "Mythic", difficultyID = 23 },
            ["Seat of the Triumvirate:1"]  = { name = "Seat of the Triumvirate", difficultyName = "Normal", difficultyID = 1  },
            ["Seat of the Triumvirate:2"]  = { name = "Seat of the Triumvirate", difficultyName = "Heroic", difficultyID = 2  },
            ["Seat of the Triumvirate:23"] = { name = "Seat of the Triumvirate", difficultyName = "Mythic", difficultyID = 23 },
            ["Skyreach:1"]  = { name = "Skyreach", difficultyName = "Normal", difficultyID = 1  },
            ["Skyreach:2"]  = { name = "Skyreach", difficultyName = "Heroic", difficultyID = 2  },
            ["Skyreach:23"] = { name = "Skyreach", difficultyName = "Mythic", difficultyID = 23 },
            ["Pit of Saron:1"]  = { name = "Pit of Saron", difficultyName = "Normal", difficultyID = 1  },
            ["Pit of Saron:2"]  = { name = "Pit of Saron", difficultyName = "Heroic", difficultyID = 2  },
            ["Pit of Saron:23"] = { name = "Pit of Saron", difficultyName = "Mythic", difficultyID = 23 },
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
end

-- Ordered list used by FindGroupForInstance for dungeon lookup
DT.SourceCatalog.dungeonGroupOrder = {
    "dungeons_mplus_rotation",
    "dungeons_midnight_gear",
    "dungeons_midnight_bonus",
}

function DT.SourceCatalog:FindGroupForInstance(name, difficultyID)
    local sig = string.format("%s:%s", tostring(name), tostring(difficultyID))
    for _, groupKey in ipairs(self.dungeonGroupOrder) do
        local group = self.groups[groupKey]
        if group and group.knownInstances and group.knownInstances[sig] then
            if DT:IsGroupEnabled(groupKey) and self:IsGroupTrackable(groupKey) then
                return groupKey
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
