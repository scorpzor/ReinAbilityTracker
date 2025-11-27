-- Modules/Spells.lua
-- Collects and manages spell data for all tracked units

local RAT = _G.RAT
RAT.Spells = {}

local Spells = RAT.Spells

-- Cached spell lists per GUID
-- Structure: { [guid] = { all = {...}, cc = {...}, interrupt = {...}, external = {...} } }
local unitSpells = {}

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function Spells:Initialize()
    -- Spell cache is updated by:
    -- 1. Comm module when receiving build data from party members
    -- 2. Inspection module after inspecting player
    -- 3. OnPartyChanged via UpdateAllUnitSpells()
    RAT:DebugPrint("Spells: Initialized spell cache system")
end

--------------------------------------------------------------------------------
-- Spell Collection
--------------------------------------------------------------------------------

--- Update spell cache for all tracked units
-- Called when party composition changes or talents update
function Spells:UpdateAllUnitSpells()
    RAT:DebugPrint("Spells:UpdateAllUnitSpells() - Rebuilding spell cache")
    wipe(unitSpells)

    if not RAT.Units then return end
    local allUnits = RAT.Units:GetAllUnits()

    for guid, unitData in pairs(allUnits) do
        self:UpdateUnitSpells(guid, unitData)
    end

    RAT:DebugPrint(string.format("Spell cache updated for %d units", self:GetUnitCount()))
end

--- Update spell cache for a specific unit (incremental update)
-- @param guid string Unit GUID
-- @param unitData table Unit data from Units module {guid, unit, name, class, race, type}
function Spells:UpdateUnitSpells(guid, unitData)
    if not guid or not unitData then return end

    unitSpells[guid] = self:CollectSpellsForGUID(guid, unitData)
end

--- Collect all spells for a specific GUID
-- @param guid string Unit GUID
-- @param unitData table Unit data from Units module {guid, unit, name, class, race, type}
-- @return table Spell data organized by type {all, cc, interrupt, external}
function Spells:CollectSpellsForGUID(guid, unitData)
    local class = unitData.class
    local race = unitData.race

    local allSpells = {}
    local spellsByType = {
        cc = {},
        interrupt = {},
        external = {},
        defensive = {},
        offensive = {},
        trinket = {},
    }

    if class then
        local classSpells = RAT.Data:GetSpellsByClass(class)
        if classSpells then
            for _, spellName in ipairs(classSpells) do
                local spellData = RAT.Data:GetSpellData(spellName)
                if spellData then
                    if RAT.IconHelpers and RAT.IconHelpers:IsSpellEnabled(class, spellName) then
                        local hasSpell = true
                        if spellData.spec and RAT.Inspection then
                            hasSpell = RAT.Inspection:GUIDHasTalent(guid, spellName)
                        end

                        if hasSpell then
                            local spellInfo = {
                                name = spellName,
                                cd = spellData.cd,
                                spellData = spellData,
                                guid = guid,
                                unit = unitData.unit,
                                class = class,
                            }

                            table.insert(allSpells, spellInfo)

                            if spellData.type and spellsByType[spellData.type] then
                                table.insert(spellsByType[spellData.type], spellInfo)
                            end
                        end
                    end
                end
            end
        end
    end

    if race then
        local raceSpells = RAT.Data:GetSpellsByRace(race)
        if raceSpells then
            for _, spellName in ipairs(raceSpells) do
                local spellData = RAT.Data:GetSpellData(spellName)
                if spellData then
                    if RAT.IconHelpers and RAT.IconHelpers:IsSpellEnabled(race, spellName) then
                        local spellInfo = {
                            name = spellName,
                            cd = spellData.cd,
                            spellData = spellData,
                            guid = guid,
                            unit = unitData.unit,
                            class = class,
                        }

                        table.insert(allSpells, spellInfo)

                        -- Add to type-specific lists
                        if spellData.type and spellsByType[spellData.type] then
                            table.insert(spellsByType[spellData.type], spellInfo)
                        end
                    end
                end
            end
        end
    end

    if RAT.State.inspectedTrinkets and RAT.State.inspectedTrinkets[guid] then
        local trinkets = RAT.State.inspectedTrinkets[guid]
        for _, trinketData in ipairs(trinkets) do
            local trinketCD = trinketData.cooldown or 120

            local spellInfo = {
                name = trinketData.spellName,
                cd = trinketCD,
                spellData = {
                    id = trinketData.spellID,
                    cd = trinketCD,
                    type = "trinket",
                    category = "trinket",
                    itemID = trinketData.itemID,
                },
                guid = guid,
                unit = unitData.unit,
                class = class,
            }

            table.insert(allSpells, spellInfo)

            table.insert(spellsByType.trinket, spellInfo)
        end
    end

    if RAT.State.inspectedMysticEnchants and RAT.State.inspectedMysticEnchants[guid] then
        local mysticEnchants = RAT.State.inspectedMysticEnchants[guid]
        for _, enchantData in ipairs(mysticEnchants) do
            local spellID, spellName, cooldown, spellType, enchantID = unpack(enchantData)

            if spellName and cooldown and cooldown > 0 and spellType then
                local spellInfo = {
                    name = spellName,
                    cd = cooldown,
                    spellData = {
                        id = spellID,
                        cd = cooldown,
                        type = spellType,
                        category = "mystic_enchant",
                        enchantID = enchantID,
                    },
                    guid = guid,
                    unit = unitData.unit,
                    class = class,
                }

                table.insert(allSpells, spellInfo)

                if spellsByType[spellType] then
                    table.insert(spellsByType[spellType], spellInfo)
                end
            end
        end
    end

    return {
        all = allSpells,
        cc = spellsByType.cc,
        interrupt = spellsByType.interrupt,
        external = spellsByType.external,
        defensive = spellsByType.defensive,
        offensive = spellsByType.offensive,
        trinket = spellsByType.trinket,
    }
end

--------------------------------------------------------------------------------
-- Query Functions
--------------------------------------------------------------------------------

--- Get all spells for a specific GUID
-- @param guid string Unit GUID
-- @param filterType string|nil Optional type filter ("cc", "interrupt", "external")
-- @return table Array of spell info tables
function Spells:GetSpellsForGUID(guid, filterType)
    local cached = unitSpells[guid]
    if not cached then
        return {}
    end

    if filterType then
        return cached[filterType] or {}
    else
        return cached.all or {}
    end
end

--- Get spells for all units, optionally filtered by type
-- @param filterType string|nil Optional type filter ("cc", "interrupt", "external")
-- @return table Array of spell info tables from all units
function Spells:GetAllSpells(filterType)
    local allSpells = {}

    for guid, spellData in pairs(unitSpells) do
        local spells = filterType and spellData[filterType] or spellData.all
        if spells then
            for _, spellInfo in ipairs(spells) do
                table.insert(allSpells, spellInfo)
            end
        end
    end

    return allSpells
end

--- Get grouped spells (all types)
-- @return table {cc = {...}, interrupt = {...}, external = {...}}
function Spells:GetGroupedSpells()
    return {
        cc = self:GetAllSpells("cc"),
        interrupt = self:GetAllSpells("interrupt"),
        external = self:GetAllSpells("external"),
    }
end

--- Check if a GUID has a specific spell
-- @param guid string Unit GUID
-- @param spellName string Spell name
-- @return boolean True if unit has the spell
function Spells:GUIDHasSpell(guid, spellName)
    local cached = unitSpells[guid]
    if not cached or not cached.all then
        return false
    end

    for _, spellInfo in ipairs(cached.all) do
        if spellInfo.name == spellName then
            return true
        end
    end

    return false
end

--- Get count of tracked units
-- @return number Number of units with spell data
function Spells:GetUnitCount()
    local count = 0
    for _ in pairs(unitSpells) do
        count = count + 1
    end
    return count
end

--- Invalidate spell cache (forces rebuild on next access)
function Spells:InvalidateCache()
    RAT:DebugPrint("Spells cache invalidated")
    wipe(unitSpells)
end

--- Get all spells that can appear in a specific group, organized by source (for filter UI)
-- @param groupType string Group type ("party", "cc", "interrupt", "external", "trinket")
-- @return table Organized spell data {classes = {WARRIOR = {spells}, ...}, races = {Human = {spells}, ...}, trinkets = {spells}}
function Spells:GetAllSpellsForGroup(groupType)
    local result = {
        classes = {},
        races = {},
        trinkets = {},
        mysticEnchants = {}
    }

    if not RAT.Data then
        return result
    end

    if groupType == "party" then
        for _, class in ipairs({"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}) do
            local classSpells = RAT.Data:GetSpellsByClass(class)
            if classSpells and #classSpells > 0 then
                result.classes[class] = {}
                for _, spellName in ipairs(classSpells) do
                    table.insert(result.classes[class], spellName)
                end
                table.sort(result.classes[class])
            end
        end

        for _, race in ipairs({"Human", "Dwarf", "NightElf", "Gnome", "Draenei", "Orc", "Undead", "Tauren", "Troll", "BloodElf"}) do
            local raceSpells = RAT.Data:GetSpellsByRace(race)
            if raceSpells and #raceSpells > 0 then
                result.races[race] = {}
                for _, spellName in ipairs(raceSpells) do
                    table.insert(result.races[race], spellName)
                end
                table.sort(result.races[race])
            end
        end

        if RAT.Data.TrinketSpells then
            for itemID, trinketData in pairs(RAT.Data.TrinketSpells) do
                if trinketData.spellID then
                    local spellName = GetSpellInfo(trinketData.spellID)
                    if spellName then
                        table.insert(result.trinkets, spellName)
                    end
                end
            end
            if #result.trinkets > 0 then
                table.sort(result.trinkets)
            end
        end

        if RAT.Data.MysticEnchantMapping then
            for className, enchants in pairs(RAT.Data.MysticEnchantMapping) do
                for enchantID, enchantData in pairs(enchants) do
                    local spellID, cooldown, spellType = unpack(enchantData)
                    local spellName = GetSpellInfo(spellID)
                    if spellName then
                        if not result.mysticEnchants[className] then
                            result.mysticEnchants[className] = {}
                        end
                        table.insert(result.mysticEnchants[className], spellName)
                    end
                end
                if result.mysticEnchants[className] and #result.mysticEnchants[className] > 0 then
                    table.sort(result.mysticEnchants[className])
                end
            end
        end
    else
        for _, class in ipairs({"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}) do
            local classSpells = RAT.Data:GetSpellsByClass(class)
            if classSpells then
                for _, spellName in ipairs(classSpells) do
                    local spellData = RAT.Data:GetSpellData(spellName)
                    if spellData and spellData.type == groupType then
                        if not result.classes[class] then
                            result.classes[class] = {}
                        end
                        table.insert(result.classes[class], spellName)
                    end
                end
                if result.classes[class] and #result.classes[class] > 0 then
                    table.sort(result.classes[class])
                end
            end
        end

        for _, race in ipairs({"Human", "Dwarf", "NightElf", "Gnome", "Draenei", "Orc", "Undead", "Tauren", "Troll", "BloodElf"}) do
            local raceSpells = RAT.Data:GetSpellsByRace(race)
            if raceSpells then
                for _, spellName in ipairs(raceSpells) do
                    local spellData = RAT.Data:GetSpellData(spellName)
                    if spellData and spellData.type == groupType then
                        if not result.races[race] then
                            result.races[race] = {}
                        end
                        table.insert(result.races[race], spellName)
                    end
                end
                if result.races[race] and #result.races[race] > 0 then
                    table.sort(result.races[race])
                end
            end
        end

        if groupType == "trinket" and RAT.Data.TrinketSpells then
            for itemID, trinketData in pairs(RAT.Data.TrinketSpells) do
                if trinketData.spellID then
                    local spellName = GetSpellInfo(trinketData.spellID)
                    if spellName then
                        table.insert(result.trinkets, spellName)
                    end
                end
            end
            if #result.trinkets > 0 then
                table.sort(result.trinkets)
            end
        end

        if RAT.Data.MysticEnchantMapping then
            for className, enchants in pairs(RAT.Data.MysticEnchantMapping) do
                for enchantID, enchantData in pairs(enchants) do
                    local spellID, cooldown, spellType = unpack(enchantData)
                    if spellType == groupType then
                        local spellName = GetSpellInfo(spellID)
                        if spellName then
                            if not result.mysticEnchants[className] then
                                result.mysticEnchants[className] = {}
                            end
                            table.insert(result.mysticEnchants[className], spellName)
                        end
                    end
                end
                if result.mysticEnchants[className] and #result.mysticEnchants[className] > 0 then
                    table.sort(result.mysticEnchants[className])
                end
            end
        end
    end

    return result
end

