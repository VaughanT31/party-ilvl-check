local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

-- Raid mode: in a raid group the window lists everyone (up to 40) as
-- compact one-line rows in a scrolling list, instead of the five party rows.
-- Same data: item level against your minimum, spec, the buff and gear icons.
-- The inspect queue already goes one player at a time, so a raid fills in
-- over a minute or so; out of range players are retried as they come close.
-- In a raid the window opens by itself only on a ready check (1.6), or
-- with /ilvlcheck or the minimap button.

local RAID_ROW_HEIGHT = 20
local RAID_ROW_GAP = 2
local RAID_ICON_SIZE = 15
local RAID_ICON_START_X = 214
local RAID_TEST_SIZE = 20

function ILvlCheck:IsRaidMode()
    if self.testMode then
        return self.testRaid == true
    end
    return IsInRaid and IsInRaid() or false
end

function ILvlCheck:GetRaidUnits()
    local units = {}
    for index = 1, GetNumGroupMembers() do
        units[#units + 1] = "raid" .. index
    end
    return units
end

local function CreateRaidRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(ns.ROW_WIDTH - 12, RAID_ROW_HEIGHT)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.16, 0.18, 0.23, 0.45)

    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetPoint("TOPLEFT")
    row.accent:SetPoint("BOTTOMLEFT")
    row.accent:SetWidth(2)
    row.accent:SetColorTexture(1, 1, 1, 1)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("LEFT", 8, 0)
    row.nameText:SetWidth(112)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.specText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.specText:SetPoint("LEFT", 124, 0)
    row.specText:SetWidth(86)
    row.specText:SetJustifyH("LEFT")
    row.specText:SetWordWrap(false)

    row.icons = {}
    for index = 1, ns.MAX_BUFF_ICONS do
        local icon = CreateFrame("Frame", nil, row)
        icon:SetSize(RAID_ICON_SIZE, RAID_ICON_SIZE)
        icon:SetPoint("LEFT", RAID_ICON_START_X + (index - 1) * (RAID_ICON_SIZE + 3), 0)
        icon.border = icon:CreateTexture(nil, "BACKGROUND")
        icon.border:SetPoint("TOPLEFT", -1, 1)
        icon.border:SetPoint("BOTTOMRIGHT", 1, -1)
        icon.border:SetColorTexture(1, 1, 1, 1)
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:EnableMouse(true)
        icon:SetScript("OnEnter", function(self)
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
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        icon:Hide()
        row.icons[index] = icon
    end

    row.ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.ilvlText:SetPoint("RIGHT", -8, 0)
    row.ilvlText:SetJustifyH("RIGHT")

    return row
end

function ILvlCheck:CreateRaidArea(frame)
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -ns.ROWS_TOP_OFFSET)
    scroll:SetSize(ns.ROW_WIDTH, ns.RAID_AREA_HEIGHT)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = self:GetVerticalScrollRange()
        local now = self:GetVerticalScroll() - delta * (RAID_ROW_HEIGHT + RAID_ROW_GAP) * 3
        self:SetVerticalScroll(math.max(0, math.min(max, now)))
    end)
    scroll:Hide()

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(ns.ROW_WIDTH, 1)
    scroll:SetScrollChild(content)

    frame.raidScroll = scroll
    frame.raidContent = content
    self.raidRows = {}
end

function ILvlCheck:UpdateRaidRows()
    local frame = self.frame
    local content = frame.raidContent
    local minimum = ns.GetMinimumItemLevel()
    local visibleBuffs = self.visibleBuffs or {}

    for index = 1, #self.displayOrder do
        local row = self.raidRows[index]
        if not row then
            row = CreateRaidRow(content)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * (RAID_ROW_HEIGHT + RAID_ROW_GAP))
            self.raidRows[index] = row
        end
        local entry = self.players[self.displayOrder[index]]
        local color = entry.classFile and RAID_CLASS_COLORS[entry.classFile]
        local r, g, b = color and color.r or 1, color and color.g or 1, color and color.b or 1
        row.nameText:SetText(ns.ReadyIcon(self, entry) .. (entry.displayName or "?") .. ns.AddonMark(entry))
        row.nameText:SetTextColor(r, g, b)
        row.accent:SetVertexColor(r, g, b, 0.9)
        row.specText:SetText(entry.specName or "")

        if entry.ilvl then
            local below = minimum and entry.ilvl < minimum
            row.ilvlText:SetText(tostring(entry.ilvl))
            if below then
                row.ilvlText:SetTextColor(1.00, 0.55, 0.20)
            else
                row.ilvlText:SetTextColor(0.35, 0.85, 0.45)
            end
        else
            local status = entry.status == "Scanning..." and "Scanning..." or entry.status == "Out of range" and "Out of range" or "Offline"
            row.ilvlText:SetText(status)
            row.ilvlText:SetTextColor(self:GetStatusColor(status))
        end

        local isSelf = entry.unit and UnitIsUnit(entry.unit, "player")
        for iconIndex, icon in ipairs(row.icons) do
            local buffDef = visibleBuffs[iconIndex]
            if buffDef and entry.ilvl and not (buffDef.selfOnly and not isSelf and not self.testMode) then
                local status = entry.buffStatus and entry.buffStatus[buffDef.key]
                icon.texture:SetTexture(buffDef.iconPath)
                icon.texture:SetDesaturated(status ~= true)
                if (status == nil and buffDef.kind == "gear") or (buffDef.optional and status ~= true) then
                    icon.border:SetVertexColor(0.45, 0.45, 0.50, 1)
                elseif status == true then
                    icon.border:SetVertexColor(0.30, 0.85, 0.35, 1)
                else
                    icon.border:SetVertexColor(0.90, 0.20, 0.20, 1)
                end
                icon.buffDef, icon.hasBuff, icon.gearAudit = buffDef, status == true, entry.gearAudit
                icon:Show()
            else
                icon.buffDef = nil
                icon:Hide()
            end
        end
        row:Show()
    end

    for index = #self.displayOrder + 1, #self.raidRows do
        self.raidRows[index]:Hide()
    end
    content:SetHeight(math.max(1, #self.displayOrder * (RAID_ROW_HEIGHT + RAID_ROW_GAP)))
end

-- Shows the party rows or the raid list, whichever fits the group.
function ILvlCheck:ApplyLayoutMode()
    local raid = self:IsRaidMode()
    local frame = self.frame
    for index = 1, #self.rowPool do
        if raid then
            self.rowPool[index]:Hide()
        end
    end
    frame.raidScroll:SetShown(raid)
    frame.title:SetText(raid and "Raid iLvl Check" or "Party iLvl Check")
    return raid
end

-- Test Mode with a made-up raid (/ilvlcheck testraid).
function ILvlCheck:GenerateTestRaid()
    wipe(self.players)
    wipe(self.displayOrder)
    self.dungeonMapID, self.dungeonName = nil, nil
    local minimum = ns.GetMinimumItemLevel() or 270
    for index = 1, RAID_TEST_SIZE do
        local mock = ns.MOCK_POOL[(index - 1) % #ns.MOCK_POOL + 1]
        local key = "~raid" .. index
        self.players[key] = {
            classFile = mock.classFile, displayName = mock.name .. index, specName = mock.specName, specID = mock.specID,
            ilvl = (index % 6 == 0) and nil or minimum + math.random(-10, 20),
            status = (index % 6 == 0) and "Out of range" or "Ready",
            hasAddon = index % 4 == 1,
            buffStatus = self:GenerateMockBuffStatus(),
            testReady = ns.MockReadyStatus(),
        }
        self:ApplyGearAudit(self.players[key], self:GenerateMockGearAudit())
        self.displayOrder[#self.displayOrder + 1] = key
    end
    self:ComputeBuffRelevance()
    self:UpdateUI()
end
