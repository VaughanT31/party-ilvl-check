local addonName, ns = ...

local ILvlCheck = CreateFrame("Frame")
ns.ILvlCheck = ILvlCheck

ILvlCheck.players = {}
ILvlCheck.displayOrder = {}
ILvlCheck.inspectQueue = {}
ILvlCheck.rowPool = {}
ILvlCheck.scanToken = 0
ILvlCheck.waitingForInspect = false
ILvlCheck.pendingUnit = nil
ILvlCheck.pendingGUID = nil
ILvlCheck.pendingKey = nil
ILvlCheck.scanDelay = 0.4
ILvlCheck.inspectTimeout = 3
ILvlCheck.thresholdAlerted = {}
ILvlCheck.scanAnnounced = {}
ILvlCheck.autoShowDelay = 1
ILvlCheck.version = "1.2.0"
ILvlCheck.testMode = false
ILvlCheck.visibleBuffs = {}

ns.STATUS_COLORS = {
    ["Scanning..."] = { 1.00, 0.82, 0.00 },
    ["Offline"] = { 0.62, 0.62, 0.66 },
}

ns.ROW_WIDTH = 424
ns.ROW_HEIGHT = 46
ns.ROW_GAP = 8
ns.ROWS_TOP_OFFSET = 104
ns.BUFF_ICON_START_X = 158
ns.BUFF_ICON_GAP = 4
ns.BUFF_ICON_SIZE = 22
ns.BUFF_RING_PADDING = 2

-- Class raid buffs use spell IDs (stable across patches). Consumable rows
-- (food/flask) match by buff NAME instead, since those items rotate every
-- season. Update the `names` lists in-game each season by right-clicking
-- the buff icon on your own buff bar to read its name, or by cross-checking
-- a current consumables guide (this list was seeded from Method's Midnight
-- 12.1 consumables guide). No Phial or Augment Rune tracked this patch:
-- Phials are too situational to flag as "missing," and Midnight doesn't
-- have an Augment Rune equivalent yet -- add rows back if that changes.
ns.BUFF_DEFINITIONS = {
    { key = "MOTW", label = "Mark of the Wild", kind = "class", providerClass = "DRUID",
      spellIds = { 1126 }, icon = "spell_nature_regeneration" },
    { key = "BATTLE_SHOUT", label = "Battle Shout", kind = "class", providerClass = "WARRIOR",
      spellIds = { 6673 }, icon = "ability_warrior_battleshout" },
    { key = "ARCANE_INTELLECT", label = "Arcane Intellect", kind = "class", providerClass = "MAGE",
      spellIds = { 1459 }, icon = "spell_holy_magicalsentry" },
    { key = "FORTITUDE", label = "Power Word: Fortitude", kind = "class", providerClass = "PRIEST",
      spellIds = { 21562 }, icon = "spell_holy_wordfortitude" },
    { key = "BLESSING_OF_THE_BRONZE", label = "Blessing of the Bronze", kind = "class", providerClass = "EVOKER",
      spellIds = { 364342 }, icon = "ability_evoker_blessingofthebronze" },
    { key = "SKYFURY", label = "Skyfury", kind = "class", providerClass = "SHAMAN",
      spellIds = { 462854 }, icon = "achievement_raidprimalist_windelemental" },
    { key = "FOOD", label = "Well Fed", kind = "consumable", icon = "spell_misc_food",
      names = {
          -- Hearty is the reduced buff members get from a dropped feast they
          -- didn't personally cook/buy -- counts as "fed" for this tracker.
          "Hearty",
          -- Feasts
          "Silvermoon Parade", "Harandar Celebration", "Quel'dorei Medley", "Blooming Feast",
          -- Single-stat / primary-stat food
          "Royal Roast", "Impossibly Royal Roast", "Twilight Angler's Medley", "Spellfire Filet",
          "Mana-Infused Stew", "Bloom Skewers",
          -- Dual-secondary-stat food
          "Flora Frenzy", "Champion's Bento", "Sunwell Delight", "Hearthflame Supper",
          "Fried Bloomtail", "Eversong Pudding", "Bloodthistle-Wrapped Cutlets", "Wise Tails",
          "Spiced Biscuits", "Silvermoon Standard", "Quick Sandwich", "Portable Snack",
          "Forager's Medley", "Farstrider Rations",
          -- Single-secondary-stat food
          "Warped Wise Wings", "Void-Kissed Fish Rolls", "Sun-Seared Lumifin", "Null and Void Plate",
          "Glitter Skewers", "Fel-Kissed Filet", "Buttered Root Crab", "Arcano Cutlets",
          "Tasty Smoked Tetra", "Crimson Calamari", "Braised Blood Hunter", "Felberry Figs",
      } },
    { key = "FLASK", label = "Flask", kind = "consumable",
      icon = "inv_12_profession_alchemy_alhemyspecializations_flasks",
      names = {
          "Flask of Thalassian Resistance", "Flask of the Blood Knights", "Flask of the Magisters",
          "Flask of the Shattered Sun", "Vicious Thalassian Flask of Honor",
      } },
}

for _, buffDef in ipairs(ns.BUFF_DEFINITIONS) do
    buffDef.iconPath = "Interface\\Icons\\" .. buffDef.icon
end

ns.MAX_BUFF_ICONS = #ns.BUFF_DEFINITIONS

ns.MOCK_POOL = {
    { classFile = "DRUID", specName = "Restoration", role = "HEALER", name = "Barkheal" },
    { classFile = "WARRIOR", specName = "Protection", role = "TANK", name = "Ironhide" },
    { classFile = "PALADIN", specName = "Protection", role = "TANK", name = "Lightwall" },
    { classFile = "PRIEST", specName = "Holy", role = "HEALER", name = "Faithbringer" },
    { classFile = "SHAMAN", specName = "Enhancement", role = "DAMAGER", name = "Stormcaller" },
    { classFile = "MAGE", specName = "Frost", role = "DAMAGER", name = "Frostbolt" },
    { classFile = "ROGUE", specName = "Assassination", role = "DAMAGER", name = "Shadowstep" },
    { classFile = "DEMONHUNTER", specName = "Havoc", role = "DAMAGER", name = "Felstrike" },
    { classFile = "MONK", specName = "Mistweaver", role = "HEALER", name = "Chiji" },
    { classFile = "DEATHKNIGHT", specName = "Blood", role = "TANK", name = "Gravebind" },
}

function ns.TableContains(list, value)
    for index = 1, #list do
        if list[index] == value then
            return true
        end
    end

    return false
end

function ns.RoundItemLevel(value)
    if not value or value <= 0 then
        return nil
    end

    return math.floor(value + 0.5)
end

function ns.RoundScore(value)
    if not value or value < 0 then
        return nil
    end

    return math.floor(value + 0.5)
end

function ns.FormatDelta(ilvl, minimum)
    if not minimum then
        return nil, nil
    end

    local diff = ilvl - minimum
    if diff >= 0 then
        return string.format("+%d over", diff), { 0.35, 0.85, 0.45 }
    end

    return string.format("%d under", diff), { 1.00, 0.45, 0.35 }
end

function ns.GetMinimumItemLevel()
    if not ILvlCheckDB or not ILvlCheckDB.minimumItemLevel then
        return nil
    end

    local minimum = tonumber(ILvlCheckDB.minimumItemLevel)
    if minimum and minimum > 0 then
        return minimum
    end

    return nil
end

function ns.SetMinimumItemLevel(value)
    ILvlCheckDB = ILvlCheckDB or {}

    local minimum = tonumber(value)
    if minimum and minimum > 0 then
        ILvlCheckDB.minimumItemLevel = math.floor(minimum)
    else
        ILvlCheckDB.minimumItemLevel = nil
    end
end

function ns.ShouldShowScanAnnouncements()
    return ILvlCheckDB and ILvlCheckDB.showScanAnnouncements == true
end

function ns.SetShowScanAnnouncements(enabled)
    ILvlCheckDB = ILvlCheckDB or {}
    ILvlCheckDB.showScanAnnouncements = enabled == true
end
