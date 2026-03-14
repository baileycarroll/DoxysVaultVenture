local ADDON_NAME, DT = ...

DT.name = ADDON_NAME
DT.modules = DT.modules or {}
DT.UI_TEXT = DT.UI_TEXT or {
    WINDOW_TITLE = "DoxyTracker",
    HEADER_TITLE = "Doxy Tracker",
    HEADER_SUBTITLE = "Midnight Progress",

    TAB_DUNGEONS = "Dungeons",
    TAB_MPLUS = "Mythic+",
    TAB_DAILY = "Daily Quests",
    TAB_WEEKLY = "Weekly Quests",
    TAB_RAIDS = "Raids",
    TAB_SETTINGS = "Settings",

    LEFT_PANEL_TITLE = "Dungeons",
    BUTTON_REFRESH = "Refresh",
    CARDS_TITLE = "Activities",
}

local CreateFrame = _G["CreateFrame"]

local frame = CreateFrame("Frame")
DT.frame = frame

local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        local msg = string.format("|cffff5555DoxyTracker error:|r %s", tostring(err))
        if _G["DEFAULT_CHAT_FRAME"] then
            _G["DEFAULT_CHAT_FRAME"]:AddMessage(msg)
        end
    end
end

function DT:RegisterModule(name, module)
    if not name or not module then
        return
    end
    self.modules[name] = module
end

function DT:Print(text)
    if _G["DEFAULT_CHAT_FRAME"] then
        _G["DEFAULT_CHAT_FRAME"]:AddMessage(string.format("|cff66ccffDoxyTracker:|r %s", tostring(text)))
    end
end

function DT:IsGroupEnabled(groupKey)
    if not self.db or not self.db.settings then
        return false
    end
    return self.db.settings.groupToggles[groupKey] == true
end

function DT:SetGroupEnabled(groupKey, enabled)
    if not self.db or not self.db.settings then
        return
    end
    self.db.settings.groupToggles[groupKey] = enabled and true or false
end

function DT:Initialize()
    if self.initialized then
        return
    end

    DoxyTrackerDB = DoxyTrackerDB or {}
    self.db = DoxyTrackerDB

    if self.Config and self.Config.ApplyDefaults then
        SafeCall(self.Config.ApplyDefaults, self.Config, self.db)
    end

    if self.SourceCatalog and self.SourceCatalog.Initialize then
        SafeCall(self.SourceCatalog.Initialize, self.SourceCatalog, self.db)
    end

    if self.CharacterTracker and self.CharacterTracker.Initialize then
        SafeCall(self.CharacterTracker.Initialize, self.CharacterTracker, self.db)
    end

    if self.ContentAvailability and self.ContentAvailability.Initialize then
        SafeCall(self.ContentAvailability.Initialize, self.ContentAvailability, self.db)
        SafeCall(self.ContentAvailability.EvaluateRaidAutoEnable, self.ContentAvailability)
    end

    for _, module in pairs(self.modules) do
        if module.OnInitialize then
            SafeCall(module.OnInitialize, module)
        end
    end

    self.initialized = true
    self:Print("Loaded. Type |cff66ccff/doxy|r to open the tracker.")
end

function DT:DispatchEvent(event, ...)
    for _, module in pairs(self.modules) do
        if module.OnEvent then
            SafeCall(module.OnEvent, module, event, ...)
        end
    end
end

function DT:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            self:Initialize()
        end
        return
    end

    if not self.initialized then
        return
    end

    if event == "PLAYER_ENTERING_WORLD" and self.ContentAvailability and self.ContentAvailability.EvaluateRaidAutoEnable then
        SafeCall(self.ContentAvailability.EvaluateRaidAutoEnable, self.ContentAvailability)
    end

    self:DispatchEvent(event, ...)
end

frame:SetScript("OnEvent", function(_, event, ...)
    DT:OnEvent(event, ...)
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("UPDATE_INSTANCE_INFO")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
frame:RegisterEvent("CHAT_MSG_LOOT")
