local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

local GetMinimumItemLevel = ns.GetMinimumItemLevel

function ILvlCheck:GROUP_ROSTER_UPDATE()
    if self:IsKeystoneTimerRunning() then
        self:HideForActiveKeystone()
        return
    end

    -- Raids fire this constantly (subgroup moves, people zoning), and every
    -- rescan starts the inspect queue again, so wait for it to settle.
    if self.frame and self.frame:IsShown() and not self.rosterRefreshQueued then
        self.rosterRefreshQueued = true
        C_Timer.After(IsInRaid() and 2 or 0.5, function()
            ILvlCheck.rosterRefreshQueued = false
            if ILvlCheck.frame:IsShown() and not ILvlCheck.testMode then
                ILvlCheck:RefreshPartyScan(true)
            end
        end)
    end
end

function ILvlCheck:PLAYER_ENTERING_WORLD()
    self:AutoShowForPartyInstance(true)
end

function ILvlCheck:IsFivePlayerPartyInstance()
    local _, instanceType, _, _, maxPlayers = GetInstanceInfo()
    return instanceType == "party" and maxPlayers == 5
end

function ILvlCheck:IsKeystoneTimerRunning()
    return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() == true
end

function ILvlCheck:CancelActiveScan()
    self.scanToken = self.scanToken + 1
    self:ResetInspectState()
end

function ILvlCheck:HideForActiveKeystone()
    self:CancelActiveScan()

    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    end
end

function ILvlCheck:CHALLENGE_MODE_START()
    self:HideForActiveKeystone()
end

function ILvlCheck:AutoShowForPartyInstance(fromEnteringWorld)

    local function showAndScan()
        if not ILvlCheck:IsFivePlayerPartyInstance() or ILvlCheck:IsKeystoneTimerRunning() then
            return
        end

        if not ILvlCheck.frame then
            ILvlCheck:CreateUI()
        end

        if ILvlCheck.frame.minEditBox then
            ILvlCheck.frame.minEditBox:SetText(GetMinimumItemLevel() or "")
        end

        if ILvlCheck.frame:IsShown() then
            ILvlCheck:RefreshPartyScan()
        else
            ILvlCheck.frame:Show()
        end
    end

    if fromEnteringWorld then
        C_Timer.After(self.autoShowDelay, function()
            showAndScan()
        end)
    else
        showAndScan()
    end
end

function ILvlCheck:ToggleWindow()
    if not self.frame then
        self:CreateUI()
    end

    if self.frame:IsShown() then
        self.frame:Hide()
    elseif self:IsKeystoneTimerRunning() then
        print("|cffffd100ILvlCheck:|r Hidden while the Mythic+ keystone timer is running.")
    else
        self.frame:Show()
    end
end

function ILvlCheck:ADDON_LOADED(loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")
    ILvlCheckDB = ILvlCheckDB or {}
    self:CreateUI()
    self:CreateMinimapButton()
    ns.Share:Init()
    self:HookGroupFinder()

    SLASH_ILVLCHECK1 = "/ilvlcheck"
    SlashCmdList.ILVLCHECK = function(msg)
        msg = (msg or ""):lower():match("^%s*(.-)%s*$")
        if msg == "testraid" or msg == "test raid" then
            if not ILvlCheck.frame:IsShown() then
                ILvlCheck.testMode, ILvlCheck.testRaid = true, true
                ILvlCheck.frame:Show()
            else
                ILvlCheck:SetTestMode("raid")
            end
            return
        elseif msg == "post" then
            ILvlCheck:PostSummary()
            return
        elseif msg:match("^scale") then
            local value = msg:match("^scale%s+(%S+)")
            if value == "reset" then
                ILvlCheck:SetWindowScale(1)
            elseif tonumber(value) then
                ILvlCheck:SetWindowScale(tonumber(value))
            end
            print(string.format("|cff66ccffParty iLvl Check:|r window size %d%%. /ilvlcheck scale 0.8, or drag the corner (scale reset for normal).", math.floor(ILvlCheck:GetWindowScale() * 100 + 0.5)))
            return
        end
        ILvlCheck:ToggleWindow()
    end

    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("INSPECT_READY")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("CHALLENGE_MODE_START")
    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
end

function ILvlCheck:CHAT_MSG_ADDON(prefix, message, channel, sender)
    ns.Share:OnMessage(prefix, message, channel, sender)
end

function ILvlCheck:PLAYER_EQUIPMENT_CHANGED()
    ns.Share:GearChanged()
end

ILvlCheck:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

ILvlCheck:RegisterEvent("ADDON_LOADED")
