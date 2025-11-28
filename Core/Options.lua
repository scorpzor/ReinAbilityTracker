-- Core/Options.lua
-- AceConfig-3.0 GUI options panel

local RAT = _G.RAT
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

--------------------------------------------------------------------------------
-- Options Table
--------------------------------------------------------------------------------

local function GetOptions()
    local options = {
        name = "Rein Ability Tracker",
        type = "group",
        args = {
            general = {
                name = "General",
                type = "group",
                order = 1,
                args = {
                    debug = {
                        name = "Debug Mode",
                        desc = "Enable debug output to chat",
                        type = "toggle",
                        order = 1,
                        get = function() return RAT.db.profile.debug end,
                        set = function(_, value)
                            RAT.db.profile.debug = value
                            RAT:Print("Debug mode: " .. (value and "ON" or "OFF"))
                        end,
                    },
                    testMode = {
                        name = "Test Mode",
                        desc = "Show player spells for testing (no party required)",
                        type = "toggle",
                        order = 2,
                        get = function() return RAT.db.profile.testMode end,
                        set = function(_, value)
                            RAT.db.profile.testMode = value
                            RAT:Print("Test mode: " .. (value and "ON" or "OFF"))
                            -- Trigger refresh
                            RAT:OnPartyChanged()
                        end,
                    },
                    showAnchors = {
                        name = "Show/Unlock Anchors",
                        desc = "Show and unlock anchor frames for positioning. When enabled, you can drag anchors. When disabled, anchors are hidden and locked.",
                        type = "toggle",
                        order = 3,
                        get = function() return RAT.db.profile.showAnchors end,
                        set = function(_, value)
                            RAT.db.profile.showAnchors = value
                            -- Lock state follows show state: shown = unlocked, hidden = locked
                            RAT.db.profile.lockPositions = not value
                            if RAT.AnchorDisplay then
                                RAT.AnchorDisplay:UpdateUnitAnchorsVisibility()
                                RAT.AnchorDisplay:UpdateGroupAnchorsVisibility()
                                RAT.AnchorDisplay:UpdateAnchorsLockState()
                            end
                        end,
                    },
                    resetPositions = {
                        name = "Reset Positions",
                        desc = "Reset all anchor positions to default",
                        type = "execute",
                        order = 4,
                        func = function()
                            RAT:ResetAllPositions()
                            RAT:Print("Positions reset to default")
                        end,
                    },
                    showTooltips = {
                        name = "Show Tooltips",
                        desc = "Show spell tooltips when hovering over icons (applies to all icon displays)",
                        type = "toggle",
                        order = 5,
                        get = function() return RAT.db.profile.showTooltips end,
                        set = function(_, value)
                            RAT.db.profile.showTooltips = value
                        end,
                    },
                },
            },
            partySpells = {
                name = "Party Spells",
                type = "group",
                order = 2,
                args = {
                    enabled = {
                        name = "Show Party Spells",
                        desc = "Display spell icons anchored to party frames",
                        type = "toggle",
                        order = 1,
                        get = function() return RAT.db.profile.partySpells.enabled end,
                        set = function(_, value)
                            RAT.db.profile.partySpells.enabled = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    hideInRaid = {
                        name = "Hide in Raid",
                        desc = "Hide party spell icons when in a raid group",
                        type = "toggle",
                        order = 2,
                        disabled = function() return not RAT.db.profile.partySpells.enabled end,
                        get = function() return RAT.db.profile.partySpells.hideInRaid end,
                        set = function(_, value)
                            RAT.db.profile.partySpells.hideInRaid = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    scale = {
                        name = "Icon Scale",
                        desc = "Scale of ability icons",
                        type = "range",
                        min = 0.5,
                        max = 2.0,
                        step = 0.05,
                        order = 3,
                        disabled = function() return not RAT.db.profile.partySpells.enabled end,
                        get = function() return RAT.db.profile.partySpells.scale end,
                        set = function(_, value)
                            RAT.db.profile.partySpells.scale = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    spacing = {
                        name = "Icon Spacing",
                        desc = "Space between icons in pixels",
                        type = "range",
                        min = 0,
                        max = 20,
                        step = 1,
                        order = 4,
                        disabled = function() return not RAT.db.profile.partySpells.enabled end,
                        get = function() return RAT.db.profile.partySpells.spacing end,
                        set = function(_, value)
                            RAT.db.profile.partySpells.spacing = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    iconsPerRow = {
                        name = "Icons Per Row",
                        desc = "Number of icons per row (0 = unlimited)",
                        type = "range",
                        min = 0,
                        max = 20,
                        step = 1,
                        order = 5,
                        disabled = function() return not RAT.db.profile.partySpells.enabled end,
                        get = function() return RAT.db.profile.partySpells.iconsPerRow end,
                        set = function(_, value)
                            RAT.db.profile.partySpells.iconsPerRow = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    anchorPoint = {
                        name = "Anchor Point",
                        desc = "Where to anchor icons on party frames",
                        type = "select",
                        order = 6,
                        disabled = function() return not RAT.db.profile.partySpells.enabled end,
                        values = {
                            TOPLEFT = "Top Left",
                            TOPRIGHT = "Top Right",
                            BOTTOMLEFT = "Bottom Left",
                            BOTTOMRIGHT = "Bottom Right",
                        },
                        get = function() return RAT.db.profile.anchorPoint end,
                        set = function(_, value)
                            RAT.db.profile.anchorPoint = value
                            if RAT.IconManager then
                                RAT.IconManager:PositionAnchors()
                            end
                        end,
                    },
                    anchorGrowth = {
                        name = "Growth Direction",
                        desc = "Direction icons grow from the anchor",
                        type = "select",
                        order = 7,
                        disabled = function() return not RAT.db.profile.partySpells.enabled end,
                        values = {
                            RIGHT = "Right",
                            LEFT = "Left",
                            DOWN = "Down",
                            UP = "Up",
                        },
                        get = function() return RAT.db.profile.anchorGrowth end,
                        set = function(_, value)
                            RAT.db.profile.anchorGrowth = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    anchorOffsetX = {
                        name = "X Offset",
                        desc = "Horizontal offset from anchor point",
                        type = "range",
                        min = -200,
                        max = 200,
                        step = 1,
                        order = 8,
                        disabled = function() return not RAT.db.profile.partySpells.enabled end,
                        get = function() return RAT.db.profile.anchorOffsetX end,
                        set = function(_, value)
                            RAT.db.profile.anchorOffsetX = value
                            if RAT.IconManager then
                                RAT.IconManager:PositionAnchors()
                            end
                        end,
                    },
                    anchorOffsetY = {
                        name = "Y Offset",
                        desc = "Vertical offset from anchor point",
                        type = "range",
                        min = -200,
                        max = 200,
                        step = 1,
                        order = 9,
                        disabled = function() return not RAT.db.profile.partySpells.enabled end,
                        get = function() return RAT.db.profile.anchorOffsetY end,
                        set = function(_, value)
                            RAT.db.profile.anchorOffsetY = value
                            if RAT.IconManager then
                                RAT.IconManager:PositionAnchors()
                            end
                        end,
                    },
                },
            },
            ccGroup = {
                name = "CC Group",
                type = "group",
                order = 3,
                args = {
                    enabled = {
                        name = "Show CC Group",
                        desc = "Display crowd control abilities in a separate group anchor",
                        type = "toggle",
                        order = 1,
                        get = function() return RAT.db.profile.groupAnchors.showCC end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.showCC = value
                            if RAT.IconManager then
                                RAT.AnchorDisplay:UpdateGroupAnchorsVisibility()
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    scale = {
                        name = "Icon Scale",
                        desc = "Scale of CC icons",
                        type = "range",
                        min = 0.5,
                        max = 2.0,
                        step = 0.05,
                        order = 2,
                        disabled = function() return not RAT.db.profile.groupAnchors.showCC end,
                        get = function() return RAT.db.profile.groupAnchors.cc.scale end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.cc.scale = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    spacing = {
                        name = "Icon Spacing",
                        desc = "Space between icons in pixels",
                        type = "range",
                        min = 0,
                        max = 20,
                        step = 1,
                        order = 3,
                        disabled = function() return not RAT.db.profile.groupAnchors.showCC end,
                        get = function() return RAT.db.profile.groupAnchors.cc.spacing end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.cc.spacing = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    iconsPerRow = {
                        name = "Icons Per Row",
                        desc = "Number of icons per row (0 = unlimited)",
                        type = "range",
                        min = 0,
                        max = 20,
                        step = 1,
                        order = 4,
                        disabled = function() return not RAT.db.profile.groupAnchors.showCC end,
                        get = function() return RAT.db.profile.groupAnchors.cc.iconsPerRow end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.cc.iconsPerRow = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    anchorGrowth = {
                        name = "Growth Direction",
                        desc = "Direction icons grow from the anchor",
                        type = "select",
                        order = 5,
                        disabled = function() return not RAT.db.profile.groupAnchors.showCC end,
                        values = {
                            RIGHT = "Right",
                            LEFT = "Left",
                            DOWN = "Down",
                            UP = "Up",
                        },
                        get = function() return RAT.db.profile.groupAnchors.cc.growth end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.cc.growth = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                },
            },
            interruptGroup = {
                name = "Interrupt Group",
                type = "group",
                order = 4,
                args = {
                    enabled = {
                        name = "Show Interrupt Group",
                        desc = "Display interrupt abilities as bars in a separate group anchor",
                        type = "toggle",
                        order = 1,
                        get = function() return RAT.db.profile.groupAnchors.showInterrupt end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.showInterrupt = value
                            if RAT.IconManager then
                                RAT.AnchorDisplay:UpdateGroupAnchorsVisibility()
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    hideInRaid = {
                        name = "Hide in Raid",
                        desc = "Hide interrupt bars when in a raid group",
                        type = "toggle",
                        order = 2,
                        disabled = function() return not RAT.db.profile.groupAnchors.showInterrupt end,
                        get = function() return RAT.db.profile.interruptBars.hideInRaid end,
                        set = function(_, value)
                            RAT.db.profile.interruptBars.hideInRaid = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    barWidth = {
                        name = "Bar Width",
                        desc = "Width of interrupt bars in pixels",
                        type = "range",
                        min = 50,
                        max = 400,
                        step = 5,
                        order = 3,
                        disabled = function() return not RAT.db.profile.groupAnchors.showInterrupt end,
                        get = function() return RAT.db.profile.interruptBars.barWidth end,
                        set = function(_, value)
                            RAT.db.profile.interruptBars.barWidth = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    barHeight = {
                        name = "Bar Height",
                        desc = "Height of interrupt bars in pixels",
                        type = "range",
                        min = 10,
                        max = 50,
                        step = 1,
                        order = 4,
                        disabled = function() return not RAT.db.profile.groupAnchors.showInterrupt end,
                        get = function() return RAT.db.profile.interruptBars.barHeight end,
                        set = function(_, value)
                            RAT.db.profile.interruptBars.barHeight = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    barTexture = {
                        name = "Bar Texture",
                        desc = "Visual texture/style for interrupt bars",
                        type = "select",
                        order = 5,
                        disabled = function() return not RAT.db.profile.groupAnchors.showInterrupt end,
                        values = {
                            Blizzard = "Blizzard (Default)",
                            Smooth = "Smooth",
                            Gradient = "Gradient",
                        },
                        get = function() return RAT.db.profile.interruptBars.barTexture end,
                        set = function(_, value)
                            RAT.db.profile.interruptBars.barTexture = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    fillDirection = {
                        name = "Fill Direction",
                        desc = "Direction bars fill/drain during cooldown",
                        type = "select",
                        order = 6,
                        disabled = function() return not RAT.db.profile.groupAnchors.showInterrupt end,
                        values = {
                            LEFT_TO_RIGHT = "Left to Right (fill)",
                            RIGHT_TO_LEFT = "Right to Left (drain)",
                        },
                        get = function() return RAT.db.profile.interruptBars.fillDirection end,
                        set = function(_, value)
                            RAT.db.profile.interruptBars.fillDirection = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                },
            },
            externalGroup = {
                name = "External Group",
                type = "group",
                order = 5,
                args = {
                    enabled = {
                        name = "Show External Group",
                        desc = "Display external cooldowns (buffs cast on others) in a separate group anchor",
                        type = "toggle",
                        order = 1,
                        get = function() return RAT.db.profile.groupAnchors.showExternal end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.showExternal = value
                            if RAT.IconManager then
                                RAT.AnchorDisplay:UpdateGroupAnchorsVisibility()
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    scale = {
                        name = "Icon Scale",
                        desc = "Scale of external cooldown icons",
                        type = "range",
                        min = 0.5,
                        max = 2.0,
                        step = 0.05,
                        order = 2,
                        disabled = function() return not RAT.db.profile.groupAnchors.showExternal end,
                        get = function() return RAT.db.profile.groupAnchors.external.scale end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.external.scale = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    spacing = {
                        name = "Icon Spacing",
                        desc = "Space between icons in pixels",
                        type = "range",
                        min = 0,
                        max = 20,
                        step = 1,
                        order = 3,
                        disabled = function() return not RAT.db.profile.groupAnchors.showExternal end,
                        get = function() return RAT.db.profile.groupAnchors.external.spacing end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.external.spacing = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    iconsPerRow = {
                        name = "Icons Per Row",
                        desc = "Number of icons per row (0 = unlimited)",
                        type = "range",
                        min = 0,
                        max = 20,
                        step = 1,
                        order = 4,
                        disabled = function() return not RAT.db.profile.groupAnchors.showExternal end,
                        get = function() return RAT.db.profile.groupAnchors.external.iconsPerRow end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.external.iconsPerRow = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    anchorGrowth = {
                        name = "Growth Direction",
                        desc = "Direction icons grow from the anchor",
                        type = "select",
                        order = 5,
                        disabled = function() return not RAT.db.profile.groupAnchors.showExternal end,
                        values = {
                            RIGHT = "Right",
                            LEFT = "Left",
                            DOWN = "Down",
                            UP = "Up",
                        },
                        get = function() return RAT.db.profile.groupAnchors.external.growth end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.external.growth = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                },
            },
            trinketGroup = {
                name = "Trinket Group",
                type = "group",
                order = 6,
                args = {
                    enabled = {
                        name = "Show Trinket Group",
                        desc = "Display equipped trinkets in a separate group anchor",
                        type = "toggle",
                        order = 1,
                        get = function() return RAT.db.profile.groupAnchors.showTrinket end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.showTrinket = value
                            if RAT.IconManager then
                                RAT.AnchorDisplay:UpdateGroupAnchorsVisibility()
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    scale = {
                        name = "Icon Scale",
                        desc = "Scale of trinket icons",
                        type = "range",
                        min = 0.5,
                        max = 2.0,
                        step = 0.05,
                        order = 2,
                        disabled = function() return not RAT.db.profile.groupAnchors.showTrinket end,
                        get = function() return RAT.db.profile.groupAnchors.trinket.scale end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.trinket.scale = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    spacing = {
                        name = "Icon Spacing",
                        desc = "Space between icons in pixels",
                        type = "range",
                        min = 0,
                        max = 20,
                        step = 1,
                        order = 3,
                        disabled = function() return not RAT.db.profile.groupAnchors.showTrinket end,
                        get = function() return RAT.db.profile.groupAnchors.trinket.spacing end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.trinket.spacing = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    iconsPerRow = {
                        name = "Icons Per Row",
                        desc = "Number of icons per row (0 = unlimited)",
                        type = "range",
                        min = 0,
                        max = 20,
                        step = 1,
                        order = 4,
                        disabled = function() return not RAT.db.profile.groupAnchors.showTrinket end,
                        get = function() return RAT.db.profile.groupAnchors.trinket.iconsPerRow end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.trinket.iconsPerRow = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    anchorGrowth = {
                        name = "Growth Direction",
                        desc = "Direction icons grow from the anchor",
                        type = "select",
                        order = 5,
                        disabled = function() return not RAT.db.profile.groupAnchors.showTrinket end,
                        values = {
                            RIGHT = "Right",
                            LEFT = "Left",
                            DOWN = "Down",
                            UP = "Up",
                        },
                        get = function() return RAT.db.profile.groupAnchors.trinket.growth end,
                        set = function(_, value)
                            RAT.db.profile.groupAnchors.trinket.growth = value
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                },
            },
            spellFilters = {
                name = "Spell Filters",
                type = "group",
                order = 7,
                args = {
                    description = {
                        name = "Filter which spells appear in each display group. Uncheck a spell to hide it from that group.",
                        type = "description",
                        order = 1,
                    },
                    groupSelect = {
                        name = "Select Group",
                        desc = "Choose which spell group to configure",
                        type = "select",
                        order = 2,
                        values = {
                            party = "Party Spells",
                            cc = "CC Group",
                            interrupt = "Interrupt Group",
                            external = "External Group",
                            trinket = "Trinket Group",
                        },
                        get = function()
                            return RAT.db.profile.spellFilterSelectedGroup or "party"
                        end,
                        set = function(_, value)
                            RAT.db.profile.spellFilterSelectedGroup = value
                        end,
                    },
                    spellList = {
                        name = "Spells",
                        type = "group",
                        order = 3,
                        inline = true,
                        args = {},
                        get = function(info)
                            local selectedGroup = RAT.db.profile.spellFilterSelectedGroup or "party"
                            local spellName = info[#info]

                            if not RAT.db.profile.spellGroupFilters[selectedGroup] then
                                return true
                            end

                            local enabled = RAT.db.profile.spellGroupFilters[selectedGroup][spellName]
                            return enabled == nil and true or enabled
                        end,
                        set = function(info, value)
                            local selectedGroup = RAT.db.profile.spellFilterSelectedGroup or "party"
                            local spellName = info[#info]

                            if not RAT.db.profile.spellGroupFilters[selectedGroup] then
                                RAT.db.profile.spellGroupFilters[selectedGroup] = {}
                            end

                            RAT.db.profile.spellGroupFilters[selectedGroup][spellName] = value

                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                },
            },
        },
    }

    -- Dynamically populate spell list based on selected group
    local selectedGroup = RAT.db and RAT.db.profile.spellFilterSelectedGroup or "party"
    local spellData = {}

    if RAT.SpellManager and RAT.SpellManager.GetAllSpellsForGroup then
        spellData = RAT.SpellManager:GetAllSpellsForGroup(selectedGroup)
    end

    local order = 10

    for _, className in ipairs({"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}) do
        local spells = spellData.classes and spellData.classes[className]
        if spells and #spells > 0 then
            local classColor = RAID_CLASS_COLORS[className]
            local colorCode = ""
            if classColor then
                colorCode = string.format("|cff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
            end

            options.args.spellFilters.args.spellList.args["class_" .. className] = {
                name = colorCode .. className .. "|r",
                type = "group",
                inline = true,
                order = order,
                args = {
                    selectAll = {
                        name = "Select All",
                        type = "execute",
                        order = 1,
                        func = function()
                            local group = RAT.db.profile.spellFilterSelectedGroup or "party"
                            if not RAT.db.profile.spellGroupFilters[group] then
                                RAT.db.profile.spellGroupFilters[group] = {}
                            end
                            for _, spellName in ipairs(spells) do
                                RAT.db.profile.spellGroupFilters[group][spellName] = true
                            end
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                    deselectAll = {
                        name = "Deselect All",
                        type = "execute",
                        order = 2,
                        func = function()
                            local group = RAT.db.profile.spellFilterSelectedGroup or "party"
                            if not RAT.db.profile.spellGroupFilters[group] then
                                RAT.db.profile.spellGroupFilters[group] = {}
                            end
                            for _, spellName in ipairs(spells) do
                                RAT.db.profile.spellGroupFilters[group][spellName] = false
                            end
                            if RAT.IconManager then
                                RAT.IconManager:RefreshAllDisplays()
                            end
                        end,
                    },
                },
                get = function(info)
                    local spellName = info[#info]
                    local group = RAT.db.profile.spellFilterSelectedGroup or "party"

                    if not RAT.db.profile.spellGroupFilters[group] then
                        return true
                    end

                    local enabled = RAT.db.profile.spellGroupFilters[group][spellName]
                    return enabled == nil and true or enabled
                end,
                set = function(info, value)
                    local spellName = info[#info]
                    local group = RAT.db.profile.spellFilterSelectedGroup or "party"

                    if not RAT.db.profile.spellGroupFilters[group] then
                        RAT.db.profile.spellGroupFilters[group] = {}
                    end

                    RAT.db.profile.spellGroupFilters[group][spellName] = value

                    if RAT.IconManager then
                        RAT.IconManager:RefreshAllDisplays()
                    end
                end,
            }

            for i, spellName in ipairs(spells) do
                options.args.spellFilters.args.spellList.args["class_" .. className].args[spellName] = {
                    name = spellName,
                    type = "toggle",
                    order = i + 10,
                }
            end

            order = order + 1
        end
    end

    local allRacialSpells = {}
    if spellData.races then
        for _, raceName in ipairs({"Human", "Dwarf", "NightElf", "Gnome", "Draenei", "Orc", "Undead", "Tauren", "Troll", "BloodElf"}) do
            local spells = spellData.races[raceName]
            if spells then
                for _, spellName in ipairs(spells) do
                    table.insert(allRacialSpells, spellName)
                end
            end
        end
    end

    if #allRacialSpells > 0 then
        table.sort(allRacialSpells)

        options.args.spellFilters.args.spellList.args["racials"] = {
            name = "Racials",
            type = "group",
            inline = true,
            order = order,
            args = {
                selectAll = {
                    name = "Select All",
                    type = "execute",
                    order = 1,
                    func = function()
                        local group = RAT.db.profile.spellFilterSelectedGroup or "party"
                        if not RAT.db.profile.spellGroupFilters[group] then
                            RAT.db.profile.spellGroupFilters[group] = {}
                        end
                        for _, spellName in ipairs(allRacialSpells) do
                            RAT.db.profile.spellGroupFilters[group][spellName] = true
                        end
                        if RAT.IconManager then
                            RAT.IconManager:RefreshAllDisplays()
                        end
                    end,
                },
                deselectAll = {
                    name = "Deselect All",
                    type = "execute",
                    order = 2,
                    func = function()
                        local group = RAT.db.profile.spellFilterSelectedGroup or "party"
                        if not RAT.db.profile.spellGroupFilters[group] then
                            RAT.db.profile.spellGroupFilters[group] = {}
                        end
                        for _, spellName in ipairs(allRacialSpells) do
                            RAT.db.profile.spellGroupFilters[group][spellName] = false
                        end
                        if RAT.IconManager then
                            RAT.IconManager:RefreshAllDisplays()
                        end
                    end,
                },
            },
            get = function(info)
                local spellName = info[#info]
                local group = RAT.db.profile.spellFilterSelectedGroup or "party"

                if not RAT.db.profile.spellGroupFilters[group] then
                    return true
                end

                local enabled = RAT.db.profile.spellGroupFilters[group][spellName]
                return enabled == nil and true or enabled
            end,
            set = function(info, value)
                local spellName = info[#info]
                local group = RAT.db.profile.spellFilterSelectedGroup or "party"

                if not RAT.db.profile.spellGroupFilters[group] then
                    RAT.db.profile.spellGroupFilters[group] = {}
                end

                RAT.db.profile.spellGroupFilters[group][spellName] = value

                if RAT.IconManager then
                    RAT.IconManager:RefreshAllDisplays()
                end
            end,
        }

        for i, spellName in ipairs(allRacialSpells) do
            options.args.spellFilters.args.spellList.args["racials"].args[spellName] = {
                name = spellName,
                type = "toggle",
                order = i + 10,
            }
        end

        order = order + 1
    end

    if spellData.trinkets and #spellData.trinkets > 0 then
        options.args.spellFilters.args.spellList.args["trinkets"] = {
            name = "Trinkets",
            type = "group",
            inline = true,
            order = order,
            args = {
                selectAll = {
                    name = "Select All",
                    type = "execute",
                    order = 1,
                    func = function()
                        local group = RAT.db.profile.spellFilterSelectedGroup or "party"
                        if not RAT.db.profile.spellGroupFilters[group] then
                            RAT.db.profile.spellGroupFilters[group] = {}
                        end
                        for _, spellName in ipairs(spellData.trinkets) do
                            RAT.db.profile.spellGroupFilters[group][spellName] = true
                        end
                        if RAT.IconManager then
                            RAT.IconManager:RefreshAllDisplays()
                        end
                    end,
                },
                deselectAll = {
                    name = "Deselect All",
                    type = "execute",
                    order = 2,
                    func = function()
                        local group = RAT.db.profile.spellFilterSelectedGroup or "party"
                        if not RAT.db.profile.spellGroupFilters[group] then
                            RAT.db.profile.spellGroupFilters[group] = {}
                        end
                        for _, spellName in ipairs(spellData.trinkets) do
                            RAT.db.profile.spellGroupFilters[group][spellName] = false
                        end
                        if RAT.IconManager then
                            RAT.IconManager:RefreshAllDisplays()
                        end
                    end,
                },
            },
            get = function(info)
                local spellName = info[#info]
                local group = RAT.db.profile.spellFilterSelectedGroup or "party"

                if not RAT.db.profile.spellGroupFilters[group] then
                    return true
                end

                local enabled = RAT.db.profile.spellGroupFilters[group][spellName]
                return enabled == nil and true or enabled
            end,
            set = function(info, value)
                local spellName = info[#info]
                local group = RAT.db.profile.spellFilterSelectedGroup or "party"

                if not RAT.db.profile.spellGroupFilters[group] then
                    RAT.db.profile.spellGroupFilters[group] = {}
                end

                RAT.db.profile.spellGroupFilters[group][spellName] = value

                if RAT.IconManager then
                    RAT.IconManager:RefreshAllDisplays()
                end
            end,
        }

        for i, spellName in ipairs(spellData.trinkets) do
            options.args.spellFilters.args.spellList.args["trinkets"].args[spellName] = {
                name = spellName,
                type = "toggle",
                order = i + 10,
            }
        end

        order = order + 1
    end

    if spellData.mysticEnchants then
        for _, className in ipairs({"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}) do
            local enchants = spellData.mysticEnchants[className]
            if enchants and #enchants > 0 then
                local classColor = RAID_CLASS_COLORS[className]
                local colorCode = ""
                if classColor then
                    colorCode = string.format("|cff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
                end

                options.args.spellFilters.args.spellList.args["mystic_" .. className] = {
                    name = colorCode .. className .. " Mystic Enchants|r",
                    type = "group",
                    inline = true,
                    order = order,
                    args = {
                        selectAll = {
                            name = "Select All",
                            type = "execute",
                            order = 1,
                            func = function()
                                local group = RAT.db.profile.spellFilterSelectedGroup or "party"
                                if not RAT.db.profile.spellGroupFilters[group] then
                                    RAT.db.profile.spellGroupFilters[group] = {}
                                end
                                for _, spellName in ipairs(enchants) do
                                    RAT.db.profile.spellGroupFilters[group][spellName] = true
                                end
                                if RAT.IconManager then
                                    RAT.IconManager:RefreshAllDisplays()
                                end
                            end,
                        },
                        deselectAll = {
                            name = "Deselect All",
                            type = "execute",
                            order = 2,
                            func = function()
                                local group = RAT.db.profile.spellFilterSelectedGroup or "party"
                                if not RAT.db.profile.spellGroupFilters[group] then
                                    RAT.db.profile.spellGroupFilters[group] = {}
                                end
                                for _, spellName in ipairs(enchants) do
                                    RAT.db.profile.spellGroupFilters[group][spellName] = false
                                end
                                if RAT.IconManager then
                                    RAT.IconManager:RefreshAllDisplays()
                                end
                            end,
                        },
                    },
                    get = function(info)
                        local spellName = info[#info]
                        local group = RAT.db.profile.spellFilterSelectedGroup or "party"

                        if not RAT.db.profile.spellGroupFilters[group] then
                            return true
                        end

                        local enabled = RAT.db.profile.spellGroupFilters[group][spellName]
                        return enabled == nil and true or enabled
                    end,
                    set = function(info, value)
                        local spellName = info[#info]
                        local group = RAT.db.profile.spellFilterSelectedGroup or "party"

                        if not RAT.db.profile.spellGroupFilters[group] then
                            RAT.db.profile.spellGroupFilters[group] = {}
                        end

                        RAT.db.profile.spellGroupFilters[group][spellName] = value

                        if RAT.IconManager then
                            RAT.IconManager:RefreshAllDisplays()
                        end
                    end,
                }

                for i, spellName in ipairs(enchants) do
                    options.args.spellFilters.args.spellList.args["mystic_" .. className].args[spellName] = {
                        name = spellName,
                        type = "toggle",
                        order = i + 10,
                    }
                end

                order = order + 1
            end
        end
    end

    return options
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function RAT:SetupOptions()
    AceConfig:RegisterOptionsTable("ReinAbilityTracker", GetOptions)
    self.optionsFrame = AceConfigDialog:AddToBlizOptions("ReinAbilityTracker", "Rein Ability Tracker")

    -- Other addons do this, so I guess I should too
    self:RegisterChatCommand("ratoptions", function()
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    end)

    RAT:DebugPrint("Options panel registered")
end

