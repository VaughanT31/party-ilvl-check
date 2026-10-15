local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

-- Group utility: does the group have interrupts, each kind of dispel, a
-- battle res and Bloodlust? Worked out from each player's class and spec
-- (the spec comes from the inspect, so until it's in, the class decides).
-- Talents can add or remove some of these, so the tooltip says "likely".
--
-- Tables: CLASS -> true for every spec, or { default = bool, [specID] = bool }
-- for specs that differ. Update when a patch moves an ability.

local function Spec(default, overrides)
    overrides.default = default
    return overrides
end

ns.UTILITY_DEFINITIONS = {
    { key = "INTERRUPT", label = "Interrupts", icon = "ability_kick", want = 2,
      note = "Two or more is comfortable for most keys.",
      classes = {
          DEATHKNIGHT = true, DEMONHUNTER = true, EVOKER = true, HUNTER = true, MAGE = true,
          ROGUE = true, SHAMAN = true, WARLOCK = true, WARRIOR = true,
          DRUID = Spec(true, { [105] = false }),          -- not Restoration
          MONK = Spec(true, { [270] = false }),           -- not Mistweaver
          PALADIN = Spec(true, { [65] = false }),         -- not Holy
          PRIEST = Spec(false, { [258] = true }),         -- Shadow (Silence)
      } },
    { key = "MAGIC", label = "Magic dispel", icon = "spell_holy_dispelmagic",
      classes = {
          PRIEST = Spec(false, { [256] = true, [257] = true }),
          PALADIN = Spec(false, { [65] = true }),
          SHAMAN = Spec(false, { [264] = true }),
          DRUID = Spec(false, { [105] = true }),
          MONK = Spec(false, { [270] = true }),
          EVOKER = Spec(false, { [1468] = true }),
          WARLOCK = true,                                 -- Imp's Singe Magic
      } },
    { key = "CURSE", label = "Curse dispel", icon = "spell_nature_removecurse",
      classes = { MAGE = true, DRUID = true, SHAMAN = true, EVOKER = true } },
    { key = "POISON", label = "Poison dispel", icon = "spell_nature_nullifypoison",
      classes = { DRUID = true, PALADIN = true, MONK = true, EVOKER = true } },
    { key = "DISEASE", label = "Disease dispel", icon = "spell_holy_nullifydisease",
      classes = { PRIEST = true, PALADIN = true, MONK = true, EVOKER = true } },
    { key = "BREZ", label = "Battle res", icon = "spell_nature_reincarnation",
      classes = { DRUID = true, DEATHKNIGHT = true, WARLOCK = true, PALADIN = true } },
    { key = "LUST", label = "Bloodlust", icon = "spell_nature_bloodlust",
      classes = { SHAMAN = true, MAGE = true, HUNTER = true, EVOKER = true } },
}

for _, def in ipairs(ns.UTILITY_DEFINITIONS) do
    def.iconPath = "Interface\\Icons\\" .. def.icon
end

-- Whether a class/spec brings def. specID may be nil (not inspected yet).
function ns.BringsUtility(def, classFile, specID)
    local rule = classFile and def.classes[classFile]
    if rule == nil then
        return false
    end
    if type(rule) == "boolean" then
        return rule
    end
    if specID and rule[specID] ~= nil then
        return rule[specID]
    end
    return rule.default
end

-- { [key] = { count, names = { ... } } } for the current roster.
function ILvlCheck:ComputeGroupUtility()
    local result = {}
    for _, def in ipairs(ns.UTILITY_DEFINITIONS) do
        result[def.key] = { count = 0, names = {} }
    end

    for index = 1, #self.displayOrder do
        local entry = self.players[self.displayOrder[index]]
        if entry and entry.classFile then
            for _, def in ipairs(ns.UTILITY_DEFINITIONS) do
                if ns.BringsUtility(def, entry.classFile, entry.specID) then
                    local slot = result[def.key]
                    slot.count = slot.count + 1
                    slot.names[#slot.names + 1] = entry.displayName or "?"
                end
            end
        end
    end

    self.groupUtility = result
    return result
end

-- "good" (enough), "short" (some, under `want`), "missing" (none).
function ns.UtilityState(def, slot)
    if not slot or slot.count == 0 then
        return "missing"
    end
    if def.want and slot.count < def.want then
        return "short"
    end
    return "good"
end
