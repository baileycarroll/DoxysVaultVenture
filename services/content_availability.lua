local _, DT = ...

DT.ContentAvailability = DT.ContentAvailability or {}

local C_DateAndTime = _G["C_DateAndTime"]
local EJ_GetInstanceInfo = _G["EJ_GetInstanceInfo"]
local nowTime = _G["time"]
local nowDate = _G["date"]

local function DateStringToParts(dateText)
    local year, month, day = string.match(dateText or "", "^(%d+)%-(%d+)%-(%d+)$")
    return tonumber(year), tonumber(month), tonumber(day)
end

function DT.ContentAvailability:Initialize(db)
    db.runtime = db.runtime or {}
    db.runtime.raids = db.runtime.raids or {
        enabledAt = nil,
        lastCheckAt = nil,
    }
end

function DT.ContentAvailability:IsAfterRaidEnableDate()
    local dateText = DT.db and DT.db.settings and DT.db.settings.raidAutoEnableDate or "2026-03-17"
    local y, m, d = DateStringToParts(dateText)
    if not y then
        return false
    end

    local now = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
    if not now then
        local t = nowDate("!*t", nowTime())
        now = { year = t.year, month = t.month, monthDay = t.day }
    end

    if now.year > y then
        return true
    end
    if now.year < y then
        return false
    end

    if now.month > m then
        return true
    end
    if now.month < m then
        return false
    end

    return (now.monthDay or 0) >= d
end

function DT.ContentAvailability:IsRaidContentAvailable()
    local raidGroup = DT.SourceCatalog and DT.SourceCatalog:GetGroup("raids_midnight_s1")
    if not raidGroup then
        return false
    end

    -- If no strict probe exists yet, assume availability on/after the launch date.
    if not raidGroup.requiredJournalInstanceIDs then
        return true
    end

    if type(raidGroup.requiredJournalInstanceIDs) ~= "table" or #raidGroup.requiredJournalInstanceIDs == 0 then
        return true
    end

    if type(EJ_GetInstanceInfo) ~= "function" then
        return false
    end

    for _, instanceID in ipairs(raidGroup.requiredJournalInstanceIDs) do
        local name = EJ_GetInstanceInfo(instanceID)
        if name then
            return true
        end
    end

    return false
end

function DT.ContentAvailability:EvaluateRaidAutoEnable()
    if not DT.db or not DT.db.settings then
        return
    end

    local runtime = DT.db.runtime and DT.db.runtime.raids
    if runtime then
        runtime.lastCheckAt = nowTime()
    end

    if not DT.db.settings.groupToggles.raids_midnight_s1 and self:IsAfterRaidEnableDate() and self:IsRaidContentAvailable() then
        DT.SourceCatalog:MarkGroupConfirmed("raids_midnight_s1")
        DT:SetGroupEnabled("raids_midnight_s1", true)
        if runtime then
            runtime.enabledAt = nowTime()
        end
        DT:Print("Midnight S1 raids are now enabled.")
    end
end
