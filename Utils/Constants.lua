-- Utils/Constants.lua
-- Centralized constants and magic numbers

local RAT = _G.RAT
RAT.Constants = {}

local Constants = RAT.Constants

--------------------------------------------------------------------------------
-- Class and Race Lists
--------------------------------------------------------------------------------

Constants.CLASSES = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID"
}

Constants.RACES = {
    "Human", "Dwarf", "NightElf", "Gnome", "Draenei",
    "Orc", "Undead", "Tauren", "Troll", "BloodElf"
}

--------------------------------------------------------------------------------
-- Group Types
--------------------------------------------------------------------------------

Constants.GROUP_TYPES = {"cc", "interrupt", "external", "trinket"}

--------------------------------------------------------------------------------
-- Display Constants
--------------------------------------------------------------------------------

Constants.ICON_SIZE = 30
Constants.BAR_SPACING = 1
Constants.ANCHOR_SIZE = 15
Constants.DEFAULT_SCALE = 1.0

--------------------------------------------------------------------------------
-- Timing Constants
--------------------------------------------------------------------------------

Constants.UPDATE_THROTTLE = 0.1
Constants.TALENT_EVENT_DELAY = 0.5

--------------------------------------------------------------------------------
-- Color Constants
--------------------------------------------------------------------------------

Constants.ANCHOR_COLORS = {
    UNIT = {1, 0, 0, 0.5},
    GROUP = {0, 1, 0, 0.5},
}

Constants.BORDER_COLOR = {0, 0, 0, 1}
