-- Modules/Manager/TrackerManager.lua
-- Handles cooldown tracking logic

local RAT = _G.RAT
RAT.TrackerManager = {}

local TrackerManager = RAT.TrackerManager

function TrackerManager:Initialize()
end

--------------------------------------------------------------------------------
-- Ability Usage Handler
--------------------------------------------------------------------------------

--- Called when a party member or player uses an ability
-- @param unit string Unit ID (e.g., "party1", "party2", "player")
-- @param spellName string Name of the spell cast
function TrackerManager:OnAbilityUsed(unit, spellName)
    if not spellName or spellName == "" then return end

    local unitData = RAT.UnitsManager and RAT.UnitsManager:GetUnitByID(unit)
    if not unitData then
        RAT:DebugPrint("Unit not tracked: " .. tostring(unit))
        return
    end

    local guid = unitData.guid
    local class = unitData.class
    local race = unitData.race

    if not class then
        RAT:DebugPrint("No class info for " .. unit)
        return
    end

    local anchorIndex = RAT:GetIndexFromUnit(unit)
    local spellData = RAT.Data:GetSpellData(spellName)

    local trinketData = nil
    if not spellData and RAT.State.inspectedTrinkets and RAT.State.inspectedTrinkets[guid] then
        for _, trinket in ipairs(RAT.State.inspectedTrinkets[guid]) do
            if trinket.spellName == spellName then
                trinketData = trinket
                spellData = {
                    cd = trinket.cooldown,
                    type = "trinket",
                }
                RAT:DebugPrint(string.format("Matched trinket: %s (cd=%ds)", spellName, trinket.cooldown))
                break
            end
        end
    end

    if not spellData and RAT.State.inspectedMysticEnchants and RAT.State.inspectedMysticEnchants[guid] then
        local mysticEnchants = RAT.State.inspectedMysticEnchants[guid]
        for _, enchantData in ipairs(mysticEnchants) do
            local enchantSpellID, enchantName, enchantCooldown, enchantType, enchantID = unpack(enchantData)

            if spellName == enchantName then
                spellData = {
                    cd = enchantCooldown,
                    type = enchantType or "external",
                }
                RAT:DebugPrint(string.format("Detected mystic enchant cast: %s (cd=%ds, type=%s)",
                    enchantName, enchantCooldown, enchantType or "external"))
                break
            end
        end
    end

    if not spellData then
        return
    end

    RAT:DebugPrint(string.format("%s used %s (CD: %ds, Type: %s)", unit, spellName, spellData.cd, spellData.type))

    if spellData.spec == true then
        if RAT.InspectionManager and not RAT.InspectionManager:GUIDHasTalent(guid, spellName) then
            RAT:DebugPrint(spellName .. " is a talent but player doesn't have it")
            return
        end
    end

    local cooldown = spellData.cd

    self:StartCooldown(guid, spellName, cooldown)
    self:HandleGroupedCooldowns(guid, class, spellName, cooldown)
    self:HandleCooldownResetters(guid, spellName)

    if anchorIndex and RAT.IconManager then
        RAT.IconManager:UpdateAnchorIcons(anchorIndex)
    end

    if RAT.ExtraSpellsDisplay then
        RAT.ExtraSpellsDisplay:RefreshCooldownForSpell(guid, spellName)

        -- Use the spellData we already have (includes mystic enchants, trinkets, etc.)
        if spellData and spellData.type == "interrupt" and RAT.InterruptBarDisplay then
            RAT.InterruptBarDisplay:UpdateBarCooldownState(guid, spellName)
        end
    end
end

--------------------------------------------------------------------------------
-- Cooldown Management
--------------------------------------------------------------------------------

--- Start a cooldown for a specific ability
-- @param anchor table Party anchor data
-- @param spellName string Name of the spell
-- @param cooldown number Cooldown duration in seconds
function TrackerManager:StartCooldown(guid, spellName, cooldown)
    if not guid then return end

    RAT.StateHelpers:SetActiveCooldown(guid, spellName, GetTime(), cooldown)

    RAT:DebugPrint(string.format("Started CD: %s (%.1fs)", spellName, cooldown))
end

--- Stop a cooldown for a specific ability
-- @param guid string Player GUID
-- @param spellName string Name of the spell
-- @param reason string Optional reason for stopping (e.g., "expired", "reset")
function TrackerManager:StopCooldown(guid, spellName, reason)
    RAT.StateHelpers:ClearActiveCooldown(guid, spellName)
    if reason then
        RAT:DebugPrint(string.format("Stopped CD: %s (%s)", spellName, reason))
    else
        RAT:DebugPrint(string.format("Stopped CD: %s", spellName))
    end
end

--- Check if an ability is on cooldown
-- @param guid string Player GUID
-- @param spellName string Name of the spell
-- @return boolean True if on cooldown
-- @return number|nil Time remaining (if on cooldown)
function TrackerManager:IsOnCooldown(guid, spellName)
    local activeCDs = RAT.StateHelpers:GetActiveCooldowns(guid)
    local cdInfo = activeCDs[spellName]
    if not cdInfo then
        return false, nil
    end

    local timeRemaining = (cdInfo.startTime + cdInfo.cooldown) - GetTime()

    if timeRemaining <= 0 then
        self:StopCooldown(guid, spellName, "expired")
        return false, nil
    end

    return true, timeRemaining
end

--- Get cooldown info for a spell
-- @param guid string Player GUID
-- @param spellName string Name of the spell
-- @return table|nil Cooldown info {startTime, duration} or nil
function TrackerManager:GetCooldownInfo(guid, spellName)
    local activeCDs = RAT.StateHelpers:GetActiveCooldowns(guid)
    local cdInfo = activeCDs[spellName]
    if not cdInfo then
        return nil
    end

    local timeRemaining = (cdInfo.startTime + cdInfo.cooldown) - GetTime()
    if timeRemaining <= 0 then
        self:StopCooldown(guid, spellName, "expired")
        return nil
    end

    return {
        startTime = cdInfo.startTime,
        duration = cdInfo.cooldown,
    }
end

--------------------------------------------------------------------------------
-- Grouped Cooldowns
--------------------------------------------------------------------------------

--- Handle abilities that share cooldowns
-- @param guid string Player GUID
-- @param class string Player class
-- @param spellName string Name of the spell cast
-- @param cooldown number Cooldown duration
function TrackerManager:HandleGroupedCooldowns(guid, class, spellName, cooldown)
    local group = RAT.Data:GetSharedGroup(class, spellName)
    if not group then
        return
    end

    if RAT.Data.sharedGroups and RAT.Data.sharedGroups[class] then
        for otherSpell, otherGroup in pairs(RAT.Data.sharedGroups[class]) do
            if otherGroup == group and otherSpell ~= spellName then
                RAT:DebugPrint(string.format("Starting grouped CD: %s", otherSpell))
                self:StartCooldown(guid, otherSpell, cooldown)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Cooldown Resetters
--------------------------------------------------------------------------------

--- Handle abilities that reset other cooldowns
-- @param guid string Player GUID
-- @param spellName string Name of the spell cast
function TrackerManager:HandleCooldownResetters(guid, spellName)
    local resetsTable = RAT.Data:GetResetTargets(spellName)
    if not resetsTable then
        return
    end

    if not guid then return end

    RAT:DebugPrint(string.format("%s resets cooldowns", spellName))

    for targetSpell, _ in pairs(resetsTable) do
        if RAT.State.activeGUIDs[guid] and RAT.State.activeGUIDs[guid][targetSpell] then
            RAT:DebugPrint(string.format("  Resetting: %s", targetSpell))
            self:StopCooldown(guid, targetSpell, "reset by " .. spellName)
        end
    end
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

--- Stop all cooldowns
function TrackerManager:StopAllCooldowns()
    RAT:DebugPrint("Stopping all cooldowns")
    wipe(RAT.State.activeGUIDs)
end

--- Stop cooldowns for a specific GUID
-- @param guid string Player GUID
function TrackerManager:StopCooldownsForGUID(guid)
    if RAT.State.activeGUIDs[guid] then
        RAT:DebugPrint("Stopping cooldowns for GUID: " .. guid)
        RAT.State.activeGUIDs[guid] = nil
    end
end

