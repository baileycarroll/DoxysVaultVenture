local _, DT = ...

local Commands = {}
DT.Commands = Commands

local strsplit = _G["strsplit"]
local SlashCmdList = _G["SlashCmdList"]
local CreateFrame = _G["CreateFrame"]
local UIParent = _G["UIParent"]
local date = _G["date"]
local GetNumSavedInstances = _G["GetNumSavedInstances"]
local GetSavedInstanceInfo = _G["GetSavedInstanceInfo"]
local GetDifficultyInfo = _G["GetDifficultyInfo"]

local dumpUI = {
    frame = nil,
    editBox = nil,
}

local function UIObjCall(obj, method, ...)
    if not obj then
        return nil
    end
    local fn = obj[method]
    if type(fn) == "function" then
        return fn(obj, ...)
    end
    return nil
end

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

local function DifficultyLabel(difficultyID, difficultyName)
    if difficultyName and difficultyName ~= "" then
        return tostring(difficultyName)
    end
    if GetDifficultyInfo then
        local label = GetDifficultyInfo(tonumber(difficultyID) or 0)
        if label and label ~= "" then
            return tostring(label)
        end
    end
    return tostring(difficultyID or "?")
end

local function FindGroupForInstanceRaw(canonicalName, difficultyID)
    local catalog = DT.SourceCatalog
    if not catalog or not catalog.groups then
        return nil
    end

    local ordered = catalog.dungeonGroupOrder or {
        "dungeons_mplus_rotation",
        "dungeons_midnight_gear",
        "dungeons_midnight_bonus",
    }

    for _, groupKey in ipairs(ordered) do
        local group = catalog.groups[groupKey]
        if group and group.knownInstances then
            for _, instance in pairs(group.knownInstances) do
                if type(instance) == "table"
                    and tostring(instance.name or "") == tostring(canonicalName or "")
                    and tonumber(instance.difficultyID) == tonumber(difficultyID)
                then
                    return groupKey
                end
            end
        end
    end

    return nil
end

local function BuildMidnightDumpText()
    local lines = {}
    lines[#lines + 1] = "-- Doxy Midnight Diagnostics Dump"
    lines[#lines + 1] = "generatedAt=" .. tostring(date and date("%Y-%m-%d %H:%M:%S") or "unknown")

    local character = DT.CharacterTracker and DT.CharacterTracker.GetCharacterData and
    DT.CharacterTracker:GetCharacterData() or nil
    local tracking = character and character.tracking or {}
    local settings = DT.db and DT.db.settings or {}

    lines[#lines + 1] = string.format("character=%s-%s",
        tostring(character and character.meta and character.meta.name or "Unknown"),
        tostring(character and character.meta and character.meta.realm or "Unknown"))

    lines[#lines + 1] = string.format("setting.clearLootOnInstanceReset=%s",
        tostring(settings.clearLootOnInstanceReset == true))
    lines[#lines + 1] = string.format("setting.showMapButton=%s", tostring(settings.showMapButton ~= false))

    local groupKeys = {
        "dungeons_mplus_rotation",
        "dungeons_midnight_gear",
        "dungeons_midnight_bonus",
    }
    lines[#lines + 1] = "groups:"
    for _, groupKey in ipairs(groupKeys) do
        local enabled = DT.IsGroupEnabled and DT:IsGroupEnabled(groupKey) or false
        local trackable = DT.SourceCatalog and DT.SourceCatalog.IsGroupTrackable and
        DT.SourceCatalog:IsGroupTrackable(groupKey) or false
        local visible = DT.SourceCatalog and DT.SourceCatalog.IsGroupVisible and
        DT.SourceCatalog:IsGroupVisible(groupKey) or false
        lines[#lines + 1] = string.format("  %s enabled=%s trackable=%s visible=%s",
            groupKey,
            tostring(enabled),
            tostring(trackable),
            tostring(visible))
    end

    local dungeonClears = tracking and tracking.dungeonClears or {}
    local clearRows = {}
    for sig, payload in pairs(dungeonClears) do
        payload = type(payload) == "table" and payload or {}
        clearRows[#clearRows + 1] = {
            sig = tostring(sig),
            name = tostring(payload.name or "Unknown"),
            difficultyID = tonumber(payload.difficultyID) or 0,
            difficultyName = payload.difficultyName,
            mapID = tonumber(payload.mapID) or 0,
            keyLevel = tonumber(payload.keyLevel) or 0,
        }
    end
    table.sort(clearRows, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        end
        if a.difficultyID ~= b.difficultyID then
            return a.difficultyID < b.difficultyID
        end
        return a.sig < b.sig
    end)

    lines[#lines + 1] = string.format("dungeonClears.count=%d", #clearRows)
    for _, row in ipairs(clearRows) do
        local rawGroup = FindGroupForInstanceRaw(row.name, row.difficultyID)
        local matchedGroup = DT.SourceCatalog and DT.SourceCatalog.FindGroupForInstance and
        DT.SourceCatalog:FindGroupForInstance(row.name, row.difficultyID) or nil
        local isVisible = DT.SourceCatalog and DT.SourceCatalog.IsDungeonVisible and
        DT.SourceCatalog:IsDungeonVisible(row.name) or false
        lines[#lines + 1] = string.format(
            "  clear sig=%s name=%s diff=%d(%s) map=%d key=%d rawGroup=%s matchedGroup=%s visible=%s",
            row.sig,
            row.name,
            row.difficultyID,
            DifficultyLabel(row.difficultyID, row.difficultyName),
            row.mapID,
            row.keyLevel,
            tostring(rawGroup or "nil"),
            tostring(matchedGroup or "nil"),
            tostring(isVisible)
        )
    end

    local knownDungeons = tracking and tracking.knownDungeons or {}
    local knownRows = {}
    for sig, payload in pairs(knownDungeons) do
        payload = type(payload) == "table" and payload or {}
        knownRows[#knownRows + 1] = {
            sig = tostring(sig),
            name = tostring(payload.name or "Unknown"),
            difficultyID = tonumber(payload.difficultyID) or 0,
            difficultyName = payload.difficultyName,
        }
    end
    table.sort(knownRows, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.difficultyID < b.difficultyID
    end)

    lines[#lines + 1] = string.format("knownDungeons.count=%d", #knownRows)
    for _, row in ipairs(knownRows) do
        lines[#lines + 1] = string.format("  known sig=%s name=%s diff=%d(%s)",
            row.sig,
            row.name,
            row.difficultyID,
            DifficultyLabel(row.difficultyID, row.difficultyName))
    end

    local weeklyDungeonLoot = tracking and tracking.weeklyDungeonLoot or {}
    lines[#lines + 1] = "weeklyDungeonLoot:"
    for dungeonName, lootRows in pairs(weeklyDungeonLoot) do
        local count = (type(lootRows) == "table") and #lootRows or 0
        lines[#lines + 1] = string.format("  %s lootCount=%d", tostring(dungeonName), count)
    end

    lines[#lines + 1] = "savedInstances.party:"
    local n = (GetNumSavedInstances and GetNumSavedInstances()) or 0
    for i = 1, n do
        local name, lockoutID, reset, difficultyID, locked, _, _, isRaid, _, difficultyName, numEncounters, encounterProgress =
            GetSavedInstanceInfo(i)
        if locked and name and not isRaid then
            local canonical = DT.SourceCatalog and DT.SourceCatalog.GetCanonicalDungeonName and
                DT.SourceCatalog:GetCanonicalDungeonName(name) or
                tostring(name)
            local rawGroup = FindGroupForInstanceRaw(canonical, difficultyID)
            local matchedGroup = DT.SourceCatalog and DT.SourceCatalog.FindGroupForInstance and
            DT.SourceCatalog:FindGroupForInstance(canonical, difficultyID) or nil
            lines[#lines + 1] = string.format(
                "  idx=%d lockoutID=%s name=%s canonical=%s diff=%d(%s) reset=%s encounters=%s/%s rawGroup=%s matchedGroup=%s",
                i,
                tostring(lockoutID),
                tostring(name),
                tostring(canonical),
                tonumber(difficultyID) or 0,
                DifficultyLabel(difficultyID, difficultyName),
                tostring(reset),
                tostring(encounterProgress or 0),
                tostring(numEncounters or 0),
                tostring(rawGroup or "nil"),
                tostring(matchedGroup or "nil")
            )
        end
    end

    return table.concat(lines, "\n")
end

local function EnsureDumpDialog()
    if dumpUI.frame then
        return dumpUI.frame
    end

    local frame = CreateFrame("Frame", "DoxyTrackerDebugDumpDialog", UIParent, "BackdropTemplate")
    frame:SetSize(700, 500)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    title:SetText("Midnight Diagnostics Dump")

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -40)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 16)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(620)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    editBox:SetScript("OnTextChanged", function(self)
        self:SetCursorPosition(0)
        self:HighlightText()
    end)
    scroll:SetScrollChild(editBox)

    frame.editBox = editBox
    dumpUI.frame = frame
    dumpUI.editBox = editBox
    return frame
end

local function ShowDumpDialog(text)
    local frame = EnsureDumpDialog()
    UIObjCall(frame, "Show")
    UIObjCall(dumpUI.editBox, "SetText", tostring(text or ""))
    UIObjCall(dumpUI.editBox, "HighlightText")
    UIObjCall(dumpUI.editBox, "SetFocus")
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

    if command == "dump" then
        if DT.InstanceTracker and DT.InstanceTracker.RequestSavedInstancesUpdate then
            DT.InstanceTracker:RequestSavedInstancesUpdate()
        end
        if DT.InstanceTracker and DT.InstanceTracker.ScanSavedInstances then
            DT.InstanceTracker:ScanSavedInstances()
        end

        local mode = string.lower(tostring(arg1 or "midnight"))
        if mode == "midnight" or mode == "dungeons" or mode == "" then
            local text = BuildMidnightDumpText()
            ShowDumpDialog(text)
            DT:Print("Midnight diagnostics dump generated. Copy from the dialog and share it.")
            return
        end

        DT:Print("Unknown dump mode. Use: /doxy dump midnight")
        return
    end

    DT:Print("/doxy           - toggle tracker window")
    DT:Print("/doxy show|hide - open or close window")
    DT:Print("/doxy status    - print summary to chat")
    DT:Print("/doxy groups    - list tracked groups")
    DT:Print("/doxy toggle <group> [on|off]")
    DT:Print("/doxy scan      - rescan instance lockouts")
    DT:Print("/doxy dump midnight - generate copyable midnight dungeon diagnostics")
end

function Commands:InitializeSlashCommands()
    SLASH_DOXYTRACKER1 = "/doxy"
    SlashCmdList.DOXYTRACKER = HandleSlash
end

DT:RegisterModule("Commands", Commands)
Commands:InitializeSlashCommands()
