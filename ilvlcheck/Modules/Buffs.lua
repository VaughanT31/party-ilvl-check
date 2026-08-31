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
        if buffDef.kind == "consumable" or (buffDef.providerClass and providerClasses[buffDef.providerClass]) then
            visible[#visible + 1] = buffDef
        end
    end

    self.visibleBuffs = visible
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
        local hasBuff = auraNames[buffDef.label] == true

        if not hasBuff and buffDef.spellIds then
            for _, spellId in ipairs(buffDef.spellIds) do
                if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID and C_UnitAuras.GetAuraDataBySpellID(unit, spellId, "HELPFUL") then
                    hasBuff = true
                    break
                end
            end
        end

        if not hasBuff and buffDef.names then
            for _, name in ipairs(buffDef.names) do
                if auraNames[name] then
                    hasBuff = true
                    break
                end
            end
        end

        entry.buffStatus[buffDef.key] = hasBuff
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
        end
    end

    self:UpdateUI()
end

function ILvlCheck:GenerateMockBuffStatus()
    local status = {}
    for _, buffDef in ipairs(BUFF_DEFINITIONS) do
        status[buffDef.key] = math.random() > 0.3
    end

    return status
end
