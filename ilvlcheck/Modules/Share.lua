local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

-- Sharing between group members who also run Party iLvl Check (1.5).
--
-- Inspecting is slow (one player at a time, in range only), so addon users
-- tell each other what they know:
--   S  "this is me": your own item level, spec, tier and gear check. Sent
--      when the window scans and when your gear changes. Nobody needs to
--      inspect you.
--   R  "I inspected them": the result of an inspect, sent as it finishes, so
--      in a raid the group shares the inspecting instead of everyone
--      inspecting all twenty.
--   H  "hello": asks everyone with the addon to send their S.
-- Every message names the player by GUID. A message is used only when that
-- GUID belongs to someone in your group, and an S only when it comes from
-- that player themselves (the server fills in who sent an addon message).
-- An R never replaces a result you inspected yourself.
-- Nothing is sent while addon messages are locked (boss encounters, Mythic+).

local Share = {}
ns.Share = Share

local MARK = " |TInterface\\AddOns\\ilvlcheck\\icon:12:12|t"

-- The small Party iLvl Check icon after the names of people who have it
-- (and yourself).
function ns.AddonMark(entry)
    if entry and (entry.hasAddon or (entry.unit and UnitIsUnit(entry.unit, "player"))) then
        return MARK
    end
    return ""
end

-- "  |  3 with Party iLvl Check" for the header, counting yourself, when
-- anyone else has it.
function ns.AddonCountText(addon)
    local count = 0
    for _, key in ipairs(addon.displayOrder) do
        local entry = addon.players[key]
        if entry and entry.hasAddon then count = count + 1 end
    end
    if count == 0 then
        return ""
    end
    return ("  |cff5a5a62|||r  %s%d with Party iLvl Check"):format(MARK:sub(2) .. " ", count + 1)
end

local PREFIX = "PILC1"
local SEND_GAP = 0.25          -- seconds between our messages
local HELLO_EVERY = 10         -- at most one hello this often
local ANSWER_DELAY = 2         -- answers to a hello spread over this many seconds

local queue = {}
local sending = false
local lastHello = nil
local registered = false

local function Secret(value)
    return issecretvalue and value ~= nil and issecretvalue(value)
end

local function Locked()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
        return ok and locked == true
    end
    return false
end

local function Channel()
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid and IsInRaid() then
        return "RAID"
    elseif IsInGroup and IsInGroup() then
        return "PARTY"
    end
    return nil
end

local function Pump()
    if #queue == 0 or Locked() then
        sending = false
        return
    end
    sending = true
    local message = table.remove(queue, 1)
    local channel = Channel()
    if channel then
        pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, channel)
    end
    C_Timer.After(SEND_GAP, Pump)
end

local function Send(message)
    if not registered or Locked() or not Channel() then
        return false
    end
    for index = 1, #queue do
        if queue[index] == message then
            return true
        end
    end
    queue[#queue + 1] = message
    if not sending then
        Pump()
    end
    return true
end

local function List(labels)
    if type(labels) ~= "table" then
        return ""
    end
    return table.concat(labels, ",")
end

-- One player's data as a message body: guid|ilvl|specID|tier|enchants|sockets
function Share.Encode(kind, guid, ilvl, specID, audit)
    return table.concat({
        kind, guid or "", tostring(ilvl or 0), tostring(specID or 0),
        tostring(audit and audit.tierPieces or ""),
        audit and List(audit.missingEnchants) or "-", audit and List(audit.emptySockets) or "-",
    }, "|")
end

local function Labels(text)
    local labels = {}
    for label in (text or ""):gmatch("[^,]+") do
        if #labels < 20 then
            labels[#labels + 1] = label:sub(1, 20)
        end
    end
    return labels
end

-- The message as a table, or nil when it isn't one of ours.
function Share.Decode(message)
    if type(message) ~= "string" or #message > 255 then
        return nil
    end
    local kind, guid, ilvl, specID, tier, enchants, sockets =
        message:match("^([SRH])|?([^|]*)|?([^|]*)|?([^|]*)|?([^|]*)|?([^|]*)|?([^|]*)$")
    if not kind then
        return nil
    end
    if kind == "H" then
        return { kind = "H" }
    end
    ilvl = tonumber(ilvl)
    if not guid:match("^Player%-") or not ilvl or ilvl <= 0 or ilvl > 2000 then
        return nil
    end
    local data = { kind = kind, guid = guid, ilvl = math.floor(ilvl + 0.5), specID = tonumber(specID) }
    if data.specID == 0 then
        data.specID = nil
    end
    if enchants ~= "-" and sockets ~= "-" then
        data.audit = { missingEnchants = Labels(enchants), emptySockets = Labels(sockets), tierPieces = tonumber(tier) }
    end
    return data
end

-- The roster unit with this GUID, or nil.
local function UnitForGUID(guid)
    local units = ILvlCheck:GetRosterUnits()
    for index = 1, #units do
        local unit = units[index]
        if UnitExists(unit) then
            local unitGUID = UnitGUID(unit)
            if not Secret(unitGUID) and unitGUID == guid then
                return unit
            end
        end
    end
    return nil
end

local function SameName(unit, sender)
    local name = UnitName(unit)
    if not name or Secret(name) then
        return false
    end
    return Ambiguate(sender, "short") == Ambiguate(name, "short")
end

local function SpecName(specID)
    if specID and GetSpecializationInfoByID then
        local _, name = GetSpecializationInfoByID(specID)
        return name
    end
    return nil
end

-- Puts shared data into the window. Returns true when it was used.
function Share:Apply(data, sender)
    local unit = UnitForGUID(data.guid)
    if not unit or UnitIsUnit(unit, "player") then
        return false
    end
    if data.kind == "S" and not SameName(unit, sender) then
        return false
    end
    local key = ILvlCheck:GetUnitKey(unit)
    local entry = key and ILvlCheck.players[key]
    if data.kind == "R" and entry and entry.status == "Ready" and not entry.via then
        return false
    end
    if ILvlCheck.pendingKey == key then
        return false
    end
    local _, updated = ILvlCheck:SetEntry(unit, "Ready", data.ilvl)
    if not updated then
        return false
    end
    if data.specID then
        updated.specID = data.specID
        updated.specName = SpecName(data.specID) or updated.specName
    end
    if data.audit then
        data.audit.sharedBy = data.kind == "S" and "self" or Ambiguate(sender, "short")
        ILvlCheck:ApplyGearAudit(updated, data.audit)
    end
    updated.failedAt = nil
    updated.hasAddon = updated.hasAddon or data.kind == "S"
    updated.via = data.kind == "R" and Ambiguate(sender, "short") or nil
    for index = #ILvlCheck.inspectQueue, 1, -1 do
        if ILvlCheck.inspectQueue[index] == key then
            table.remove(ILvlCheck.inspectQueue, index)
        end
    end
    ILvlCheck.inspectAttempts[key] = nil
    ILvlCheck:UpdateUI()
    ILvlCheck:CheckThresholdAlerts()
    return true
end

-- Your own data.
function Share:SendSelf()
    local ilvl = ILvlCheck:GetPlayerItemLevel()
    if not ilvl then
        return false
    end
    return Send(Share.Encode("S", UnitGUID("player"), ilvl, ILvlCheck:GetPlayerSpecID(), ILvlCheck:AuditGear("player")))
end

-- An inspect you finished, for the others.
function Share:Relay(unit, ilvl, specID, audit)
    local guid = unit and UnitGUID(unit)
    if not guid or Secret(guid) or not ilvl then
        return false
    end
    return Send(Share.Encode("R", guid, ilvl, specID, audit))
end

-- Called when the window scans: say who you are and ask the others.
function Share:Hello()
    local now = GetTime()
    if lastHello and now - lastHello < HELLO_EVERY then
        return false
    end
    lastHello = now
    self:SendSelf()
    return Send("H")
end

function Share:OnMessage(prefix, message, channel, sender)
    if prefix ~= PREFIX or Secret(message) or Secret(sender) or not sender then
        return
    end
    if channel ~= "PARTY" and channel ~= "RAID" and channel ~= "INSTANCE_CHAT" then
        return
    end
    if Ambiguate(sender, "none") == UnitName("player") then
        return
    end
    local data = Share.Decode(message)
    if not data then
        return
    end
    if data.kind == "H" then
        C_Timer.After(math.random() * ANSWER_DELAY, function() Share:SendSelf() end)
        return
    end
    self:Apply(data, sender)
end

function Share:Init()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        registered = C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) ~= false
    end
end

-- Gear changes: tell the group, a moment after the last change.
local gearTimer
function Share:GearChanged()
    if gearTimer then
        gearTimer:Cancel()
    end
    gearTimer = C_Timer.NewTimer(3, function()
        gearTimer = nil
        if IsInGroup() then
            Share:SendSelf()
        end
    end)
end
