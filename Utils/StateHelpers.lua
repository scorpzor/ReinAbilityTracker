-- Utils/StateHelpers.lua
-- Null-safe accessors for RAT.State with fallbacks

local RAT = _G.RAT
RAT.StateHelpers = {}

local StateHelpers = RAT.StateHelpers

--------------------------------------------------------------------------------
-- Inspection Data Access
--------------------------------------------------------------------------------

--- Get inspected talents for a GUID
-- @param guid string Unit GUID
-- @return table Talents table (empty table if not found)
function StateHelpers:GetInspectedTalents(guid)
    if not RAT.State.inspectedTalents then
        RAT.State.inspectedTalents = {}
    end
    return RAT.State.inspectedTalents[guid] or {}
end

--- Get inspected trinkets for a GUID
-- @param guid string Unit GUID
-- @return table|nil Trinkets table or nil if not found
function StateHelpers:GetInspectedTrinkets(guid)
    if not RAT.State.inspectedTrinkets then
        RAT.State.inspectedTrinkets = {}
    end
    return RAT.State.inspectedTrinkets[guid]
end

--- Get inspected mystic enchants for a GUID
-- @param guid string Unit GUID
-- @return table|nil Mystic enchants table or nil if not found
function StateHelpers:GetInspectedMysticEnchants(guid)
    if not RAT.State.inspectedMysticEnchants then
        RAT.State.inspectedMysticEnchants = {}
    end
    return RAT.State.inspectedMysticEnchants[guid]
end

--- Set inspected talents for a GUID
-- @param guid string Unit GUID
-- @param talents table Talents table
function StateHelpers:SetInspectedTalents(guid, talents)
    if not RAT.State.inspectedTalents then
        RAT.State.inspectedTalents = {}
    end
    RAT.State.inspectedTalents[guid] = talents
end

--- Set inspected trinkets for a GUID
-- @param guid string Unit GUID
-- @param trinkets table Trinkets table
function StateHelpers:SetInspectedTrinkets(guid, trinkets)
    if not RAT.State.inspectedTrinkets then
        RAT.State.inspectedTrinkets = {}
    end
    RAT.State.inspectedTrinkets[guid] = trinkets
end

--- Set inspected mystic enchants for a GUID
-- @param guid string Unit GUID
-- @param enchants table Mystic enchants table
function StateHelpers:SetInspectedMysticEnchants(guid, enchants)
    if not RAT.State.inspectedMysticEnchants then
        RAT.State.inspectedMysticEnchants = {}
    end
    RAT.State.inspectedMysticEnchants[guid] = enchants
end

--------------------------------------------------------------------------------
-- Cooldown Data Access
--------------------------------------------------------------------------------

--- Get active cooldowns for a GUID
-- @param guid string Unit GUID
-- @return table Cooldowns table (empty table if not found)
function StateHelpers:GetActiveCooldowns(guid)
    if not RAT.State.activeGUIDs then
        RAT.State.activeGUIDs = {}
    end
    if not RAT.State.activeGUIDs[guid] then
        RAT.State.activeGUIDs[guid] = {}
    end
    return RAT.State.activeGUIDs[guid]
end

--- Set active cooldown for a GUID and spell
-- @param guid string Unit GUID
-- @param spellName string Spell name
-- @param startTime number Cooldown start time
-- @param cooldown number Cooldown duration
function StateHelpers:SetActiveCooldown(guid, spellName, startTime, cooldown)
    if not RAT.State.activeGUIDs then
        RAT.State.activeGUIDs = {}
    end
    if not RAT.State.activeGUIDs[guid] then
        RAT.State.activeGUIDs[guid] = {}
    end
    RAT.State.activeGUIDs[guid][spellName] = {
        startTime = startTime,
        cooldown = cooldown
    }
end

--- Clear active cooldown for a GUID and spell
-- @param guid string Unit GUID
-- @param spellName string Spell name
function StateHelpers:ClearActiveCooldown(guid, spellName)
    if not RAT.State.activeGUIDs then
        return
    end
    if not RAT.State.activeGUIDs[guid] then
        return
    end
    RAT.State.activeGUIDs[guid][spellName] = nil
end

--- Check if a GUID has any active cooldowns
-- @param guid string Unit GUID
-- @return boolean True if GUID has active cooldowns
function StateHelpers:HasActiveCooldowns(guid)
    if not RAT.State.activeGUIDs then
        return false
    end
    if not RAT.State.activeGUIDs[guid] then
        return false
    end
    for _ in pairs(RAT.State.activeGUIDs[guid]) do
        return true
    end
    return false
end

--------------------------------------------------------------------------------
-- Search Helpers
--------------------------------------------------------------------------------

--- Find trinket by spell name in inspected trinkets
-- @param guid string Unit GUID
-- @param spellName string Spell name to find
-- @return table|nil Trinket data or nil if not found
function StateHelpers:FindTrinketBySpellName(guid, spellName)
    local trinkets = self:GetInspectedTrinkets(guid)
    if not trinkets then
        return nil
    end

    for _, trinket in ipairs(trinkets) do
        if trinket.name == spellName then
            return trinket
        end
    end
    return nil
end

--- Find mystic enchant by spell name in inspected enchants
-- @param guid string Unit GUID
-- @param spellName string Spell name to find
-- @return table|nil Enchant data or nil if not found
function StateHelpers:FindMysticEnchantBySpellName(guid, spellName)
    local enchants = self:GetInspectedMysticEnchants(guid)
    if not enchants then
        return nil
    end

    for _, enchant in ipairs(enchants) do
        if enchant.name == spellName then
            return enchant
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Party Data Access
--------------------------------------------------------------------------------

--- Get party anchor for an index
-- @param index number Anchor index (1-5)
-- @return table|nil Anchor data or nil if not found
function StateHelpers:GetPartyAnchor(index)
    if not RAT.State.partyAnchors then
        RAT.State.partyAnchors = {}
    end
    return RAT.State.partyAnchors[index]
end

--- Set party anchor for an index
-- @param index number Anchor index (1-5)
-- @param data table Anchor data {guid, unitID, name}
function StateHelpers:SetPartyAnchor(index, data)
    if not RAT.State.partyAnchors then
        RAT.State.partyAnchors = {}
    end
    RAT.State.partyAnchors[index] = data
end

--- Clear party anchor for an index
-- @param index number Anchor index (1-5)
function StateHelpers:ClearPartyAnchor(index)
    if not RAT.State.partyAnchors then
        return
    end
    RAT.State.partyAnchors[index] = nil
end
