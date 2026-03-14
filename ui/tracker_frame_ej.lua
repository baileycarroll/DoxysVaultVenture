local _, DT = ...

DT.TrackerFrame = DT.TrackerFrame or {}

local CreateFrame = _G["CreateFrame"]
local UIParent = _G["UIParent"]
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
    { key = "daily",    label = UIText("TAB_DAILY", "Daily Quests") },
    { key = "weekly",   label = UIText("TAB_WEEKLY", "Weekly Quests") },
    { key = "raids",    label = UIText("TAB_RAIDS", "Raids") },
    { key = "settings", label = UIText("TAB_SETTINGS", "Settings") },
}

local LEFT_ROW_H = 28

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

local state = {
    activeTab = "dungeons",
    selectedDungeon = nil,
    dungeonNames = {},
    dungeonsByName = {},
    dungeonDoneCount = 0,
    dungeonTotalCount = 0,
}

local ui = {
    frame = nil,
    leftButtons = {},
    cards = {},
    difficultyRows = {},
    tabs = {},
}

local function FrameCall(frame, method)
    if not frame then return nil end
    local fn = frame[method]
    if type(fn) == "function" then
        return fn(frame)
    end
    return nil
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

local function DungeonCellText(row, slot)
    if slot == "MPLUS" and row.done.MPLUS and row.bestKey and row.bestKey > 0 then
        return string.format("|cff44ff44+%d|r", row.bestKey)
    end
    if row.done[slot] then return ICON_DONE end
    if row.known[slot] then return ICON_MISSING end
    return ICON_NEUTRAL
end

local function CollectDungeons(char)
    state.dungeonNames = {}
    state.dungeonsByName = {}
    state.dungeonDoneCount = 0
    state.dungeonTotalCount = 0

    if not char or not char.tracking then
        return
    end

    local doneStore = char.tracking.dungeonClears or {}
    local groups = { "dungeons_mplus_rotation", "dungeons_midnight_gear", "dungeons_midnight_bonus" }

    local function ensure(name)
        local key = tostring(name or "Unknown")
        local row = state.dungeonsByName[key]
        if not row then
            row = {
                name = key,
                known = { LFG = false, N = false, H = false, M = false, MPLUS = false },
                done = { LFG = false, N = false, H = false, M = false, MPLUS = false },
                bestKey = 0,
            }
            state.dungeonsByName[key] = row
        end
        return row
    end

    for _, groupKey in ipairs(groups) do
        if DT:IsGroupEnabled(groupKey) and DT.SourceCatalog:IsGroupVisible(groupKey) then
            local group = DT.SourceCatalog:GetGroup(groupKey)
            local known = group and group.knownInstances or {}
            for _, entry in pairs(known) do
                local row = ensure(type(entry) == "table" and entry.name or "Unknown")
                local slot = DifficultySlot(type(entry) == "table" and entry.difficultyID,
                    type(entry) == "table" and entry.difficultyName)
                if slot then row.known[slot] = true end
            end
        end
    end

    for _, entry in pairs(doneStore) do
        local row = ensure(type(entry) == "table" and entry.name or "Unknown")
        local slot = DifficultySlot(type(entry) == "table" and entry.difficultyID,
            type(entry) == "table" and entry.difficultyName)
        if slot then
            row.done[slot] = true
            row.known[slot] = true
            if slot == "MPLUS" and type(entry.keyLevel) == "number" then
                row.bestKey = math.max(row.bestKey, entry.keyLevel)
            end
        end
    end

    for name, _ in pairs(state.dungeonsByName) do
        table.insert(state.dungeonNames, name)
    end
    table.sort(state.dungeonNames)

    for _, name in ipairs(state.dungeonNames) do
        local row = state.dungeonsByName[name]
        for _, slot in ipairs({ "LFG", "N", "H", "M", "MPLUS" }) do
            if row.known[slot] then
                state.dungeonTotalCount = state.dungeonTotalCount + 1
                if row.done[slot] then
                    state.dungeonDoneCount = state.dungeonDoneCount + 1
                end
            end
        end
    end

    if not state.selectedDungeon or not state.dungeonsByName[state.selectedDungeon] then
        state.selectedDungeon = state.dungeonNames[1]
    end
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

    btn:SetScript("OnClick", function(self)
        state.selectedDungeon = self._dungeonName
        DT.TrackerFrame:Refresh()
    end)

    ui.leftButtons[index] = btn
    return btn
end

local function UpdateLeftList()
    for _, btn in ipairs(ui.leftButtons) do
        btn:Hide()
    end

    local y = -2
    for i, dungeonName in ipairs(state.dungeonNames) do
        local btn = EnsureLeftButton(i)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", ui.leftListChild, "TOPLEFT", 0, y)
        btn:SetPoint("TOPRIGHT", ui.leftListChild, "TOPRIGHT", 0, y)
        y = y - LEFT_ROW_H

        btn._dungeonName = dungeonName
        btn.text:SetText(dungeonName)

        if state.selectedDungeon == dungeonName then
            btn:SetBackdropColor(0.23, 0.17, 0.08, 0.95)
            btn:SetBackdropBorderColor(0.90, 0.72, 0.22, 0.95)
            btn.text:SetTextColor(1.0, 0.92, 0.45)
        else
            btn:SetBackdropColor(0.10, 0.10, 0.12, 0.92)
            btn:SetBackdropBorderColor(0.22, 0.22, 0.24, 0.80)
            btn.text:SetTextColor(0.84, 0.88, 0.94)
        end

        btn:Show()
    end

    ui.leftListChild:SetHeight(math.max(1, #state.dungeonNames * LEFT_ROW_H + 4))
end

local function UpdateDifficultyTable()
    local row = state.dungeonsByName[state.selectedDungeon]
    local slots = {
        { key = "LFG",   label = "LFG" },
        { key = "N",     label = "Normal" },
        { key = "H",     label = "Heroic" },
        { key = "M",     label = "Mythic" },
        { key = "MPLUS", label = "Mythic+" },
    }

    for i, slotInfo in ipairs(slots) do
        local line = ui.difficultyRows[i]
        if row then
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

local function UpdateDungeonCards()
    local selected = state.selectedDungeon
    ui.summaryTitle:SetText("Dungeon Overview")
    ui.summarySub:SetText(string.format("%d / %d checks complete", state.dungeonDoneCount, state.dungeonTotalCount))

    if selected then
        ui.detailTitle:SetText(selected)
        ui.detailSub:SetText("Difficulty Progress")
    else
        ui.detailTitle:SetText("No Dungeons Available")
        ui.detailSub:SetText("Enable a dungeon group to populate this list.")
    end

    UpdateDifficultyTable()
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

    ui.cards[index] = card
    return card
end

local function RenderQuestCards(doneStore, knownStore, emptyText)
    for _, card in ipairs(ui.cards) do
        card:Hide()
    end

    doneStore = doneStore or {}
    knownStore = knownStore or {}

    local entries = {}
    local seen = {}

    for id, entry in pairs(doneStore) do
        entries[#entries + 1] = {
            id = id,
            title = (type(entry) == "table" and (entry.title or entry.name)) or tostring(id),
            status = "done",
        }
        seen[id] = true
    end

    for id, entry in pairs(knownStore) do
        if not seen[id] then
            entries[#entries + 1] = {
                id = id,
                title = (type(entry) == "table" and (entry.title or entry.name)) or tostring(id),
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
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", ui.cardsChild, "TOPLEFT", 0, -30)
        card:SetPoint("TOPRIGHT", ui.cardsChild, "TOPRIGHT", -4, -30)
        card.title:SetText(emptyText or "No entries yet")
        card.sub:SetText("Complete activities to populate this panel.")
        card.status:SetText(ICON_NEUTRAL)
        card:Show()
        ui.cardsChild:SetHeight(96)
        return
    end

    local y = -30
    for i, entry in ipairs(entries) do
        local card = AcquireCard(i)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", ui.cardsChild, "TOPLEFT", 0, y)
        card:SetPoint("TOPRIGHT", ui.cardsChild, "TOPRIGHT", -4, y)
        y = y - 64

        card.title:SetText(entry.title)
        if entry.status == "done" then
            card.status:SetText(ICON_DONE)
            card.sub:SetText("Completed")
        else
            card.status:SetText(ICON_MISSING)
            card.sub:SetText("Missing")
        end

        card:Show()
    end

    ui.cardsChild:SetHeight(math.max(1, #entries * 64 + 34))
end

local function RenderInfoCards(entries, emptyTitle, emptySub)
    for _, card in ipairs(ui.cards) do
        card:Hide()
    end

    entries = entries or {}

    if #entries == 0 then
        local card = AcquireCard(1)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", ui.cardsChild, "TOPLEFT", 0, -30)
        card:SetPoint("TOPRIGHT", ui.cardsChild, "TOPRIGHT", -4, -30)
        card.title:SetText(emptyTitle or "No entries")
        card.sub:SetText(emptySub or "No information available.")
        card.status:SetText(ICON_NEUTRAL)
        card:Show()
        ui.cardsChild:SetHeight(96)
        return
    end

    local y = -30
    for i, entry in ipairs(entries) do
        local card = AcquireCard(i)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", ui.cardsChild, "TOPLEFT", 0, y)
        card:SetPoint("TOPRIGHT", ui.cardsChild, "TOPRIGHT", -4, y)
        y = y - 64

        card.title:SetText(entry.title or "Entry")
        card.sub:SetText(entry.sub or "")
        card.status:SetText(entry.status or ICON_NEUTRAL)
        card:Show()
    end

    ui.cardsChild:SetHeight(math.max(1, #entries * 64 + 34))
end

local function BuildRaidEntries(tracking)
    local byRaidName = {}
    local clears = (tracking and tracking.raidClears) or {}

    for _, clear in pairs(clears) do
        if type(clear) == "table" then
            local name = tostring(clear.name or "Unknown Raid")
            local row = byRaidName[name]
            if not row then
                row = {
                    name = name,
                    difficulties = 0,
                    encountersDone = 0,
                    encountersTotal = 0,
                }
                byRaidName[name] = row
            end

            row.difficulties = row.difficulties + 1
            row.encountersDone = math.max(row.encountersDone, tonumber(clear.encounterProgress) or 0)
            row.encountersTotal = math.max(row.encountersTotal, tonumber(clear.numEncounters) or 0)
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

        entries[#entries + 1] = {
            title = row.name,
            sub = string.format("%d lockout(s) recorded  •  %s", row.difficulties, progress),
            status = ICON_DONE,
        }
    end

    table.sort(entries, function(a, b)
        return tostring(a.title) < tostring(b.title)
    end)

    return entries
end

local function BuildSettingsEntries()
    local entries = {}
    local settings = (DT.db and DT.db.settings) or {}
    local toggles = settings.groupToggles or {}

    local keys = {}
    for k in pairs(toggles) do
        keys[#keys + 1] = k
    end
    table.sort(keys)

    for _, key in ipairs(keys) do
        local enabled = toggles[key] == true
        local label = key
        if DT.SourceCatalog and DT.SourceCatalog.GetGroup then
            local group = DT.SourceCatalog:GetGroup(key)
            if group and group.label then
                label = group.label
            end
        end

        entries[#entries + 1] = {
            title = label,
            sub = string.format("%s (%s)", enabled and "Enabled" or "Disabled", key),
            status = enabled and ICON_DONE or ICON_MISSING,
        }
    end

    entries[#entries + 1] = {
        title = "Tip",
        sub = "Use /doxy toggle <group_key> to change source toggles.",
        status = ICON_NEUTRAL,
    }

    return entries
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
            tab:SetBackdropColor(t_unpack(COLORS.inactiveTab))
            tab:SetBackdropBorderColor(t_unpack(COLORS.inactiveTabEdge))
            tab.text:SetTextColor(0.80, 0.84, 0.92)
        end
    end
end

local function Rebuild()
    if not ui.frame then return end

    local char = DT.CharacterTracker and DT.CharacterTracker:GetCharacterData()
    local subtitle = UIText("HEADER_SUBTITLE", "Midnight Progress")
    if char and char.meta then
        ui.headerSub:SetText(string.format("%s  •  %s - %s", subtitle, char.meta.name or "?", char.meta.realm or "?"))
    else
        ui.headerSub:SetText(subtitle)
    end

    UpdateTabVisuals()

    local isDungeon = state.activeTab == "dungeons"
    ui.leftPanel:SetShown(isDungeon)
    ui.rightPanel:SetShown(isDungeon)
    ui.cardsScroll:SetShown(not isDungeon)

    if isDungeon then
        CollectDungeons(char)
        UpdateLeftList()
        UpdateDungeonCards()
        return
    end

    local tracking = char and char.tracking or {}
    if state.activeTab == "daily" then
        ui.cardsHeader:SetText(UIText("TAB_DAILY", "Daily Quests"))
        RenderQuestCards(tracking.dailyQuests or {}, (DT.QuestTracker and DT.QuestTracker.knownDaily) or {},
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

        RenderQuestCards(mergedDone, mergedKnown, "No weekly quests discovered")
    elseif state.activeTab == "raids" then
        ui.cardsHeader:SetText(UIText("TAB_RAIDS", "Raids"))
        RenderInfoCards(BuildRaidEntries(tracking), "No raid lockouts discovered",
            "Clear a tracked raid difficulty to populate this panel.")
    else
        ui.cardsHeader:SetText(UIText("TAB_SETTINGS", "Settings"))
        RenderInfoCards(BuildSettingsEntries(), "No settings available",
            "Configuration data has not been initialized yet.")
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

    local listWidth = (FrameCall(ui.leftScroll, "GetWidth") or (leftW - 26)) - 2
    ui.leftListChild:SetWidth(math.max(120, listWidth))

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
    refresh:SetScript("OnClick", Rebuild)

    local leftPanel = MakePanel(frame)
    ui.leftPanel = leftPanel

    local leftTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 10, -10)
    leftTitle:SetText(UIText("LEFT_PANEL_TITLE", "Dungeons"))
    leftTitle:SetTextColor(1.0, 0.86, 0.25)

    local leftScroll = CreateFrame("ScrollFrame", nil, leftPanel, "UIPanelScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 6, -30)
    leftScroll:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -26, 8)
    ui.leftScroll = leftScroll

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
    for i, label in ipairs({ "LFG", "Normal", "Heroic", "Mythic", "Mythic+" }) do
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

    local cardsScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    ui.cardsScroll = cardsScroll

    local cardsChild = CreateFrame("Frame", nil, cardsScroll)
    cardsChild:SetSize(1, 1)
    cardsScroll:SetScrollChild(cardsChild)
    ui.cardsChild = cardsChild

    local cardsHeader = cardsChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cardsHeader:SetPoint("TOPLEFT", cardsChild, "TOPLEFT", 4, -4)
    cardsHeader:SetPoint("TOPRIGHT", cardsChild, "TOPRIGHT", -8, -4)
    cardsHeader:SetJustifyH("LEFT")
    cardsHeader:SetText(UIText("CARDS_TITLE", "Activities"))
    ui.cardsHeader = cardsHeader

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
            Rebuild()
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
        Rebuild()
    end)

    frame:SetScript("OnSizeChanged", function()
        Layout()
    end)

    frame:SetScript("OnShow", function()
        Layout()
        Rebuild()
    end)
end

function DT.TrackerFrame:OnInitialize()
    Build()
end

function DT.TrackerFrame:Toggle()
    if not ui.frame then Build() end
    if FrameCall(ui.frame, "IsShown") then
        FrameCall(ui.frame, "Hide")
    else
        Rebuild()
        FrameCall(ui.frame, "Show")
    end
end

function DT.TrackerFrame:Show()
    if not ui.frame then Build() end
    Rebuild()
    FrameCall(ui.frame, "Show")
end

function DT.TrackerFrame:Hide()
    if ui.frame then FrameCall(ui.frame, "Hide") end
end

function DT.TrackerFrame:Refresh()
    if ui.frame and FrameCall(ui.frame, "IsShown") then
        Rebuild()
    end
end

DT:RegisterModule("TrackerFrame", DT.TrackerFrame)
