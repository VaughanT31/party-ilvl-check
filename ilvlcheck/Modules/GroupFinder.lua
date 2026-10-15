local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

-- Group finder applicants. When you list a Mythic+ group, each applicant
-- row shows their best run in your listed dungeon ("+14", green when timed,
-- orange when over time), without hovering, and their item level turns
-- orange when it's under your Min iLvl. Hooks Blizzard's own row update, so
-- nothing changes about how applying or inviting works.

local function ListedActivity()
    local entry = C_LFGList and C_LFGList.GetActiveEntryInfo and C_LFGList.GetActiveEntryInfo()
    if not entry then
        return nil
    end
    return (entry.activityIDs and entry.activityIDs[1]) or entry.activityID
end

local function BestRunText(appID, memberIdx, activityID)
    if not activityID or not C_LFGList.GetApplicantDungeonScoreForListing then
        return nil
    end
    local info = C_LFGList.GetApplicantDungeonScoreForListing(appID, memberIdx, activityID)
    if not info or not info.mapName then
        return nil -- not a Mythic+ listing
    end
    if not info.bestRunLevel or info.bestRunLevel <= 0 then
        return "|cff8c8c94no run|r"
    end
    if info.finishedSuccess then
        return ("|cff59d973+%d|r"):format(info.bestRunLevel)
    end
    return ("|cfff2a64d+%d|r"):format(info.bestRunLevel)
end

local function UpdateMember(member, appID, memberIdx)
    if not member or not appID or not memberIdx then
        return
    end

    local text = BestRunText(appID, memberIdx, ListedActivity())
    if text then
        if not member.ILvlCheckBest then
            member.ILvlCheckBest = member:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            local anchor = member.Rating or member.ItemLevel
            if anchor then
                member.ILvlCheckBest:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
            else
                member.ILvlCheckBest:SetPoint("RIGHT", member, "RIGHT", -4, 0)
            end
        end
        member.ILvlCheckBest:SetText(text)
        member.ILvlCheckBest:Show()
    elseif member.ILvlCheckBest then
        member.ILvlCheckBest:Hide()
    end

    local minimum = ns.GetMinimumItemLevel()
    if minimum and member.ItemLevel and C_LFGList.GetApplicantMemberInfo then
        local itemLevel = select(5, C_LFGList.GetApplicantMemberInfo(appID, memberIdx))
        if itemLevel and itemLevel > 0 and itemLevel < minimum then
            member.ItemLevel:SetTextColor(1.00, 0.55, 0.20)
        end
    end
end

local hooked = false
local function Hook()
    if hooked or not _G.LFGListApplicationViewer_UpdateApplicantMember then
        return hooked
    end
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", function(member, appID, memberIdx)
        -- Never let a problem here break Blizzard's applicant list.
        pcall(UpdateMember, member, appID, memberIdx)
    end)
    hooked = true
    return true
end

function ILvlCheck:HookGroupFinder()
    if Hook() then
        return
    end
    if EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_GroupFinder", Hook)
    end
end
