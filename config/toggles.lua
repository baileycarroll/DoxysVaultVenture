local _, DT = ...

DT.Config = DT.Config or {}

DT.Config.defaults = {
    schemaVersion = 1,
    settings = {
        characterFirst = true,
        allowPossibleSources = false,
        hidePossibleSources = true,
        raidAutoEnableDate = "2026-03-17",
        clearLootOnInstanceReset = false,
        showMapButton = true,
        dungeonVisibility = {
            expansions = {},
            dungeons = {},
        },
        groupToggles = {
            quests_daily = true,
            quests_weekly = true,
            dungeons_mplus_rotation = true,
            dungeons_midnight_gear = true,
            dungeons_midnight_bonus = true,
            raids_midnight_s1 = false,
            delves_bountiful = false,
            knowledge_weekly = true,
        },
    },
}

local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function DT.Config:ApplyDefaults(db)
    CopyDefaults(db, self.defaults)
end
