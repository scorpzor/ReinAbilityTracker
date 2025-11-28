-- Data/Spells.lua
-- Spell and ability database for cooldown tracking (OmniCD-style structure)

local RAT = _G.RAT or {}
RAT.Data = RAT.Data or {}

--------------------------------------------------------------------------------
-- Spell Database Structure
--   id       = spell ID
--   cd       = cooldown in seconds
--   type     = ability type (interrupt, cc, defensive, offensive, other, etc.)
--   spec     = talent requirement (true = requires sync/inspection)
--   duration = (optional) buff/effect duration in seconds - shows glow for this duration
--
-- Spell types:
--   interrupt - Interrupts (kick, counterspell, etc.)
--   cc        - Crowd control (stun, fear, poly, etc.)
--   defensive - Defensive cooldowns (wall etc.)
--   offensive - Offensive cooldowns (wings etc.)
--   external  - Spells that can help your group (innervate, bop, etc.)
--   trinket   - Trinket on-use effects
--------------------------------------------------------------------------------

RAT.Data.Spells = {
    ["DRUID"] = {
        -- Interrupts
        { id = 1105211, cd = 60,  type = "interrupt", spec = true }, -- Bash

        -- CC
        { id = 1150516, cd = 20,  type = "cc", spec = true }, -- Typhoon

        -- Defensive
        { id = 1122812, cd = 60, type = "defensive" }, -- Barkskin

        -- Offensive
        { id = 1148505, cd = 90,  type = "offensive", spec = true }, -- Starfall

        -- External
        { id = 1129166, cd = 180, type = "external" }, -- Innervate
        { id = 1109863, cd = 480, type = "external" }, -- Tranquility
    },

    ["HUNTER"] = {
        -- CC
        { id = 19503, cd = 30,  type = "cc", spec = true }, -- Scatter Shot
        { id = 60192, cd = 28,  type = "cc" },              -- Freezing Arrow
        { id = 13809, cd = 28,  type = "cc" },              -- Frost Trap
        { id = 14311, cd = 28,  type = "cc" },              -- Freezing Trap
        { id = 49012, cd = 30,  type = "cc", spec = true }, -- Wyvern Sting

        -- Defensive
        { id = 19263, cd = 90,  type = "defensive" },       -- Deterrence
        { id = 53271, cd = 60,  type = "defensive" },       -- Master's Call

        -- Offensive
        { id = 19574, cd = 120, type = "offensive", spec = true }, -- Bestial Wrath
        { id = 34490, cd = 20,  type = "offensive", spec = true }, -- Silencing Shot
        { id = 67481, cd = 60,  type = "offensive" },       -- Roar of Sacrifice

        -- Other
        { id = 23989, cd = 180, type = "other", spec = true }, -- Readiness
    },

    ["MAGE"] = {
        -- Interrupts
        { id = 2139,  cd = 24,  type = "interrupt" },       -- Counterspell

        -- CC
        { id = 44572, cd = 30,  type = "cc", spec = true }, -- Deep Freeze
        { id = 42917, cd = 20,  type = "cc" },              -- Frost Nova

        -- Defensive
        { id = 45438, cd = 300, type = "defensive" },       -- Ice Block

        -- Offensive
        { id = 11958, cd = 384, type = "offensive", spec = true }, -- Cold Snap
        { id = 12043, cd = 60,  type = "offensive", spec = true }, -- Presence of Mind
        { id = 11129, cd = 120, type = "offensive", spec = true }, -- Combustion
        { id = 42950, cd = 20,  type = "offensive", spec = true }, -- Dragon's Breath

        -- Other
        { id = 12051, cd = 240, type = "other" },           -- Evocation
    },

    ["PALADIN"] = {
        -- CC
        { id = 10308, cd = 60,  type = "interrupt" },                  -- Hammer of Justice
        { id = 66008, cd = 60,  type = "cc", spec = true },            -- Repentance

        -- Defensive
        { id = 1100498, cd = 180, type = "defensive", duration = 12 }, -- Divine Protection
        { id = 1100642, cd = 300, type = "defensive" },                -- Divine Shield
        { id = 1101044, cd = 25, type = "defensive" },                 -- Hand of Freedom
        { id = 1106940, cd = 120, type = "defensive" },                -- Hand of Sacrifice
        { id = 1110278, cd = 300, type = "external" },                 -- Hand of Protection

        -- Raid Defensive
        { id = 1131821, cd = 120, type = "external", spec = true },    -- Aura Mastery
        { id = 1164205, cd = 120, type = "external", spec = true },    -- Divine Sacrifice

        -- Offensive
        { id = 31884, cd = 120, type = "offensive" },                  -- Avenging Wrath
    },

    ["PRIEST"] = {
        -- CC
        { id = 1110890, cd = 27,  type = "cc" },                            -- Psychic Scream
        { id = 64044, cd = 120, type = "cc", spec = true },                 -- Psychic Horror

        -- Defensive
        --{ id = 47585, cd = 75,  type = "defensive", spec = true },          -- Dispersion
        { id = 1106346, cd = 180, type = "defensive" },                     -- Fear Ward
        { id = 1100586, cd = 30,  type = "defensive" },                     -- Fade
        { id = 1164901,  cd = 360, type = "defensive"},                     -- Hymn of Hope
        { id = 1164843,  cd = 480, type = "defensive"},                     -- Divine Hymn

        -- Offensive
        { id = 1134433, cd = 300, type = "offensive" },                     -- Shadowfiend
        { id = 1110060, cd = 120,  type = "offensive", spec = true },       -- Power Infusion

        -- External
        { id = 1147788,  cd = 180, type = "external", spec = true },        -- Guardian Spirit
        { id = 1133206,  cd = 180, type = "external", spec = true },        -- Pain Suppression
    },

    ["ROGUE"] = {
        -- Interrupts
        { id = 1766,  cd = 10,  type = "interrupt" },       -- Kick

        -- CC
        { id = 8643,  cd = 20,  type = "cc" },              -- Kidney Shot
        { id = 2094,  cd = 120, type = "cc" },              -- Blind

        -- Defensive
        { id = 31224, cd = 60,  type = "defensive" },       -- Cloak of Shadows
        { id = 51722, cd = 60,  type = "defensive" },       -- Dismantle
        { id = 26889, cd = 120, type = "defensive" },       -- Vanish

        -- Offensive
        { id = 14185, cd = 300, type = "offensive", spec = true }, -- Preparation
        { id = 51713, cd = 60,  type = "offensive", spec = true }, -- Shadow Dance
        { id = 51690, cd = 120, type = "offensive", spec = true }, -- Killing Spree
        { id = 14177, cd = 180, type = "offensive", spec = true }, -- Cold Blood
        { id = 36554, cd = 20,  type = "offensive", spec = true }, -- Shadowstep
    },

    ["SHAMAN"] = {
        -- Interrupts
        { id = 57994, cd = 5,   type = "interrupt" },       -- Wind Shear

        -- CC
        { id = 51514, cd = 45,  type = "cc" },              -- Hex
        { id = 2484,  cd = 10.5, type = "cc" },             -- Earthbind Totem

        -- Defensive
        { id = 16188, cd = 120, type = "defensive", spec = true }, -- Nature's Swiftness
        { id = 8177,  cd = 15,  type = "defensive" },       -- Grounding Totem

        -- Offensive
        { id = 51490, cd = 35,  type = "offensive", spec = true }, -- Thunderstorm
        { id = 30823, cd = 60,  type = "offensive", spec = true }, -- Shamanistic Rage
        { id = 16166, cd = 180, type = "offensive", spec = true }, -- Elemental Mastery

        -- Other
        { id = 16190, cd = 300, type = "other", spec = true }, -- Mana Tide Totem
    },

    ["WARLOCK"] = {
        -- Interrupts
        { id = 19647, cd = 24,  type = "interrupt" },       -- Spell Lock (Felhunter)

        -- CC
        { id = 17925, cd = 120, type = "cc" },              -- Death Coil
        { id = 47847, cd = 20,  type = "cc", spec = true }, -- Shadowfury

        -- Defensive
        { id = 48011, cd = 8,   type = "defensive" },       -- Devour Magic

        -- Other
        { id = 48020, cd = 30,  type = "other" },           -- Demonic Circle: Teleport
        { id = 18708, cd = 180, type = "other", spec = true }, -- Fel Domination
        { id = 17928, cd = 40,  type = "other" },           -- Howl of Terror
    },

    ["WARRIOR"] = {
        -- Interrupts
        { id = 6552,  cd = 10,  type = "interrupt", spec = true},       -- Pummel
        { id = 72,    cd = 12,  type = "interrupt", spec = true},       -- Shield Bash

        -- CC
        { id = 12809, cd = 30,  type = "cc", spec = true }, -- Concussion Blow
        { id = 46968, cd = 17,  type = "cc", spec = true }, -- Shockwave

        -- Defensive
        { id = 871,   cd = 300, type = "defensive" },       -- Shield Wall
        { id = 2565,  cd = 60,  type = "defensive" },       -- Shield Block
        { id = 676,   cd = 60,  type = "defensive" },       -- Disarm

        -- Offensive
        { id = 11578, cd = 13,  type = "offensive" },       -- Charge
        { id = 47996, cd = 15,  type = "offensive" },       -- Intercept
        { id = 46924, cd = 90,  type = "offensive", spec = true }, -- Bladestorm
        { id = 3411,  cd = 30,  type = "offensive" },       -- Intervene
    },
}

--------------------------------------------------------------------------------
-- Racial Abilities
--------------------------------------------------------------------------------

RAT.Data.Racials = {
    ["Scourge"] = {
        { id = 7744,  cd = 120, type = "defensive" },       -- Will of the Forsaken
    },
    ["BloodElf"] = {
        { id = 28730, cd = 120, type = "interrupt" },       -- Arcane Torrent
    },
    ["Tauren"] = {
        { id = 20549, cd = 120, type = "cc" },              -- War Stomp
    },
    ["Orc"] = {
        { id = 20572, cd = 120, type = "offensive" },       -- Blood Fury
    },
    ["Troll"] = {
        { id = 26297, cd = 120, type = "offensive" },       -- Berserking
    },
    ["NightElf"] = {
        { id = 58984, cd = 120, type = "defensive" },       -- Shadowmeld
    },
    ["Draenei"] = {
        { id = 59547, cd = 120, type = "defensive" },       -- Gift of the Naaru
    },
    ["Human"] = {
        { id = 59752, cd = 120, type = "defensive" },       -- Every Man for Himself
    },
    ["Gnome"] = {
        { id = 20589, cd = 120, type = "defensive" },       -- Escape Artist
    },
    ["Dwarf"] = {
        { id = 20594, cd = 120, type = "defensive" },       -- Stoneform
    },
}

--------------------------------------------------------------------------------
-- Shared Cooldowns
--------------------------------------------------------------------------------

RAT.Data.SharedCooldowns = {
    ["DRUID"] = {
        { ids = { 16979, 49376 } },                         -- Feral Charge - Bear/Cat
    },
    ["SHAMAN"] = {
        { ids = { 49231, 49233, 49236 } },                  -- Earth/Flame/Frost Shock
    },
    ["HUNTER"] = {
        { ids = { 60192, 14311, 13809 } },                  -- Freezing Arrow/Trap, Frost Trap
        { ids = { 49067, 49056 } },                         -- Explosive/Immolation Trap
    },
    ["MAGE"] = {
        { ids = { 43010, 43012 } },                         -- Fire/Frost Ward
    },
    ["WARRIOR"] = {
        { ids = { 6552, 72 } },                             -- Pummel/Shield Bash
    },
}

--------------------------------------------------------------------------------
-- Cooldown Resetters (Abilities that reset other cooldowns)
--------------------------------------------------------------------------------

RAT.Data.Resetters = {
    [11958] = { 42931, 43012, 43039, 45438, 31687, 44572, 44545, 12472, 42917 }, -- Cold Snap
    [14185] = { 14177, 26669, 11305, 26889, 36554, 1766, 51722 },                -- Preparation
    [23989] = { 19503, 60192, 13809, 14311, 19574, 34490, 19263, 53271, 49012 }, -- Readiness
}

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

--------------------------------------------------------------------------------
-- Trinket Database
--------------------------------------------------------------------------------
RAT.Data.TrinketSpells = {
    -- PvP Trinkets
    [37864] = {spellID = 42292, cd = 120},  -- Medallion of the Alliance
    [37865] = {spellID = 42292, cd = 120},  -- Medallion of the Horde
    [42292] = {spellID = 42292, cd = 120},  -- Generic PvP Trinket

    [1414524] = {spellID = 23996, cd = 120},  -- Drakefury Scale

    -- Example: [itemID] = {spellID = differentSpellID, cd = customCooldown},
}

--------------------------------------------------------------------------------
-- Mystic Enchant ID Mapping
-- Maps enchant/collection IDs to castable spell IDs
-- Structure: ["CLASS"] = { [enchantID] = {spellID, cooldown, type} }
-- Types: interrupt, cc, defensive, offensive, external
--------------------------------------------------------------------------------
RAT.Data.MysticEnchantMapping = {
    ["PALADIN"] = {
        [1591108] = {1589815, 25, "defensive"},
    },

    ["WARRIOR"] = {

    },

    ["PRIEST"] = {
        [1398201] = {2304522, 120, "external"},
        [1180520] = {1180523, 120, "external"},
        [1398178] = {2110066, 30, "defensive"},
        [1398211] = {2304897, 45, "defensive"},
    },

    ["DRUID"] = {
        [1398202] = {2304523, 60, "interrupt"},
    },

    ["HUNTER"] = {

    },

    ["MAGE"] = {

    },

    ["ROGUE"] = {

    },

    ["SHAMAN"] = {

    },

    ["WARLOCK"] = {

    },
}

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

