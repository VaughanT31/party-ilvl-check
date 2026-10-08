local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

local BUFF_DEFINITIONS = ns.BUFF_DEFINITIONS

function ILvlCheck:ComputeBuffRelevance()
    local providerClasses = {}
    for index = 1, #self.displayOrder do
        local entry = self.players[self.displayOrder[index]]
        if entry and entry.classFile then
            providerClasses[entry.classFile] = true
        end
    end

    local visible = {}
    for _, buffDef in ipairs(BUFF_DEFINITIONS) do
        if buffDef.kind ~= "class" or (buffDef.providerClass and providerClasses[buffDef.providerClass]) then
            visible[#visible + 1] = buffDef
        end
    end

    self.visibleBuffs = visible
end

local function HasAuraBuff(unit, buffDef, auraNames)
    if auraNames[buffDef.label] then
        return true
    end

    if buffDef.spellIds then
        for _, spellId in ipairs(buffDef.spellIds) do
            if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID and C_UnitAuras.GetAuraDataBySpellID(unit, spellId, "HELPFUL") then
                return true
            end
        end
    end

    if buffDef.names then
        for _, name in ipairs(buffDef.names) do
            if auraNames[name] then
                return true
            end
        end
    end

    return false
end

function ILvlCheck:ScanEntryBuffs(entry)
    if not entry or not entry.unit or not UnitExists(entry.unit) then
        return
    end

    entry.buffStatus = entry.buffStatus or {}
    local unit = entry.unit

    local auraNames = {}
    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
        for index = 1, 40 do
            local aura = C_UnitAuras.GetBuffDataByIndex(unit, index)
            if not aura then
                break
            end

            if aura.name then
                auraNames[aura.name] = true
            end
        end
    end

    for _, buffDef in ipairs(BUFF_DEFINITIONS) do
        if buffDef.kind == "weapon" then
            if UnitIsUnit(unit, "player") then
                entry.buffStatus[buffDef.key] = self:HasWeaponOil()
            end
        elseif buffDef.kind ~= "gear" then
            -- "gear" is set by ApplyGearAudit (Gear.lua), not from auras.
            entry.buffStatus[buffDef.key] = HasAuraBuff(unit, buffDef, auraNames)
        end
    end
end

function ILvlCheck:StartBuffPolling()
    self:StopBuffPolling()

    if self.testMode then
        return
    end

    self.buffPollTicker = C_Timer.NewTicker(3, function()
        ILvlCheck:RescanBuffs()
    end)
end

function ILvlCheck:StopBuffPolling()
    if self.buffPollTicker then
        self.buffPollTicker:Cancel()
        self.buffPollTicker = nil
    end
end

function ILvlCheck:RescanBuffs()
    if self.testMode or not self.frame or not self.frame:IsShown() then
        return
    end

    self:ComputeBuffRelevance()

    for index = 1, #self.displayOrder do
        local entry = self.players[self.displayOrder[index]]
        if entry then
            self:ScanEntryBuffs(entry)
            -- Your own gear can change while the window is open (enchanting
            -- or socketing at the table), so it's re-audited each poll.
            if entry.unit and UnitIsUnit(entry.unit, "player") then
                self:ApplyGearAudit(entry, self:AuditGear("player"))
            end
        end
    end

    self:RetryOutOfRange()
    self:UpdateUI()
end

function ILvlCheck:GenerateMockBuffStatus()
    local status = {}
    for _, buffDef in ipairs(BUFF_DEFINITIONS) do
        status[buffDef.key] = math.random() > 0.3
    end

    return status
end
