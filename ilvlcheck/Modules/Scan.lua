local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

local TableContains = ns.TableContains
local RoundItemLevel = ns.RoundItemLevel
local RoundScore = ns.RoundScore
local GetMinimumItemLevel = ns.GetMinimumItemLevel
local ShouldShowScanAnnouncements = ns.ShouldShowScanAnnouncements

function ILvlCheck:GetRosterUnits()
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
    entry.mythicRating = self:GetMythicPlusRating(unit)
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

function ILvlCheck:ResetInspectState()
    wipe(self.inspectQueue)
    self.waitingForInspect = false
    self.pendingUnit = nil
    self.pendingGUID = nil
    self.pendingKey = nil
    ClearInspectPlayer()
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

function ILvlCheck:FinishPendingInspect(status, ilvl)
    if not self.pendingKey then
        return
    end

    local pendingKey = self.pendingKey
    local entry = self.players[pendingKey]
    if entry then
        entry.ilvl = ilvl
        entry.status = status
        entry.specName = entry.specName or self:GetInspectedSpecName(self.pendingUnit)
        entry.mythicRating = entry.mythicRating or self:GetMythicPlusRating(self.pendingUnit)
    end

    self.waitingForInspect = false
    self.pendingUnit = nil
    self.pendingGUID = nil
    self.pendingKey = nil
    ClearInspectPlayer()
    self:UpdateUI()
    if ilvl and entry and not self.scanAnnounced[pendingKey] then
        self.scanAnnounced[pendingKey] = true
        self:ShowScanAnnouncement(entry)
    end
    self:CheckThresholdAlerts()
    self:ScheduleNextInspect(self.scanDelay)
end

function ILvlCheck:ProcessNextInspect()
    if self.waitingForInspect then
        return
    end

    local unit = table.remove(self.inspectQueue, 1)
    if not unit then
        return
    end

    if not UnitExists(unit) then
        self:ScheduleNextInspect(0.1)
        return
    end

    local key = self:GetUnitKey(unit)
    local entry = key and self.players[key]

    if not key or not entry then
        self:ScheduleNextInspect(0.1)
        return
    end

    if not CanInspect(unit) then
        entry.status = "Not inspectable"
        self:UpdateUI()
        self:ScheduleNextInspect(self.scanDelay)
        return
    end

    if not CheckInteractDistance(unit, 1) then
        entry.status = "Out of range"
        self:UpdateUI()
        self:ScheduleNextInspect(self.scanDelay)
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
    local pendingKey = key
    local pendingUnit = unit
    C_Timer.After(self.inspectTimeout, function()
        if token ~= ILvlCheck.scanToken then
            return
        end

        if ILvlCheck.waitingForInspect and ILvlCheck.pendingKey == pendingKey and ILvlCheck.pendingUnit == pendingUnit then
            ILvlCheck:FinishPendingInspect("Not inspectable", nil)
        end
    end)
end

function ILvlCheck:RefreshPartyScan()
    self.scanToken = self.scanToken + 1
    self:ResetInspectState()

    if self.testMode then
        self:GenerateTestRoster()
        return
    end

    wipe(self.players)
    wipe(self.displayOrder)
    wipe(self.thresholdAlerted)
    wipe(self.scanAnnounced)

    local units = self:GetRosterUnits()
    for index = 1, #units do
        local unit = units[index]
        if UnitExists(unit) then
            if UnitIsUnit(unit, "player") then
                local playerLevel = self:GetPlayerItemLevel()
                if playerLevel then
                    local _, entry = self:SetEntry(unit, "Ready", playerLevel)
                    if entry then
                        entry.specName = self:GetPlayerSpecName()
                    end
                else
                    self:SetEntry(unit, "Not inspectable", nil)
                end
            elseif not UnitIsConnected(unit) then
                self:SetEntry(unit, "Not inspectable", nil)
            elseif not CanInspect(unit) then
                self:SetEntry(unit, "Not inspectable", nil)
            elseif not CheckInteractDistance(unit, 1) then
                self:SetEntry(unit, "Out of range", nil)
            else
                self:SetEntry(unit, "Scanning...", nil)
                self.inspectQueue[#self.inspectQueue + 1] = unit
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

function ILvlCheck:INSPECT_READY(inspectGUID)
    if not self.waitingForInspect or not self.pendingGUID or inspectGUID ~= self.pendingGUID then
        return
    end

    local itemLevel
    if self.pendingUnit and UnitExists(self.pendingUnit) and C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        itemLevel = RoundItemLevel(C_PaperDollInfo.GetInspectItemLevel(self.pendingUnit))
    end

    if itemLevel then
        self:FinishPendingInspect("Ready", itemLevel)
    else
        self:FinishPendingInspect("Not inspectable", nil)
    end
end
