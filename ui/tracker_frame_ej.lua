local _, DT = ...

DT.TrackerFrame = DT.TrackerFrame or {}

local CreateFrame = _G["CreateFrame"]
local UIParent = _G["UIParent"]
local C_Timer = _G["C_Timer"]
local date = _G["date"]
local GetRealZoneText = _G["GetRealZoneText"]
local GetSubZoneText = _G["GetSubZoneText"]
local UIDropDownMenu_SetWidth = _G["UIDropDownMenu_SetWidth"]
local UIDropDownMenu_SetText = _G["UIDropDownMenu_SetText"]
local UIDropDownMenu_Initialize = _G["UIDropDownMenu_Initialize"]
local UIDropDownMenu_CreateInfo = _G["UIDropDownMenu_CreateInfo"]
local UIDropDownMenu_AddButton = _G["UIDropDownMenu_AddButton"]
local C_Map = _G["C_Map"]
local C_SuperTrack = _G["C_SuperTrack"]
local C_QuestLog = _G["C_QuestLog"]
local UiMapPoint = _G["UiMapPoint"]
local function t_unpack(t)
    if table and table.unpack then
        return table.unpack(t)
    end

    return t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8]
end

local ICON_DONE = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t"
local ICON_MISSING = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14:0:0|t"
local ICON_NEUTRAL = "|cff666666-|r"

local function UIText(key, fallback)
    local cfg = DT and DT.UI_TEXT
    if cfg and cfg[key] and cfg[key] ~= "" then
        return cfg[key]
    end
    return fallback
end

local TAB_ORDER = {
    { key = "dungeons", label = UIText("TAB_DUNGEONS", "Dungeons") },
    { key = "mplus",    label = UIText("TAB_MPLUS", "Mythic+") },
    { key = "daily",    label = UIText("TAB_DAILY", "Daily Quests") },
    { key = "weekly",   label = UIText("TAB_WEEKLY", "Weekly Quests") },
    { key = "raids",    label = UIText("TAB_RAIDS", "Raids") },
    { key = "settings", label = UIText("TAB_SETTINGS", "Settings") },
}

local LEFT_ROW_H = 28
local LEFT_LIST_BUFFER = 2
local MAX_CARD_POOL = 18

local COLORS = {
    bg = { 0.03, 0.03, 0.04, 0.96 },
    inset = { 0.05, 0.05, 0.06, 0.95 },
    panel = { 0.08, 0.08, 0.09, 0.92 },
    panelEdge = { 0.26, 0.20, 0.10, 0.85 },
    card = { 0.15, 0.11, 0.07, 0.92 },
    card2 = { 0.17, 0.13, 0.08, 0.92 },
    activeTab = { 0.20, 0.15, 0.07, 0.95 },
    activeTabEdge = { 0.85, 0.70, 0.20, 0.9 },
    inactiveTab = { 0.08, 0.08, 0.09, 0.95 },
    inactiveTabEdge = { 0.20, 0.20, 0.22, 0.8 },
}

local SETTINGS_ABOUT = {
    name = "Doxy's Vault & Venture",
    author = "Doxy",
    version = "0.0.1",
    lastUpdated = "2026-03-14",
    notes =
    "Initial release of add-on. Tracks daily and weekly quests, dungeon and raid progress, and more. Feedback and suggestions welcome! This is still a work in progress, so expect some rough edges. Thanks for trying it out!",
}

local state = {
    activeTab = "dungeons",
    selectedDungeon = nil,
    selectedRaid = nil,
    dungeonExpansionFilter = "midnight",
    raidExpansionFilter = "all",
    mplusSelectedRunKey = nil,
    dungeonNames = {},
    dungeonsByName = {},
    dungeonDoneCount = 0,
    dungeonTotalCount = 0,
    raidNames = {},
    raidsByName = {},
    raidDoneCount = 0,
    raidTotalCount = 0,
    dungeonCacheDirty = true,
    raidCacheDirty = true,
}

local ui = {
    frame = nil,
    leftButtons = {},
    cards = {},
    difficultyRows = {},
    detailLootRows = {},
    settingsChecks = {},
    tabs = {},
    leftScrollOffset = 0,
    exportContext = nil,
}

local refreshPending = false
local Rebuild, UpdateLeftList, UpdateDungeonCards, UpdateRaidCards, ScheduleRebuild

local function GetExpansionFilterOptions()
    local source = DT.SourceCatalog and DT.SourceCatalog.GetExpansionOptions and DT.SourceCatalog:GetExpansionOptions() or
        {}
    local out = {}
    local seen = {}

    local function push(key, label)
        if not key or key == "" or seen[key] then
            return
        end
        seen[key] = true
        out[#out + 1] = {
            key = key,
            label = label or key,
        }
    end

    for _, option in ipairs(source) do
        if option.key == "midnight" then
            push(option.key, option.label)
        end
    end

    for _, option in ipairs(source) do
        if option.key ~= "midnight" then
            push(option.key, option.label)
        end
    end

    push("all", "All Expansions")
    return out
end

local function GetRaidFilterOptions()
    return (DT.SourceCatalog and DT.SourceCatalog.GetRaidExpansionOptions and DT.SourceCatalog:GetRaidExpansionOptions()) or
        {
            { key = "all", label = "All Expansions" },
        }
end

local function EnsureExpansionFilterValid()
    local options = GetExpansionFilterOptions()
    for _, option in ipairs(options) do
        if option.key == state.dungeonExpansionFilter then
            return
        end
    end

    state.dungeonExpansionFilter = "midnight"
    if #options > 0 then
        local hasMidnight = false
        for _, option in ipairs(options) do
            if option.key == "midnight" then
                hasMidnight = true
                break
            end
        end
        if not hasMidnight then
            state.dungeonExpansionFilter = options[1].key
        end
    end
end

local function EnsureRaidFilterValid()
    local options = GetRaidFilterOptions()
    for _, option in ipairs(options) do
        if option.key == state.raidExpansionFilter then
            return
        end
    end
    state.raidExpansionFilter = "all"
end

local function FrameCall(frame, method)
    if not frame then return nil end
    local fn = frame[method]
    if type(fn) == "function" then
        return fn(frame)
    end
    return nil
end

local function IsShown(frame)
    return frame and FrameCall(frame, "IsShown") == true
end

local function ApplyLeftButtonStyle(btn, selected, hovered)
    if selected then
        btn:SetBackdropColor(0.23, 0.17, 0.08, 0.95)
        btn:SetBackdropBorderColor(0.90, 0.72, 0.22, 0.95)
        btn.text:SetTextColor(1.0, 0.92, 0.45)
        return
    end

    if hovered then
        btn:SetBackdropColor(0.14, 0.12, 0.10, 0.94)
        btn:SetBackdropBorderColor(0.62, 0.52, 0.24, 0.90)
        btn.text:SetTextColor(0.96, 0.90, 0.76)
        return
    end

    btn:SetBackdropColor(0.10, 0.10, 0.12, 0.92)
    btn:SetBackdropBorderColor(0.22, 0.22, 0.24, 0.80)
    btn.text:SetTextColor(0.84, 0.88, 0.94)
end

local function MakePanel(parent)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(t_unpack(COLORS.panel))
    panel:SetBackdropBorderColor(t_unpack(COLORS.panelEdge))
    return panel
end

local function MakeCard(parent)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    card:SetBackdropColor(t_unpack(COLORS.card))
    card:SetBackdropBorderColor(0.30, 0.22, 0.12, 0.95)

    local shine = card:CreateTexture(nil, "ARTWORK")
    shine:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
    shine:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 1)
    shine:SetTexture("Interface\\Buttons\\WHITE8x8")
    shine:SetVertexColor(t_unpack(COLORS.card2))
    shine:SetAlpha(0.35)

    return card
end

local function DifficultySlot(difficultyID, difficultyName)
    if difficultyID == 8 then return "MPLUS" end
    if difficultyID == 23 then return "M" end
    if difficultyID == 2 then return "H" end
    if difficultyID == 1 then return "N" end

    local name = string.lower(tostring(difficultyName or ""))
    if string.find(name, "keystone") or string.find(name, "mythic%+") then return "MPLUS" end
    if string.find(name, "mythic") then return "M" end
    if string.find(name, "heroic") then return "H" end
    if string.find(name, "normal") then return "N" end
    if string.find(name, "lfg") or string.find(name, "random") then return "LFG" end

    return nil
end

local function IsDungeonDifficultySlot(slot)
    return slot == "N" or slot == "H" or slot == "M"
end

local function RaidDifficultySlot(difficultyID, difficultyName)
    local id = tonumber(difficultyID) or 0
    if id == 3 or id == 4 or id == 14 then return "N" end
    if id == 5 or id == 6 or id == 15 then return "H" end
    if id == 16 then return "M" end

    local name = string.lower(tostring(difficultyName or ""))
    if string.find(name, "mythic") then return "M" end
    if string.find(name, "heroic") then return "H" end
    if string.find(name, "normal") then return "N" end

    return nil
end

local function DungeonCellText(row, slot)
    if slot == "MPLUS" and row.done.MPLUS and row.bestKey and row.bestKey > 0 then
        return string.format("|cff44ff44+%d|r", row.bestKey)
    end
    if row.done[slot] then return ICON_DONE end
    if row.known[slot] then return ICON_MISSING end
    return ICON_NEUTRAL
end

local function BuildDungeonModel(char)
    local model = {
        names = {},
        byName = {},
        doneCount = 0,
        totalCount = 0,
    }

    if not char or not char.tracking then
        return model
    end

    local doneStore = char.tracking.dungeonClears or {}
    local lootStore = char.tracking.weeklyDungeonLoot or {}
    local allDungeons = DT.SourceCatalog and DT.SourceCatalog.GetAllDungeonEntries and
        DT.SourceCatalog:GetAllDungeonEntries() or {}

    local function ensure(name)
        local canonical = name
        if DT.SourceCatalog and DT.SourceCatalog.GetCanonicalDungeonName then
            canonical = DT.SourceCatalog:GetCanonicalDungeonName(name)
        end
        local key = tostring(canonical or "Unknown")
        local row = model.byName[key]
        if not row then
            row = {
                name = key,
                known = { LFG = false, N = false, H = false, M = false, MPLUS = false },
                done = { LFG = false, N = false, H = false, M = false, MPLUS = false },
                bestKey = 0,
                lootCount = 0,
            }
            model.byName[key] = row
        end
        return row
    end

    for _, dungeon in ipairs(allDungeons) do
        local expansionMatch = (state.dungeonExpansionFilter == "all" or state.dungeonExpansionFilter == dungeon.expansionKey)
        local isVisible = true
        if DT.SourceCatalog and DT.SourceCatalog.IsDungeonVisible then
            isVisible = DT.SourceCatalog:IsDungeonVisible(dungeon.name)
        end

        if expansionMatch and isVisible then
            local row = ensure(dungeon.name)
            row.lootCount = #(lootStore[row.name] or {})
            for difficultyID in pairs(dungeon.difficulties or {}) do
                local slot = DifficultySlot(difficultyID)
                if slot and IsDungeonDifficultySlot(slot) then
                    row.known[slot] = true
                end
            end
        end
    end

    for _, entry in pairs(doneStore) do
        local dungeonName = (type(entry) == "table" and entry.name) or "Unknown"
        if DT.SourceCatalog and DT.SourceCatalog.GetCanonicalDungeonName then
            dungeonName = DT.SourceCatalog:GetCanonicalDungeonName(dungeonName)
        end

        -- Use the row created by the first loop as the authority on filter membership.
        -- This avoids a mismatch where GetDungeonExpansionInfo returns a hardcoded
        -- group expansion key (e.g. "midnight_s1") that differs from the Journal-derived
        -- key used by GetAllDungeonEntries (e.g. "midnight"), causing clears to be
        -- silently dropped when the two keys don't match the active filter.
        local row = model.byName[dungeonName]
        if row then
            local slot = DifficultySlot(type(entry) == "table" and entry.difficultyID,
                type(entry) == "table" and entry.difficultyName)
            if slot and IsDungeonDifficultySlot(slot) then
                row.done[slot] = true
                row.known[slot] = true
            end
        end
    end

    for name, _ in pairs(model.byName) do
        table.insert(model.names, name)
    end
    table.sort(model.names)

    for _, name in ipairs(model.names) do
        local row = model.byName[name]
        for _, slot in ipairs({ "N", "H", "M" }) do
            if row.known[slot] then
                model.totalCount = model.totalCount + 1
                if row.done[slot] then
                    model.doneCount = model.doneCount + 1
                end
            end
        end
    end

    return model
end

local function BuildRaidModel(char)
    local model = {
        names = {},
        byName = {},
        doneCount = 0,
        totalCount = 0,
    }

    if not char or not char.tracking then
        return model
    end

    local clears = char.tracking.raidClears or {}
    local bossStore = char.tracking.weeklyRaidBossKills or {}
    local lootStore = char.tracking.weeklyRaidLoot or {}
    local allRaids = DT.SourceCatalog and DT.SourceCatalog.GetKnownRaidMap and DT.SourceCatalog:GetKnownRaidMap() or {}
    local filter = state.raidExpansionFilter or "all"

    local function parseMoneyToCopper(text)
        local lower = string.lower(tostring(text or ""))
        if lower == "" then
            return 0
        end

        local function pick(pattern)
            local n = lower:match(pattern)
            n = tostring(n or ""):gsub(",", "")
            return tonumber(n) or 0
        end

        local gold = pick("(%d[%d,]*)%s*gold")
        local silver = pick("(%d[%d,]*)%s*silver")
        local copper = pick("(%d[%d,]*)%s*copper")

        if gold == 0 and silver == 0 and copper == 0 then
            gold = pick("(%d[%d,]*)%s*g")
            silver = pick("(%d[%d,]*)%s*s")
            copper = pick("(%d[%d,]*)%s*c")
        end

        return (gold * 10000) + (silver * 100) + copper
    end

    local function includeExpansion(expansionKey)
        return filter == "all" or expansionKey == filter
    end

    local function ensure(name)
        local key = tostring(name or "Unknown Raid")
        local row = model.byName[key]
        if not row then
            row = {
                name = key,
                known = { N = false, H = false, M = false },
                done = { N = false, H = false, M = false },
                encountersDone = 0,
                encountersTotal = 0,
                bossKills = 0,
                lootCount = 0,
                lootBySlot = {
                    N = { items = {}, moneyCopper = 0 },
                    H = { items = {}, moneyCopper = 0 },
                    M = { items = {}, moneyCopper = 0 },
                },
            }
            model.byName[key] = row
        end
        return row
    end

    for raidName, raidInfo in pairs(allRaids) do
        local expansionKey = type(raidInfo) == "table" and raidInfo.expansionKey or nil
        if includeExpansion(expansionKey) then
            local row = ensure(raidName)
            for _, difficultyID in ipairs((type(raidInfo) == "table" and raidInfo.difficultyIDs) or {}) do
                local slot = RaidDifficultySlot(difficultyID)
                if slot then
                    row.known[slot] = true
                end
            end
        end
    end

    for _, entry in pairs(clears) do
        if type(entry) == "table" and entry.name then
            local expansionKey = (DT.SourceCatalog and DT.SourceCatalog.GetRaidExpansionInfo and select(1, DT.SourceCatalog:GetRaidExpansionInfo(entry.name))) or
                nil
            if includeExpansion(expansionKey) then
                local slot = RaidDifficultySlot(entry.difficultyID, entry.difficultyName)
                if slot then
                    local row = ensure(entry.name)
                    row.known[slot] = true
                    row.done[slot] = true
                    row.encountersDone = math.max(row.encountersDone, tonumber(entry.encounterProgress) or 0)
                    row.encountersTotal = math.max(row.encountersTotal, tonumber(entry.numEncounters) or 0)
                end
            end
        end
    end

    local function splitRaidKey(key)
        local text = tostring(key or "")
        local name, diff = text:match("^(.*):(%-?%d+)$")
        return name, tonumber(diff)
    end

    for key, kills in pairs(bossStore) do
        local raidName, diff = splitRaidKey(key)
        local expansionKey = (DT.SourceCatalog and DT.SourceCatalog.GetRaidExpansionInfo and raidName and select(1, DT.SourceCatalog:GetRaidExpansionInfo(raidName))) or
            nil
        if raidName and type(kills) == "table" and includeExpansion(expansionKey) then
            local row = ensure(raidName)
            row.bossKills = row.bossKills + #kills
        end
    end

    for key, loot in pairs(lootStore) do
        local raidName, diff = splitRaidKey(key)
        local slot = RaidDifficultySlot(diff)
        local expansionKey = (DT.SourceCatalog and DT.SourceCatalog.GetRaidExpansionInfo and raidName and select(1, DT.SourceCatalog:GetRaidExpansionInfo(raidName))) or
            nil
        if raidName and slot and type(loot) == "table" and includeExpansion(expansionKey) then
            local row = ensure(raidName)
            local bucket = row.lootBySlot[slot]
            for _, entry in ipairs(loot) do
                local text = type(entry) == "table" and tostring(entry.text or "") or tostring(entry or "")
                if text ~= "" then
                    local copper = parseMoneyToCopper(text)
                    if copper > 0 then
                        bucket.moneyCopper = (bucket.moneyCopper or 0) + copper
                    else
                        bucket.items[#bucket.items + 1] = text
                    end
                    row.lootCount = row.lootCount + 1
                end
            end
        end
    end

    for name, row in pairs(model.byName) do
        local hasKnown = false
        for _, slot in ipairs({ "N", "H", "M" }) do
            if row.known[slot] then
                hasKnown = true
                model.totalCount = model.totalCount + 1
                if row.done[slot] then
                    model.doneCount = model.doneCount + 1
                end
            end
        end
        if hasKnown then
            model.names[#model.names + 1] = name
        end
    end

    table.sort(model.names)
    return model
end

local function EnsureDungeonModel(char)
    EnsureExpansionFilterValid()
    if state.dungeonCacheDirty then
        local model = BuildDungeonModel(char)
        state.dungeonNames = model.names
        state.dungeonsByName = model.byName
        state.dungeonDoneCount = model.doneCount
        state.dungeonTotalCount = model.totalCount
        state.dungeonCacheDirty = false

        if not state.selectedDungeon or not state.dungeonsByName[state.selectedDungeon] then
            state.selectedDungeon = state.dungeonNames[1]
        end
    end
end

local function EnsureRaidModel(char)
    EnsureRaidFilterValid()
    if state.raidCacheDirty then
        local model = BuildRaidModel(char)
        state.raidNames = model.names
        state.raidsByName = model.byName
        state.raidDoneCount = model.doneCount
        state.raidTotalCount = model.totalCount
        state.raidCacheDirty = false

        if not state.selectedRaid or not state.raidsByName[state.selectedRaid] then
            state.selectedRaid = state.raidNames[1]
        end
    end
end

local function GetExpansionFilterLabel()
    local options = GetExpansionFilterOptions()
    for _, option in ipairs(options) do
        if option.key == state.dungeonExpansionFilter then
            return option.label or option.key
        end
    end

    return state.dungeonExpansionFilter
end

local function GetRaidFilterLabel()
    local options = GetRaidFilterOptions()
    for _, option in ipairs(options) do
        if option.key == state.raidExpansionFilter then
            return option.label or option.key
        end
    end
    return state.raidExpansionFilter
end

local function GetLeftFilterLabel()
    if state.activeTab == "raids" then
        return GetRaidFilterLabel()
    end
    return GetExpansionFilterLabel()
end

local function RefreshExpansionDropdown()
    if not ui.leftFilter then
        return
    end

    if state.activeTab == "raids" then
        EnsureRaidFilterValid()
    else
        EnsureExpansionFilterValid()
    end
    if UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(ui.leftFilter, GetLeftFilterLabel())
    end
end

local function GetCurrentZoneLabel()
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local subZone = GetSubZoneText and GetSubZoneText() or ""

    zone = tostring(zone or "")
    subZone = tostring(subZone or "")

    if subZone ~= "" and subZone ~= zone then
        return string.format("%s / %s", zone, subZone)
    end

    if zone ~= "" then
        return zone
    end

    return "Unknown Zone"
end

local function EnsureLeftButton(index)
    local btn = ui.leftButtons[index]
    if btn then return btn end

    btn = CreateFrame("Button", nil, ui.leftListChild, "BackdropTemplate")
    btn:SetHeight(LEFT_ROW_H)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.text:SetPoint("LEFT", btn, "LEFT", 8, 0)
    btn.text:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    btn.text:SetJustifyH("LEFT")
    btn.text:SetWordWrap(false)

    local function selectedName()
        return state.activeTab == "raids" and state.selectedRaid or state.selectedDungeon
    end

    btn:SetScript("OnClick", function(self)
        if state.activeTab == "raids" then
            state.selectedRaid = self._rowName
        else
            state.selectedDungeon = self._rowName
        end
        UpdateLeftList()
        if state.activeTab == "raids" then
            UpdateRaidCards()
        else
            UpdateDungeonCards()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        self._hovered = true
        ApplyLeftButtonStyle(self, selectedName() == self._rowName, true)
    end)

    btn:SetScript("OnLeave", function(self)
        self._hovered = false
        ApplyLeftButtonStyle(self, selectedName() == self._rowName, false)
    end)

    ui.leftButtons[index] = btn
    return btn
end

UpdateLeftList = function()
    local names = state.activeTab == "raids" and state.raidNames or state.dungeonNames
    local selected = state.activeTab == "raids" and state.selectedRaid or state.selectedDungeon
    local total = #names
    local scrollH = FrameCall(ui.leftScroll, "GetHeight") or 0
    local visibleRows = math.max(1, math.floor(scrollH / LEFT_ROW_H) + LEFT_LIST_BUFFER)
    local startIndex = math.floor((ui.leftScrollOffset or 0) / LEFT_ROW_H) + 1

    for i = 1, visibleRows do
        local btn = EnsureLeftButton(i)
        local rowIndex = startIndex + i - 1
        local rowName = names[rowIndex]

        if rowName then
            local y = -2 - ((rowIndex - 1) * LEFT_ROW_H)

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", ui.leftListChild, "TOPLEFT", 0, y)
            btn:SetPoint("TOPRIGHT", ui.leftListChild, "TOPRIGHT", 0, y)

            btn._rowName = rowName
            btn.text:SetText(rowName)

            ApplyLeftButtonStyle(btn, selected == rowName, btn._hovered)
            btn:Show()
        else
            btn:Hide()
        end
    end

    for i = visibleRows + 1, #ui.leftButtons do
        local btn = ui.leftButtons[i]
        if btn then
            btn:Hide()
        end
    end

    ui.leftListChild:SetHeight(math.max(1, total * LEFT_ROW_H + 4))
end

local function HideAllCards()
    for _, card in ipairs(ui.cards) do
        card:Hide()
    end
end

local function UpdateDifficultyTable()
    local row = state.dungeonsByName[state.selectedDungeon]
    local slots = {
        { key = "N", label = "Normal" },
        { key = "H", label = "Heroic" },
        { key = "M", label = "Mythic" },
    }

    for i = 1, #ui.difficultyRows do
        local line = ui.difficultyRows[i]
        local slotInfo = slots[i]
        if not slotInfo then
            line:Hide()
        elseif row then
            line.label:SetText(slotInfo.label)
            line.value:SetText(DungeonCellText(row, slotInfo.key))
            line:Show()
        else
            line.label:SetText(slotInfo.label)
            line.value:SetText(ICON_NEUTRAL)
            line:Show()
        end
    end
end

local function RaidCellText(row, slot)
    if row.done[slot] then return ICON_DONE end
    if row.known[slot] then return ICON_MISSING end
    return ICON_NEUTRAL
end

local function FormatMoneyFromCopper(totalCopper)
    local value = tonumber(totalCopper) or 0
    if value <= 0 then
        return "0c"
    end
    local gold = math.floor(value / 10000)
    local silver = math.floor((value % 10000) / 100)
    local copper = value % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = string.format("%dg", gold) end
    if silver > 0 then parts[#parts + 1] = string.format("%ds", silver) end
    if copper > 0 or #parts == 0 then parts[#parts + 1] = string.format("%dc", copper) end
    return table.concat(parts, " ")
end

local function SlotLabel(slot)
    if slot == "N" then return "Normal" end
    if slot == "H" then return "Heroic" end
    if slot == "M" then return "Mythic" end
    if slot == "MPLUS" then return "Mythic+" end
    return tostring(slot or "?")
end

local function DungeonLootSlot(difficultyID, difficultyName, source)
    if source == "mplus" then
        return "MPLUS"
    end

    local id = tonumber(difficultyID) or 0
    if id == 23 then return "M" end
    if id == 2 then return "H" end
    if id == 1 then return "N" end
    if id == 8 then return "MPLUS" end

    local name = string.lower(tostring(difficultyName or ""))
    if string.find(name, "keystone") or string.find(name, "mythic%+") then return "MPLUS" end
    if string.find(name, "mythic") then return "M" end
    if string.find(name, "heroic") then return "H" end
    if string.find(name, "normal") then return "N" end

    return "N"
end

local function BuildRaidLootDetailsText(row)
    if not row or not row.lootBySlot then
        return "Loot by difficulty: none recorded"
    end

    local lines = {}
    for _, slot in ipairs({ "N", "H", "M" }) do
        local bucket = row.lootBySlot[slot] or { items = {}, moneyCopper = 0 }
        local itemCount = #(bucket.items or {})
        local moneyText = FormatMoneyFromCopper(bucket.moneyCopper)

        if itemCount > 0 or (bucket.moneyCopper or 0) > 0 then
            local preview = ""
            if itemCount > 0 then
                local first = tostring(bucket.items[1] or "")
                if itemCount > 1 then
                    preview = string.format(" • %s (+%d)", first, itemCount - 1)
                else
                    preview = string.format(" • %s", first)
                end
            end
            lines[#lines + 1] = string.format("%s: %d item(s), %s%s", SlotLabel(slot), itemCount, moneyText, preview)
        end
    end

    if #lines == 0 then
        return "Loot by difficulty: none recorded"
    end

    return "Loot by difficulty\n" .. table.concat(lines, "\n")
end

local function ParseRaidSessionKey(key)
    local text = tostring(key or "")
    local name, diff = text:match("^(.*):(%-?%d+)$")
    return name, tonumber(diff)
end

local function BuildSelectedRaidLootEntries(raidName, tracking)
    local out = {}
    local aggregated = {}
    if not raidName or raidName == "" then
        return out
    end

    local function norm(value)
        local text = string.lower(tostring(value or ""))
        text = text:gsub("’", "'")
        text = text:gsub("`", "'")
        text = text:gsub("[^%w']+", " ")
        text = text:gsub("^%s+", "")
        text = text:gsub("%s+$", "")
        text = text:gsub("%s+", " ")
        return text
    end

    local wanted = norm(raidName)

    local store = (tracking and tracking.weeklyRaidLoot) or {}
    for key, list in pairs(store) do
        local name, diffID = ParseRaidSessionKey(key)
        local slot = RaidDifficultySlot(diffID)
        if norm(name) == wanted and slot and type(list) == "table" then
            for _, row in ipairs(list) do
                local text = (type(row) == "table" and tostring(row.text or "")) or tostring(row or "")
                local stamp = (type(row) == "table" and tonumber(row.addedAt)) or 0
                if text ~= "" then
                    local itemName = type(row) == "table" and row.itemName or nil
                    local itemLink = type(row) == "table" and row.itemLink or nil
                    local quantity = type(row) == "table" and tonumber(row.quantity) or nil
                    if quantity and quantity <= 0 then
                        quantity = 1
                    end

                    local qty = quantity or 1
                    local key
                    if (itemLink and itemLink ~= "") or (itemName and itemName ~= "") then
                        key = string.format("%s|%s", tostring(slot), tostring(itemLink or itemName))
                    else
                        key = string.format("%s|%s|%s", tostring(slot), tostring(text), tostring(stamp))
                    end

                    local existing = aggregated[key]
                    if existing then
                        existing.quantity = (tonumber(existing.quantity) or 0) + qty
                        if stamp > (tonumber(existing.addedAt) or 0) then
                            existing.addedAt = stamp
                        end
                    else
                        local entry = {
                            slot = slot,
                            text = text,
                            itemName = itemName,
                            itemLink = itemLink,
                            quantity = qty,
                            addedAt = stamp,
                        }
                        aggregated[key] = entry
                        out[#out + 1] = entry
                    end
                end
            end
        end
    end

    table.sort(out, function(a, b)
        local ta = tonumber(a.addedAt) or 0
        local tb = tonumber(b.addedAt) or 0
        if ta ~= tb then
            return ta > tb
        end
        if a.slot ~= b.slot then
            return tostring(a.slot) < tostring(b.slot)
        end
        return tostring(a.text) < tostring(b.text)
    end)

    return out
end

local function BuildSelectedDungeonLootEntries(dungeonName, tracking)
    local out = {}
    local aggregated = {}
    if not dungeonName or dungeonName == "" then
        return out
    end

    local list = ((tracking and tracking.weeklyDungeonLoot) or {})[dungeonName] or {}
    for _, row in ipairs(list) do
        local text = (type(row) == "table" and tostring(row.text or "")) or tostring(row or "")
        if text ~= "" then
            local itemName = type(row) == "table" and row.itemName or nil
            local itemLink = type(row) == "table" and row.itemLink or nil
            local quantity = type(row) == "table" and tonumber(row.quantity) or 1
            local stamp = (type(row) == "table" and tonumber(row.addedAt)) or 0
            local source = type(row) == "table" and row.source or nil
            local diffID = type(row) == "table" and row.difficultyID or nil
            local diffName = type(row) == "table" and row.difficultyName or nil
            local slot = DungeonLootSlot(diffID, diffName, source)

            local key
            if (itemLink and itemLink ~= "") or (itemName and itemName ~= "") then
                key = string.format("%s|%s", tostring(slot), tostring(itemLink or itemName))
            else
                key = string.format("%s|%s|%s", tostring(slot), tostring(text), tostring(stamp))
            end

            local existing = aggregated[key]
            if existing then
                existing.quantity = (tonumber(existing.quantity) or 0) + (quantity or 1)
                if stamp > (tonumber(existing.addedAt) or 0) then
                    existing.addedAt = stamp
                end
            else
                local entry = {
                    slot = slot,
                    text = text,
                    itemName = itemName,
                    itemLink = itemLink,
                    quantity = quantity or 1,
                    addedAt = stamp,
                }
                aggregated[key] = entry
                out[#out + 1] = entry
            end
        end
    end

    table.sort(out, function(a, b)
        local ta = tonumber(a.addedAt) or 0
        local tb = tonumber(b.addedAt) or 0
        if ta ~= tb then
            return ta > tb
        end
        if a.slot ~= b.slot then
            return tostring(a.slot) < tostring(b.slot)
        end
        return tostring(a.text) < tostring(b.text)
    end)

    return out
end

local function EnsureDetailLootRow(index)
    local row = ui.detailLootRows[index]
    if row then
        return row
    end

    row = CreateFrame("Button", nil, ui.detailLootChild)
    row:SetHeight(20)
    row:SetScript("OnEnter", function(self)
        local link = self._itemLink
        if link and _G["GameTooltip"] and _G["GameTooltip"].SetHyperlink then
            _G["GameTooltip"]:SetOwner(self, "ANCHOR_RIGHT")
            _G["GameTooltip"]:SetHyperlink(link)
            _G["GameTooltip"]:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        if _G["GameTooltip"] then
            _G["GameTooltip"]:Hide()
        end
    end)
    row:SetScript("OnClick", function(self)
        local link = self._itemLink
        if not link then
            return
        end
        if _G["HandleModifiedItemClick"] and _G["HandleModifiedItemClick"](link) then
            return
        end
        if _G["SetItemRef"] then
            _G["SetItemRef"](link, link, "LeftButton", self)
        end
    end)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.08, 0.08, 0.10, 0.72)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    ui.detailLootRows[index] = row
    return row
end

local function RenderDetailLootTable(entries)
    entries = entries or {}
    if not ui.detailLootScroll or not ui.detailLootChild then
        return
    end

    local y = -2
    local shown = 0
    for i, entry in ipairs(entries) do
        local row = EnsureDetailLootRow(i)
        shown = i
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", ui.detailLootChild, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", ui.detailLootChild, "TOPRIGHT", -2, y)
        y = y - 21

        local itemDisplay = entry.itemName
        if not itemDisplay or itemDisplay == "" then
            itemDisplay = entry.itemLink and tostring(entry.itemLink):match("%[([^%]]+)%]") or nil
        end
        if not itemDisplay or itemDisplay == "" then
            itemDisplay = tostring(entry.text or "")
        end
        local qty = tonumber(entry.quantity) or 1
        row.text:SetText(string.format("[%s] - %d - %s", tostring(itemDisplay), qty, SlotLabel(entry.slot)))
        row._itemLink = entry.itemLink
        row:Show()
    end

    if shown == 0 then
        local row = EnsureDetailLootRow(1)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", ui.detailLootChild, "TOPLEFT", 0, -2)
        row:SetPoint("TOPRIGHT", ui.detailLootChild, "TOPRIGHT", -2, -2)
        row.text:SetText("No loot recorded for this raid yet.")
        row._itemLink = nil
        row:Show()
        shown = 1
        y = -23
    end

    for i = shown + 1, #ui.detailLootRows do
        local row = ui.detailLootRows[i]
        if row then
            row:Hide()
        end
    end

    ui.detailLootChild:SetHeight(math.max(1, -y + 4))
    ui.detailLootScroll:SetVerticalScroll(0)
end

local function UpdateRaidDifficultyTable()
    local row = state.raidsByName[state.selectedRaid]
    local slots = {
        { key = "N", label = "Normal" },
        { key = "H", label = "Heroic" },
        { key = "M", label = "Mythic" },
    }

    for i = 1, #ui.difficultyRows do
        local line = ui.difficultyRows[i]
        local slotInfo = slots[i]
        if not slotInfo then
            line:Hide()
        elseif row then
            local bucket = (row.lootBySlot and row.lootBySlot[slotInfo.key]) or { items = {}, moneyCopper = 0 }
            local itemCount = #(bucket.items or {})
            local moneyText = FormatMoneyFromCopper(bucket.moneyCopper)
            line.label:SetText(slotInfo.label)
            line.value:SetText(string.format("%s  %d item(s)  %s", RaidCellText(row, slotInfo.key), itemCount, moneyText))
            line:Show()
        else
            line.label:SetText(slotInfo.label)
            line.value:SetText(ICON_NEUTRAL)
            line:Show()
        end
    end
end

UpdateDungeonCards = function()
    local selected = state.selectedDungeon
    RefreshExpansionDropdown()

    if ui.leftTitle then
        ui.leftTitle:SetText(UIText("LEFT_PANEL_TITLE", "Dungeons"))
    end

    ui.summaryTitle:SetText("Dungeon Overview")
    ui.summarySub:SetText(string.format("%d / %d checks complete  •  Filter: %s", state.dungeonDoneCount,
        state.dungeonTotalCount,
        GetExpansionFilterLabel()))

    if selected then
        local row = state.dungeonsByName[selected]
        local char = DT.CharacterTracker and DT.CharacterTracker:GetCharacterData()
        local tracking = char and char.tracking or {}
        local lootEntries = BuildSelectedDungeonLootEntries(selected, tracking)
        ui.detailTitle:SetText(selected)
        ui.detailSub:SetText(string.format("Difficulty Progress  •  Weekly Loot: %d", row and (row.lootCount or 0) or 0))
        if ui.detailLootTitle then
            ui.detailLootTitle:SetText("Loot Log (all events, grouped by difficulty)")
            ui.detailLootTitle:Show()
        end
        if ui.detailLootScroll then
            ui.detailLootScroll:Show()
        end
        RenderDetailLootTable(lootEntries)
    else
        ui.detailTitle:SetText("No Dungeons Available")
        ui.detailSub:SetText("Enable a dungeon group to populate this list.")
        if ui.detailLootTitle then
            ui.detailLootTitle:SetText("Loot Log")
            ui.detailLootTitle:Show()
        end
        if ui.detailLootScroll then
            ui.detailLootScroll:Show()
        end
        RenderDetailLootTable({})
    end

    UpdateDifficultyTable()
end

UpdateRaidCards = function()
    local selected = state.selectedRaid
    RefreshExpansionDropdown()

    if ui.leftTitle then
        ui.leftTitle:SetText(UIText("TAB_RAIDS", "Raids"))
    end

    ui.summaryTitle:SetText("Raid Overview")
    ui.summarySub:SetText(string.format("%d / %d checks complete  •  Filter: %s", state.raidDoneCount,
        state.raidTotalCount,
        GetRaidFilterLabel()))

    if selected then
        local row = state.raidsByName[selected]
        local char = DT.CharacterTracker and DT.CharacterTracker:GetCharacterData()
        local tracking = char and char.tracking or {}
        local lootEntries = BuildSelectedRaidLootEntries(selected, tracking)
        local progress = (row and row.encountersTotal and row.encountersTotal > 0)
            and string.format("%d/%d bosses", row.encountersDone or 0, row.encountersTotal or 0)
            or "Boss progress unavailable"
        ui.detailTitle:SetText(selected)
        ui.detailSub:SetText(string.format("%s  •  Boss kills: %d  •  Loot events: %d", progress,
            row and (row.bossKills or 0) or 0,
            row and (row.lootCount or 0) or 0))

        if ui.detailLootTitle then
            ui.detailLootTitle:SetText("Loot Log (all events, grouped by difficulty)")
            ui.detailLootTitle:Show()
        end
        if ui.detailLootScroll then
            ui.detailLootScroll:Show()
        end
        RenderDetailLootTable(lootEntries)
    else
        ui.detailTitle:SetText("No Raids Available")
        ui.detailSub:SetText("No raids match current filter.")
        if ui.detailLootTitle then
            ui.detailLootTitle:SetText("Loot Log")
            ui.detailLootTitle:Show()
        end
        if ui.detailLootScroll then
            ui.detailLootScroll:Show()
        end
        RenderDetailLootTable({})
    end

    UpdateRaidDifficultyTable()
end

local function AcquireCard(index)
    local card = ui.cards[index]
    if card then return card end

    card = MakeCard(ui.cardsChild)
    card:SetHeight(58)

    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -8)
    card.title:SetPoint("TOPRIGHT", card, "TOPRIGHT", -90, -8)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(true)

    card.status = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.status:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    card.status:SetJustifyH("RIGHT")

    card.sub = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.sub:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
    card.sub:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -28)
    card.sub:SetJustifyH("LEFT")
    card.sub:SetWordWrap(true)

    card.pin = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
    card.pin:SetSize(34, 16)
    card.pin:SetText("Pin")
    card.pin:SetPoint("RIGHT", card, "RIGHT", -30, 0)
    card.pin:Hide()

    ui.cards[index] = card
    return card
end

local function SetQuestPin(questID, mapID)
    local questMapID = mapID
    if (not questMapID or questMapID == 0) and DT.SourceCatalog and DT.SourceCatalog.GetQuestMapID then
        questMapID = DT.SourceCatalog:GetQuestMapID(questID)
    end

    local inLog = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and
        (C_QuestLog.GetLogIndexForQuestID(questID) or 0) > 0

    if inLog and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        C_SuperTrack.SetSuperTrackedQuestID(questID)
    end

    local waypointPlaced = false
    if C_QuestLog and C_QuestLog.GetNextWaypoint and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        local wpMapID, wpX, wpY = C_QuestLog.GetNextWaypoint(questID)
        if type(wpMapID) == "number" and type(wpX) == "number" and type(wpY) == "number" and wpMapID > 0 then
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(wpMapID, wpX, wpY))
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
            waypointPlaced = true
        end
    end

    if not waypointPlaced and type(questMapID) == "number" and questMapID > 0 and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(questMapID, 0.5, 0.5))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
        waypointPlaced = true
    end

    if DT and DT.Print then
        if waypointPlaced then
            DT:Print(string.format("Pinned quest %d.", tonumber(questID) or 0))
        elseif inLog then
            DT:Print(string.format("Supertracked quest %d.", tonumber(questID) or 0))
        else
            DT:Print(string.format("Quest %d is not in your log yet.", tonumber(questID) or 0))
        end
    end
end

local function SetCardCompact(card, compact)
    if not card then
        return
    end

    if compact then
        card:SetHeight(42)
        card.title:ClearAllPoints()
        card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -7)
        card.title:SetPoint("RIGHT", card, "RIGHT", -76, 0)
        card.title:SetJustifyH("LEFT")
        card.title:SetWordWrap(false)
        card.title:SetFontObject("GameFontHighlight")

        card.status:ClearAllPoints()
        card.status:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        card.status:SetJustifyH("RIGHT")

        card.sub:ClearAllPoints()
        card.sub:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -2)
        card.sub:SetPoint("TOPRIGHT", card, "TOPRIGHT", -76, -22)
        card.sub:SetJustifyH("LEFT")
        card.sub:SetWordWrap(false)
        card.sub:SetFontObject("GameFontHighlightSmall")
        card.sub:Show()
        card.pin:Show()
        return
    end

    card:SetHeight(58)
    card.title:ClearAllPoints()
    card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -8)
    card.title:SetPoint("TOPRIGHT", card, "TOPRIGHT", -90, -8)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(true)
    card.title:SetFontObject("GameFontNormalLarge")

    card.status:ClearAllPoints()
    card.status:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    card.status:SetJustifyH("RIGHT")

    card.sub:ClearAllPoints()
    card.sub:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
    card.sub:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -28)
    card.sub:SetJustifyH("LEFT")
    card.sub:SetWordWrap(true)
    card.sub:Show()
    card.pin:Hide()
end

local function RenderQuestCards(doneStore, knownStore, emptyText)
    HideAllCards()

    doneStore = doneStore or {}
    knownStore = knownStore or {}

    local entries = {}
    local seen = {}

    for id, entry in pairs(doneStore) do
        local knownMeta = knownStore[id]
        entries[#entries + 1] = {
            id = id,
            title = (type(entry) == "table" and (entry.title or entry.name)) or tostring(id),
            zone = (type(entry) == "table" and entry.zone) or (type(knownMeta) == "table" and knownMeta.zone) or nil,
            mapID = (type(entry) == "table" and entry.mapID) or (type(knownMeta) == "table" and knownMeta.mapID) or nil,
            status = "done",
        }
        seen[id] = true
    end

    for id, entry in pairs(knownStore) do
        if not seen[id] then
            entries[#entries + 1] = {
                id = id,
                title = (type(entry) == "table" and (entry.title or entry.name)) or tostring(id),
                zone = type(entry) == "table" and entry.zone or nil,
                mapID = type(entry) == "table" and entry.mapID or nil,
                status = "missing",
            }
        end
    end

    table.sort(entries, function(a, b)
        if a.status ~= b.status then
            return a.status == "done"
        end
        return a.title < b.title
    end)

    if #entries == 0 then
        local card = AcquireCard(1)
        if not card then
            ui.cardsChild:SetHeight(96)
            return
        end
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", ui.cardsChild, "TOPLEFT", 0, -30)
        card:SetPoint("TOPRIGHT", ui.cardsChild, "TOPRIGHT", -4, -30)
        SetCardCompact(card, true)
        card.title:SetText(emptyText or "No entries yet")
        card.sub:SetText("Zone unknown")
        card.status:SetText(ICON_NEUTRAL)
        card.pin:Hide()
        card.pin:SetScript("OnClick", nil)
        card:EnableMouse(false)
        card:SetScript("OnMouseUp", nil)
        card:Show()
        ui.cardsChild:SetHeight(74)
        return
    end

    local maxEntries = #entries
    local y = -30
    for i = 1, maxEntries do
        local entry = entries[i]
        local card = AcquireCard(i)
        if not card then break end
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", ui.cardsChild, "TOPLEFT", 0, y)
        card:SetPoint("TOPRIGHT", ui.cardsChild, "TOPRIGHT", -4, y)
        y = y - 46

        SetCardCompact(card, true)

        card.title:SetText(entry.title)
        card.sub:SetText(entry.zone or "Zone unknown")
        if entry.status == "done" then
            card.status:SetText(ICON_DONE)
        else
            card.status:SetText(ICON_MISSING)
        end

        if state.activeTab == "daily" and entry.id then
            card.pin:Show()
            card.pin:SetScript("OnClick", function()
                SetQuestPin(entry.id, entry.mapID)
            end)
        else
            card.pin:Hide()
            card.pin:SetScript("OnClick", nil)
        end

        card:EnableMouse(false)
        card:SetScript("OnMouseUp", nil)

        card:Show()
    end

    ui.cardsChild:SetHeight(math.max(1, maxEntries * 46 + 34))
end

local function EscapeLuaString(v)
    local s = tostring(v or "")
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, "\"", "\\\"")
    s = string.gsub(s, "\n", "\\n")
    s = string.gsub(s, "\r", "")
    return s
end

local function BuildQuestExportText(tabKey, doneStore, knownStore)
    doneStore = doneStore or {}
    knownStore = knownStore or {}

    local ids = {}
    local seen = {}
    for id in pairs(doneStore) do
        if not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    for id in pairs(knownStore) do
        if not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end

    table.sort(ids, function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if na and nb then
            return na < nb
        end
        if na then return true end
        if nb then return false end
        return tostring(a) < tostring(b)
    end)

    local lines = {}
    lines[#lines + 1] = "-- DoxyTracker quest export"
    lines[#lines + 1] = string.format("-- Tab: %s", tostring(tabKey or "unknown"))
    lines[#lines + 1] = string.format("-- Generated: %s", date("%Y-%m-%d %H:%M:%S"))
    lines[#lines + 1] = string.format("-- Total quests: %d", #ids)
    lines[#lines + 1] = "local exportedQuestData = {"

    for _, id in ipairs(ids) do
        local done = type(doneStore[id]) == "table" and doneStore[id] or {}
        local known = type(knownStore[id]) == "table" and knownStore[id] or {}

        local idNum = tonumber(id)
        local keyText = idNum and ("[" .. tostring(idNum) .. "]") or ("[\"" .. EscapeLuaString(id) .. "\"]")
        local questTitle = done.title or done.name or known.title or known.name or ("Quest " .. tostring(id))
        local zone = done.zone or known.zone
        local npc = done.npc or known.npc
        local mapID = tonumber(done.mapID) or tonumber(known.mapID)
        local x = tonumber(done.x) or tonumber(known.x)
        local y = tonumber(done.y) or tonumber(known.y)
        local completedAt = tonumber(done.completedAt)
        local completed = doneStore[id] ~= nil

        lines[#lines + 1] = string.format("    %s = {", keyText)
        lines[#lines + 1] = string.format("        id = %s,",
            idNum and tostring(idNum) or ("\"" .. EscapeLuaString(id) .. "\""))
        lines[#lines + 1] = string.format("        title = \"%s\",", EscapeLuaString(questTitle))
        if zone and zone ~= "" then
            lines[#lines + 1] = string.format("        zone = \"%s\",", EscapeLuaString(zone))
        end
        if npc and npc ~= "" then
            lines[#lines + 1] = string.format("        npc = \"%s\",", EscapeLuaString(npc))
        end
        if mapID then
            lines[#lines + 1] = string.format("        mapID = %d,", mapID)
        end
        if x then
            lines[#lines + 1] = string.format("        x = %.5f,", x)
        end
        if y then
            lines[#lines + 1] = string.format("        y = %.5f,", y)
        end
        lines[#lines + 1] = string.format("        completed = %s,", completed and "true" or "false")
        if completedAt then
            lines[#lines + 1] = string.format("        completedAt = %d,", completedAt)
        end
        lines[#lines + 1] = "    },"
    end

    lines[#lines + 1] = "}"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "return exportedQuestData"

    return table.concat(lines, "\n")
end

local function EnsureExportDialog()
    if ui.exportDialog then
        return ui.exportDialog
    end

    local dialog = CreateFrame("Frame", "DoxyTrackerQuestExportDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(650, 520)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dialog:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
    dialog:SetBackdropBorderColor(0.90, 0.72, 0.22, 0.95)
    dialog:Hide()

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -12)
    title:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -42, -12)
    title:SetJustifyH("LEFT")
    title:SetText("Quest Export")
    dialog.title = title

    local subtitle = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -42, -4)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Copy this Lua table for hardcoded quest data.")

    local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -4, -4)

    local scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -50)
    scroll:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -36, 46)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetAutoFocus(true)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(560)
    editBox:SetScript("OnEscapePressed", function()
        dialog:Hide()
    end)
    scroll:SetScrollChild(editBox)
    dialog.scroll = scroll
    dialog.editBox = editBox

    local selectAll = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    selectAll:SetSize(94, 22)
    selectAll:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 14, 12)
    selectAll:SetText("Select All")
    selectAll:SetScript("OnClick", function()
        dialog.editBox:SetFocus()
        dialog.editBox:HighlightText()
    end)

    local done = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    done:SetSize(74, 22)
    done:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -14, 12)
    done:SetText("Close")
    done:SetScript("OnClick", function()
        dialog:Hide()
    end)

    ui.exportDialog = dialog
    return dialog
end

local function ShowQuestExportDialog(tabKey, doneStore, knownStore)
    local dialog = EnsureExportDialog()
    local label = (tabKey == "daily") and UIText("TAB_DAILY", "Daily Quests") or UIText("TAB_WEEKLY", "Weekly Quests")
    dialog.title:SetText(string.format("%s Export", label))

    local text = BuildQuestExportText(tabKey, doneStore, knownStore)
    dialog.editBox:SetText(text)

    local lineCount = 1
    for _ in string.gmatch(text, "\n") do
        lineCount = lineCount + 1
    end
    dialog.editBox:SetHeight(math.max(420, lineCount * 14 + 20))
    dialog.editBox:SetCursorPosition(0)
    dialog.scroll:SetVerticalScroll(0)

    dialog:Show()
    dialog.editBox:SetFocus()
    dialog.editBox:HighlightText()
end

local function SetQuestExportContext(tabKey, doneStore, knownStore)
    local visible = tabKey == "daily" or tabKey == "weekly"
    if ui.exportButton then
        ui.exportButton:SetShown(visible)
    end

    if visible then
        ui.exportContext = {
            tab = tabKey,
            done = doneStore or {},
            known = knownStore or {},
        }
    else
        ui.exportContext = nil
    end
end

local function RenderInfoCards(entries, emptyTitle, emptySub)
    HideAllCards()

    entries = entries or {}

    if #entries == 0 then
        local card = AcquireCard(1)
        if not card then
            ui.cardsChild:SetHeight(96)
            return
        end
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", ui.cardsChild, "TOPLEFT", 0, -30)
        card:SetPoint("TOPRIGHT", ui.cardsChild, "TOPRIGHT", -4, -30)
        SetCardCompact(card, false)
        card.title:SetText(emptyTitle or "No entries")
        card.sub:SetText(emptySub or "No information available.")
        card.status:SetText(ICON_NEUTRAL)
        card:EnableMouse(false)
        card:SetScript("OnMouseUp", nil)
        card:Show()
        ui.cardsChild:SetHeight(96)
        return
    end

    local maxEntries = math.min(#entries, MAX_CARD_POOL)
    local y = -30
    for i = 1, maxEntries do
        local entry = entries[i]
        local card = AcquireCard(i)
        if not card then break end
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", ui.cardsChild, "TOPLEFT", 0, y)
        card:SetPoint("TOPRIGHT", ui.cardsChild, "TOPRIGHT", -4, y)
        y = y - 64

        SetCardCompact(card, false)

        card.title:SetText(entry.title or "Entry")
        card.sub:SetText(entry.sub or "")
        card.status:SetText(entry.status or ICON_NEUTRAL)
        card:EnableMouse(false)
        card:SetScript("OnMouseUp", nil)
        card:Show()
    end

    if #entries > MAX_CARD_POOL then
        local card = AcquireCard(MAX_CARD_POOL)
        if card then
            card.title:SetText(string.format("And %d more...", #entries - (MAX_CARD_POOL - 1)))
            card.sub:SetText("Refine filters or expand UI in a future update.")
            card.status:SetText(ICON_NEUTRAL)
        end
    end

    ui.cardsChild:SetHeight(math.max(1, maxEntries * 64 + 34))
end

local function RenderToggleCards(entries, emptyTitle, emptySub)
    HideAllCards()

    entries = entries or {}
    if #entries == 0 then
        RenderInfoCards({}, emptyTitle, emptySub)
        return
    end

    local maxEntries = math.min(#entries, MAX_CARD_POOL)
    local y = -30
    for i = 1, maxEntries do
        local entry = entries[i]
        local card = AcquireCard(i)
        if not card then break end

        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", ui.cardsChild, "TOPLEFT", 0, y)
        card:SetPoint("TOPRIGHT", ui.cardsChild, "TOPRIGHT", -4, y)
        y = y - 64

        SetCardCompact(card, false)

        card.title:SetText(entry.title or "Entry")
        card.sub:SetText(entry.sub or "")
        card.status:SetText(entry.status or ICON_NEUTRAL)
        card:EnableMouse(type(entry.onToggle) == "function")
        card:SetScript("OnMouseUp", function()
            if type(entry.onToggle) == "function" then
                entry.onToggle()
            end
        end)
        card:Show()
    end

    ui.cardsChild:SetHeight(math.max(1, maxEntries * 64 + 34))
end

local function CompareMPlusRuns(a, b)
    local keyA = tonumber(a and a.keyLevel) or 0
    local keyB = tonumber(b and b.keyLevel) or 0
    if keyA ~= keyB then
        return keyA > keyB
    end

    local timedA = (a and (a.timed == true or a.timed == 1)) and 1 or 0
    local timedB = (b and (b.timed == true or b.timed == 1)) and 1 or 0
    if timedA ~= timedB then
        return timedA > timedB
    end

    local timeA = tonumber(a and a.completionTimeMS) or 2147483647
    local timeB = tonumber(b and b.completionTimeMS) or 2147483647
    if timeA ~= timeB then
        return timeA < timeB
    end

    return (tonumber(a and a.completedAt) or 0) > (tonumber(b and b.completedAt) or 0)
end

local function SortedRunsCopy(runs)
    local out = {}
    for _, run in ipairs(runs or {}) do
        if type(run) == "table" then
            out[#out + 1] = run
        end
    end
    table.sort(out, CompareMPlusRuns)
    return out
end

local function BuildMPlusEntries(tracking)
    local runsByDungeon = (tracking and tracking.mplusRuns) or {}
    local targetNames = DT.SourceCatalog and DT.SourceCatalog.GetSeasonOneDungeonNames and
        DT.SourceCatalog:GetSeasonOneDungeonNames() or {}
    local entries = {}
    local pool = {}
    local timedCount = 0
    local totalRuns = 0
    local activeDungeonCount = 0

    for _, dungeonName in ipairs(targetNames) do
        local runs = SortedRunsCopy(runsByDungeon[dungeonName] or {})
        totalRuns = totalRuns + #runs
        if #runs > 0 then
            activeDungeonCount = activeDungeonCount + 1
            for _, run in ipairs(runs) do
                if run.timed == true or run.timed == 1 then
                    timedCount = timedCount + 1
                end
            end
            pool[#pool + 1] = runs[1]
        end
    end

    entries[#entries + 1] = {
        title = "Mythic+ Summary",
        sub = string.format("%d seasonal dungeons active  •  %d total runs  •  %d timed",
            activeDungeonCount, totalRuns, timedCount),
        status = ICON_NEUTRAL,
    }

    entries[#entries + 1] = {
        title = "Top 4 Seasonal Runs",
        sub = "Ranked by key level, then timed runs, then fastest clear.",
        status = ICON_NEUTRAL,
    }

    table.sort(pool, CompareMPlusRuns)

    for i = 1, math.min(4, #pool) do
        local run = pool[i]
        local runKey = string.format("%s|%s|%s|%s", tostring(run.name or ""), tostring(run.keyLevel or 0),
            tostring(run.completionTimeMS or 0), tostring(run.completedAt or 0))
        local lootList = run.loot or {}
        local lootSummary
        if #lootList > 0 then
            local preview = tostring(lootList[1] or "")
            if #lootList > 1 then
                lootSummary = string.format("Loot: %s (+%d)", preview, #lootList - 1)
            else
                lootSummary = string.format("Loot: %s", preview)
            end
        else
            lootSummary = "Loot: none recorded"
        end

        local timerText = (run.timed == true or run.timed == 1) and "Timed" or "Untimed"
        local mins = math.floor((tonumber(run.completionTimeMS) or 0) / 60000)
        local secs = math.floor(((tonumber(run.completionTimeMS) or 0) % 60000) / 1000)
        local stamp = tonumber(run.completedAt) or 0
        local when = (date and stamp > 0) and date("%m/%d %H:%M", stamp) or "Unknown time"
        local selected = (state.mplusSelectedRunKey == runKey)

        entries[#entries + 1] = {
            title = string.format("#%d  %s  •  +%d%s", i, tostring(run.name or "Unknown"), tonumber(run.keyLevel) or 0,
                selected and "  [Selected]" or ""),
            sub = string.format("%s  •  %d:%02d  •  %s  •  %s", timerText, mins, secs, when, lootSummary),
            status = ICON_DONE,
            onToggle = function()
                if state.mplusSelectedRunKey == runKey then
                    state.mplusSelectedRunKey = nil
                else
                    state.mplusSelectedRunKey = runKey
                end
                ScheduleRebuild(true)
            end,
        }

        if selected then
            local details
            if #lootList == 0 then
                details = "No personal loot lines captured for this run."
            else
                local lines = {}
                for idx, loot in ipairs(lootList) do
                    lines[#lines + 1] = string.format("%d) %s", idx, tostring(loot))
                end
                details = table.concat(lines, "\n")
            end

            entries[#entries + 1] = {
                title = "Selected Run Details",
                sub = details,
                status = ICON_NEUTRAL,
            }
        end
    end

    if #pool == 0 then
        entries[#entries + 1] = {
            title = "No Mythic+ run yet",
            sub = "Complete a tracked key to populate this section.",
            status = ICON_MISSING,
        }
    end

    entries[#entries + 1] = {
        title = "Season Dungeon Status",
        sub = "Best weekly result by dungeon.",
        status = ICON_NEUTRAL,
    }

    for _, dungeonName in ipairs(targetNames) do
        local runs = SortedRunsCopy(runsByDungeon[dungeonName] or {})
        if #runs == 0 then
            entries[#entries + 1] = {
                title = dungeonName,
                sub = "No Mythic+ run recorded this week.",
                status = ICON_MISSING,
            }
        else
            local best = runs[1]
            local timedText = (best.timed == true or best.timed == 1) and "Timed" or "Untimed"
            local mins = math.floor((tonumber(best.completionTimeMS) or 0) / 60000)
            local secs = math.floor(((tonumber(best.completionTimeMS) or 0) % 60000) / 1000)
            local bestKey = string.format("%s|%s|%s|%s", tostring(best.name or ""), tostring(best.keyLevel or 0),
                tostring(best.completionTimeMS or 0), tostring(best.completedAt or 0))
            local isSelected = state.mplusSelectedRunKey == bestKey

            entries[#entries + 1] = {
                title = string.format("%s%s", dungeonName, isSelected and "  [Selected]" or ""),
                sub = string.format("Best: +%d  •  %s  •  %d:%02d  •  Runs: %d", tonumber(best.keyLevel) or 0,
                    timedText, mins, secs, #runs),
                status = ICON_DONE,
                onToggle = function()
                    if state.mplusSelectedRunKey == bestKey then
                        state.mplusSelectedRunKey = nil
                    else
                        state.mplusSelectedRunKey = bestKey
                    end
                    ScheduleRebuild(true)
                end,
            }
        end
    end

    return entries
end

local function BuildRaidEntries(tracking)
    local byRaidName = {}
    local clears = (tracking and tracking.raidClears) or {}
    local prepop = (DT.SourceCatalog and DT.SourceCatalog.GetKnownRaidMap and DT.SourceCatalog:GetKnownRaidMap()) or {}

    for raidName, row in pairs(prepop) do
        local labels = (type(row) == "table" and row.difficultyLabels) or {}
        byRaidName[raidName] = {
            name = raidName,
            expectedDifficultyCount = #labels,
            expectedDifficultyLabels = labels,
            difficulties = 0,
            seenDifficultyIDs = {},
            encountersDone = 0,
            encountersTotal = 0,
            bossKills = 0,
            lootCount = 0,
        }
    end

    for _, clear in pairs(clears) do
        if type(clear) == "table" then
            local name = tostring(clear.name or "Unknown Raid")
            local row = byRaidName[name]
            if not row then
                row = {
                    name = name,
                    expectedDifficultyCount = 0,
                    expectedDifficultyLabels = {},
                    difficulties = 0,
                    seenDifficultyIDs = {},
                    encountersDone = 0,
                    encountersTotal = 0,
                    bossKills = 0,
                    lootCount = 0,
                }
                byRaidName[name] = row
            end

            local diffID = tonumber(clear.difficultyID) or 0
            if diffID > 0 and not row.seenDifficultyIDs[diffID] then
                row.seenDifficultyIDs[diffID] = true
                row.difficulties = row.difficulties + 1
            end
            row.encountersDone = math.max(row.encountersDone, tonumber(clear.encounterProgress) or 0)
            row.encountersTotal = math.max(row.encountersTotal, tonumber(clear.numEncounters) or 0)
        end
    end

    local function splitRaidKey(key)
        local text = tostring(key or "")
        local name, diff = text:match("^(.*):(%-?%d+)$")
        return name, tonumber(diff)
    end

    local bossStore = (tracking and tracking.weeklyRaidBossKills) or {}
    for key, kills in pairs(bossStore) do
        local raidName = splitRaidKey(key)
        if raidName and type(kills) == "table" then
            local row = byRaidName[raidName]
            if not row then
                row = {
                    name = raidName,
                    expectedDifficultyCount = 0,
                    expectedDifficultyLabels = {},
                    difficulties = 0,
                    seenDifficultyIDs = {},
                    encountersDone = 0,
                    encountersTotal = 0,
                    bossKills = 0,
                    lootCount = 0,
                }
                byRaidName[raidName] = row
            end
            row.bossKills = row.bossKills + #kills
        end
    end

    local lootStore = (tracking and tracking.weeklyRaidLoot) or {}
    for key, lootList in pairs(lootStore) do
        local raidName = splitRaidKey(key)
        if raidName and type(lootList) == "table" then
            local row = byRaidName[raidName]
            if not row then
                row = {
                    name = raidName,
                    expectedDifficultyCount = 0,
                    expectedDifficultyLabels = {},
                    difficulties = 0,
                    seenDifficultyIDs = {},
                    encountersDone = 0,
                    encountersTotal = 0,
                    bossKills = 0,
                    lootCount = 0,
                }
                byRaidName[raidName] = row
            end
            row.lootCount = row.lootCount + #lootList
        end
    end

    local entries = {}
    for _, row in pairs(byRaidName) do
        local progress
        if row.encountersTotal > 0 then
            progress = string.format("%d/%d bosses", row.encountersDone, row.encountersTotal)
        else
            progress = "Boss progress unavailable"
        end

        local diffText
        if row.expectedDifficultyCount and row.expectedDifficultyCount > 0 then
            diffText = string.format("%d/%d difficulties", row.difficulties, row.expectedDifficultyCount)
        else
            diffText = string.format("%d lockout(s) recorded", row.difficulties)
        end

        local bossLootText = string.format("Boss kills: %d  •  Loot: %d", tonumber(row.bossKills) or 0,
            tonumber(row.lootCount) or 0)

        entries[#entries + 1] = {
            title = row.name,
            sub = string.format("%s  •  %s  •  %s", diffText, progress, bossLootText),
            status = row.difficulties > 0 and ICON_DONE or ICON_NEUTRAL,
        }
    end

    table.sort(entries, function(a, b)
        return tostring(a.title) < tostring(b.title)
    end)

    return entries
end

local function BuildSettingsCheckboxItems()
    return {
        {
            key = "clearLootOnInstanceReset",
            label = "Clear loot on instance reset",
            note = "If enabled, reset-instance clears loot logs only for runs with no boss kills.",
        },
        {
            key = "showMapButton",
            label = "Show world map button",
            note = "Displays a quick-open button on the world map.",
        },
    }
end

local function EnsureSettingsCheckbox(index)
    local row = ui.settingsChecks[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, ui.settingsPanel)
    row:SetHeight(38)

    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.label:SetJustifyH("LEFT")

    row.note = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.note:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
    row.note:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.note:SetJustifyH("LEFT")

    ui.settingsChecks[index] = row
    return row
end

local function RenderSettingsView()
    if not ui.settingsPanel then
        return
    end

    local settings = (DT.db and DT.db.settings) or {}
    local addonName = tostring((DT and DT.name) or SETTINGS_ABOUT.name)
    local version = (_G["GetAddOnMetadata"] and _G["GetAddOnMetadata"](addonName, "Version")) or SETTINGS_ABOUT.version
    local author = (_G["GetAddOnMetadata"] and _G["GetAddOnMetadata"](addonName, "Author")) or SETTINGS_ABOUT.author

    if ui.settingsAboutRow then
        ui.settingsAboutRow:SetText(string.format(
            "Add On: %s    |    Author: %s    |    Version: %s    |    Last Updated: %s",
            addonName,
            tostring(author or SETTINGS_ABOUT.author),
            tostring(version or SETTINGS_ABOUT.version),
            tostring(SETTINGS_ABOUT.lastUpdated)))
    end

    if ui.settingsNotesText then
        local notes = UIText("SETTINGS_NOTES", SETTINGS_ABOUT.notes)
        ui.settingsNotesText:SetText(tostring(notes or ""))
    end

    local items = BuildSettingsCheckboxItems()
    local topY = -176
    for i, item in ipairs(items) do
        local row = EnsureSettingsCheckbox(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", ui.settingsPanel, "TOPLEFT", 14, topY - ((i - 1) * 42))
        row:SetPoint("TOPRIGHT", ui.settingsPanel, "TOPRIGHT", -14, topY - ((i - 1) * 42))

        row.label:SetText(item.label)
        row.note:SetText(item.note or "")
        row.check:SetChecked(settings[item.key] == true)
        row.check:SetScript("OnClick", function(self)
            settings[item.key] = self:GetChecked() and true or false
            if item.key == "allowPossibleSources" or item.key == "hidePossibleSources" then
                state.dungeonCacheDirty = true
                state.raidCacheDirty = true
            end
            if item.key == "showMapButton" and DT.MapButton and DT.MapButton.ApplyVisibility then
                DT.MapButton:ApplyVisibility()
            end
            ScheduleRebuild(true)
        end)

        row:Show()
    end

    for i = #items + 1, #ui.settingsChecks do
        local row = ui.settingsChecks[i]
        if row then
            row:Hide()
        end
    end
end

local function GetWeeklyKnowledgeKnown()
    local out = {}
    local group = DT.SourceCatalog:GetGroup("knowledge_weekly")
    local known = group and group.knownWeeklyQuestIDs or {}
    for questID in pairs(known) do
        out[questID] = { title = "Quest " .. tostring(questID) }
    end
    return out
end

local function UpdateTabVisuals()
    for _, tab in ipairs(ui.tabs) do
        local selected = (tab._key == state.activeTab)
        if selected then
            tab:SetBackdropColor(t_unpack(COLORS.activeTab))
            tab:SetBackdropBorderColor(t_unpack(COLORS.activeTabEdge))
            tab.text:SetTextColor(1.0, 0.92, 0.35)
        else
            if tab._hovered then
                tab:SetBackdropColor(0.12, 0.11, 0.09, 0.95)
                tab:SetBackdropBorderColor(0.56, 0.50, 0.26, 0.88)
                tab.text:SetTextColor(0.95, 0.90, 0.72)
            else
                tab:SetBackdropColor(t_unpack(COLORS.inactiveTab))
                tab:SetBackdropBorderColor(t_unpack(COLORS.inactiveTabEdge))
                tab.text:SetTextColor(0.80, 0.84, 0.92)
            end
        end
    end
end

ScheduleRebuild = function(immediate)
    if not ui.frame then return end

    if immediate then
        refreshPending = false
        Rebuild()
        return
    end

    if refreshPending then
        return
    end

    refreshPending = true

    local function doRefresh()
        refreshPending = false
        if IsShown(ui.frame) then
            Rebuild()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.03, doRefresh)
    else
        doRefresh()
    end
end

Rebuild = function()
    if not ui.frame then return end

    local char = DT.CharacterTracker and DT.CharacterTracker:GetCharacterData()
    local subtitle = UIText("HEADER_SUBTITLE", "Midnight Progress")
    local zoneText = GetCurrentZoneLabel()
    if char and char.meta then
        ui.headerSub:SetText(string.format("%s  •  %s - %s  •  %s", subtitle, char.meta.name or "?",
            char.meta.realm or "?", zoneText))
    else
        ui.headerSub:SetText(string.format("%s  •  %s", subtitle, zoneText))
    end

    UpdateTabVisuals()

    local isInstanceTab = (state.activeTab == "dungeons" or state.activeTab == "raids")
    local isSettingsTab = state.activeTab == "settings"
    ui.leftPanel:SetShown(isInstanceTab)
    ui.rightPanel:SetShown(isInstanceTab)
    ui.cardsScroll:SetShown((not isInstanceTab) and (not isSettingsTab))
    if ui.settingsPanel then
        ui.settingsPanel:SetShown(isSettingsTab)
    end

    if state.activeTab == "dungeons" then
        SetQuestExportContext(nil)
        EnsureDungeonModel(char)
        UpdateLeftList()
        UpdateDungeonCards()
        return
    end

    if state.activeTab == "raids" then
        SetQuestExportContext(nil)
        EnsureRaidModel(char)
        UpdateLeftList()
        UpdateRaidCards()
        return
    end

    local tracking = char and char.tracking or {}
    if state.activeTab == "mplus" then
        SetQuestExportContext(nil)
        ui.cardsHeader:SetText(UIText("TAB_MPLUS", "Mythic+"))
        local ok, entriesOrErr = pcall(BuildMPlusEntries, tracking)
        if ok then
            RenderToggleCards(entriesOrErr, "No Mythic+ runs recorded",
                "Complete a tracked S1 key to populate top-4 runs.")
        else
            RenderInfoCards({
                {
                    title = "Mythic+ data issue",
                    sub = "Detected older or invalid run data. New runs will self-heal this view.",
                    status = ICON_MISSING,
                },
            }, "No Mythic+ runs recorded", tostring(entriesOrErr))
        end
    elseif state.activeTab == "daily" then
        ui.cardsHeader:SetText(UIText("TAB_DAILY", "Daily Quests"))
        local dailyDone = tracking.dailyQuests or {}
        local dailyKnown = (DT.QuestTracker and DT.QuestTracker.knownDaily) or {}
        SetQuestExportContext("daily", dailyDone, dailyKnown)
        RenderQuestCards(dailyDone, dailyKnown,
            "No daily quests discovered")
    elseif state.activeTab == "weekly" then
        ui.cardsHeader:SetText(UIText("TAB_WEEKLY", "Weekly Quests"))

        local weeklyDone = tracking.weeklyQuests or {}
        local weeklyKnown = (DT.QuestTracker and DT.QuestTracker.knownWeekly) or {}

        local mergedDone = {}
        local mergedKnown = {}
        for id, v in pairs(weeklyDone) do mergedDone[id] = v end
        for id, v in pairs(weeklyKnown) do mergedKnown[id] = v end

        if DT:IsGroupEnabled("knowledge_weekly") and DT.SourceCatalog:IsGroupVisible("knowledge_weekly") then
            local knowledgeDone = tracking.weeklyKnowledge or {}
            local knowledgeKnown = GetWeeklyKnowledgeKnown()
            for id, v in pairs(knowledgeDone) do mergedDone[id] = v end
            for id, v in pairs(knowledgeKnown) do mergedKnown[id] = v end
        end

        SetQuestExportContext("weekly", mergedDone, mergedKnown)
        RenderQuestCards(mergedDone, mergedKnown, "No weekly quests discovered")
    else
        SetQuestExportContext(nil)
        RenderSettingsView()
    end
end

local function Layout()
    if not ui.frame then return end

    local w = FrameCall(ui.frame, "GetWidth") or 820
    local h = FrameCall(ui.frame, "GetHeight") or 620

    ui.tabPanel:ClearAllPoints()
    ui.tabPanel:SetPoint("BOTTOMLEFT", ui.frame, "BOTTOMLEFT", 14, 10)
    ui.tabPanel:SetPoint("BOTTOMRIGHT", ui.frame, "BOTTOMRIGHT", -14, 10)
    ui.tabPanel:SetHeight(24)

    local tabPanelWidth = FrameCall(ui.tabPanel, "GetWidth") or (w - 28)
    local tabWidth = math.floor((tabPanelWidth - (8 * (#TAB_ORDER - 1))) / #TAB_ORDER)
    for i, tab in ipairs(ui.tabs) do
        tab:ClearAllPoints()
        tab:SetSize(tabWidth, 24)
        tab:SetPoint("LEFT", ui.tabPanel, "LEFT", (i - 1) * (tabWidth + 8), 0)
    end

    local topY = -56
    local bottomY = 42

    ui.leftPanel:ClearAllPoints()
    local leftW = math.max(185, math.min(280, math.floor(w * 0.33)))
    ui.leftPanel:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 10, topY)
    ui.leftPanel:SetPoint("BOTTOMLEFT", ui.frame, "BOTTOMLEFT", 10, bottomY)
    ui.leftPanel:SetWidth(leftW)

    ui.rightPanel:ClearAllPoints()
    ui.rightPanel:SetPoint("TOPLEFT", ui.leftPanel, "TOPRIGHT", 10, 0)
    ui.rightPanel:SetPoint("BOTTOMRIGHT", ui.frame, "BOTTOMRIGHT", -12, bottomY)

    ui.cardsScroll:ClearAllPoints()
    ui.cardsScroll:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 10, topY)
    ui.cardsScroll:SetPoint("BOTTOMRIGHT", ui.frame, "BOTTOMRIGHT", -28, bottomY)

    if ui.settingsPanel then
        ui.settingsPanel:ClearAllPoints()
        ui.settingsPanel:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 10, topY)
        ui.settingsPanel:SetPoint("BOTTOMRIGHT", ui.frame, "BOTTOMRIGHT", -12, bottomY)
    end

    local cardsWidth = (FrameCall(ui.cardsScroll, "GetWidth") or (w - 46)) - 24
    if ui.cardsChild then
        ui.cardsChild:SetWidth(math.max(160, cardsWidth))
    end

    if ui.detailLootScroll and ui.detailLootChild then
        local lootWidth = (FrameCall(ui.detailLootScroll, "GetWidth") or 280) - 24
        ui.detailLootChild:SetWidth(math.max(140, lootWidth))
    end

    local listWidth = (FrameCall(ui.leftScroll, "GetWidth") or (leftW - 26)) - 2
    ui.leftListChild:SetWidth(math.max(120, listWidth))

    local maxScroll = math.max(0,
        (FrameCall(ui.leftListChild, "GetHeight") or 0) - (FrameCall(ui.leftScroll, "GetHeight") or 0))
    if ui.leftScrollOffset > maxScroll then
        ui.leftScrollOffset = maxScroll
        if ui.leftScroll and ui.leftScroll.SetVerticalScroll then
            ui.leftScroll:SetVerticalScroll(ui.leftScrollOffset)
        end
    end

    if ui.rightPanel and ui.detailCard then
        ui.detailCard:SetHeight(math.max(180, math.floor((h - 170) * 0.56)))
    end
end

local function Build()
    if ui.frame then return end

    local frame = CreateFrame("Frame", "DoxyTrackerMainFrame", UIParent, "BasicFrameTemplateWithInset")
    ui.frame = frame

    frame:SetSize(820, 620)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(700, 500, 1300, 900)
    else
        if frame.SetMinResize then
            frame:SetMinResize(700, 500)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(1300, 900)
        end
    end
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")
    frame:Hide()

    frame.TitleText:SetText(UIText("WINDOW_TITLE", "DoxyTracker"))
    if frame.Bg then
        frame.Bg:SetVertexColor(t_unpack(COLORS.bg))
    end
    if frame.Inset and frame.Inset.Bg then
        frame.Inset.Bg:SetVertexColor(t_unpack(COLORS.inset))
    end

    local topStrip = frame:CreateTexture(nil, "BACKGROUND")
    topStrip:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -24)
    topStrip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -24)
    topStrip:SetHeight(30)
    topStrip:SetTexture("Interface\\Buttons\\WHITE8x8")
    topStrip:SetVertexColor(0.12, 0.09, 0.05, 0.80)

    local sepTop = frame:CreateTexture(nil, "BORDER")
    sepTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -54)
    sepTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -54)
    sepTop:SetHeight(1)
    sepTop:SetTexture("Interface\\Buttons\\WHITE8x8")
    sepTop:SetVertexColor(0.66, 0.52, 0.20, 0.45)

    local sepBottom = frame:CreateTexture(nil, "BORDER")
    sepBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 40)
    sepBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 40)
    sepBottom:SetHeight(1)
    sepBottom:SetTexture("Interface\\Buttons\\WHITE8x8")
    sepBottom:SetVertexColor(0.66, 0.52, 0.20, 0.35)

    local vignette = frame:CreateTexture(nil, "ARTWORK")
    vignette:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -24)
    vignette:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    vignette:SetTexture("Interface\\Buttons\\WHITE8x8")
    vignette:SetVertexColor(0.03, 0.03, 0.03, 0.25)

    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -32)
    header:SetText(UIText("HEADER_TITLE", "Doxy Tracker"))
    header:SetTextColor(1.0, 0.85, 0.25)
    ui.headerTitle = header

    local headerSub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerSub:SetPoint("LEFT", header, "RIGHT", 14, 0)
    headerSub:SetPoint("RIGHT", frame, "RIGHT", -120, 0)
    headerSub:SetJustifyH("LEFT")
    headerSub:SetTextColor(0.92, 0.92, 0.92)
    headerSub:SetText("")
    ui.headerSub = headerSub

    local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refresh:SetSize(84, 22)
    refresh:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -30)
    refresh:SetText(UIText("BUTTON_REFRESH", "Refresh"))
    refresh:SetScript("OnClick", function()
        ScheduleRebuild(true)
    end)

    local leftPanel = MakePanel(frame)
    ui.leftPanel = leftPanel

    local leftTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 10, -10)
    leftTitle:SetText(UIText("LEFT_PANEL_TITLE", "Dungeons"))
    leftTitle:SetTextColor(1.0, 0.86, 0.25)
    ui.leftTitle = leftTitle

    local leftFilter = CreateFrame("Frame", "DoxyTrackerExpansionDropdown", leftPanel, "UIDropDownMenuTemplate")
    leftFilter:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", 18, 0)
    leftFilter:SetScale(0.86)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(leftFilter, 150)
    end

    if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton then
        UIDropDownMenu_Initialize(leftFilter, function(_, level)
            if level ~= 1 then
                return
            end

            local options = (state.activeTab == "raids") and GetRaidFilterOptions() or GetExpansionFilterOptions()
            local selectedValue = (state.activeTab == "raids") and state.raidExpansionFilter or
                state.dungeonExpansionFilter
            for _, option in ipairs(options) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = option.label
                info.value = option.key
                info.checked = (option.key == selectedValue)
                info.func = function(btn)
                    if state.activeTab == "raids" then
                        state.raidExpansionFilter = btn.value
                        state.raidCacheDirty = true
                    else
                        state.dungeonExpansionFilter = btn.value
                        state.dungeonCacheDirty = true
                    end
                    ScheduleRebuild(true)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    end

    ui.leftFilter = leftFilter
    RefreshExpansionDropdown()

    local leftScroll = CreateFrame("ScrollFrame", nil, leftPanel, "UIPanelScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 6, -30)
    leftScroll:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -26, 8)
    ui.leftScroll = leftScroll
    leftScroll:SetScript("OnVerticalScroll", function(self, offset)
        ui.leftScrollOffset = offset
        self:SetVerticalScroll(offset)
        UpdateLeftList()
    end)

    local leftChild = CreateFrame("Frame", nil, leftScroll)
    leftChild:SetSize(1, 1)
    leftScroll:SetScrollChild(leftChild)
    ui.leftListChild = leftChild

    local rightPanel = MakePanel(frame)
    ui.rightPanel = rightPanel

    local summary = MakeCard(rightPanel)
    summary:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 10, -10)
    summary:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -10, -10)
    summary:SetHeight(64)

    ui.summaryTitle = summary:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ui.summaryTitle:SetPoint("TOPLEFT", summary, "TOPLEFT", 12, -10)
    ui.summaryTitle:SetPoint("TOPRIGHT", summary, "TOPRIGHT", -12, -10)
    ui.summaryTitle:SetJustifyH("LEFT")

    ui.summarySub = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ui.summarySub:SetPoint("TOPLEFT", ui.summaryTitle, "BOTTOMLEFT", 0, -6)
    ui.summarySub:SetPoint("TOPRIGHT", summary, "TOPRIGHT", -12, -32)
    ui.summarySub:SetJustifyH("LEFT")

    local detail = MakeCard(rightPanel)
    detail:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -10)
    detail:SetPoint("TOPRIGHT", summary, "BOTTOMRIGHT", 0, -10)
    detail:SetPoint("BOTTOM", rightPanel, "BOTTOM", 0, 12)
    ui.detailCard = detail

    ui.detailTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ui.detailTitle:SetPoint("TOPLEFT", detail, "TOPLEFT", 12, -10)
    ui.detailTitle:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -12, -10)
    ui.detailTitle:SetJustifyH("LEFT")

    ui.detailSub = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ui.detailSub:SetPoint("TOPLEFT", ui.detailTitle, "BOTTOMLEFT", 0, -6)
    ui.detailSub:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -12, -34)
    ui.detailSub:SetJustifyH("LEFT")

    local rowTop = -70
    for i, label in ipairs({ "Normal", "Heroic", "Mythic" }) do
        local line = CreateFrame("Frame", nil, detail)
        line:SetPoint("TOPLEFT", detail, "TOPLEFT", 12, rowTop - ((i - 1) * 26))
        line:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -12, rowTop - ((i - 1) * 26))
        line:SetHeight(24)

        local bg = line:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(line)
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(0.10, 0.10, 0.11, 0.72)

        line.label = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        line.label:SetPoint("LEFT", line, "LEFT", 8, 0)
        line.label:SetJustifyH("LEFT")

        line.value = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        line.value:SetPoint("RIGHT", line, "RIGHT", -8, 0)
        line.value:SetJustifyH("RIGHT")

        line.label:SetText(label)
        line.value:SetText(ICON_NEUTRAL)

        ui.difficultyRows[i] = line
    end

    local lootTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lootTitle:SetPoint("TOPLEFT", detail, "TOPLEFT", 12, -154)
    lootTitle:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -16, -154)
    lootTitle:SetJustifyH("LEFT")
    lootTitle:SetText("Loot Log")
    ui.detailLootTitle = lootTitle

    local lootScroll = CreateFrame("ScrollFrame", nil, detail, "UIPanelScrollFrameTemplate")
    lootScroll:SetPoint("TOPLEFT", detail, "TOPLEFT", 12, -174)
    lootScroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -28, 12)
    ui.detailLootScroll = lootScroll

    local lootChild = CreateFrame("Frame", nil, lootScroll)
    lootChild:SetSize(1, 1)
    lootScroll:SetScrollChild(lootChild)
    ui.detailLootChild = lootChild

    local settingsPanel = MakePanel(frame)
    settingsPanel:Hide()
    ui.settingsPanel = settingsPanel

    local settingsTitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    settingsTitle:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 12, -10)
    settingsTitle:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", -12, -10)
    settingsTitle:SetJustifyH("LEFT")
    settingsTitle:SetText("About")

    local aboutRow = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    aboutRow:SetPoint("TOPLEFT", settingsTitle, "BOTTOMLEFT", 0, -8)
    aboutRow:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", -12, -8)
    aboutRow:SetJustifyH("LEFT")
    aboutRow:SetWordWrap(false)
    aboutRow:SetText("")
    ui.settingsAboutRow = aboutRow

    local notesHeader = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    notesHeader:SetPoint("TOPLEFT", aboutRow, "BOTTOMLEFT", 0, -14)
    notesHeader:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", -12, -14)
    notesHeader:SetJustifyH("LEFT")
    notesHeader:SetText("Description / Notes")

    local notesText = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    notesText:SetPoint("TOPLEFT", notesHeader, "BOTTOMLEFT", 0, -6)
    notesText:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", -12, -6)
    notesText:SetJustifyH("LEFT")
    notesText:SetJustifyV("TOP")
    notesText:SetWordWrap(true)
    notesText:SetText("")
    ui.settingsNotesText = notesText

    local settingsHeader = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    settingsHeader:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 12, -150)
    settingsHeader:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", -12, -150)
    settingsHeader:SetJustifyH("LEFT")
    settingsHeader:SetText("Settings")

    local cardsScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    ui.cardsScroll = cardsScroll

    local cardsChild = CreateFrame("Frame", nil, cardsScroll)
    cardsChild:SetSize(1, 1)
    cardsScroll:SetScrollChild(cardsChild)
    ui.cardsChild = cardsChild

    local cardsHeader = cardsChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cardsHeader:SetPoint("TOPLEFT", cardsChild, "TOPLEFT", 4, -4)
    cardsHeader:SetPoint("TOPRIGHT", cardsChild, "TOPRIGHT", -90, -4)
    cardsHeader:SetJustifyH("LEFT")
    cardsHeader:SetText(UIText("CARDS_TITLE", "Activities"))
    ui.cardsHeader = cardsHeader

    local exportButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    exportButton:SetSize(70, 20)
    exportButton:SetPoint("TOPRIGHT", cardsScroll, "TOPRIGHT", -6, -2)
    exportButton:SetText("Export")
    exportButton:SetScript("OnClick", function()
        local ctx = ui.exportContext
        if not ctx then
            if DT and DT.Print then
                DT:Print("Export is only available on Daily and Weekly tabs.")
            end
            return
        end

        ShowQuestExportDialog(ctx.tab, ctx.done, ctx.known)
    end)
    exportButton:Hide()
    ui.exportButton = exportButton

    local tabPanel = CreateFrame("Frame", nil, frame)
    tabPanel:SetSize(600, 24)
    ui.tabPanel = tabPanel

    for i, tabInfo in ipairs(TAB_ORDER) do
        local tab = CreateFrame("Button", nil, tabPanel, "BackdropTemplate")
        tab._key = tabInfo.key

        tab:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tab.text:SetPoint("CENTER")
        tab.text:SetText(tabInfo.label)

        tab:SetScript("OnClick", function(self)
            state.activeTab = self._key
            ScheduleRebuild(true)
        end)

        tab:SetScript("OnEnter", function(self)
            self._hovered = true
            UpdateTabVisuals()
        end)

        tab:SetScript("OnLeave", function(self)
            self._hovered = false
            UpdateTabVisuals()
        end)

        ui.tabs[i] = tab
    end

    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)

    local gripTex = resizeGrip:CreateTexture(nil, "OVERLAY")
    gripTex:SetAllPoints(resizeGrip)
    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    gripTex:SetAlpha(0.9)

    resizeGrip:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        Layout()
        ScheduleRebuild()
    end)

    frame:SetScript("OnSizeChanged", function()
        Layout()
    end)

    frame:SetScript("OnShow", function()
        Layout()
        ScheduleRebuild(true)
    end)
end

function DT.TrackerFrame:OnInitialize()
    Build()
end

function DT.TrackerFrame:Toggle()
    if not ui.frame then Build() end
    if IsShown(ui.frame) then
        FrameCall(ui.frame, "Hide")
    else
        ScheduleRebuild(true)
        FrameCall(ui.frame, "Show")
    end
end

function DT.TrackerFrame:Show()
    if not ui.frame then Build() end
    ScheduleRebuild(true)
    FrameCall(ui.frame, "Show")
end

function DT.TrackerFrame:Hide()
    if ui.frame then FrameCall(ui.frame, "Hide") end
end

function DT.TrackerFrame:Refresh()
    if IsShown(ui.frame) then
        ScheduleRebuild()
    end
end

function DT.TrackerFrame:OnEvent(event)
    if event == "UPDATE_INSTANCE_INFO" or event == "ENCOUNTER_END" or event == "CHALLENGE_MODE_COMPLETED" or event == "CHAT_MSG_LOOT" then
        state.dungeonCacheDirty = true
        state.raidCacheDirty = true
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "CHAT_MSG_SYSTEM" then
        state.dungeonCacheDirty = true
        state.raidCacheDirty = true
    end

    if IsShown(ui.frame) then
        ScheduleRebuild()
    end
end

DT:RegisterModule("TrackerFrame", DT.TrackerFrame)
