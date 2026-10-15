local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

-- The "Post" button: the group check as one or two chat lines, so a group
-- leader can share it fast. Sent to instance chat in a group finder group,
-- party chat otherwise, and only printed for you when you're alone.

local MAX_MESSAGE = 250 -- chat lines are cut at 255 characters

local UTILITY_SHORT = {
    INTERRUPT = "interrupt", MAGIC = "magic dispel", CURSE = "curse dispel", POISON = "poison dispel",
    DISEASE = "disease dispel", BREZ = "battle res", LUST = "Bloodlust",
}

-- The summary as a list of chat-sized lines.
function ILvlCheck:BuildSummaryLines()
    local minimum = ns.GetMinimumItemLevel()
    local raid = self:IsRaidMode()
    local players = {}
    for index = 1, #self.displayOrder do
        local entry = self.players[self.displayOrder[index]]
        if entry then
            local text = entry.displayName or "?"
            if raid then
                -- A raid list is long, so only the players to talk to.
                if entry.ilvl and minimum and entry.ilvl < minimum then
                    players[#players + 1] = text .. " " .. entry.ilvl
                end
                text = nil
            elseif entry.ilvl then
                text = text .. " " .. entry.ilvl
                if minimum and entry.ilvl < minimum then
                    text = text .. " (under " .. minimum .. ")"
                end
            else
                text = text .. " (not checked)"
            end
            if text and entry.dungeonRun then
                text = text .. (" +%d%s here"):format(entry.dungeonRun.level, entry.dungeonRun.timed and "" or " over time")
            end
            if text then
                players[#players + 1] = text
            end
        end
    end

    local parts = {}
    if raid then
        local ready, below, offline = self:GetReadinessCounts()
        local text = ("Raid iLvl Check: %d checked"):format(ready + below)
        if offline > 0 then text = text .. (", %d not checked"):format(offline) end
        if minimum then
            text = text .. (#players > 0 and (", under " .. minimum .. ": " .. table.concat(players, ", ")) or (", everyone " .. minimum .. "+"))
        end
        parts[#parts + 1] = text
    else
        parts[#parts + 1] = "Party iLvl Check: " .. table.concat(players, ", ")
    end

    local utility = self.groupUtility or self:ComputeGroupUtility()
    local missing, short = {}, {}
    for _, def in ipairs(ns.UTILITY_DEFINITIONS) do
        local state = ns.UtilityState(def, utility[def.key])
        if state == "missing" then
            missing[#missing + 1] = UTILITY_SHORT[def.key]
        elseif state == "short" then
            short[#short + 1] = "only 1 " .. UTILITY_SHORT[def.key]
        end
    end
    if #missing > 0 or #short > 0 then
        local text = {}
        if #missing > 0 then text[#text + 1] = "No " .. table.concat(missing, ", ") end
        if #short > 0 then text[#text + 1] = table.concat(short, ", ") end
        parts[#parts + 1] = table.concat(text, "; ")
    else
        parts[#parts + 1] = "Group utility all covered"
    end

    local keys = self:ListKeystones()
    if #keys > 0 then
        local text = {}
        for _, key in ipairs(keys) do
            text[#text + 1] = ("%s +%d %s"):format(key.name, key.level, ns.KeystoneMapName(key.mapID))
        end
        parts[#parts + 1] = "Keys: " .. table.concat(text, ", ")
    end

    -- Pack the parts into as few lines as fit.
    local lines, current = {}, ""
    for _, part in ipairs(parts) do
        local joined = current == "" and part or (current .. " | " .. part)
        if #joined <= MAX_MESSAGE then
            current = joined
        else
            if current ~= "" then lines[#lines + 1] = current end
            current = #part <= MAX_MESSAGE and part or part:sub(1, MAX_MESSAGE - 3) .. "..."
        end
    end
    if current ~= "" then lines[#lines + 1] = current end
    return lines
end

function ILvlCheck:PostSummary()
    local lines = self:BuildSummaryLines()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        print("|cffffd100ILvlCheck:|r Chat is locked right now (boss fight or Mythic+), try again after.")
        return
    end

    local channel
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        channel = "INSTANCE_CHAT"
    elseif IsInRaid and IsInRaid() then
        channel = "RAID"
    elseif IsInGroup and IsInGroup() then
        channel = "PARTY"
    end

    for _, line in ipairs(lines) do
        if channel and not self.testMode then
            local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
            send(line, channel)
        else
            print("|cffffd100ILvlCheck:|r " .. line)
        end
    end
end
