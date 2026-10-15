local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

-- Each player's best Mythic+ run in the dungeon you're about to run. The
-- overall score says little about this key; their best here says more.
-- From C_PlayerInfo.GetPlayerMythicPlusRatingSummary, which every party
-- member's client shares, so no inspect is needed.
--
-- The dungeon is the one you're standing in (matched by its instance map
-- ID against the season's dungeons), or outside a dungeon the one your own
-- keystone is for.

function ILvlCheck:GetCurrentChallengeMap()
    if not C_ChallengeMode then
        return nil
    end

    local active = C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
    if active then
        return active, C_ChallengeMode.GetMapUIInfo(active)
    end

    local instanceID = select(8, GetInstanceInfo())
    if instanceID and C_ChallengeMode.GetMapTable then
        for _, mapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
            local name, _, _, _, _, instanceMapID = C_ChallengeMode.GetMapUIInfo(mapID)
            if instanceMapID == instanceID then
                return mapID, name
            end
        end
    end

    local owned = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if owned then
        return owned, C_ChallengeMode.GetMapUIInfo(owned)
    end

    return nil
end

-- { level, timed, score } for the unit's best run on mapID, false when they
-- have none there, nil when it can't be read.
function ILvlCheck:GetDungeonRun(unit, mapID)
    if not unit or not mapID or not C_PlayerInfo or not C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        return nil
    end

    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
    if not summary then
        return nil
    end

    for _, run in ipairs(summary.runs or {}) do
        if run.challengeModeID == mapID then
            if not run.bestRunLevel or run.bestRunLevel <= 0 then
                return false
            end
            return { level = run.bestRunLevel, timed = run.finishedSuccess == true, score = run.mapScore }
        end
    end

    return false
end

-- "+14 here" (green when timed, orange when only over time), "none here".
function ns.FormatDungeonRun(run)
    if run == nil then
        return nil
    end
    if run == false then
        return "|cff8c8c94none here|r"
    end
    if run.timed then
        return ("|cff59d973+%d here|r"):format(run.level)
    end
    return ("|cfff2a64d+%d here (over time)|r"):format(run.level)
end

function ILvlCheck:UpdateDungeonRuns()
    local mapID, name = self:GetCurrentChallengeMap()
    self.dungeonMapID, self.dungeonName = mapID, name

    for index = 1, #self.displayOrder do
        local entry = self.players[self.displayOrder[index]]
        if entry and entry.unit then
            entry.dungeonRun = self:GetDungeonRun(entry.unit, mapID)
        end
    end
end
