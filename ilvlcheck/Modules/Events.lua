local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

local GetMinimumItemLevel = ns.GetMinimumItemLevel

function ILvlCheck:GROUP_ROSTER_UPDATE()
    if self:IsKeystoneTimerRunning() then
        self:HideForActiveKeystone()
        return
    end

    if self.frame and self.frame:IsShown() then
        self:RefreshPartyScan()
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

    SLASH_ILVLCHECK1 = "/ilvlcheck"
    SlashCmdList.ILVLCHECK = function()
        ILvlCheck:ToggleWindow()
    end

    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("INSPECT_READY")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("CHALLENGE_MODE_START")
end

ILvlCheck:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

ILvlCheck:RegisterEvent("ADDON_LOADED")
