-- Data/Queries/SpellQueries.lua
-- Query functions for spell data (extracted from Data/Spells.lua)

local RAT = _G.RAT or {}
RAT.Data = RAT.Data or {}

--------------------------------------------------------------------------------
-- Data Initialization
--------------------------------------------------------------------------------

function RAT.Data:Initialize()
    self.spellCache = {}
    self.iconCache = {}
    self.idToName = {}
    self.invalidSpells = {}

    self:ProcessSpellCategory(self.Spells, "class")
    self:ProcessSpellCategory(self.Racials, "racial")

    self:ProcessSharedCooldowns()

    self:ProcessResetters()

    if #self.invalidSpells > 0 then
        RAT:Print(string.format("|cFFFFAA00Warning:|r Found %d invalid spell ID(s) in database. These spells will be skipped.", #self.invalidSpells))
        for _, entry in ipairs(self.invalidSpells) do
            RAT:DebugPrint(string.format("Invalid spell: [%s] ID=%d", entry.class, entry.id))
        end
        RAT:Print("Enable debug mode with /rat debug to see details")
    end

    RAT:DebugPrint("Spell database initialized: " .. self:GetTotalSpellCount() .. " spells")
end

function RAT.Data:ProcessSpellCategory(category, categoryType)
    for className, spells in pairs(category) do
        for _, spellData in ipairs(spells) do
            local spellName, _, icon = GetSpellInfo(spellData.id)
            if spellName then
                self.idToName[spellData.id] = spellName

                if icon then
                    self.iconCache[spellName] = icon
                end

                if not self.spellCache[spellName] then
                    self.spellCache[spellName] = {
                        id = spellData.id,
                        cd = spellData.cd,
                        type = spellData.type,
                        spec = spellData.spec,
                        duration = spellData.duration,
                        class = className,
                        category = categoryType,
                    }
                end
            else
                table.insert(self.invalidSpells, {
                    class = className,
                    id = spellData.id,
                    category = categoryType
                })
            end
        end
    end
end

function RAT.Data:ProcessSharedCooldowns()
    self.sharedGroups = {}
    if not self.SharedCooldowns then return end

    for className, groups in pairs(self.SharedCooldowns) do
        self.sharedGroups[className] = {}
        for groupIndex, group in ipairs(groups) do
            for _, spellID in ipairs(group.ids) do
                local spellName = self.idToName[spellID]
                if spellName then
                    self.sharedGroups[className][spellName] = groupIndex
                end
            end
        end
    end
end

function RAT.Data:ProcessResetters()
    self.resetterMap = {}
    if not self.Resetters then return end

    for resetterID, targetIDs in pairs(self.Resetters) do
        local resetterName = self.idToName[resetterID]
        if resetterName then
            self.resetterMap[resetterName] = {}
            for _, targetID in ipairs(targetIDs) do
                local targetName = self.idToName[targetID]
                if targetName then
                    self.resetterMap[resetterName][targetName] = true
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Query Functions
--------------------------------------------------------------------------------

function RAT.Data:GetSpellData(spellName)
    return self.spellCache[spellName]
end

function RAT.Data:GetSpellIcon(spellName)
    return self.iconCache[spellName]
end

function RAT.Data:GetSpellCooldown(spellName)
    local data = self.spellCache[spellName]
    return data and data.cd
end

function RAT.Data:IsTalentSpell(spellName)
    local data = self.spellCache[spellName]
    return data and data.spec == true
end

function RAT.Data:GetSharedGroup(class, spellName)
    if not self.sharedGroups[class] then return nil end
    return self.sharedGroups[class][spellName]
end

function RAT.Data:GetResetTargets(resetterName)
    return self.resetterMap[resetterName]
end

function RAT.Data:GetTotalSpellCount()
    local count = 0
    for _ in pairs(self.spellCache) do
        count = count + 1
    end
    return count
end

function RAT.Data:GetSpellsByClass(className)
    local spells = {}
    for spellName, data in pairs(self.spellCache) do
        if data.class == className and data.category == "class" then
            table.insert(spells, spellName)
        end
    end
    return spells
end

function RAT.Data:GetSpellsByRace(raceName)
    local spells = {}
    for spellName, data in pairs(self.spellCache) do
        if data.class == raceName and data.category == "racial" then
            table.insert(spells, spellName)
        end
    end
    return spells
end

--- Get trinket data from item ID
-- @param itemID number Item ID of the trinket
-- @return number|nil, number|nil Spell ID and cooldown if trinket is tracked, nil otherwise
function RAT.Data:GetTrinketSpellID(itemID)
    local trinketData = self.TrinketSpells[itemID]
    if trinketData then
        return trinketData.spellID, trinketData.cd
    end
    return nil, nil
end
