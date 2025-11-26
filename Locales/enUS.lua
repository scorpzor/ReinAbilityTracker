-- Locales/enUS.lua
-- English (US) localization

local ADDON_NAME = "ReinAbilityTracker"
local L = LibStub("AceLocale-3.0"):NewLocale(ADDON_NAME, "enUS", true)

if not L then return end

-- General
L["ADDON_LOADED"] = "Rein Ability Tracker v%s loaded!"
L["VERSION_INFO"] = "Rein Ability Tracker version %s"

-- Commands
L["CMD_HELP"] = "Available commands:"
L["CMD_TOGGLE"] = "/rat toggle - Show/hide ability icons"
L["CMD_LOCK"] = "/rat lock - Toggle anchor visibility/lock state"
L["CMD_RESET"] = "/rat reset - Reset all positions to default"
L["CMD_DEBUG"] = "/rat debug - Toggle debug mode"
L["CMD_TEST"] = "/rat test - Toggle test mode (show player spells for testing)"
L["CMD_ANCHOR"] = "/rat anchor <point> - Set anchor point (TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT)"
L["CMD_GROWTH"] = "/rat growth <dir> - Set growth direction (RIGHT, LEFT, DOWN, UP)"
L["CMD_OFFSET"] = "/rat offset <x> <y> - Set anchor offset"
L["CMD_STATUS"] = "/rat status - Show current configuration and party state"

-- Errors
L["ERROR_NO_PARTY"] = "You are not in a party"
L["ERROR_INSPECTION_FAILED"] = "Failed to inspect party member"

-- Settings
L["SETTINGS_SCALE"] = "Icon Scale"
L["SETTINGS_SCALE_DESC"] = "Adjust the size of ability icons"
L["SETTINGS_SPACING"] = "Icon Spacing"
L["SETTINGS_SPACING_DESC"] = "Distance between icons"
L["SETTINGS_ICONS_PER_ROW"] = "Icons Per Row"
L["SETTINGS_ICONS_PER_ROW_DESC"] = "Number of icons to display per row (0 = unlimited)"
L["SETTINGS_HIDDEN_MODE"] = "Hidden Mode"
L["SETTINGS_HIDDEN_MODE_DESC"] = "Only show icons when abilities are on cooldown"
L["SETTINGS_LOCK_POSITIONS"] = "Lock Positions"
L["SETTINGS_LOCK_POSITIONS_DESC"] = "Lock anchor positions to prevent moving"

-- Profile
L["PROFILE_SWITCHED"] = "Switched to profile: %s"
L["PROFILE_CREATED"] = "Created new profile: %s"
L["PROFILE_DELETED"] = "Deleted profile: %s"
L["PROFILE_COPIED"] = "Copied settings from %s to %s"
