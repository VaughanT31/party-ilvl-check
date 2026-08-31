local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

local RADIAN = math.pi / 180
local DEFAULT_ANGLE = 200

-- math.atan2 should exist in WoW's Lua, but fall back to a manual
-- implementation just in case a future client build strips it (the way
-- math.randomseed turned out to be unavailable).
local atan2 = math.atan2
if not atan2 then
    atan2 = function(y, x)
        if x > 0 then
            return math.atan(y / x)
        elseif x < 0 and y >= 0 then
            return math.atan(y / x) + math.pi
        elseif x < 0 and y < 0 then
            return math.atan(y / x) - math.pi
        elseif x == 0 and y > 0 then
            return math.pi / 2
        elseif x == 0 and y < 0 then
            return -math.pi / 2
        end

        return 0
    end
end

local function GetMinimapAngle()
    ILvlCheckDB = ILvlCheckDB or {}
    return ILvlCheckDB.minimapAngle or DEFAULT_ANGLE
end

local function SetMinimapAngle(angle)
    ILvlCheckDB = ILvlCheckDB or {}
    ILvlCheckDB.minimapAngle = angle
end

local function UpdateButtonPosition(button)
    local angle = GetMinimapAngle()
    local radius = (Minimap:GetWidth() / 2) + 6
    local x = radius * math.cos(angle * RADIAN)
    local y = radius * math.sin(angle * RADIAN)

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function ILvlCheck:CreateMinimapButton()
    if self.minimapButton then
        return
    end

    local button = CreateFrame("Button", "ILvlCheckMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\AddOns\\ilvlcheck\\icon")
    local iconMask = button:CreateMaskTexture()
    iconMask:SetAllPoints(icon)
    iconMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(iconMask)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(self)
            local minimapX, minimapY = Minimap:GetCenter()
            local cursorX, cursorY = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cursorX = cursorX / scale
            cursorY = cursorY / scale

            local angle = atan2(cursorY - minimapY, cursorX - minimapX) / RADIAN
            SetMinimapAngle(angle)
            UpdateButtonPosition(self)
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnClick", function()
        ILvlCheck:ToggleWindow()
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Party iLvl Check")
        GameTooltip:AddLine("Left-click to toggle the window", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Drag to move", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdateButtonPosition(button)

    self.minimapButton = button
end
