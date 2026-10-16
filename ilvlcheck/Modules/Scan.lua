local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

local TableContains = ns.TableContains
local RoundItemLevel = ns.RoundItemLevel
local RoundScore = ns.RoundScore
local GetMinimumItemLevel = ns.GetMinimumItemLevel
local ShouldShowScanAnnouncements = ns.ShouldShowScanAnnouncements

function ILvlCheck:GetRosterUnits()
    if IsInRaid and IsInRaid() then
        return self:GetRaidUnits()
    end

    local units = { "player" }
    local subgroupMembers = GetNumSubgroupMembers()

    for index = 1, subgroupMembers do
        units[#units + 1] = "party" .. index
    end

    return units
end

function ILvlCheck:GetUnitKey(unit)
    local name, realm = UnitName(unit)
    if not name then
        return nil
    end

    if realm and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end

function ILvlCheck:GetDisplayName(unit, key)
    if unit and UnitExists(unit) then
        local unitName = GetUnitName(unit, true)
        if unitName and unitName ~= "" then
            return Ambiguate(unitName, "short")
        end
    end

    return key and Ambiguate(key, "short") or "Unknown"
end

function ILvlCheck:GetPlayerSpecName()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex then
        return nil
    end

    local _, specName = GetSpecializationInfo(specIndex)
    return specName
end

function ILvlCheck:GetPlayerSpecID()
    local specIndex = GetSpecialization and GetSpecialization()
    return specIndex and GetSpecializationInfo(specIndex) or nil
end

function ILvlCheck:GetInspectedSpecID(unit)
    local specID = GetInspectSpecialization and GetInspectSpecialization(unit)
    if not specID or specID == 0 then
        return nil
    end
    return specID
end

function ILvlCheck:GetInspectedSpecName(unit)
    local specID = GetInspectSpecialization and GetInspectSpecialization(unit)
    if not specID or specID == 0 then
        return nil
    end

    local _, specName = GetSpecializationInfoByID(specID)
    return specName
end

function ILvlCheck:GetMythicPlusRating(unit)
    if not C_PlayerInfo or not C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        return nil
    end

    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
    if not summary then
        return nil
    end

    return RoundScore(summary.currentSeasonScore)
end

function ILvlCheck:SetEntry(unit, status, ilvl)
    local key = self:GetUnitKey(unit)
    if not key then
        return nil
    end

    local entry = self.players[key] or {}
    entry.unit = unit
    entry.classFile = select(2, UnitClass(unit))
    entry.displayName = self:GetDisplayName(unit, key)
    entry.specName = entry.specName or (UnitIsUnit(unit, "player") and self:GetPlayerSpecName() or nil)
    entry.specID = entry.specID or (UnitIsUnit(unit, "player") and self:GetPlayerSpecID() or nil)
    entry.mythicRating = self:GetMythicPlusRating(unit)
    entry.dungeonRun = self:GetDungeonRun(unit, self.dungeonMapID)
    entry.ilvl = ilvl
    entry.status = status
    self.players[key] = entry

    if not TableContains(self.displayOrder, key) then
        self.displayOrder[#self.displayOrder + 1] = key
    end

    return key, entry
end

function ILvlCheck:GetRosterSize()
    local count = 0
    local units = self:GetRosterUnits()

    for index = 1, #units do
        if UnitExists(units[index]) then
            count = count + 1
        end
    end

    return count
end

function ILvlCheck:GetPlayerItemLevel()
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local inspectLevel = C_PaperDollInfo.GetInspectItemLevel("player")
        if inspectLevel and inspectLevel > 0 then
            return RoundItemLevel(inspectLevel)
        end
    end

    if GetAverageItemLevel then
        local _, equippedLevel = GetAverageItemLevel()
        return RoundItemLevel(equippedLevel)
    end

    return nil
end

-- Our inspect data is cleared once read, but never while Blizzard's inspect
-- window is open: that would empty the player's own inspect.
local function ClearOurInspect()
    if not (InspectFrame and InspectFrame:IsShown()) then
        ClearInspectPlayer()
    end
end

function ILvlCheck:ResetInspectState()
    wipe(self.inspectQueue)
    wipe(self.inspectAttempts)
    self.waitingForInspect = false
    self.pendingUnit = nil
    self.pendingGUID = nil
    self.pendingKey = nil
    ClearOurInspect()
end

function ILvlCheck:ShowThresholdAlert(entry)
    local minimum = GetMinimumItemLevel()
    if not minimum or not entry or not entry.ilvl or entry.ilvl >= minimum then
        return
    end

    local name = entry.displayName or "Unknown"
    local message = string.format("%s is below minimum iLvl: %d/%d", name, entry.ilvl, minimum)

    if RaidNotice_AddMessage and RaidWarningFrame then
        local warningColor = ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.15, b = 0.15 }
        RaidNotice_AddMessage(RaidWarningFrame, message, warningColor)
    end

    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(message, 1, 0.15, 0.15, 1)
    end

    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
        PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    end

    print("|cffff2020ILvlCheck:|r " .. message)
end

function ILvlCheck:ShowScanAnnouncement(entry)
    if not ShouldShowScanAnnouncements() or not entry or not entry.ilvl then
        return
    end

    if entry.unit and UnitIsUnit(entry.unit, "player") then
        return
    end

    local name = entry.displayName or "Unknown"
    local score = entry.mythicRating and tostring(entry.mythicRating) or "n/a"
    local message = string.format("%s scanned: iLvl %d, IO %s", name, entry.ilvl, score)

    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(message, 0.95, 0.82, 0.18, 1)
    end

    print("|cffffd100ILvlCheck:|r " .. message)
end

function ILvlCheck:CheckThresholdAlerts()
    local minimum = GetMinimumItemLevel()
    if not minimum then
        return
    end

    for index = 1, #self.displayOrder do
        local key = self.displayOrder[index]
        local entry = self.players[key]

        if entry and entry.ilvl and entry.ilvl < minimum and not self.thresholdAlerted[key] then
            self.thresholdAlerted[key] = true
            self:ShowThresholdAlert(entry)
        end
    end
end

function ILvlCheck:ScheduleNextInspect(delay)
    local token = self.scanToken
    C_Timer.After(delay or self.scanDelay, function()
        if token ~= ILvlCheck.scanToken then
            return
        end

        ILvlCheck:ProcessNextInspect()
    end)
end

-- The queue holds player keys (Name-Realm), not unit tokens: in a raid,
-- raid1..raid40 move to other players whenever someone joins, leaves or is
-- moved, so a token queued a few seconds ago can point at someone else.
function ILvlCheck:UnitForKey(key)
    local units = self:GetRosterUnits()
    for index = 1, #units do
        local unit = units[index]
        if UnitExists(unit) and self:GetUnitKey(unit) == key then
            return unit
        end
    end
    return nil
end

function ILvlCheck:QueueInspect(key)
    if not TableContains(self.inspectQueue, key) then
        self.inspectQueue[#self.inspectQueue + 1] = key
    end
end

function ILvlCheck:ClearPending()
    self.waitingForInspect = false
    self.pendingUnit = nil
    self.pendingGUID = nil
    self.pendingKey = nil
    ClearOurInspect()
end

function ILvlCheck:FinishPendingInspect(status, ilvl)
    if not self.pendingKey then
        return
    end

    local pendingKey = self.pendingKey
    local entry = self.players[pendingKey]
    if entry then
        entry.ilvl = ilvl
        entry.status = status
        entry.failedAt = nil
        entry.specName = entry.specName or self:GetInspectedSpecName(self.pendingUnit)
        entry.specID = entry.specID or self:GetInspectedSpecID(self.pendingUnit)
        entry.mythicRating = entry.mythicRating or self:GetMythicPlusRating(self.pendingUnit)
        if entry.dungeonRun == nil then
            entry.dungeonRun = self:GetDungeonRun(self.pendingUnit, self.dungeonMapID)
        end
    end
    self.inspectAttempts[pendingKey] = nil

    self:ClearPending()
    self:UpdateUI()
    if ilvl and entry and not self.scanAnnounced[pendingKey] then
        self.scanAnnounced[pendingKey] = true
        self:ShowScanAnnouncement(entry)
    end
    self:CheckThresholdAlerts()
    self:ScheduleNextInspect(self.scanDelay)
end

-- No answer in time, or an answer without an item level (their items
-- weren't loaded yet, or another addon's inspect replaced ours: raids often
-- run several addons that inspect). Tried again at the back of the queue, a
-- little later, up to maxInspectAttempts times.
function ILvlCheck:FailPendingInspect()
    local key = self.pendingKey
    if not key then
        return
    end

    local entry = self.players[key]
    local attempts = (self.inspectAttempts[key] or 0) + 1
    self.inspectAttempts[key] = attempts
    self:ClearPending()

    if entry and attempts < self.maxInspectAttempts then
        entry.status = "Scanning..."
        self:QueueInspect(key)
    elseif entry then
        entry.status = "Not inspectable"
        entry.failedAt = GetTime()
        self.inspectAttempts[key] = nil
    end

    self:UpdateUI()
    self:ScheduleNextInspect(self.retryDelay)
end

function ILvlCheck:ProcessNextInspect()
    if self.waitingForInspect then
        return
    end

    local key = table.remove(self.inspectQueue, 1)
    if not key then
        return
    end

    local entry = self.players[key]
    local unit = entry and self:UnitForKey(key)
    if not unit then
        self:ScheduleNextInspect(0.1)
        return
    end
    entry.unit = unit

    if not UnitIsConnected(unit) or not CanInspect(unit) then
        entry.status = "Not inspectable"
        entry.failedAt = GetTime()
        self:UpdateUI()
        self:ScheduleNextInspect(0.1)
        return
    end

    if not CheckInteractDistance(unit, 1) then
        entry.status = "Out of range"
        self:UpdateUI()
        self:ScheduleNextInspect(0.1)
        return
    end

    self.waitingForInspect = true
    self.pendingUnit = unit
    self.pendingGUID = UnitGUID(unit)
    self.pendingKey = key
    entry.status = "Scanning..."
    self:UpdateUI()
    NotifyInspect(unit)

    local token = self.scanToken
    local pendingGUID = self.pendingGUID
    C_Timer.After(self.inspectTimeout, function()
        if token ~= ILvlCheck.scanToken then
            return
        end

        if ILvlCheck.waitingForInspect and ILvlCheck.pendingKey == key and ILvlCheck.pendingGUID == pendingGUID then
            ILvlCheck:FailPendingInspect()
        end
    end)
end

-- Sorts one roster member into the list: yourself straight away, anyone
-- else queued for inspection when they can be.
function ILvlCheck:AddRosterUnit(unit)
    if UnitIsUnit(unit, "player") then
        local playerLevel = self:GetPlayerItemLevel()
        if playerLevel then
            local _, entry = self:SetEntry(unit, "Ready", playerLevel)
            if entry then
                entry.specName = self:GetPlayerSpecName()
                self:ApplyGearAudit(entry, self:AuditGear("player"))
            end
        else
            self:SetEntry(unit, "Not inspectable", nil)
        end
    elseif not UnitIsConnected(unit) or not CanInspect(unit) then
        local _, entry = self:SetEntry(unit, "Not inspectable", nil)
        if entry then entry.failedAt = GetTime() end
    elseif not CheckInteractDistance(unit, 1) then
        self:SetEntry(unit, "Out of range", nil)
    else
        local key = self:SetEntry(unit, "Scanning...", nil)
        if key then self:QueueInspect(key) end
    end
end

-- keepResults (roster changes): people already scanned keep their result and
-- aren't inspected again, people who left are dropped, and only the rest are
-- queued. Raids change their roster all the time, and starting over each
-- time meant the people at the end of the queue were never reached.
function ILvlCheck:RefreshPartyScan(keepResults)
    self.scanToken = self.scanToken + 1
    self:ResetInspectState()

    if self.testMode then
        if self.testRaid then
            self:GenerateTestRaid()
        else
            self:GenerateTestRoster()
        end
        return
    end

    local units = self:GetRosterUnits()
    local kept = {}
    if keepResults then
        local inRoster = {}
        for index = 1, #units do
            local key = UnitExists(units[index]) and self:GetUnitKey(units[index])
            if key then inRoster[key] = units[index] end
        end
        local order = {}
        for index = 1, #self.displayOrder do
            local key = self.displayOrder[index]
            local entry = self.players[key]
            if entry and inRoster[key] then
                order[#order + 1] = key
                entry.unit = inRoster[key]
                if entry.status == "Ready" and not UnitIsUnit(inRoster[key], "player") then
                    kept[key] = true
                end
            else
                self.players[key] = nil
                self.thresholdAlerted[key] = nil
                self.scanAnnounced[key] = nil
            end
        end
        self.displayOrder = order
    else
        wipe(self.players)
        wipe(self.displayOrder)
        wipe(self.thresholdAlerted)
        wipe(self.scanAnnounced)
    end

    self.dungeonMapID, self.dungeonName = self:GetCurrentChallengeMap()
    -- Keys are a party thing: LibKeystone only asks party chat.
    if not self:IsRaidMode() then
        self:RequestKeystones()
    else
        wipe(self.keystones)
    end

    for index = 1, #units do
        local unit = units[index]
        if UnitExists(unit) then
            local key = self:GetUnitKey(unit)
            if not (key and kept[key]) then
                self:AddRosterUnit(unit)
            end
        end
    end

    self:ComputeBuffRelevance()
    for index = 1, #self.displayOrder do
        local entry = self.players[self.displayOrder[index]]
        if entry then
            self:ScanEntryBuffs(entry)
        end
    end

    self:UpdateUI()
    self:CheckThresholdAlerts()

    if #self.inspectQueue > 0 then
        self:ScheduleNextInspect(0.15)
    end
end

-- Called from the buff poll while the window is open: anyone marked "Out of
-- range" who has since come close is queued for inspection again, and so is
-- anyone who couldn't be inspected a while ago (retryAfterFail seconds), so
-- the window fills in on its own instead of needing Refresh. Skipped in
-- combat, where CheckInteractDistance is restricted.
function ILvlCheck:RetryOutOfRange()
    if self.testMode or (InCombatLockdown and InCombatLockdown()) then
        return
    end

    local wasIdle = #self.inspectQueue == 0 and not self.waitingForInspect
    local queued = false
    local now = GetTime()

    for index = 1, #self.displayOrder do
        local key = self.displayOrder[index]
        local entry = self.players[key]
        local retry = entry and (entry.status == "Out of range"
            or (entry.status == "Not inspectable" and entry.failedAt and now - entry.failedAt >= self.retryAfterFail))
        local unit = retry and self:UnitForKey(key)
        if unit and not UnitIsUnit(unit, "player") and UnitIsConnected(unit) and CanInspect(unit)
            and CheckInteractDistance(unit, 1) and not TableContains(self.inspectQueue, key) then
            entry.status = "Scanning..."
            entry.unit = unit
            self:QueueInspect(key)
            queued = true
        end
    end

    if queued and wasIdle then
        self:ScheduleNextInspect(0.1)
    end
end

function ILvlCheck:INSPECT_READY(inspectGUID)
    if not self.waitingForInspect or not self.pendingGUID or inspectGUID ~= self.pendingGUID then
        return
    end

    local itemLevel
    if self.pendingUnit and UnitExists(self.pendingUnit) and UnitGUID(self.pendingUnit) == self.pendingGUID
        and C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        itemLevel = RoundItemLevel(C_PaperDollInfo.GetInspectItemLevel(self.pendingUnit))
    end

    -- Gear links are only readable until FinishPendingInspect clears the
    -- inspect, so the enchant/gem audit has to happen here.
    if itemLevel then
        self:ApplyGearAudit(self.players[self.pendingKey], self:AuditGear(self.pendingUnit))
        self:FinishPendingInspect("Ready", itemLevel)
    else
        self:FailPendingInspect()
    end
end
