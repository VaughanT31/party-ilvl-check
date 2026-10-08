local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

-- Enchantable slots for the current season. Like the consumable buff names in
-- Core.lua, this list changes between expansions: update it each season from a
-- current enchanting guide. Off-hand only counts when it's an actual weapon
-- (not a shield or held-in-off-hand item), see IsWeapon below.
local ENCHANT_SLOTS = {
    { slot = 1, label = "Head" },
    { slot = 3, label = "Shoulder" },
    { slot = 5, label = "Chest" },
    { slot = 7, label = "Legs" },
    { slot = 8, label = "Feet" },
    { slot = 11, label = "Ring 1" },
    { slot = 12, label = "Ring 2" },
    { slot = 16, label = "Main Hand" },
    { slot = 17, label = "Off Hand", weaponOnly = true },
}

-- Every slot that can carry a socket, checked for empty ones.
local SOCKET_SLOTS = {
    { slot = 1, label = "Head" }, { slot = 2, label = "Neck" }, { slot = 3, label = "Shoulder" },
    { slot = 15, label = "Back" }, { slot = 5, label = "Chest" }, { slot = 9, label = "Wrist" },
    { slot = 10, label = "Hands" }, { slot = 6, label = "Waist" }, { slot = 7, label = "Legs" },
    { slot = 8, label = "Feet" }, { slot = 11, label = "Ring 1" }, { slot = 12, label = "Ring 2" },
    { slot = 13, label = "Trinket 1" }, { slot = 14, label = "Trinket 2" },
    { slot = 16, label = "Main Hand" }, { slot = 17, label = "Off Hand" },
}

-- itemString fields: item:itemID:enchantID:gem1:gem2:gem3:gem4:...
local function ParseLink(link)
    local enchant, g1, g2, g3, g4 = link:match("item:%-?%d*:(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*)")
    local gems = 0
    for _, gem in ipairs({ g1, g2, g3, g4 }) do
        if tonumber(gem) and tonumber(gem) > 0 then
            gems = gems + 1
        end
    end
    return tonumber(enchant) or 0, gems
end

-- Socket count comes from the item's stats (EMPTY_SOCKET_* keys), which reflect
-- the bonus IDs on this exact copy. Returns nil when the item isn't cached yet,
-- so an unloaded item never reads as "no sockets".
local function CountSockets(link)
    local getStats = (C_Item and C_Item.GetItemStats) or GetItemStats
    local stats = getStats and getStats(link)
    if not stats then
        return nil
    end

    local sockets = 0
    for key, value in pairs(stats) do
        if type(key) == "string" and key:find("^EMPTY_SOCKET_") then
            sockets = sockets + value
        end
    end
    return sockets
end

local function IsWeapon(link)
    local getInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not getInfo then
        return false
    end
    local classID = select(6, getInfo(link))
    return classID == (Enum.ItemClass and Enum.ItemClass.Weapon or 2)
end

-- Returns { missingEnchants = { labels }, emptySockets = { labels } } for the
-- unit's equipped gear, or nil when nothing is readable (inspect data gone).
-- For other players this must run while their inspect data is still loaded,
-- i.e. from INSPECT_READY before ClearInspectPlayer.
function ILvlCheck:AuditGear(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local audit = { missingEnchants = {}, emptySockets = {} }
    local anyItem = false

    for _, info in ipairs(ENCHANT_SLOTS) do
        local link = GetInventoryItemLink(unit, info.slot)
        if link then
            anyItem = true
            if not info.weaponOnly or IsWeapon(link) then
                local enchant = ParseLink(link)
                if enchant == 0 then
                    audit.missingEnchants[#audit.missingEnchants + 1] = info.label
                end
            end
        end
    end

    for _, info in ipairs(SOCKET_SLOTS) do
        local link = GetInventoryItemLink(unit, info.slot)
        if link then
            anyItem = true
            local sockets = CountSockets(link)
            local _, gems = ParseLink(link)
            if sockets and sockets > gems then
                audit.emptySockets[#audit.emptySockets + 1] = info.label
            end
        end
    end

    if not anyItem then
        return nil
    end
    return audit
end

function ILvlCheck:ApplyGearAudit(entry, audit)
    if not entry then
        return
    end

    entry.gearAudit = audit
    entry.buffStatus = entry.buffStatus or {}
    if audit then
        entry.buffStatus.GEAR = #audit.missingEnchants == 0 and #audit.emptySockets == 0
    else
        entry.buffStatus.GEAR = nil
    end
end

-- Player's own temporary weapon enchant (oil / whetstone). Other players'
-- temporary enchants aren't exposed by any API, so this is self-only.
function ILvlCheck:HasWeaponOil()
    if not GetWeaponEnchantInfo then
        return false
    end
    local hasMainHand = GetWeaponEnchantInfo()
    return hasMainHand and true or false
end

function ILvlCheck:GenerateMockGearAudit()
    if math.random() > 0.4 then
        return { missingEnchants = {}, emptySockets = {} }
    end
    return { missingEnchants = { "Legs", "Ring 2" }, emptySockets = { "Neck" } }
end
