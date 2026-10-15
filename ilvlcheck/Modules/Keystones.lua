local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

-- Keystones in the group. Your own key comes from the game. Other players'
-- keys come from LibKeystone, the library BigWigs and other addons use to
-- share keys: when any loaded addon carries it, Party iLvl Check asks the
-- party and lists the answers. It isn't bundled with this addon, so without
-- one of those addons only your own key shows.

ILvlCheck.keystones = {}

local function ShortName(name)
    return name and (name:match("^[^%-]+") or name) or nil
end

local function GetLib()
    return LibStub and LibStub("LibKeystone", true) or nil
end

function ILvlCheck:HasKeystoneLib()
    return GetLib() ~= nil
end

function ILvlCheck:GetOwnKeystone()
    if not C_MythicPlus or not C_MythicPlus.GetOwnedKeystoneLevel then
        return nil
    end
    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if level and level > 0 and mapID then
        return { level = level, mapID = mapID }
    end
    return false
end

function ILvlCheck:OnKeystone(level, mapID, name)
    local key = ShortName(name)
    if not key then
        return
    end
    if level and level > 0 and mapID and mapID > 0 then
        self.keystones[key] = { level = level, mapID = mapID }
    else
        self.keystones[key] = false
    end
    if not self.keystoneRefreshQueued then
        self.keystoneRefreshQueued = true
        C_Timer.After(0.3, function()
            ILvlCheck.keystoneRefreshQueued = false
            ILvlCheck:UpdateUI()
        end)
    end
end

-- Asks the party for keys (when LibKeystone is there). Called on every scan.
function ILvlCheck:RequestKeystones()
    wipe(self.keystones)
    local lib = GetLib()
    if not lib then
        return
    end
    if not self.keystoneRegistered then
        lib.Register(self, function(level, mapID, _, name)
            ILvlCheck:OnKeystone(level, mapID, name)
        end)
        self.keystoneRegistered = true
    end
    if IsInGroup and IsInGroup() then
        lib.Request("PARTY")
    end
end

-- { level, mapID } for an entry, false when they have no key, nil unknown.
function ILvlCheck:GetEntryKeystone(entry)
    if entry.testKeystone ~= nil then
        return entry.testKeystone
    end
    if entry.unit and UnitIsUnit(entry.unit, "player") then
        return self:GetOwnKeystone()
    end
    return self.keystones[ShortName(entry.displayName)]
end

function ns.KeystoneMapName(mapID)
    if not mapID then
        return ""
    end
    local name = mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(mapID)
    return name or ("Dungeon " .. tostring(mapID))
end

-- Every player's key for the tooltip and the chat summary, highest first:
-- { { name, level, mapID } }, plus how many players are unknown.
function ILvlCheck:ListKeystones()
    local list, unknown = {}, 0
    for index = 1, #self.displayOrder do
        local entry = self.players[self.displayOrder[index]]
        if entry then
            local key = self:GetEntryKeystone(entry)
            if key then
                list[#list + 1] = { name = entry.displayName or "?", classFile = entry.classFile, level = key.level, mapID = key.mapID }
            elseif key == nil then
                unknown = unknown + 1
            end
        end
    end
    table.sort(list, function(a, b) return a.level > b.level or (a.level == b.level and a.name < b.name) end)
    return list, unknown
end
