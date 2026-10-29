local addonName, ns = ...
local ILvlCheck = ns.ILvlCheck

local GetMinimumItemLevel = ns.GetMinimumItemLevel
local MOCK_POOL = ns.MOCK_POOL

function ILvlCheck:GenerateTestRoster()
    wipe(self.players)
    wipe(self.displayOrder)
    wipe(self.thresholdAlerted)
    wipe(self.scanAnnounced)
    self.dungeonMapID, self.dungeonName = nil, "Test dungeon"

    local minimum = GetMinimumItemLevel() or 270

    local playerLevel = self:GetPlayerItemLevel() or minimum
    local _, playerEntry = self:SetEntry("player", "Ready", playerLevel)
    if playerEntry then
        playerEntry.specName = self:GetPlayerSpecName()
        playerEntry.buffStatus = self:GenerateMockBuffStatus()
        playerEntry.testReady = "ready"
        playerEntry.dungeonRun = { level = math.random(8, 16), timed = true }
        playerEntry.testKeystone = { level = math.random(10, 16), mapID = nil }
        self:ApplyGearAudit(playerEntry, self:GenerateMockGearAudit())
    end

    local playerRole
    local specIndex = GetSpecialization and GetSpecialization()
    if specIndex then
        local specID = GetSpecializationInfo(specIndex)
        playerRole = specID and GetSpecializationRoleByID(specID)
    end
    if playerRole ~= "TANK" and playerRole ~= "HEALER" and playerRole ~= "DAMAGER" then
        playerRole = "DAMAGER"
    end

    local needed = { TANK = 1, HEALER = 1, DAMAGER = 3 }
    needed[playerRole] = math.max(0, needed[playerRole] - 1)

    local pool = {}
    for _, candidate in ipairs(MOCK_POOL) do
        pool[#pool + 1] = candidate
    end

    local fillOrder = {}
    for _, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
        for _ = 1, needed[role] do
            fillOrder[#fillOrder + 1] = role
        end
    end

    for index = 1, #fillOrder do
        local role = fillOrder[index]
        local candidateIndex

        for poolIndex, candidate in ipairs(pool) do
            if candidate.role == role then
                candidateIndex = poolIndex
                break
            end
        end

        if candidateIndex then
            local mock = table.remove(pool, candidateIndex)
            local key = "~test" .. index
            local isBelow = (index % 3 == 0)
            local ilvl = isBelow and (minimum - math.random(1, 15)) or (minimum + math.random(0, 25))

            self.players[key] = {
                unit = nil,
                classFile = mock.classFile,
                displayName = mock.name,
                specName = mock.specName,
                specID = mock.specID,
                -- One with no run here, one over time, the rest timed.
                dungeonRun = (index == 1) and false or { level = math.random(6, 18), timed = index ~= 3 },
                -- One without a key, one unknown (no LibKeystone), the rest with keys.
                testKeystone = (index == 2) and false or (index == 4) and nil or { level = math.random(6, 18), mapID = nil },
                mythicRating = (index == 2) and 0 or math.random(800, 3200),
                ilvl = ilvl,
                status = "Ready",
                -- Two of them "have the addon", to show its mark.
                hasAddon = index == 1 or index == 4,
                buffStatus = self:GenerateMockBuffStatus(),
                testReady = ns.MockReadyStatus(),
            }
            self:ApplyGearAudit(self.players[key], self:GenerateMockGearAudit())
            self.displayOrder[#self.displayOrder + 1] = key
        end
    end

    self:ComputeBuffRelevance()
    self:UpdateUI()
end
