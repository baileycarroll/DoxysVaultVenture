local _, DT = ...

local Commands = {}
DT.Commands = Commands

local strsplit = _G["strsplit"]
local SlashCmdList = _G["SlashCmdList"]

local function CountEntries(tbl)
    local n = 0
    for _ in pairs(tbl or {}) do
        n = n + 1
    end
    return n
end

local function PrintStatus()
    if not DT.CharacterTracker then
        return
    end

    local character = DT.CharacterTracker:GetCharacterData()
    if not character then
        return
    end

    local tracking = character.tracking
    DT:Print("Character: " .. (character.meta.name or "Unknown") .. "-" .. (character.meta.realm or "Unknown"))
    DT:Print("Daily quests: " .. CountEntries(tracking.dailyQuests))
    DT:Print("Weekly quests: " .. CountEntries(tracking.weeklyQuests))
    DT:Print("Weekly knowledge: " .. CountEntries(tracking.weeklyKnowledge))
    DT:Print("Dungeon clears: " .. CountEntries(tracking.dungeonClears))
    DT:Print("Raid clears: " .. CountEntries(tracking.raidClears))
end

local function PrintGroups()
    DT:Print("Trackable groups:")
    local keys = DT.SourceCatalog:GetVisibleGroupKeys()
    for _, key in ipairs(keys) do
        local group = DT.SourceCatalog:GetGroup(key)
        local enabled = DT:IsGroupEnabled(key) and "ON" or "OFF"
        DT:Print(string.format("- %s (%s)", key, enabled))
        if group and group.status ~= "confirmed" then
            DT:Print("  hidden")
        end
    end
end

local function ToggleGroup(groupKey, explicit)
    local group = DT.SourceCatalog:GetGroup(groupKey)
    if not group then
        DT:Print("Unknown group: " .. tostring(groupKey))
        return
    end

    if not DT.SourceCatalog:IsGroupTrackable(groupKey) then
        DT:Print("Group is not trackable yet.")
        return
    end

    local current = DT:IsGroupEnabled(groupKey)
    local nextValue = explicit
    if nextValue == nil then
        nextValue = not current
    end

    DT:SetGroupEnabled(groupKey, nextValue)
    DT:Print(string.format("%s -> %s", groupKey, nextValue and "ON" or "OFF"))
end

local function HandleSlash(msg)
    local command, arg1, arg2 = strsplit(" ", (msg or ""), 3)
    command = string.lower(command or "")

    if command == "" then
        if DT.TrackerFrame then
            DT.TrackerFrame:Toggle()
        else
            PrintStatus()
        end
        return
    end

    if command == "show" then
        if DT.TrackerFrame then DT.TrackerFrame:Show() end
        return
    end

    if command == "hide" then
        if DT.TrackerFrame then DT.TrackerFrame:Hide() end
        return
    end

    if command == "status" then
        PrintStatus()
        return
    end

    if command == "groups" then
        PrintGroups()
        return
    end

    if command == "toggle" and arg1 and arg1 ~= "" then
        local normalized = string.lower(arg1)
        if arg2 == "on" then
            ToggleGroup(normalized, true)
            return
        end
        if arg2 == "off" then
            ToggleGroup(normalized, false)
            return
        end
        ToggleGroup(normalized)
        return
    end

    if command == "scan" then
        if DT.InstanceTracker and DT.InstanceTracker.RequestSavedInstancesUpdate then
            DT.InstanceTracker:RequestSavedInstancesUpdate()
            if DT.InstanceTracker.ScanSavedInstances then
                DT.InstanceTracker:ScanSavedInstances()
            end
            DT:Print("Instance scan requested.")
        end
        return
    end

    DT:Print("/doxy           - toggle tracker window")
    DT:Print("/doxy show|hide - open or close window")
    DT:Print("/doxy status    - print summary to chat")
    DT:Print("/doxy groups    - list tracked groups")
    DT:Print("/doxy toggle <group> [on|off]")
    DT:Print("/doxy scan      - rescan instance lockouts")
end

function Commands:InitializeSlashCommands()
    SLASH_DOXYTRACKER1 = "/doxy"
    SlashCmdList.DOXYTRACKER = HandleSlash
end

DT:RegisterModule("Commands", Commands)
Commands:InitializeSlashCommands()
