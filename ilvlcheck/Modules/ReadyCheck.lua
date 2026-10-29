local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

-- Ready checks (1.6): the mini window (Modules/Mini.lua) pops up when a
-- ready check starts (in raids only when turned on), and every name, there
-- and in the full window, gets the game's ready, not ready or waiting icon. Once the check ends, anyone who never answered shows as
-- not ready (away). The answers stay until the window closes or the next
-- check starts.
--
-- When the window opens by itself, ILvlCheckDB.popup:
--   "readycheck" (default)  the mini window, on a ready check
--   "dungeon"               entering a 5-player dungeon (how it worked
--                           before 1.6)
--   "both", "off"
--
-- The header also shows your own average durability: the game only gives
-- it for your own gear.

local READY_ICONS = {
    ready = "Interface\\RaidFrame\\ReadyCheck-Ready",
    notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
    waiting = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}

local POPUP_MODES = { readycheck = true, dungeon = true, both = true, off = true }

function ns.GetPopupMode()
    local mode = ILvlCheckDB and ILvlCheckDB.popup
    return POPUP_MODES[mode] and mode or "readycheck"
end

function ns.SetPopupMode(mode)
    if not POPUP_MODES[mode] then
        return false
    end
    ILvlCheckDB = ILvlCheckDB or {}
    ILvlCheckDB.popup = mode
    return true
end

function ns.PopsUpOnReadyCheck()
    local mode = ns.GetPopupMode()
    return mode == "readycheck" or mode == "both"
end

function ns.PopsUpInDungeons()
    local mode = ns.GetPopupMode()
    return mode == "dungeon" or mode == "both"
end

local function GroupUnits()
    local units = {}
    if IsInRaid and IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. index
        end
    else
        units[1] = "player"
        for index = 1, GetNumSubgroupMembers() do
            units[#units + 1] = "party" .. index
        end
    end
    return units
end

local function SetStatus(unit, status)
    local check = ILvlCheck.readyCheck
    local guid = unit and UnitGUID(unit)
    if check and guid then
        check.statuses[guid] = status
    end
end

function ILvlCheck:READY_CHECK(initiator)
    self.readyCheck = { active = true, statuses = {} }
    for _, unit in ipairs(GroupUnits()) do
        local status = GetReadyCheckStatus and GetReadyCheckStatus(unit)
        SetStatus(unit, READY_ICONS[status] and status or "waiting")
    end
    -- Whoever started it is ready.
    if initiator and UnitExists(initiator) then
        SetStatus(initiator, "ready")
    end

    local inRaid = IsInRaid and IsInRaid()
    if self.frame and self.frame:IsShown() then
        self:UpdateUI()
    elseif ns.PopsUpOnReadyCheck() and (not inRaid or ns.MiniInRaid()) and not self:PopupSuppressed() then
        self:ShowMini()
    end
end

function ILvlCheck:READY_CHECK_CONFIRM(unit, isReady)
    SetStatus(unit, isReady and "ready" or "notready")
    if self:IsDisplaying() then
        self:UpdateUI()
    end
end

function ILvlCheck:READY_CHECK_FINISHED()
    local check = self.readyCheck
    if not check then
        return
    end
    check.active = false
    for guid, status in pairs(check.statuses) do
        if status == "waiting" then
            check.statuses[guid] = "notready"
        end
    end
    if self:IsDisplaying() then
        self:UpdateUI()
    end
    -- The mini window has done its job: it fades out shortly after.
    self:FadeMini()
end

-- The full window or the mini window is up, so scans and polls are wanted.
function ILvlCheck:IsDisplaying()
    return (self.frame and self.frame:IsShown()) or self:IsMiniShown()
end

-- The window closing forgets a finished check, so it doesn't come back
-- stale the next time the window opens.
function ILvlCheck:ForgetReadyCheck()
    if self.readyCheck and not self.readyCheck.active then
        self.readyCheck = nil
    end
end

-- Test mode's made-up players: mostly ready.
function ns.MockReadyStatus()
    local roll = math.random()
    return roll < 0.7 and "ready" or (roll < 0.85 and "waiting" or "notready")
end

-- The icon before a name, or "" when there's no check to show.
function ns.ReadyIcon(addon, entry)
    local check = addon.readyCheck
    local status
    if addon.testMode then
        status = entry and entry.testReady
    elseif check and entry and entry.unit then
        status = check.statuses[UnitGUID(entry.unit) or ""]
    end
    local icon = status and READY_ICONS[status]
    return icon and ("|T" .. icon .. ":14:14|t ") or ""
end

-- "Ready 3/5", green when everyone is, for the header.
local function ReadyText(addon)
    local ready, total = 0, 0
    for _, key in ipairs(addon.displayOrder) do
        local entry = addon.players[key]
        local status
        if addon.testMode then
            status = entry and entry.testReady
        elseif addon.readyCheck and entry and entry.unit then
            status = addon.readyCheck.statuses[UnitGUID(entry.unit) or ""]
        end
        if status then
            total = total + 1
            if status == "ready" then ready = ready + 1 end
        end
    end
    if total == 0 then
        return nil
    end
    local color = ready == total and "66dd77" or "ffaa44"
    return ("|cff%sReady %d/%d|r"):format(color, ready, total)
end

-- Your average durability over the gear that has any, or nil.
function ns.AverageDurability()
    local current, maximum = 0, 0
    for slot = 1, 19 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            current, maximum = current + cur, maximum + max
        end
    end
    if maximum == 0 then
        return nil
    end
    return math.floor(current / maximum * 100 + 0.5)
end

local function DurabilityText()
    local percent = ns.AverageDurability()
    if not percent then
        return nil
    end
    local color = percent >= 50 and "66dd77" or (percent >= 20 and "ffaa44" or "ff5555")
    return ("Durability |cff%s%d%%|r"):format(color, percent)
end

-- The header line: "Ready 3/5  |  Durability 87%  |  " then main (the
-- dungeon or the raid size), leaving out whichever are empty.
function ns.HeaderText(addon, main)
    local parts = {}
    parts[#parts + 1] = ReadyText(addon)
    parts[#parts + 1] = DurabilityText()
    if main and main ~= "" then parts[#parts + 1] = main end
    return table.concat(parts, "  |cff5a5a62|||r  ")
end
