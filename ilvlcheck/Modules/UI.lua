local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

local STATUS_COLORS = ns.STATUS_COLORS
local ROW_WIDTH = ns.ROW_WIDTH
local ROW_HEIGHT = ns.ROW_HEIGHT
local ROW_GAP = ns.ROW_GAP
local ROWS_TOP_OFFSET = ns.ROWS_TOP_OFFSET
local BUFF_ICON_START_X = ns.BUFF_ICON_START_X
local BUFF_ICON_GAP = ns.BUFF_ICON_GAP
local BUFF_ICON_SIZE = ns.BUFF_ICON_SIZE
local BUFF_RING_PADDING = ns.BUFF_RING_PADDING
local MAX_BUFF_ICONS = ns.MAX_BUFF_ICONS
local GetMinimumItemLevel = ns.GetMinimumItemLevel
local SetMinimumItemLevel = ns.SetMinimumItemLevel
local ShouldShowScanAnnouncements = ns.ShouldShowScanAnnouncements
local SetShowScanAnnouncements = ns.SetShowScanAnnouncements
local FormatDelta = ns.FormatDelta
local UTILITY_TOP_OFFSET = ns.UTILITY_TOP_OFFSET
local UTILITY_ICON_SIZE = ns.UTILITY_ICON_SIZE

function ILvlCheck:GetStatusColor(status)
    local color = STATUS_COLORS[status]
    if color then
        return unpack(color)
    end

    return 0.85, 0.85, 0.85
end

function ILvlCheck:AddGearTooltipLines(audit)
    if not audit then
        GameTooltip:AddLine("Not checked yet", 0.62, 0.62, 0.66)
        return
    end
    if audit.sharedBy == "self" then
        GameTooltip:AddLine("Sent by their own Party iLvl Check", 0.40, 0.80, 1.00)
    elseif audit.sharedBy then
        GameTooltip:AddLine("Inspected by " .. audit.sharedBy .. " (Party iLvl Check)", 0.40, 0.80, 1.00)
    end

    if audit.tierPieces then
        local pieces = audit.tierPieces
        GameTooltip:AddLine(("Tier set: %d of 5 pieces"):format(pieces),
            pieces >= 4 and 0.30 or 1.00, pieces >= 4 and 0.85 or 0.65, pieces >= 4 and 0.35 or 0.20)
    end

    if #audit.missingEnchants == 0 and #audit.emptySockets == 0 then
        GameTooltip:AddLine("All enchanted and gemmed", 0.30, 0.85, 0.35)
        return
    end

    if #audit.missingEnchants > 0 then
        GameTooltip:AddLine("Missing enchant: " .. table.concat(audit.missingEnchants, ", "), 0.90, 0.20, 0.20, true)
    end
    if #audit.emptySockets > 0 then
        GameTooltip:AddLine("Empty socket: " .. table.concat(audit.emptySockets, ", "), 1.00, 0.55, 0.20, true)
    end
end

function ILvlCheck:CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 18, -ROWS_TOP_OFFSET - ((index - 1) * (ROW_HEIGHT + ROW_GAP)))

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 1)
    row.bg:SetVertexColor(0.16, 0.18, 0.23, 0.55)

    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetPoint("TOPLEFT", 0, 0)
    row.accent:SetPoint("BOTTOMLEFT", 0, 0)
    row.accent:SetWidth(3)
    row.accent:SetColorTexture(1, 1, 1, 1)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("TOPLEFT", 12, -6)
    row.nameText:SetJustifyH("LEFT")
    -- The text stops before the buff icons start, so nothing runs under them.
    local textWidth = BUFF_ICON_START_X - 16
    row.nameText:SetWidth(textWidth)
    row.nameText:SetWordWrap(false)

    row.scoreText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.scoreText:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -2)
    row.scoreText:SetJustifyH("LEFT")
    row.scoreText:SetWidth(textWidth)
    row.scoreText:SetWordWrap(false)

    row.specText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.specText:SetPoint("TOPLEFT", row.scoreText, "BOTTOMLEFT", 0, -3)
    row.specText:SetJustifyH("LEFT")
    row.specText:SetWidth(textWidth)
    row.specText:SetWordWrap(false)
    row.specText:SetTextColor(0.65, 0.65, 0.70)

    row.buffIcons = {}
    local previousIcon
    for iconIndex = 1, MAX_BUFF_ICONS do
        local holder = CreateFrame("Frame", nil, row)
        holder:SetSize(BUFF_ICON_SIZE + BUFF_RING_PADDING, BUFF_ICON_SIZE + BUFF_RING_PADDING)
        holder:EnableMouse(true)
        holder:SetScript("OnEnter", function(self)
            if not self.buffDef then
                return
            end

            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.buffDef.label)
            if self.buffDef.kind == "gear" then
                ILvlCheck:AddGearTooltipLines(self.gearAudit)
            elseif self.hasBuff then
                GameTooltip:AddLine("Active", 0.30, 0.85, 0.35)
            elseif self.buffDef.optional then
                GameTooltip:AddLine("Not used (optional)", 0.65, 0.65, 0.70)
            else
                GameTooltip:AddLine("Missing", 0.90, 0.20, 0.20)
            end
            GameTooltip:Show()
        end)
        holder:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        holder:Hide()
        if previousIcon then
            holder:SetPoint("LEFT", previousIcon, "RIGHT", BUFF_ICON_GAP, 0)
        else
            holder:SetPoint("LEFT", row, "LEFT", BUFF_ICON_START_X, 0)
        end

        holder.ring = holder:CreateTexture(nil, "BACKGROUND")
        holder.ring:SetPoint("CENTER")
        holder.ring:SetSize(BUFF_ICON_SIZE + BUFF_RING_PADDING, BUFF_ICON_SIZE + BUFF_RING_PADDING)
        holder.ring:SetColorTexture(1, 1, 1, 1)
        local ringMask = holder:CreateMaskTexture()
        ringMask:SetAllPoints(holder.ring)
        ringMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        holder.ring:AddMaskTexture(ringMask)

        holder.icon = holder:CreateTexture(nil, "ARTWORK")
        holder.icon:SetPoint("CENTER")
        holder.icon:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
        local iconMask = holder:CreateMaskTexture()
        iconMask:SetAllPoints(holder.icon)
        iconMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        holder.icon:AddMaskTexture(iconMask)

        row.buffIcons[iconIndex] = holder
        previousIcon = holder
    end

    row.ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    row.ilvlText:SetPoint("TOPRIGHT", -12, -8)
    row.ilvlText:SetJustifyH("RIGHT")

    row.deltaText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.deltaText:SetPoint("TOPRIGHT", row.ilvlText, "BOTTOMRIGHT", 0, -2)
    row.deltaText:SetJustifyH("RIGHT")

    row.statusBG = row:CreateTexture(nil, "ARTWORK")
    row.statusBG:SetSize(84, 20)
    row.statusBG:SetPoint("RIGHT", -12, 0)
    row.statusBG:SetColorTexture(1, 1, 1, 1)
    row.statusBG:SetVertexColor(0.22, 0.22, 0.25, 0.85)

    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.statusText:SetPoint("CENTER", row.statusBG, "CENTER", 0, 0)
    row.statusText:SetJustifyH("CENTER")

    return row
end

local SUMMARY_TILE_STYLES = {
    { bg = { 0.12, 0.24, 0.16 }, text = { 0.45, 0.90, 0.55 } },
    { bg = { 0.28, 0.14, 0.10 }, text = { 1.00, 0.55, 0.30 } },
    { bg = { 0.16, 0.16, 0.18 }, text = { 0.75, 0.75, 0.78 } },
}

local function CreateSummaryTile(parent, style)
    local tile = CreateFrame("Frame", nil, parent)
    tile:SetHeight(42)

    tile.bg = tile:CreateTexture(nil, "BACKGROUND")
    tile.bg:SetAllPoints()
    tile.bg:SetColorTexture(1, 1, 1, 1)
    tile.bg:SetVertexColor(style.bg[1], style.bg[2], style.bg[3], 0.9)

    tile.count = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tile.count:SetPoint("TOP", 0, -6)
    tile.count:SetTextColor(style.text[1], style.text[2], style.text[3])

    tile.label = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tile.label:SetPoint("TOP", tile.count, "BOTTOM", 0, -2)
    tile.label:SetTextColor(style.text[1] * 0.85, style.text[2] * 0.85, style.text[3] * 0.85)

    return tile
end

local function CreateFlatButton(parent, bgColor, text)
    local button = CreateFrame("Button", nil, parent)

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(1, 1, 1, 1)
    button.bg:SetVertexColor(bgColor[1], bgColor[2], bgColor[3], 1)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)

    button:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(bgColor[1] * 1.15, bgColor[2] * 1.15, bgColor[3] * 1.15, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(bgColor[1], bgColor[2], bgColor[3], 1)
    end)

    return button
end

-- Window size (1.5): 50% to 200%, saved in ILvlCheckDB.scale. The whole
-- window scales together, so the layout stays as designed.
local MIN_SCALE, MAX_SCALE = 0.5, 2

function ILvlCheck:GetWindowScale()
    local scale = ILvlCheckDB and tonumber(ILvlCheckDB.scale) or 1
    return math.min(MAX_SCALE, math.max(MIN_SCALE, scale))
end

-- Keeps the window's top-left corner where it is while it grows or shrinks.
function ILvlCheck:SetWindowScale(scale)
    scale = math.min(MAX_SCALE, math.max(MIN_SCALE, tonumber(scale) or 1))
    ILvlCheckDB = ILvlCheckDB or {}
    ILvlCheckDB.scale = scale
    local frame = self.frame
    if not frame then
        return
    end
    local old = frame:GetScale()
    local left, top = frame:GetLeft(), frame:GetTop()
    frame:SetScale(scale)
    if left and top then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * old / scale, top * old / scale)
    end
end

-- The drag grip in the bottom-right corner.
function ILvlCheck:CreateScaleGrip(frame)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function()
        local cx, cy = GetCursorPosition()
        local ui = UIParent:GetEffectiveScale()
        local left, top = frame:GetLeft() * frame:GetEffectiveScale(), frame:GetTop() * frame:GetEffectiveScale()
        local startDistance = math.max(1, math.sqrt((cx - left) ^ 2 + (top - cy) ^ 2))
        local startScale = frame:GetScale()
        grip:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local distance = math.sqrt((x - left) ^ 2 + (top - y) ^ 2)
            local scale = math.min(MAX_SCALE, math.max(MIN_SCALE, startScale * distance / startDistance))
            frame:SetScale(scale)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / (scale * ui), top / (scale * ui))
        end)
    end)
    grip:SetScript("OnMouseUp", function()
        grip:SetScript("OnUpdate", nil)
        ILvlCheckDB = ILvlCheckDB or {}
        ILvlCheckDB.scale = frame:GetScale()
    end)
    grip:SetScript("OnEnter", function()
        GameTooltip:SetOwner(grip, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Drag to resize")
        GameTooltip:AddLine("/ilvlcheck scale reset for the normal size", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.scaleGrip = grip
end

function ILvlCheck:CreateUI()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "ILvlCheckMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(ROW_WIDTH + 36, 534)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.07, 0.075, 0.09, 0.97)
    frame:SetBackdropBorderColor(1, 1, 1, 0.08)
    frame:Hide()
    self.frame = frame
    frame:SetScale(self:GetWindowScale())
    self:CreateScaleGrip(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Party iLvl Check")
    frame.title = title

    -- The dungeon the "here" runs are for.
    local dungeonText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dungeonText:SetPoint("LEFT", title, "RIGHT", 10, -1)
    dungeonText:SetPoint("RIGHT", frame, "RIGHT", -44, 0)
    dungeonText:SetJustifyH("LEFT")
    dungeonText:SetWordWrap(false)
    frame.dungeonText = dungeonText

    local closeButton = CreateFlatButton(frame, { 0.45, 0.14, 0.14 }, "x")
    closeButton:SetSize(22, 22)
    closeButton:SetPoint("TOPRIGHT", -12, -12)
    closeButton.label:SetTextColor(1, 1, 1)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    frame.closeButton = closeButton

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.10)
    divider:SetSize(ROW_WIDTH, 1)
    divider:SetPoint("TOP", 0, -40)

    local summaryTiles = {}
    for index = 1, 3 do
        summaryTiles[index] = CreateSummaryTile(frame, SUMMARY_TILE_STYLES[index])
    end
    frame.summaryTiles = summaryTiles

    self:CreateUtilityBar(frame)

    local refreshButton = CreateFlatButton(frame, { 0.42, 0.32, 0.10 }, "Refresh")
    refreshButton:SetSize(90, 26)
    refreshButton:SetPoint("BOTTOM", -50, 36)
    refreshButton.label:SetTextColor(1, 0.92, 0.75)
    refreshButton:SetScript("OnClick", function()
        ILvlCheck:RefreshPartyScan()
    end)
    frame.refreshButton = refreshButton

    local postButton = CreateFlatButton(frame, { 0.16, 0.22, 0.32 }, "Post")
    postButton:SetSize(90, 26)
    postButton:SetPoint("LEFT", refreshButton, "RIGHT", 10, 0)
    postButton.label:SetTextColor(0.80, 0.90, 1.00)
    postButton:SetScript("OnClick", function()
        ILvlCheck:PostSummary()
    end)
    postButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Post to chat")
        GameTooltip:AddLine("Item levels, best runs here, what the group is missing and everyone's keys, in party or instance chat.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    postButton:HookScript("OnLeave", function() GameTooltip:Hide() end)
    frame.postButton = postButton

    -- Shows the ready check window (Mini.lua) for 30 seconds, to see it and
    -- drag it into place.
    local miniButton = CreateFlatButton(frame, { 0.20, 0.20, 0.24 }, "Test Mini")
    miniButton:SetSize(90, 26)
    miniButton:SetPoint("RIGHT", refreshButton, "LEFT", -10, 0)
    miniButton.label:SetTextColor(0.85, 0.85, 0.90)
    miniButton:SetScript("OnClick", function()
        ILvlCheck:ShowMini(30)
    end)
    miniButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Test the ready check window")
        GameTooltip:AddLine("Shows the small window that pops up on a ready check, for 30 seconds. Drag it where you want it.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    miniButton:HookScript("OnLeave", function() GameTooltip:Hide() end)
    frame.miniButton = miniButton

    local minLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minLabel:SetPoint("BOTTOMLEFT", 20, 90)
    minLabel:SetText("Min iLvl")
    frame.minLabel = minLabel

    local minEditBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    minEditBox:SetSize(60, 22)
    minEditBox:SetPoint("LEFT", minLabel, "RIGHT", 10, 0)
    minEditBox:SetAutoFocus(false)
    minEditBox:SetNumeric(true)
    minEditBox:SetMaxLetters(4)
    minEditBox:SetTextColor(0.55, 0.90, 0.70, 1)
    minEditBox:SetText(GetMinimumItemLevel() or "")
    minEditBox:SetCursorPosition(0)
    minEditBox:SetScript("OnEnterPressed", function(editBox)
        SetMinimumItemLevel(editBox:GetText())
        editBox:SetText(GetMinimumItemLevel() or "")
        editBox:ClearFocus()
        ILvlCheck:CheckThresholdAlerts()
        ILvlCheck:UpdateUI()
    end)
    minEditBox:SetScript("OnEscapePressed", function(editBox)
        editBox:SetText(GetMinimumItemLevel() or "")
        editBox:ClearFocus()
    end)
    minEditBox:SetScript("OnEditFocusLost", function(editBox)
        SetMinimumItemLevel(editBox:GetText())
        editBox:SetText(GetMinimumItemLevel() or "")
        ILvlCheck:CheckThresholdAlerts()
        ILvlCheck:UpdateUI()
    end)
    frame.minEditBox = minEditBox

    local announceCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    announceCheck:SetPoint("LEFT", minEditBox, "RIGHT", 16, 0)
    announceCheck:SetChecked(ShouldShowScanAnnouncements())
    announceCheck:SetScript("OnClick", function(checkButton)
        SetShowScanAnnouncements(checkButton:GetChecked())
    end)

    announceCheck.Text:SetText("Scan iLvl")
    frame.announceCheck = announceCheck

    -- Test M+ and Test Raid work like radio buttons: one or the other, or
    -- click the ticked one again to leave test mode.
    local function TestButton(anchor, label, raid)
        local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        check:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
        check:SetChecked(false)
        check:SetScript("OnClick", function(checkButton)
            ILvlCheck:SetTestMode(checkButton:GetChecked() and (raid and "raid" or "party") or nil)
        end)
        check.Text:SetText(label)
        return check
    end
    frame.testModeCheck = TestButton(announceCheck.Text, "Test M+", false)
    frame.testRaidCheck = TestButton(frame.testModeCheck.Text, "Test Raid", true)

    for index = 1, 5 do
        self.rowPool[index] = self:CreateRow(frame, index)
    end
    self:CreateRaidArea(frame)

    frame:SetScript("OnShow", function()
        if ILvlCheck:IsKeystoneTimerRunning() then
            ILvlCheck:HideForActiveKeystone()
            return
        end

        if ILvlCheck.frame.minEditBox then
            ILvlCheck.frame.minEditBox:SetText(GetMinimumItemLevel() or "")
        end

        if ILvlCheck.frame.announceCheck then
            ILvlCheck.frame.announceCheck:SetChecked(ShouldShowScanAnnouncements())
        end

        ILvlCheck:SyncTestButtons()

        ILvlCheck:RefreshPartyScan()
        ILvlCheck:StartBuffPolling()
    end)

    frame:SetScript("OnHide", function()
        -- The mini window may still be up and need the polls.
        if not ILvlCheck:IsMiniShown() then
            ILvlCheck:StopBuffPolling()
            ILvlCheck:ForgetReadyCheck()
        end
    end)

    self.frame = frame
end

function ILvlCheck:UpdateUI()
    if not self.frame then
        return
    end

    if #self.displayOrder == 0 then
        self:SetEntry("player", "Not inspectable")
    end

    if self:ApplyLayoutMode() then
        self:UpdateRaidRows()
        self:UpdateSummary()
        self:UpdateUtilityBar()
        self.frame.dungeonText:SetText(ns.HeaderText(self, ("%d players"):format(#self.displayOrder)) .. ns.AddonCountText(self))
        return
    end

    for index = 1, #self.rowPool do
        local row = self.rowPool[index]
        local key = self.displayOrder[index]
        local entry = key and self.players[key]

        if entry then
            local classColor = entry.classFile and RAID_CLASS_COLORS[entry.classFile]
            local nr, ng, nb = 1, 1, 1
            if classColor then
                nr, ng, nb = classColor.r, classColor.g, classColor.b
            end
            row.nameText:SetTextColor(nr, ng, nb)
            row.nameText:SetText(ns.ReadyIcon(self, entry) .. (entry.displayName or key) .. ns.AddonMark(entry))

            if entry.ilvl then
                row.bg:Show()
                row.accent:Show()
                row.accent:SetVertexColor(nr, ng, nb, 0.9)

                if entry.mythicRating then
                    local scoreColor = C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(entry.mythicRating)
                    if scoreColor then
                        row.scoreText:SetTextColor(scoreColor.r, scoreColor.g, scoreColor.b)
                    else
                        row.scoreText:SetTextColor(0.70, 0.82, 1.00)
                    end

                    row.scoreText:SetText("M+ Score: " .. tostring(entry.mythicRating))
                    row.scoreText:Show()
                else
                    row.scoreText:SetTextColor(0.70, 0.82, 1.00)
                    row.scoreText:SetText("M+ Score: -")
                    row.scoreText:Show()
                end

                -- Their best run here goes on the spec line, which has room for it.
                local here = ns.FormatDungeonRun(entry.dungeonRun)
                row.specText:SetText((entry.specName or "-") .. (here and ("  |cff5a5a62|||r  " .. here) or ""))
                row.specText:Show()

                local minimum = GetMinimumItemLevel()
                local isBelow = minimum and entry.ilvl < minimum
                if isBelow then
                    row.ilvlText:SetTextColor(1.00, 0.55, 0.20)
                else
                    row.ilvlText:SetTextColor(0.35, 0.85, 0.45)
                end
                row.ilvlText:SetText(tostring(entry.ilvl))
                row.ilvlText:Show()

                local deltaLabel, deltaColor = FormatDelta(entry.ilvl, minimum)
                if deltaLabel then
                    row.deltaText:SetTextColor(deltaColor[1], deltaColor[2], deltaColor[3])
                    row.deltaText:SetText(deltaLabel)
                    row.deltaText:Show()
                else
                    row.deltaText:Hide()
                end

                local visibleBuffs = self.visibleBuffs or {}
                for iconIndex = 1, MAX_BUFF_ICONS do
                    local buffDef = visibleBuffs[iconIndex]
                    local holder = row.buffIcons[iconIndex]
                    -- Self-only checks (weapon oil) leave a blank slot on other
                    -- rows so the icon columns still line up.
                    local isSelf = entry.unit and UnitIsUnit(entry.unit, "player")
                    if buffDef and buffDef.selfOnly and not isSelf and not self.testMode then
                        holder.buffDef = nil
                        holder:Hide()
                    elseif buffDef then
                        local status = entry.buffStatus and entry.buffStatus[buffDef.key]
                        local hasBuff = status == true
                        holder.icon:SetTexture(buffDef.iconPath)
                        holder.icon:SetDesaturated(not hasBuff)
                        if (status == nil and buffDef.kind == "gear") or (buffDef.optional and not hasBuff) then
                            holder.ring:SetVertexColor(0.45, 0.45, 0.50, 1)
                        elseif hasBuff then
                            holder.ring:SetVertexColor(0.30, 0.85, 0.35, 1)
                        else
                            holder.ring:SetVertexColor(0.90, 0.20, 0.20, 1)
                        end
                        holder.buffDef = buffDef
                        holder.hasBuff = hasBuff
                        holder.gearAudit = entry.gearAudit
                        holder:Show()
                    else
                        holder.buffDef = nil
                        holder:Hide()
                    end
                end

                row.statusBG:Hide()
                row.statusText:Hide()
            else
                row.bg:Hide()
                row.accent:Hide()
                row.scoreText:Hide()
                row.specText:Hide()
                row.ilvlText:Hide()
                row.deltaText:Hide()

                for iconIndex = 1, MAX_BUFF_ICONS do
                    row.buffIcons[iconIndex]:Hide()
                end

                local statusLabel = "Offline"
                if entry.status == "Scanning..." or entry.status == "Out of range" then
                    statusLabel = entry.status
                end
                local sr, sg, sb = self:GetStatusColor(statusLabel)
                row.statusText:SetTextColor(sr, sg, sb)
                row.statusText:SetText(statusLabel)
                row.statusBG:Show()
                row.statusText:Show()
            end

            row:Show()
        else
            row:Hide()
        end
    end

    self:UpdateSummary()
    self:UpdateUtilityBar()
    if self.frame.dungeonText then
        self.frame.dungeonText:SetText(ns.HeaderText(self, self.dungeonName and ("Best runs in " .. self.dungeonName) or "") .. ns.AddonCountText(self))
    end
end

-- Group utility bar --------------------------------------------------------

function ILvlCheck:CreateUtilityBar(frame)
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetSize(ROW_WIDTH, UTILITY_ICON_SIZE + 6)
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -UTILITY_TOP_OFFSET)

    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", 2, 0)
    label:SetText("GROUP")
    label:SetTextColor(0.65, 0.65, 0.70)

    bar.icons = {}
    local previous
    for index, def in ipairs(ns.UTILITY_DEFINITIONS) do
        local holder = CreateFrame("Frame", nil, bar)
        holder:SetSize(UTILITY_ICON_SIZE + BUFF_RING_PADDING, UTILITY_ICON_SIZE + BUFF_RING_PADDING)
        if previous then
            holder:SetPoint("LEFT", previous, "RIGHT", 8, 0)
        else
            holder:SetPoint("LEFT", bar, "LEFT", 56, 0)
        end
        holder.def = def

        holder.ring = holder:CreateTexture(nil, "BACKGROUND")
        holder.ring:SetAllPoints()
        holder.ring:SetColorTexture(1, 1, 1, 1)
        local ringMask = holder:CreateMaskTexture()
        ringMask:SetAllPoints(holder.ring)
        ringMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        holder.ring:AddMaskTexture(ringMask)

        holder.icon = holder:CreateTexture(nil, "ARTWORK")
        holder.icon:SetPoint("CENTER")
        holder.icon:SetSize(UTILITY_ICON_SIZE, UTILITY_ICON_SIZE)
        holder.icon:SetTexture(def.iconPath)
        local iconMask = holder:CreateMaskTexture()
        iconMask:SetAllPoints(holder.icon)
        iconMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        holder.icon:AddMaskTexture(iconMask)

        holder.count = holder:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        holder.count:SetPoint("BOTTOMRIGHT", 3, -2)

        holder:EnableMouse(true)
        holder:SetScript("OnEnter", function(self)
            local slot = ILvlCheck.groupUtility and ILvlCheck.groupUtility[self.def.key]
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.def.label)
            if slot and slot.count > 0 then
                GameTooltip:AddLine("Likely from: " .. table.concat(slot.names, ", "), 1, 1, 1, true)
            else
                GameTooltip:AddLine("Nobody in the group brings this.", 0.90, 0.20, 0.20, true)
            end
            if self.def.note then
                GameTooltip:AddLine(self.def.note, 0.65, 0.65, 0.70, true)
            end
            GameTooltip:AddLine("From class and spec; talents can change it.", 0.50, 0.50, 0.55, true)
            GameTooltip:Show()
        end)
        holder:SetScript("OnLeave", function() GameTooltip:Hide() end)

        bar.icons[index] = holder
        previous = holder
    end

    -- Keys: "4 keys", hover for the list.
    local keys = CreateFrame("Frame", nil, bar)
    keys:SetSize(110, UTILITY_ICON_SIZE)
    keys:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    keys.icon = keys:CreateTexture(nil, "ARTWORK")
    keys.icon:SetSize(UTILITY_ICON_SIZE, UTILITY_ICON_SIZE)
    keys.icon:SetPoint("RIGHT")
    keys.icon:SetTexture("Interface\\Icons\\inv_relics_hourglass")
    keys.text = keys:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    keys.text:SetPoint("RIGHT", keys.icon, "LEFT", -6, 0)
    keys.text:SetJustifyH("RIGHT")
    keys:EnableMouse(true)
    keys:SetScript("OnEnter", function(self)
        local list, unknown = ILvlCheck:ListKeystones()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Keystones")
        for _, key in ipairs(list) do
            local color = key.classFile and RAID_CLASS_COLORS[key.classFile]
            GameTooltip:AddDoubleLine(key.name, ("+%d %s"):format(key.level, key.mapID and ns.KeystoneMapName(key.mapID) or ""),
                color and color.r or 1, color and color.g or 1, color and color.b or 1, 1, 0.82, 0)
        end
        if #list == 0 then
            GameTooltip:AddLine("No keys seen yet.", 0.65, 0.65, 0.70)
        end
        if unknown > 0 then
            if ILvlCheck:HasKeystoneLib() then
                GameTooltip:AddLine(("%d player%s didn't answer (their addons don't share keys)."):format(unknown, unknown == 1 and "" or "s"), 0.65, 0.65, 0.70, true)
            else
                GameTooltip:AddLine("Other players' keys show when an addon that shares keys (like BigWigs) is installed.", 0.65, 0.65, 0.70, true)
            end
        end
        GameTooltip:Show()
    end)
    keys:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar.keys = keys

    frame.utilityBar = bar
end

local UTILITY_COLORS = {
    good = { 0.30, 0.85, 0.35 },
    short = { 1.00, 0.65, 0.20 },
    missing = { 0.90, 0.20, 0.20 },
}

function ILvlCheck:UpdateUtilityBar()
    local bar = self.frame and self.frame.utilityBar
    if not bar then
        return
    end

    local utility = self:ComputeGroupUtility()
    for _, holder in ipairs(bar.icons) do
        local slot = utility[holder.def.key]
        local state = ns.UtilityState(holder.def, slot)
        local color = UTILITY_COLORS[state]
        holder.ring:SetVertexColor(color[1], color[2], color[3], 1)
        holder.icon:SetDesaturated(state == "missing")
        holder.count:SetText(holder.def.want and slot and slot.count > 0 and tostring(slot.count) or "")
    end

    local list = self:ListKeystones()
    bar.keys.text:SetText(#list == 0 and "|cff8c8c94No keys|r" or (#list == 1 and "1 key" or (#list .. " keys")) .. (list[1] and ("  |cffffd100+" .. list[1].level .. "|r") or ""))
end

function ILvlCheck:GetReadinessCounts()
    local minimum = GetMinimumItemLevel()
    local ready, below, offline = 0, 0, 0

    for index = 1, #self.displayOrder do
        local entry = self.players[self.displayOrder[index]]
        if entry then
            if entry.ilvl then
                if minimum and entry.ilvl < minimum then
                    below = below + 1
                else
                    ready = ready + 1
                end
            else
                offline = offline + 1
            end
        end
    end

    return ready, below, offline, minimum
end

function ILvlCheck:UpdateSummary()
    if not self.frame or not self.frame.summaryTiles then
        return
    end

    local ready, below, offline, minimum = self:GetReadinessCounts()

    local tiles = self.frame.summaryTiles
    tiles[1].count:SetText(tostring(ready))
    tiles[1].label:SetText("READY")

    if minimum then
        tiles[2]:Show()
        tiles[2].count:SetText(tostring(below))
        tiles[2].label:SetText("BELOW " .. minimum)
    else
        tiles[2]:Hide()
    end

    tiles[3].count:SetText(tostring(offline))
    tiles[3].label:SetText("OFFLINE")

    self:LayoutSummaryTiles(minimum ~= nil)
end

function ILvlCheck:LayoutSummaryTiles(showAll)
    local tiles = self.frame.summaryTiles
    local containerWidth = ROW_WIDTH
    local gap = 8

    for index = 1, 3 do
        tiles[index]:ClearAllPoints()
    end

    if showAll then
        local tileWidth = (containerWidth - gap * 2) / 3
        for index = 1, 3 do
            tiles[index]:SetWidth(tileWidth)
        end
        tiles[1]:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 18, -52)
        tiles[2]:SetPoint("LEFT", tiles[1], "RIGHT", gap, 0)
        tiles[3]:SetPoint("LEFT", tiles[2], "RIGHT", gap, 0)
    else
        local tileWidth = (containerWidth - gap) / 2
        tiles[1]:SetWidth(tileWidth)
        tiles[3]:SetWidth(tileWidth)
        tiles[1]:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 18, -52)
        tiles[3]:SetPoint("LEFT", tiles[1], "RIGHT", gap, 0)
    end
end

-- mode: "party", "raid" or nil (test mode off).
function ILvlCheck:SetTestMode(mode)
    self.testMode = mode ~= nil
    self.testRaid = mode == "raid"
    self:SyncTestButtons()
    if self.testMode then
        self:StopBuffPolling()
    end
    self:RefreshPartyScan()
    if not self.testMode and self.frame and self.frame:IsShown() then
        self:StartBuffPolling()
    end
end

function ILvlCheck:SyncTestButtons()
    local frame = self.frame
    if frame and frame.testModeCheck then
        frame.testModeCheck:SetChecked(self.testMode and not self.testRaid)
        frame.testRaidCheck:SetChecked(self.testMode and self.testRaid)
    end
end
