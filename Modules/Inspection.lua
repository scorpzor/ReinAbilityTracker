-- Modules/Inspection.lua
-- Handles player self-inspection for talents and trinkets

local RAT = _G.RAT
RAT.Inspection = {}

local Inspection = RAT.Inspection

local hasAscensionAPI = C_CharacterAdvancement ~= nil

--------------------------------------------------------------------------------
-- Local State
--------------------------------------------------------------------------------

local inspectionFrame = nil
local lastInspectTime = 0

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function Inspection:Initialize()
    if hasAscensionAPI then
        RAT:DebugPrint("C_CharacterAdvancement - using for player talent inspection")
    else
        RAT:DebugPrint("WARNING: C_CharacterAdvancement API not found - talent detection will not work")
    end

    if not inspectionFrame then
        inspectionFrame = CreateFrame("Frame")
        inspectionFrame:SetScript("OnEvent", function(self, event, ...)
            Inspection:OnInspectReady(...)
        end)
        inspectionFrame:RegisterEvent("INSPECT_READY")
    end

    RAT:DebugPrint("Inspection: Player self-inspection enabled, party members use addon comm")
end

--------------------------------------------------------------------------------
-- Player Self-Inspection
--------------------------------------------------------------------------------

--- Inspect the player (self-inspection)
-- Collects talents and trinkets and stores them in RAT.State, caller is still responsible for broadcasting via Comm
function Inspection:GetLastInspectTime()
    return lastInspectTime
end

function Inspection:InspectPlayer()
    if not UnitExists("player") then
        return
    end

    local now = GetTime()
    if (now - lastInspectTime) < 2 then
        RAT:DebugPrint(string.format("Player inspection throttled (last inspected %.1fs ago)", now - lastInspectTime))
        return
    end

    lastInspectTime = now

    RAT:DebugPrint("Inspecting player (self)")

    if hasAscensionAPI and C_CharacterAdvancement.InspectUnit then
        C_CharacterAdvancement.InspectUnit("player")
        local timerFrame = CreateFrame("Frame")
        local elapsed = 0
        timerFrame:SetScript("OnUpdate", function(self, delta)
            elapsed = elapsed + delta
            if elapsed >= 0.2 then
                self:SetScript("OnUpdate", nil)
                Inspection:ProcessAscensionInspection()
            end
        end)
    end

    self:InspectPlayerTrinkets()
end

function Inspection:ProcessAscensionInspection()
    local guid = UnitGUID("player")
    if not guid then
        RAT:DebugPrint("ProcessAscensionInspection: could not get player GUID")
        return
    end

    local activeSpec, unlockedSpecs = C_CharacterAdvancement.GetInspectInfo("player")

    if not unlockedSpecs then
        RAT:DebugPrint("ProcessAscensionInspection: no unlocked specs found")
        return
    end

    if not activeSpec or activeSpec < 1 or activeSpec > #unlockedSpecs then
        RAT:DebugPrint(string.format("ProcessAscensionInspection: invalid active spec %s", tostring(activeSpec)))
        return
    end

    RAT:DebugPrint(string.format("ProcessAscensionInspection: using spec %d of %d", activeSpec, #unlockedSpecs))

    local talentSpells = {}

    local build = C_CharacterAdvancement.GetInspectedBuild("player", activeSpec)

    if build and #build > 0 then
        RAT:DebugPrint(string.format("  Active spec %d: processing %d build entries...", activeSpec, #build))
        local processedCount = 0
        for _, entryInfo in ipairs(build) do
            if entryInfo and entryInfo.EntryId then
                local entry = C_CharacterAdvancement.GetEntryByInternalID(entryInfo.EntryId)
                if entry and entry.Spells and entryInfo.Rank and entry.Spells[entryInfo.Rank] then
                    local spellID = entry.Spells[entryInfo.Rank]
                    local spellName = GetSpellInfo(spellID)
                    if spellName then
                        talentSpells[spellName] = spellID
                        processedCount = processedCount + 1
                    end
                end
            end
        end
        RAT:DebugPrint(string.format("    -> Found %d spells in active spec", processedCount))
    else
        RAT:DebugPrint(string.format("  Active spec %d: no build data available", activeSpec))
    end

    local talentCount = 0
    for _ in pairs(talentSpells) do talentCount = talentCount + 1 end

    RAT:DebugPrint(string.format("ProcessAscensionInspection: found %d unique talent spells", talentCount))

    if not RAT.State.inspectedTalents then
        RAT.State.inspectedTalents = {}
    end
    RAT.State.inspectedTalents[guid] = talentSpells

    local playerGUID = UnitGUID("player")
    if guid == playerGUID then
        local mysticEnchants = self:GetMysticEnchants("player")
        if not RAT.State.inspectedMysticEnchants then
            RAT.State.inspectedMysticEnchants = {}
        end
        RAT.State.inspectedMysticEnchants[guid] = mysticEnchants
        RAT:DebugPrint(string.format("Stored %d mystic enchants for player", #mysticEnchants))
    end

    if RAT.Spells and RAT.Spells.UpdateAllUnitSpells then
        RAT.Spells:UpdateAllUnitSpells()
    end

    if RAT.Icons then
        RAT.Icons:RefreshAllDisplays()
    end

    self.lastInspectionComplete = GetTime()
end

function Inspection:InspectPlayerTrinkets()
    local guid = UnitGUID("player")
    if not guid then
        RAT:DebugPrint("InspectPlayerTrinkets: could not get player GUID")
        return
    end

    RAT:DebugPrint("Processing player trinket inspection directly")

    local trinkets = self:GetInspectedTrinkets("player")
    local trinketCount = #trinkets

    RAT:DebugPrint(string.format("Inspected player: trinkets=%d", trinketCount))

    if not RAT.State.inspectedTrinkets then
        RAT.State.inspectedTrinkets = {}
    end
    RAT.State.inspectedTrinkets[guid] = trinkets

    if RAT.Spells and RAT.Units then
        local unitData = RAT.Units:GetUnitByID("player")
        if unitData then
            RAT.Spells:UpdateUnitSpells(guid, unitData)
            if RAT.Icons then
                RAT.Icons:RefreshAllDisplays()
            end
        end
    end
end

--- Handle INSPECT_READY event
-- Note: This may fire for traditional NotifyInspect calls
-- @param guid string GUID of inspected unit
function Inspection:OnInspectReady(guid)
    if not guid then return end

    local playerGUID = UnitGUID("player")
    if guid ~= playerGUID then
        RAT:DebugPrint("INSPECT_READY for non-player GUID (ignored)")
        ClearInspectPlayer()
        return
    end

    RAT:DebugPrint("Processing INSPECT_READY for player (trinket update)")

    local trinkets = self:GetInspectedTrinkets("player")
    local trinketCount = #trinkets

    RAT:DebugPrint(string.format("Inspected player trinkets: %d found", trinketCount))

    if not RAT.State.inspectedTrinkets then
        RAT.State.inspectedTrinkets = {}
    end
    RAT.State.inspectedTrinkets[playerGUID] = trinkets

    if RAT.Spells and RAT.Units then
        local unitData = RAT.Units:GetUnitByID("player")
        if unitData then
            RAT.Spells:UpdateUnitSpells(playerGUID, unitData)
            if RAT.Icons then
                RAT.Icons:RefreshAllDisplays()
            end
        end
    end

    ClearInspectPlayer()
end

--- Get trinkets from inspected unit
-- @param unit string Unit ID
-- @return table Array of trinket spell data: {spellID, spellName, itemID, cooldown}
function Inspection:GetInspectedTrinkets(unit)
    local trinkets = {}
    for slot = 13, 14 do
        local itemLink = GetInventoryItemLink(unit, slot)
        if itemLink then
            local itemID = tonumber(itemLink:match("item:(%d+)"))
            if itemID then
                RAT:DebugPrint(string.format("  Checking trinket slot %d: itemID=%d", slot, itemID))
                local spellID, cooldown = RAT.Data:GetTrinketSpellID(itemID)
                if not spellID then
                    local itemSpellName, itemSpellID = GetItemSpell(itemID)

                    if itemSpellName and itemSpellID then
                        if type(itemSpellID) == "string" then
                            itemSpellID = tonumber(itemSpellID)
                        end

                        if itemSpellID and itemSpellID > 0 then
                            spellID = itemSpellID
                            cooldown = 120 -- Default cooldown for on-use trinkets
                            RAT:DebugPrint(string.format("    Auto-detected via GetItemSpell: spellID=%d (%s)", spellID, itemSpellName))
                        else
                            RAT:DebugPrint(string.format("    GetItemSpell returned invalid spellID for %s", itemSpellName))
                        end
                    else
                        RAT:DebugPrint(string.format("    GetItemSpell returned nil - passive trinket (no on-use effect)"))
                    end
                end

                if spellID then
                    local spellName = GetSpellInfo(spellID)
                    if spellName then
                        RAT:DebugPrint(string.format("  Found trinket: %s (itemID=%d, spellID=%d, cd=%ds)",
                            spellName, itemID, spellID, cooldown))
                        table.insert(trinkets, {
                            spellID = spellID,
                            spellName = spellName,
                            itemID = itemID,
                            cooldown = cooldown,
                        })
                    else
                        RAT:DebugPrint(string.format("    Warning: spellID=%d has no spell info", spellID))
                    end
                end
            end
        end
    end

    return trinkets
end

--------------------------------------------------------------------------------
-- Talent Checking Functions
--------------------------------------------------------------------------------

--- Check if a unit has a specific talent
-- @param unit string Unit ID (party1-party4 or player)
-- @param spellName string Spell name to check
-- @return boolean True if unit has the talent
function Inspection:UnitHasTalent(unit, spellName)
    local guid = UnitGUID(unit)
    if not guid then return false end

    return self:GUIDHasTalent(guid, spellName)
end

--- Check if a GUID has a specific talent
-- @param guid string Unit GUID
-- @param spellName string Spell name to check
-- @return boolean True if unit has the talent
function Inspection:GUIDHasTalent(guid, spellName)
    if not guid or not spellName then return false end

    if RAT.State.inspectedTalents and RAT.State.inspectedTalents[guid] then
        local hasTalent = RAT.State.inspectedTalents[guid][spellName] ~= nil
        return hasTalent
    end

    return false
end

-- @param unit string Unit token
--- Get mystic enchants currently applied to the given unit
-- @return table Array of mystic enchant data: {{spellID, spellName, cooldown, type, enchantID}, ...}
function Inspection:GetMysticEnchants(unit)
    local mysticEnchants = {}

    if not UnitIsUnit(unit, "player") then
        return mysticEnchants
    end

    local _, playerClass = UnitClass("player")
    if not playerClass then
        RAT:DebugPrint("GetMysticEnchants: Could not determine player class")
        return mysticEnchants
    end

    if not MysticEnchantUtil or not MysticEnchantUtil.GetAppliedEnchants then
        RAT:DebugPrint("GetMysticEnchants: MysticEnchantUtil not available")
        return mysticEnchants
    end

    local appliedEnchants = MysticEnchantUtil.GetAppliedEnchants("player")
    if not appliedEnchants or type(appliedEnchants) ~= "table" then
        RAT:DebugPrint("GetMysticEnchants: No applied enchants found")
        return mysticEnchants
    end

    local allMappings = RAT.Data.MysticEnchantMapping or {}
    local classMappings = allMappings[playerClass] or {}

    local foundCount = 0
    local totalCount = 0

    for enchantID, _ in pairs(appliedEnchants) do
        totalCount = totalCount + 1
        local mappingData = classMappings[enchantID]

        if mappingData then
            local spellID, cooldown, spellType = unpack(mappingData)

            local spellName = GetSpellInfo(spellID)
            if spellName then
                table.insert(mysticEnchants, {spellID, spellName, cooldown, spellType, enchantID})
                foundCount = foundCount + 1
                RAT:DebugPrint(string.format("  Found enchant: %s (enchantID=%d, spellID=%d, cd=%ds, type=%s)",
                    spellName, enchantID, spellID, cooldown, spellType))
            else
                RAT:DebugPrint(string.format("  Warning: Spell ID %d not found for enchant ID %d",
                    spellID, enchantID))
            end
        else
            RAT:DebugPrint(string.format("  Unknown %s enchant ID %d (add to MysticEnchantMapping[\"%s\"])",
                playerClass, enchantID, playerClass))
        end
    end

    RAT:DebugPrint(string.format("GetMysticEnchants: Found %d/%d %s enchants with cooldowns",
        foundCount, totalCount, playerClass))

    return mysticEnchants
end
