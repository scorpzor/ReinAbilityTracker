-- Modules/Manager/UnitsManager.lua
-- Centralized unit tracking module
-- Tracks player, party members, and raid members independent of UI frames

local RAT = _G.RAT
local Units = {}
RAT.UnitsManager = Units

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

-- Tracked units table: [guid] = {guid, unit, name, class, type}
-- type can be: "player", "party", "raid"
local trackedUnits = {}

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function Units:Initialize()
end

--------------------------------------------------------------------------------
-- Unit Tracking
--------------------------------------------------------------------------------

--- Get all tracked units
-- @return table Table of units indexed by GUID: [guid] = {guid, unit, name, class, type}
function Units:GetAllUnits()
    return trackedUnits
end

--- Get a specific unit by GUID
-- @param guid string Unit GUID
-- @return table|nil Unit data or nil if not found
function Units:GetUnit(guid)
    return trackedUnits[guid]
end

--- Get unit by unit ID (e.g., "player", "party1", "raid5")
-- @param unitID string Unit ID
-- @return table|nil Unit data or nil if not found
function Units:GetUnitByID(unitID)
    if not unitID or not UnitExists(unitID) then
        return nil
    end

    local guid = UnitGUID(unitID)
    return trackedUnits[guid]
end

--- Update unit tracking based on current group composition
-- This should be called whenever party/raid composition changes
function Units:Update()
    RAT:DebugPrint("Units:Update() - Refreshing unit tracking")
    wipe(trackedUnits)

    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        RAT:DebugPrint("In raid group - tracking raid members")
        self:TrackRaidMembers()
        return
    end

    local numParty = GetNumPartyMembers()
    if numParty > 0 then
        RAT:DebugPrint(string.format("In party group - tracking %d party members + player", numParty))
        self:TrackPartyMembers()
        return
    end

    RAT:DebugPrint("Solo - tracking player only")
    self:TrackPlayer()
end

function Units:TrackPlayer()
    local guid = UnitGUID("player")
    if not guid then return end

    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    local name = UnitName("player")

    trackedUnits[guid] = {
        guid = guid,
        unit = "player",
        name = name,
        class = class,
        race = race,
        type = "player",
    }

    RAT:DebugPrint(string.format("Tracked player: %s (%s/%s) - GUID: %s", name, class, race or "?", guid))
end

--- Track party members (including player)
function Units:TrackPartyMembers()
    self:TrackPlayer()

    local numParty = GetNumPartyMembers()
    for i = 1, numParty do
        local unit = "party" .. i
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            local _, class = UnitClass(unit)
            local _, race = UnitRace(unit)
            local name = UnitName(unit)

            if guid and class and name then
                trackedUnits[guid] = {
                    guid = guid,
                    unit = unit,
                    name = name,
                    class = class,
                    race = race,
                    type = "party",
                }

                RAT:DebugPrint(string.format("Tracked party%d: %s (%s/%s) - GUID: %s", i, name, class, race or "?", guid))
            end
        end
    end
end

--- Track raid members
function Units:TrackRaidMembers()
    local numRaid = GetNumRaidMembers()
    for i = 1, numRaid do
        local unit = "raid" .. i
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            local _, class = UnitClass(unit)
            local _, race = UnitRace(unit)
            local name = UnitName(unit)

            if guid and class and name then
                local unitType = "raid"
                if UnitIsUnit(unit, "player") then
                    unitType = "player"
                end

                trackedUnits[guid] = {
                    guid = guid,
                    unit = unit,
                    name = name,
                    class = class,
                    race = race,
                    type = unitType,
                }

                RAT:DebugPrint(string.format("Tracked raid%d: %s (%s/%s) - GUID: %s", i, name, class, race or "?", guid))
            end
        end
    end
end

--- Get units by type
-- @param unitType string Type of units to get: "player", "party", "raid", or nil for all
-- @return table Array of unit data
function Units:GetUnitsByType(unitType)
    local units = {}

    if not unitType then
        for guid, unitData in pairs(trackedUnits) do
            table.insert(units, unitData)
        end
    else
        for guid, unitData in pairs(trackedUnits) do
            if unitData.type == unitType then
                table.insert(units, unitData)
            end
        end
    end

    return units
end

--- Get count of tracked units
-- @return number Total number of tracked units
function Units:GetUnitCount()
    local count = 0
    for _ in pairs(trackedUnits) do
        count = count + 1
    end
    return count
end

--- Check if a unit is tracked
-- @param guid string Unit GUID
-- @return boolean True if unit is tracked
function Units:IsTracked(guid)
    return trackedUnits[guid] ~= nil
end

--- Get player unit data
-- @return table|nil Player unit data or nil
function Units:GetPlayer()
    local playerGUID = UnitGUID("player")
    return trackedUnits[playerGUID]
end

--- Check if currently in a raid group
-- @return boolean True if in raid
function Units:IsInRaid()
    return GetNumRaidMembers() > 0
end

--- Check if currently in a party group
-- @return boolean True if in party
function Units:IsInParty()
    return GetNumPartyMembers() > 0
end

--- Get current group state
-- @return string "solo", "party", or "raid"
function Units:GetGroupState()
    if self:IsInRaid() then
        return "raid"
    elseif self:IsInParty() then
        return "party"
    else
        return "solo"
    end
end

