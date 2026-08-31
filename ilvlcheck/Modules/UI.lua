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

function ILvlCheck:GetStatusColor(status)
    local color = STATUS_COLORS[status]
    if color then
        return unpack(color)
    end

    return 0.85, 0.85, 0.85
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
    row.nameText:SetWidth(210)

    row.scoreText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.scoreText:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -2)
    row.scoreText:SetJustifyH("LEFT")
    row.scoreText:SetWidth(210)

    row.specText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.specText:SetPoint("TOPLEFT", row.scoreText, "BOTTOMLEFT", 0, -3)
    row.specText:SetJustifyH("LEFT")
    row.specText:SetWidth(180)
    row.specText:SetTextColor(0.65, 0.65, 0.70)

    row.buffIcons = {}
    local previousIcon
    for iconIndex = 1, MAX_BUFF_ICONS do
        local holder = CreateFrame("Frame", nil, row)
        holder:SetSize(BUFF_ICON_SIZE + BUFF_RING_PADDING, BUFF_ICON_SIZE + BUFF_RING_PADDING)
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
    row.statusBG:SetSize(72, 20)
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

function ILvlCheck:CreateUI()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "ILvlCheckMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(460, 500)
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

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Party iLvl Check")
    frame.title = title

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
    divider:SetSize(424, 1)
    divider:SetPoint("TOP", 0, -40)

    local summaryTiles = {}
    for index = 1, 3 do
        summaryTiles[index] = CreateSummaryTile(frame, SUMMARY_TILE_STYLES[index])
    end
    frame.summaryTiles = summaryTiles

    local refreshButton = CreateFlatButton(frame, { 0.42, 0.32, 0.10 }, "Refresh")
    refreshButton:SetSize(90, 26)
    refreshButton:SetPoint("BOTTOM", 0, 36)
    refreshButton.label:SetTextColor(1, 0.92, 0.75)
    refreshButton:SetScript("OnClick", function()
        ILvlCheck:RefreshPartyScan()
    end)
    frame.refreshButton = refreshButton

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

    local testModeCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    testModeCheck:SetPoint("LEFT", announceCheck.Text, "RIGHT", 8, 0)
    testModeCheck:SetChecked(false)
    testModeCheck:SetScript("OnClick", function(checkButton)
        ILvlCheck.testMode = checkButton:GetChecked() and true or false

        if ILvlCheck.testMode then
            ILvlCheck:StopBuffPolling()
        end

        ILvlCheck:RefreshPartyScan()

        if not ILvlCheck.testMode and ILvlCheck.frame and ILvlCheck.frame:IsShown() then
            ILvlCheck:StartBuffPolling()
        end
    end)
    testModeCheck.Text:SetText("Test Mode")
    frame.testModeCheck = testModeCheck

    for index = 1, 5 do
        self.rowPool[index] = self:CreateRow(frame, index)
    end

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

        if ILvlCheck.frame.testModeCheck then
            ILvlCheck.frame.testModeCheck:SetChecked(ILvlCheck.testMode)
        end

        ILvlCheck:RefreshPartyScan()
        ILvlCheck:StartBuffPolling()
    end)

    frame:SetScript("OnHide", function()
        ILvlCheck:StopBuffPolling()
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
            row.nameText:SetText(entry.displayName or key)

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
                    row.scoreText:Hide()
                end

                row.specText:SetText(entry.specName or "-")
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
                    if buffDef then
                        local hasBuff = entry.buffStatus and entry.buffStatus[buffDef.key] == true
                        holder.icon:SetTexture(buffDef.iconPath)
                        holder.icon:SetDesaturated(not hasBuff)
                        if hasBuff then
                            holder.ring:SetVertexColor(0.30, 0.85, 0.35, 1)
                        else
                            holder.ring:SetVertexColor(0.90, 0.20, 0.20, 1)
                        end
                        holder:Show()
                    else
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

                local statusLabel = entry.status == "Scanning..." and "Scanning..." or "Offline"
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
end

function ILvlCheck:UpdateSummary()
    if not self.frame or not self.frame.summaryTiles then
        return
    end

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
