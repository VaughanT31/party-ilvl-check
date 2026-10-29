local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

-- The mini window (1.6): what pops up on a ready check instead of the full
-- window. One line per player: ready check icon, name, item level and only
-- what's wrong (missing buffs, food, flask, enchants or gems). The top says
-- who's ready, your durability and the group utility nobody brings.
--   - It fades out a few seconds after the ready check ends (the game's
--     check runs out after 30 seconds).
--   - A pull timer (/pull, /countdown, or an addon's pull using the game's
--     countdown) hides it at once, and it stays away until the pull is over.
--   - In raids it's off by default: ILvlCheckDB.miniInRaid. A raid shows
--     only the players who aren't ready or are missing something.
--   - Drag it anywhere: the spot is saved in ILvlCheckDB.miniPos.
--     /ilvlcheck mini shows it to place it, /ilvlcheck mini reset puts it back.
--   - Click it for the full window.

local WIDTH = 280
local PAD = 8
local ROW_HEIGHT = 16
local ICON = 13
local ICON_X = 156
-- Problem icons that fit on a line; more shows as "+N" on the last one.
local MAX_ICONS = math.floor((WIDTH - PAD * 2 - ICON_X) / (ICON + 2))
local HEADER_HEIGHT = 40
local MAX_RAID_ROWS = 10
local FADE_AFTER = 4        -- seconds after the check ends
local FADE_TIME = 1
local PREVIEW_TIME = 30     -- /ilvlcheck mini
local PULL_GRACE = 10       -- seconds hidden after a countdown ends

local mini
local rows = {}
local fadeTimer
local suppressedUntil = 0

local function SavePosition()
    local left, top = mini:GetLeft(), mini:GetTop()
    if left and top then
        ILvlCheckDB = ILvlCheckDB or {}
        ILvlCheckDB.miniPos = { math.floor(left + 0.5), math.floor(top + 0.5) }
    end
end

local function RestorePosition()
    mini:ClearAllPoints()
    local pos = ILvlCheckDB and ILvlCheckDB.miniPos
    if pos and pos[1] and pos[2] then
        mini:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
    else
        mini:SetPoint("TOP", UIParent, "TOP", 0, -180)
    end
end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, mini)
    row:SetSize(WIDTH - PAD * 2, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", PAD, -HEADER_HEIGHT - (index - 1) * ROW_HEIGHT)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 0, 0)
    row.name:SetWidth(118)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.ilvl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.ilvl:SetPoint("LEFT", 120, 0)
    row.ilvl:SetWidth(30)
    row.ilvl:SetJustifyH("RIGHT")

    row.icons = {}
    for i = 1, MAX_ICONS do
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON, ICON)
        icon:SetPoint("LEFT", ICON_X + (i - 1) * (ICON + 2), 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:Hide()
        row.icons[i] = icon
    end
    row.extra = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.extra:SetPoint("LEFT", ICON_X + (MAX_ICONS - 1) * (ICON + 2), 0)
    rows[index] = row
    return row
end

local function Create()
    mini = CreateFrame("Button", "ILvlCheckMiniFrame", UIParent, "BackdropTemplate")
    mini:SetSize(WIDTH, HEADER_HEIGHT + PAD)
    mini:SetFrameStrata("MEDIUM")
    mini:SetClampedToScreen(true)
    mini:SetMovable(true)
    mini:EnableMouse(true)
    mini:RegisterForDrag("LeftButton")
    mini:RegisterForClicks("LeftButtonUp")
    mini:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    mini:SetBackdropColor(0.07, 0.075, 0.09, 0.92)
    mini:SetBackdropBorderColor(1, 1, 1, 0.10)
    mini:Hide()
    RestorePosition()

    mini:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:StartMoving()
    end)
    mini:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
        -- Moving isn't a click.
        C_Timer.After(0, function() self.dragging = false end)
    end)
    mini:SetScript("OnClick", function(self)
        if self.dragging then return end
        ILvlCheck:HideMini(true)
        if not ILvlCheck.frame then ILvlCheck:CreateUI() end
        ILvlCheck.frame:Show()
    end)
    mini:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Party iLvl Check")
        GameTooltip:AddLine("Click for the full window. Drag to move it.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    mini:SetScript("OnLeave", function() GameTooltip:Hide() end)

    mini.title = mini:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mini.title:SetPoint("TOPLEFT", PAD, -7)
    mini.title:SetPoint("RIGHT", -PAD, 0)
    mini.title:SetJustifyH("LEFT")

    mini.sub = mini:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mini.sub:SetPoint("TOPLEFT", mini.title, "BOTTOMLEFT", 0, -3)
    mini.sub:SetPoint("RIGHT", -PAD, 0)
    mini.sub:SetJustifyH("LEFT")
    mini.sub:SetWordWrap(false)

    mini.more = mini:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    mini.more:SetJustifyH("LEFT")

    local fade = mini:CreateAnimationGroup()
    local alpha = fade:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(FADE_TIME)
    fade:SetScript("OnFinished", function()
        mini:Hide()
        mini:SetAlpha(1)
    end)
    mini.fade = fade

    mini:SetScript("OnHide", function()
        if fadeTimer then fadeTimer:Cancel(); fadeTimer = nil end
        mini.fade:Stop()
        mini:SetAlpha(1)
        if not (ILvlCheck.frame and ILvlCheck.frame:IsShown()) then
            ILvlCheck:StopBuffPolling()
            ILvlCheck:ForgetReadyCheck()
        end
    end)
end

-- What's wrong with a player, as icon paths: missing buffs (not optional
-- ones), and the gear check when it found something.
local function Problems(addon, entry)
    local list = {}
    if not entry.ilvl then return list end
    local isSelf = entry.unit and UnitIsUnit(entry.unit, "player")
    for _, buffDef in ipairs(addon.visibleBuffs or {}) do
        local status = entry.buffStatus and entry.buffStatus[buffDef.key]
        local skip = buffDef.optional or (buffDef.selfOnly and not isSelf and not addon.testMode)
            or (status == nil and buffDef.kind == "gear")
        if not skip and status ~= true then
            list[#list + 1] = buffDef.iconPath
        end
    end
    return list
end

local function ReadyState(addon, entry)
    if addon.testMode then return entry.testReady end
    local check = addon.readyCheck
    return check and entry.unit and check.statuses[UnitGUID(entry.unit) or ""]
end

local function UtilityGaps(addon)
    local utility = addon.groupUtility or addon:ComputeGroupUtility()
    local gaps = {}
    for _, def in ipairs(ns.UTILITY_DEFINITIONS) do
        if ns.UtilityState(def, utility[def.key]) == "missing" then
            gaps[#gaps + 1] = def.label
        end
    end
    return gaps
end

function ILvlCheck:UpdateMini()
    if not mini or not mini:IsShown() then return end
    local minimum = ns.GetMinimumItemLevel()
    local raid = self:IsRaidMode()

    -- Who to list: everyone in a party, only problems in a raid.
    local list, ready, total, fine = {}, 0, 0, 0
    for _, key in ipairs(self.displayOrder) do
        local entry = self.players[key]
        if entry then
            local state = ReadyState(self, entry)
            if state then
                total = total + 1
                if state == "ready" then ready = ready + 1 end
            end
            local problems = Problems(self, entry)
            local under = entry.ilvl and minimum and entry.ilvl < minimum
            if not raid or state == "notready" or state == "waiting" or #problems > 0 or under then
                list[#list + 1] = { entry = entry, state = state, problems = problems, under = under }
            else
                fine = fine + 1
            end
        end
    end

    local title = raid and "Raid ready check" or "Ready check"
    if total > 0 then
        title = title .. ("  |cff%s%d/%d ready|r"):format(ready == total and "66dd77" or "ffaa44", ready, total)
    end
    mini.title:SetText(title)

    local sub = {}
    local durability = ns.AverageDurability()
    if durability then
        local color = durability >= 50 and "66dd77" or (durability >= 20 and "ffaa44" or "ff5555")
        sub[#sub + 1] = ("Durability |cff%s%d%%|r"):format(color, durability)
    end
    if not raid then
        local gaps = UtilityGaps(self)
        sub[#sub + 1] = #gaps > 0 and ("|cffff7755No " .. table.concat(gaps, ", ") .. "|r") or "|cff66dd77Utility covered|r"
    end
    mini.sub:SetText(table.concat(sub, "  |cff5a5a62|||r  "))

    local shown = raid and math.min(#list, MAX_RAID_ROWS) or #list
    for i = 1, math.max(shown, #rows) do
        local row = rows[i] or (i <= shown and CreateRow(i))
        local item = i <= shown and list[i]
        if row and item then
            local entry = item.entry
            local color = entry.classFile and RAID_CLASS_COLORS[entry.classFile]
            row.name:SetText(ns.ReadyIcon(self, entry) .. (entry.displayName or "?"))
            row.name:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
            if entry.ilvl then
                row.ilvl:SetText(entry.ilvl)
                if item.under then row.ilvl:SetTextColor(1, 0.45, 0.35) else row.ilvl:SetTextColor(0.85, 0.85, 0.88) end
            else
                row.ilvl:SetText("|cff8a8a92...|r")
            end
            local count = #item.problems
            local overflow = count > MAX_ICONS
            for n, icon in ipairs(row.icons) do
                local path = item.problems[n]
                if overflow and n == MAX_ICONS then path = nil end
                icon:SetShown(path ~= nil)
                if path then icon:SetTexture(path) end
            end
            row.extra:SetText(overflow and ("|cffff7755+%d|r"):format(count - MAX_ICONS + 1) or "")
            row:Show()
        elseif row then
            row:Hide()
        end
    end

    local height = HEADER_HEIGHT + shown * ROW_HEIGHT + PAD
    local extra = (#list - shown) + (raid and fine or 0)
    if raid and extra > 0 then
        mini.more:ClearAllPoints()
        mini.more:SetPoint("TOPLEFT", PAD, -HEADER_HEIGHT - shown * ROW_HEIGHT - 1)
        local hidden = #list - shown
        mini.more:SetText(hidden > 0 and ("+%d more, and %d all set"):format(hidden, fine) or ("%d all set"):format(fine))
        mini.more:Show()
        height = height + ROW_HEIGHT
    else
        mini.more:Hide()
    end
    mini:SetHeight(height)
end

-- After UpdateUI (UI.lua), so the mini follows every scan and buff poll.
local UpdateUI = ILvlCheck.UpdateUI
function ILvlCheck:UpdateUI(...)
    UpdateUI(self, ...)
    self:UpdateMini()
end

function ILvlCheck:IsMiniShown()
    return mini ~= nil and mini:IsShown()
end

-- Shows the mini window and scans the group. seconds: fade out after this
-- long (for the preview); nil waits for the ready check to end.
function ILvlCheck:ShowMini(seconds)
    if not mini then Create() end
    if fadeTimer then fadeTimer:Cancel(); fadeTimer = nil end
    mini.fade:Stop()
    mini:SetAlpha(1)
    local wasShown = mini:IsShown()
    mini:Show()
    if not wasShown and not (self.frame and self.frame:IsShown()) then
        self:RefreshPartyScan(true)
        self:StartBuffPolling()
        if not self.testMode then self:RescanBuffs() end
    end
    self:UpdateUI()
    if seconds then self:FadeMini(seconds) end
end

-- Fades it out after delay seconds.
function ILvlCheck:FadeMini(delay)
    if not mini or not mini:IsShown() then return end
    if fadeTimer then fadeTimer:Cancel() end
    fadeTimer = C_Timer.NewTimer(delay or FADE_AFTER, function()
        fadeTimer = nil
        if mini:IsShown() then mini.fade:Play() end
    end)
end

-- now: hide at once rather than fading.
function ILvlCheck:HideMini(now)
    if not mini or not mini:IsShown() then return end
    if now then mini:Hide() else self:FadeMini(0) end
end

function ILvlCheck:ResetMiniPosition()
    ILvlCheckDB = ILvlCheckDB or {}
    ILvlCheckDB.miniPos = nil
    if mini then RestorePosition() end
end

function ns.MiniInRaid()
    return ILvlCheckDB and ILvlCheckDB.miniInRaid == true
end

function ns.SetMiniInRaid(on)
    ILvlCheckDB = ILvlCheckDB or {}
    ILvlCheckDB.miniInRaid = on == true
end

-- No pop-up during a pull countdown, combat or a running key.
function ILvlCheck:PopupSuppressed()
    return GetTime() < suppressedUntil or InCombatLockdown() or self:IsKeystoneTimerRunning()
end

function ILvlCheck:START_PLAYER_COUNTDOWN(_, timeRemaining)
    suppressedUntil = GetTime() + (tonumber(timeRemaining) or 10) + PULL_GRACE
    self:HideMini(true)
end

function ILvlCheck:CANCEL_PLAYER_COUNTDOWN()
    suppressedUntil = 0
end

function ILvlCheck:PLAYER_REGEN_DISABLED()
    self:HideMini(true)
end
