local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

-- Ran with before. Each finished key is remembered, per account and on this
-- computer only, so rows and applicants can say "2 timed, 1 over" with you.
--
--   ILvlCheckDB.runs = { { t = date, m = mapID, n = dungeon, l = level,
--                          ok = timed, s = seconds, p = { "Name-Realm", ... } }, ... }
--
-- Oldest first. Records keep enough to link a log report to them later.
-- The group is noted at the start of a key too, in case the game won't say
-- at the end who was there.

local History = {}
ns.History = History

local DEFAULT_MAX, LOWEST_MAX, HIGHEST_MAX = 1000, 50, 5000
local RETRIES, RETRY_DELAY = 3, 2
local SAME_RUN_SECONDS = 60

local byName

-- A value the game keeps secret during a key can't be stored or compared.
local function Plain(value)
    if value ~= nil and issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Runs()
    ILvlCheckDB = ILvlCheckDB or {}
    ILvlCheckDB.runs = ILvlCheckDB.runs or {}
    return ILvlCheckDB.runs
end

function History.NameKey(name)
    name = Plain(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    if name:find("-", 1, true) then
        return name
    end
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    return realm and (name .. "-" .. realm) or nil
end

local function UnitKey(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end
    local name, realm = UnitFullName(unit)
    name, realm = Plain(name), Plain(realm)
    if not name or name == "" or name == UNKNOWNOBJECT then
        return nil
    end
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return History.NameKey(name)
end

local function Group()
    local names = {}
    for index = 1, 4 do
        local key = UnitKey("party" .. index)
        if key then
            names[#names + 1] = key
        end
    end
    return names
end

local function Tally(run)
    if not byName then
        return
    end
    for _, name in ipairs(run.p or {}) do
        local item = byName[name]
        if not item then
            item = { timed = 0, over = 0 }
            byName[name] = item
        end
        if run.ok then
            item.timed = item.timed + 1
        else
            item.over = item.over + 1
        end
        item.last = math.max(item.last or 0, run.t or 0)
    end
end

local function BuildIndex()
    byName = {}
    for _, run in ipairs(Runs()) do
        Tally(run)
    end
end

function History.GetMax()
    return ILvlCheckDB and ILvlCheckDB.runsMax or DEFAULT_MAX
end

function History.SetMax(value)
    ILvlCheckDB = ILvlCheckDB or {}
    ILvlCheckDB.runsMax = math.max(LOWEST_MAX, math.min(HIGHEST_MAX, math.floor(value)))
    History.Trim()
end

function History.GetMinLevel()
    return ILvlCheckDB and ILvlCheckDB.runsMinLevel or 0
end

function History.SetMinLevel(value)
    ILvlCheckDB = ILvlCheckDB or {}
    value = math.floor(value)
    ILvlCheckDB.runsMinLevel = value > 0 and value or nil
end

-- Drops the oldest runs over the limit.
function History.Trim()
    local runs = Runs()
    local extra = #runs - History.GetMax()
    if extra > 0 then
        for index = 1, #runs do
            runs[index] = runs[index + extra]
        end
        BuildIndex()
    end
end

function History.Add(run)
    if run.l and run.l < History.GetMinLevel() then
        return false
    end
    local runs = Runs()
    local last = runs[#runs]
    if last and last.m == run.m and last.l == run.l and math.abs((last.t or 0) - run.t) < SAME_RUN_SECONDS then
        return false
    end
    runs[#runs + 1] = run
    if not byName then
        BuildIndex()
    else
        Tally(run)
    end
    History.Trim()
    return true
end

function History.Clear()
    ILvlCheckDB = ILvlCheckDB or {}
    ILvlCheckDB.runs = {}
    byName = {}
end

-- { timed, over, last } for a name, or nil when you haven't run with them.
function History.With(name)
    local key = History.NameKey(name)
    if not key then
        return nil
    end
    if not byName then
        BuildIndex()
    end
    return byName[key]
end

function History.ForUnit(unit)
    local key = UnitKey(unit)
    return key and History.With(key) or nil
end

-- "2 timed, 1 over", timed in green and over time in orange.
function ns.FormatRanWith(item)
    if not item then
        return nil
    end
    local parts = {}
    if item.timed > 0 then
        parts[#parts + 1] = ("|cff59d973%d timed|r"):format(item.timed)
    end
    if item.over > 0 then
        parts[#parts + 1] = ("|cfff2a64d%d over|r"):format(item.over)
    end
    return table.concat(parts, ", ")
end

-- What the game says about the key just finished, as map, level, seconds,
-- timed, member names (nil when it won't say).
local function Completion()
    local mapID, level, milliseconds, onTime, members
    if C_ChallengeMode.GetChallengeCompletionInfo then
        local ok, info = pcall(C_ChallengeMode.GetChallengeCompletionInfo)
        if ok and info then
            mapID, level = Plain(info.mapChallengeModeID), Plain(info.level)
            milliseconds, onTime = Plain(info.time), Plain(info.onTime)
            members = info.members
        end
    end
    if not mapID and C_ChallengeMode.GetCompletedInfo then
        local ok, map, lvl, time, timed = pcall(C_ChallengeMode.GetCompletedInfo)
        if ok then
            mapID, level, milliseconds, onTime = Plain(map), Plain(lvl), Plain(time), Plain(timed)
        end
    end
    local names
    if type(members) == "table" then
        local me = UnitKey("player")
        names = {}
        for _, member in ipairs(members) do
            local key = History.NameKey(member.name)
            if key and key ~= me then
                names[#names + 1] = key
            end
        end
    end
    return mapID, level, milliseconds, onTime, names
end

function ILvlCheck:CHALLENGE_MODE_START()
    self:HideForActiveKeystone()

    local level
    if C_ChallengeMode.GetActiveKeystoneInfo then
        local ok, active = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
        if ok then
            level = Plain(active)
        end
    end
    ILvlCheckDB = ILvlCheckDB or {}
    ILvlCheckDB.runActive = {
        t = GetServerTime(),
        m = Plain(C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()),
        l = level,
        p = Group(),
    }
end

local function Record(tries)
    local active = ILvlCheckDB and ILvlCheckDB.runActive
    local mapID, level, milliseconds, onTime, names = Completion()
    if (not mapID or not level or onTime == nil) and tries > 0 then
        C_Timer.After(RETRY_DELAY, function()
            Record(tries - 1)
        end)
        return
    end

    mapID = mapID or (active and active.m)
    level = level or (active and active.l)
    if not mapID then
        return
    end
    if not names or #names == 0 then
        names = Group()
    end
    if #names == 0 and active then
        names = active.p or {}
    end

    local dungeon = C_ChallengeMode.GetMapUIInfo and Plain((C_ChallengeMode.GetMapUIInfo(mapID)))
    History.Add({
        t = GetServerTime(),
        m = mapID,
        n = dungeon,
        l = level,
        ok = onTime == true,
        s = milliseconds and math.floor(milliseconds / 1000) or nil,
        p = names,
    })
    if ILvlCheckDB then
        ILvlCheckDB.runActive = nil
    end
    if ILvlCheck.IsDisplaying and ILvlCheck:IsDisplaying() then
        ILvlCheck:UpdateUI()
    end
end

function ILvlCheck:CHALLENGE_MODE_COMPLETED()
    Record(RETRIES)
end

-- /ilvlcheck runs ...
function ILvlCheck:RunsCommand(args)
    local say = "|cff66ccffParty iLvl Check:|r "
    local command, value = (args or ""):match("^(%S*)%s*(%S*)")
    if command == "min" and tonumber(value) then
        History.SetMinLevel(tonumber(value))
    elseif command == "max" and tonumber(value) then
        History.SetMax(tonumber(value))
    elseif command == "clear" then
        History.Clear()
        print(say .. "forgot every run.")
        return
    end

    local runs = Runs()
    local least = History.GetMinLevel()
    print(say .. ("%d runs remembered, up to %d. %s /ilvlcheck runs min 10, max 500 or clear."):format(
        #runs, History.GetMax(), least > 0 and ("Keys from +%d."):format(least) or "Every key level."))
    for index = #runs, math.max(1, #runs - 4), -1 do
        local run = runs[index]
        print(("  %s: %s +%s, %s, with %s"):format(date("%d %b", run.t), run.n or "?", run.l or "?",
            run.ok and "timed" or "over time", #run.p > 0 and table.concat(run.p, ", ") or "nobody"))
    end
end
