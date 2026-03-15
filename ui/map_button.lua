local _, DT = ...

DT.MapButton = DT.MapButton or {}

local CreateFrame = _G["CreateFrame"]
local UIParent = _G["UIParent"]
local C_AddOns = _G["C_AddOns"]
local hooksecurefunc = _G["hooksecurefunc"]

local function IsMapButtonEnabled()
    local settings = DT.db and DT.db.settings
    if not settings then
        return true
    end
    if settings.showMapButton == nil then
        settings.showMapButton = true
    end
    return settings.showMapButton == true
end

local function ResolveMapParent()
    local map = _G["WorldMapFrame"]
    if map then
        return map
    end

    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_WorldMap")
    end

    return _G["WorldMapFrame"] or UIParent
end

function DT.MapButton:ApplyVisibility()
    if not self.button then
        return
    end
    self.button:SetShown(IsMapButtonEnabled())
end

function DT.MapButton:CreateButton()
    local parent = ResolveMapParent()
    if not parent then
        return
    end

    if self.button then
        self.button:SetParent(parent)
        self.button:ClearAllPoints()
        if parent == UIParent then
            self.button:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -340, -180)
        else
            self.button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -105, -34)
        end
        self:ApplyVisibility()
        return
    end

    local button = CreateFrame("Button", "DoxyTrackerWorldMapButton", parent, "UIPanelButtonTemplate")
    button:SetSize(112, 22)
    button:SetText("Vault&Venture")

    if parent == UIParent then
        button:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -340, -180)
    else
        button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -105, -34)
    end

    button:SetScript("OnClick", function()
        if DT.TrackerFrame and DT.TrackerFrame.Toggle then
            DT.TrackerFrame:Toggle()
        end
    end)

    self.button = button
    self:ApplyVisibility()
end

function DT.MapButton:OnInitialize()
    if type(hooksecurefunc) == "function" then
        hooksecurefunc("ToggleWorldMap", function()
            DT.MapButton:CreateButton()
        end)
    end

    self:CreateButton()
end

function DT.MapButton:OnEvent(event)
    if event == "PLAYER_ENTERING_WORLD" and (not self.button or self.button:GetParent() == UIParent) then
        self:CreateButton()
    end
end

DT:RegisterModule("MapButton", DT.MapButton)
