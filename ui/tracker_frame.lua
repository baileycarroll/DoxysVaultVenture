local _, DT = ...

DT.TrackerFrame = DT.TrackerFrame or {}

local CreateFrame = _G["CreateFrame"]
local UIParent    = _G["UIParent"]

-- ─── Layout constants ─────────────────────────────────────────────────────────
local W         = 560
local H         = 530
local PAD       = 12
local ROW_H     = 18
local SEC_GAP   = 10
local TAB_H     = 24
local TAB_GAP   = 8
local TAB_COUNT = 3
local TAB_TOTAL_W = 440
local TAB_W     = math.floor((TAB_TOTAL_W - (TAB_GAP * (TAB_COUNT - 1))) / TAB_COUNT)
-- Usable content width: frame - left inset(6) - scrollbar(20) - right anchor(26) - padding*2
local CONTENT_W = W - 76
local ICON_DONE    = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t"
local ICON_MISSING = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14:0:0|t"
local ICON_NEUTRAL = "|cff666666-|r"

local TABS = {
    { key = "dungeons", label = "Dungeons" },
    { key = "daily", label = "Daily Quests" },
    { key = "weekly", label = "Weekly Quests" },
}

local function FrameCall(frame, method, ...)
    if not frame then return nil end
    local fn = frame[method]
    if type(fn) == "function" then
        return fn(frame, ...)
    end
    return nil
end

-- ─── State ────────────────────────────────────────────────────────────────────
local mainFrame  = nil
local scrollChild = nil
local rowPool    = {}
local rowCursor  = 0
local activeTab  = "dungeons"
local tabButtons = {}

-- ─── Row pool helpers ─────────────────────────────────────────────────────────
local function ResetRows()
    for _, fs in ipairs(rowPool) do
        fs:Hide()
    end
    rowCursor = 0
end

local function NextRow(y, text, indent, font, r, g, b)
    rowCursor = rowCursor + 1
    local fs = rowPool[rowCursor]
    if not fs then
        fs = FrameCall(scrollChild, "CreateFontString", nil, "OVERLAY", "GameFontNormal")
        if not fs then
            return y - ROW_H
        end
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        rowPool[rowCursor] = fs
    end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PAD + (indent or 0), y)
    fs:SetWidth(CONTENT_W - (indent or 0))
    fs:SetFontObject(font or "GameFontNormal")
    fs:SetText(text)
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:Show()
    return y - ROW_H
end

local function SortedKeysByLabel(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do
        table.insert(keys, key)
    end

    table.sort(keys, function(a, b)
        local av = tbl[a]
        local bv = tbl[b]
        local al = (type(av) == "table" and (av.name or av.title)) or tostring(a)
        local bl = (type(bv) == "table" and (bv.name or bv.title)) or tostring(b)
        return al < bl
    end)

    return keys
end

local function IsDungeonGroup(groupKey)
    return type(groupKey) == "string" and string.find(groupKey, "^dungeons_") ~= nil
end

local function DifficultySlot(difficultyID, difficultyName)
    if difficultyID == 8 then
        return "MPLUS"
    end
    if difficultyID == 23 then
        return "M"
    end
    if difficultyID == 2 then
        return "H"
    end
    if difficultyID == 1 then
        return "N"
    end

    local name = string.lower(tostring(difficultyName or ""))
    if string.find(name, "keystone") or string.find(name, "mythic%+") then
        return "MPLUS"
    end
    if string.find(name, "mythic") then
        return "M"
    end
    if string.find(name, "heroic") then
        return "H"
    end
    if string.find(name, "normal") then
        return "N"
    end
    if string.find(name, "lfg") or string.find(name, "random") then
        return "LFG"
    end

    return nil
end

local function BuildDungeonRows(known, done)
    local rowsByName = {}

    local function GetRow(name)
        local key = tostring(name or "Unknown")
        local row = rowsByName[key]
        if not row then
            row = {
                name = key,
                known = { LFG = false, N = false, H = false, M = false, MPLUS = false },
                done = { LFG = false, N = false, H = false, M = false, MPLUS = false },
                bestKey = 0,
            }
            rowsByName[key] = row
        end
        return row
    end

    for _, entry in pairs(known or {}) do
        local name = (type(entry) == "table" and entry.name) or "Unknown"
        local slot = DifficultySlot(type(entry) == "table" and entry.difficultyID, type(entry) == "table" and entry.difficultyName)
        if slot then
            local row = GetRow(name)
            row.known[slot] = true
        end
    end

    for _, entry in pairs(done or {}) do
        local name = (type(entry) == "table" and entry.name) or "Unknown"
        local slot = DifficultySlot(type(entry) == "table" and entry.difficultyID, type(entry) == "table" and entry.difficultyName)
        if slot then
            local row = GetRow(name)
            row.done[slot] = true
            row.known[slot] = true
            if slot == "MPLUS" and type(entry.keyLevel) == "number" then
                row.bestKey = math.max(row.bestKey, entry.keyLevel)
            end
        end
    end

    local sortedNames = {}
    for name in pairs(rowsByName) do
        table.insert(sortedNames, name)
    end
    table.sort(sortedNames)

    local doneChecks, totalChecks = 0, 0
    for _, name in ipairs(sortedNames) do
        local row = rowsByName[name]
        for _, slot in ipairs({ "LFG", "N", "H", "M", "MPLUS" }) do
            if row.known[slot] then
                totalChecks = totalChecks + 1
                if row.done[slot] then
                    doneChecks = doneChecks + 1
                end
            end
        end
    end

    return rowsByName, sortedNames, doneChecks, totalChecks
end

local function DungeonCellText(row, slot)
    if slot == "MPLUS" and row.done.MPLUS and row.bestKey and row.bestKey > 0 then
        return string.format("|cff44ff44+%d|r", row.bestKey)
    end

    if row.done[slot] then
        return ICON_DONE
    end

    if row.known[slot] then
        return ICON_MISSING
    end

    return ICON_NEUTRAL
end

local function RenderSectionHeader(y, label, doneCount, totalCount)
    y = y - SEC_GAP
    y = NextRow(y, " ", 0, "GameFontDisable", 0.2, 0.2, 0.2)

    local countStr = (totalCount > 0)
        and string.format("|cff44ff44%d|r / |cffd9dde3%d|r", doneCount, totalCount)
        or string.format("|cff44ff44%d|r completed", doneCount)

    y = NextRow(y, string.format("|cffF4D35E%s|r   %s", label, countStr), 0, "GameFontNormalLarge")
    return y
end

local function RenderQuestSection(y, label, doneStore, knownStore)
    doneStore = doneStore or {}
    knownStore = knownStore or {}

    local hasKnown = next(knownStore) ~= nil
    local doneCount, totalCount = 0, 0

    if hasKnown then
        for _ in pairs(knownStore) do totalCount = totalCount + 1 end
        for id in pairs(doneStore) do
            if knownStore[id] then
                doneCount = doneCount + 1
            end
        end
    else
        for _ in pairs(doneStore) do
            doneCount = doneCount + 1
            totalCount = totalCount + 1
        end
    end

    y = RenderSectionHeader(y, label, doneCount, totalCount)

    local hasRows = false
    for _, id in ipairs(SortedKeysByLabel(doneStore)) do
        if not hasKnown or knownStore[id] then
            local entry = doneStore[id]
            local text = (type(entry) == "table" and (entry.title or entry.name)) or tostring(id)
            y = NextRow(y, ICON_DONE .. "  " .. text, 16)
            hasRows = true
        end
    end

    if hasKnown then
        for _, id in ipairs(SortedKeysByLabel(knownStore)) do
            if not doneStore[id] then
                local entry = knownStore[id]
                local text = (type(entry) == "table" and (entry.title or entry.name)) or tostring(id)
                y = NextRow(y, ICON_MISSING .. "  " .. text, 16, nil, 0.82, 0.82, 0.82)
                hasRows = true
            end
        end
    end

    if not hasRows then
        y = NextRow(y, "No data yet.", 16, nil, 0.5, 0.5, 0.5)
    end

    return y
end

local function RenderDungeonSection(y, groupLabel, doneStore, knownStore)
    doneStore = doneStore or {}
    knownStore = knownStore or {}

    local doneForGroup = {}
    for id, entry in pairs(doneStore) do
        if knownStore[id] then
            doneForGroup[id] = entry
        end
    end

    local rowsByName, sortedNames, doneChecks, totalChecks = BuildDungeonRows(knownStore, doneForGroup)
    y = RenderSectionHeader(y, groupLabel, doneChecks, totalChecks)

    if #sortedNames == 0 then
        y = NextRow(y, "No dungeon rows configured.", 16, nil, 0.5, 0.5, 0.5)
        return y
    end

    y = NextRow(y, "|cff8ea4bfDungeon|r                        |cff8ea4bfLFG|r |cff8ea4bfN|r |cff8ea4bfH|r |cff8ea4bfM|r |cff8ea4bfM+|r", 16, "GameFontHighlightSmall")

    for _, dungeonName in ipairs(sortedNames) do
        local row = rowsByName[dungeonName]
        local displayName = dungeonName
        if string.len(displayName) > 28 then
            displayName = string.sub(displayName, 1, 25) .. "..."
        end

        local line = string.format(
            "|cffe4e8ef%-28s|r  %s  %s  %s  %s  %s",
            displayName,
            DungeonCellText(row, "LFG"),
            DungeonCellText(row, "N"),
            DungeonCellText(row, "H"),
            DungeonCellText(row, "M"),
            DungeonCellText(row, "MPLUS")
        )

        y = NextRow(y, line, 16, "GameFontHighlightSmall")
    end

    return y
end

local function RenderDungeonsTab(y, char)
    local dungeonStore = char.tracking and char.tracking.dungeonClears or {}
    local groups = { "dungeons_mplus_rotation", "dungeons_midnight_gear", "dungeons_midnight_bonus" }

    local renderedAny = false
    for _, groupKey in ipairs(groups) do
        if DT:IsGroupEnabled(groupKey) and DT.SourceCatalog:IsGroupVisible(groupKey) then
            local group = DT.SourceCatalog:GetGroup(groupKey)
            local known = group and group.knownInstances or {}
            y = RenderDungeonSection(y, group and group.label or groupKey, dungeonStore, known)
            renderedAny = true
        end
    end

    if not renderedAny then
        y = NextRow(y, "No dungeon groups are enabled.", 0, nil, 0.5, 0.5, 0.5)
    end

    return y
end

local function RenderDailyTab(y, char)
    local knownDaily = (DT.QuestTracker and DT.QuestTracker.knownDaily) or {}
    local doneDaily = char.tracking and char.tracking.dailyQuests or {}
    return RenderQuestSection(y, "Daily Quests", doneDaily, knownDaily)
end

local function KnownWeeklyKnowledgeFromCatalog()
    local out = {}
    local group = DT.SourceCatalog:GetGroup("knowledge_weekly")
    local known = group and group.knownWeeklyQuestIDs or {}
    for questID in pairs(known) do
        out[questID] = { title = "Quest " .. tostring(questID) }
    end
    return out
end

local function RenderWeeklyTab(y, char)
    local knownWeekly = (DT.QuestTracker and DT.QuestTracker.knownWeekly) or {}
    local doneWeekly = char.tracking and char.tracking.weeklyQuests or {}
    y = RenderQuestSection(y, "Weekly Quests", doneWeekly, knownWeekly)

    if DT:IsGroupEnabled("knowledge_weekly") and DT.SourceCatalog:IsGroupVisible("knowledge_weekly") then
        local knownKnowledge = KnownWeeklyKnowledgeFromCatalog()
        local doneKnowledge = char.tracking and char.tracking.weeklyKnowledge or {}
        y = RenderQuestSection(y, "Weekly Knowledge", doneKnowledge, knownKnowledge)
    end

    return y
end

local function UpdateTabButtonState()
    for _, tab in ipairs(tabButtons) do
        local selected = tab.key == activeTab
        tab:SetText(tab.label)

        if tab._selectedBg then
            tab._selectedBg:SetShown(selected)
        end

        local fs = tab:GetFontString()
        if fs then
            if selected then
                fs:SetTextColor(1.00, 0.90, 0.35)
            else
                fs:SetTextColor(0.78, 0.82, 0.90)
            end
        end
    end
end

-- ─── Content rebuild ──────────────────────────────────────────────────────────
local function Rebuild()
    if not scrollChild then return end
    ResetRows()

    local y = -PAD
    local char = DT.CharacterTracker and DT.CharacterTracker:GetCharacterData()
    if not char or not char.meta then
        y = NextRow(y, "No character data available yet.", 0, nil, 0.5, 0.5, 0.5)
        scrollChild:SetHeight(math.abs(y) + PAD)
        return
    end

    y = NextRow(y, string.format("|cff66ccff%s|r  -  %s", char.meta.name or "?", char.meta.realm or "?"), 0, "GameFontNormalLarge")
    y = NextRow(y, "|cff7f91aaSection:|r " .. (activeTab == "daily" and "Daily Quests" or activeTab == "weekly" and "Weekly Quests" or "Dungeons"), 0, "GameFontHighlightSmall")

    if activeTab == "dungeons" then
        y = RenderDungeonsTab(y, char)
    elseif activeTab == "daily" then
        y = RenderDailyTab(y, char)
    else
        y = RenderWeeklyTab(y, char)
    end

    scrollChild:SetHeight(math.abs(y) + PAD)
end

-- ─── Frame construction ───────────────────────────────────────────────────────
local function Build()
    if mainFrame then return end

    mainFrame = CreateFrame("Frame", "DoxyTrackerMainFrame", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(W, H)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop",  mainFrame.StopMovingOrSizing)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:Hide()

    mainFrame.TitleText:SetText("|cff66ccffDoxyTracker|r")
    if mainFrame.Bg then
        mainFrame.Bg:SetVertexColor(0.05, 0.06, 0.08, 0.95)
    end
    if mainFrame.Inset and mainFrame.Inset.Bg then
        mainFrame.Inset.Bg:SetVertexColor(0.08, 0.09, 0.11, 0.95)
    end

    -- Refresh button
    local btn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    btn:SetSize(72, 22)
    btn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -12, -28)
    btn:SetText("Refresh")
    btn:SetScript("OnClick", Rebuild)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "DoxyTrackerScroll", mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     mainFrame, "TOPLEFT",     6, -54)
    scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26,  44)

    -- Scroll child (content canvas)
    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(CONTENT_W)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    local tabPanel = CreateFrame("Frame", nil, mainFrame)
    tabPanel:SetSize(TAB_TOTAL_W, TAB_H)
    tabPanel:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0, 12)

    for i, tabInfo in ipairs(TABS) do
        local tab = CreateFrame("Button", nil, tabPanel, "UIPanelButtonTemplate")
        tab.key = tabInfo.key
        tab.label = tabInfo.label
        tab:SetSize(TAB_W, TAB_H)
        tab:SetPoint("LEFT", tabPanel, "LEFT", (i - 1) * (TAB_W + TAB_GAP), 0)

        local selectedBg = tab:CreateTexture(nil, "BACKGROUND")
        selectedBg:SetAllPoints(tab)
        selectedBg:SetColorTexture(0.20, 0.15, 0.06, 0.85)
        selectedBg:Hide()
        tab._selectedBg = selectedBg

        tab:SetScript("OnClick", function(self)
            activeTab = self.key
            UpdateTabButtonState()
            Rebuild()
        end)

        table.insert(tabButtons, tab)
    end

    UpdateTabButtonState()

    mainFrame:SetScript("OnShow", Rebuild)
end

-- ─── Public API ───────────────────────────────────────────────────────────────
function DT.TrackerFrame:OnInitialize()
    Build()
end

function DT.TrackerFrame:Toggle()
    if not mainFrame then Build() end
    if FrameCall(mainFrame, "IsShown") then
        FrameCall(mainFrame, "Hide")
    else
        Rebuild()
        FrameCall(mainFrame, "Show")
    end
end

function DT.TrackerFrame:Show()
    if not mainFrame then Build() end
    Rebuild()
    FrameCall(mainFrame, "Show")
end

function DT.TrackerFrame:Hide()
    if mainFrame then FrameCall(mainFrame, "Hide") end
end

function DT.TrackerFrame:Refresh()
    if mainFrame and FrameCall(mainFrame, "IsShown") then
        Rebuild()
    end
end

DT:RegisterModule("TrackerFrame", DT.TrackerFrame)
