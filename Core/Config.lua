-- Core/Config.lua
-- AceDB configuration and profile management

local RAT = _G.RAT
local L = LibStub("AceLocale-3.0"):GetLocale("ReinAbilityTracker")

--------------------------------------------------------------------------------
-- Default Settings Structure
--------------------------------------------------------------------------------

local defaults = {
    profile = {
        debug = false,
        testMode = false,
        showAnchors = true,
        lockPositions = false,
        showTooltips = true,

        configVersion = 3,

        partySpells = {
            enabled = true,
            hideInRaid = true,
            scale = 1.0,
            spacing = 2,
            iconsPerRow = 0,
        },

        -- Anchor positioning (relative to party frames)
        anchorPoint = "TOPLEFT",        -- Where to anchor on party frame (TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT)
        anchorGrowth = "RIGHT",         -- Direction icons grow from first icon (RIGHT, LEFT, DOWN, UP)
        anchorOffsetX = 0,              -- X offset from anchor point
        anchorOffsetY = 0,              -- Y offset from anchor point

        -- Position settings for each anchor (1-5)
        positions = {
            -- [1] = { point = "TOPLEFT", x = 50, y = -300 },
            -- [2] = { point = "TOPLEFT", x = 50, y = -400 },
            -- [3] = { point = "TOPLEFT", x = 50, y = -500 },
            -- [4] = { point = "TOPLEFT", x = 50, y = -600 },
            -- [5] = { point = "TOPLEFT", x = 50, y = -700 },
        },

        -- Group anchor settings
        groupAnchors = {
            showCC = false,
            showInterrupt = false,
            showExternal = false,
            showTrinket = false,

            cc = {
                growth = "RIGHT",
                scale = 1.0,
                spacing = 2,
                iconsPerRow = 0,
            },

            external = {
                growth = "RIGHT",
                scale = 1.0,
                spacing = 2,
                iconsPerRow = 0,
            },

            trinket = {
                growth = "RIGHT",
                scale = 1.0,
                spacing = 2,
                iconsPerRow = 0,
            },

            -- Position settings for group anchors
            positions = {
                -- cc = { point = "TOPLEFT", x = 300, y = -200 },
                -- interrupt = { point = "TOPLEFT", x = 300, y = -300 },
                -- external = { point = "TOPLEFT", x = 300, y = -400 },
                -- trinket = { point = "TOPLEFT", x = 300, y = -500 },
            },
        },

        -- Interrupt bar settings
        interruptBars = {
            fillDirection = "LEFT_TO_RIGHT",  -- Cooldown fill direction: "LEFT_TO_RIGHT" or "RIGHT_TO_LEFT"
            barWidth = 200,                   -- Bar width in pixels
            barHeight = 20,                   -- Bar height in pixels
            barTexture = "Blizzard",          -- Bar texture: "Blizzard", "Smooth", "Gradient"
            hideInRaid = true,                -- Hide interrupt bars when in raid
        },

        -- Enabled abilities per class/race
        enabledSpells = {
            -- Will be populated from Data/Spells.lua defaults
            -- ["WARRIOR"] = { ["Pummel"] = true, ["Shield Wall"] = true, ... },
            -- ["Human"] = { ["Every Man for Himself"] = true },
            -- ["Items"] = { ["PvP Trinket"] = true },
        },

        -- Spell group filters (filter spells by display group)
        spellGroupFilters = {
            -- ["party"] = { ["Spell Name"] = true/false },
            -- ["cc"] = { ["Spell Name"] = true/false },
            -- ["interrupt"] = { ["Spell Name"] = true/false },
            -- ["external"] = { ["Spell Name"] = true/false },
            -- ["trinket"] = { ["Spell Name"] = true/false },
        },
    },
}

--------------------------------------------------------------------------------
-- Database Initialization (called from Init.lua OnInitialize)
--------------------------------------------------------------------------------

function RAT:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ReinAbilityTrackerDB", defaults, true)

    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

    -- Run migrations if needed
    self:MigrateConfig()

    -- Register slash commands
    self:RegisterChatCommand("rat", "SlashCommand")
    self:RegisterChatCommand("reinabilitytracker", "SlashCommand")

    self:DebugPrint("Database initialized")
end

--------------------------------------------------------------------------------
-- Position Management
--------------------------------------------------------------------------------

--- Reset all anchor positions to default
function RAT:ResetAllPositions()
    wipe(self.db.profile.positions)
    wipe(self.db.profile.groupAnchors.positions)

    if self.Anchors then
        self.Anchors:PositionAnchors()
        self.Anchors:PositionGroupAnchors()
    end

    if self.Icons then
        self.Icons:RefreshAllDisplays()
    end
end

--------------------------------------------------------------------------------
-- Config Migrations
--------------------------------------------------------------------------------

function RAT:MigrateConfig()
    local currentVersion = self.db.profile.configVersion or 0

    if currentVersion < 3 then
        self.db.profile.configVersion = 3
    end
end

--------------------------------------------------------------------------------
-- Slash Command Handler
--------------------------------------------------------------------------------

function RAT:SlashCommand(input)
    local args = {strsplit(" ", input:lower())}
    local cmd = args[1]

    if not cmd or cmd == "" or cmd == "help" then
        self:Print(L["CMD_HELP"])
        self:Print("/ratoptions - Open GUI options panel")
        self:Print(L["CMD_TOGGLE"])
        self:Print(L["CMD_LOCK"])
        self:Print(L["CMD_RESET"])
        self:Print(L["CMD_DEBUG"])
        self:Print(L["CMD_TEST"])
        self:Print(L["CMD_ANCHOR"])
        self:Print(L["CMD_GROWTH"])
        self:Print(L["CMD_OFFSET"])
        self:Print(L["CMD_STATUS"])
        return
    end

    if cmd == "toggle" then
        if self.Icons then
            self.Icons:Toggle()
        end
        return
    end

    if cmd == "lock" then
        self.db.profile.showAnchors = not self.db.profile.showAnchors
        self.db.profile.lockPositions = not self.db.profile.showAnchors
        local state = self.db.profile.showAnchors and "unlocked/visible" or "locked/hidden"
        self:Print("Anchors: " .. state)
        if self.Anchors then
            self.Anchors:UpdateUnitAnchorsVisibility()
            self.Anchors:UpdateGroupAnchorsVisibility()
            self.Anchors:UpdateAnchorsLockState()
        end
        return
    end

    if cmd == "reset" then
        self:ResetAllPositions()
        self:Print("Positions reset to default")
        return
    end

    if cmd == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:Print("Debug mode: " .. (self.db.profile.debug and "ON" or "OFF"))
        return
    end

    if cmd == "test" then
        self.db.profile.testMode = not self.db.profile.testMode
        self:Print("Test mode: " .. (self.db.profile.testMode and "ON" or "OFF"))

        self:OnPartyChanged()
        return
    end

    if cmd == "anchor" then
        local point = args[2]
        if not point then
            self:Print("Current anchor: " .. self.db.profile.anchorPoint)
            self:Print("Usage: /rat anchor <TOPLEFT|TOPRIGHT|BOTTOMLEFT|BOTTOMRIGHT>")
            return
        end

        point = point:upper()
        if point == "TOPLEFT" or point == "TOPRIGHT" or point == "BOTTOMLEFT" or point == "BOTTOMRIGHT" then
            self.db.profile.anchorPoint = point
            self:Print("Anchor point set to: " .. point)
            if self.Icons then
                self.Icons:PositionAnchors()
            end
        else
            self:Print("Invalid anchor point. Use: TOPLEFT, TOPRIGHT, BOTTOMLEFT, or BOTTOMRIGHT")
        end
        return
    end

    if cmd == "growth" then
        local direction = args[2]
        if not direction then
            self:Print("Current growth: " .. self.db.profile.anchorGrowth)
            self:Print("Usage: /rat growth <RIGHT|LEFT|DOWN|UP>")
            return
        end

        direction = direction:upper()
        if direction == "RIGHT" or direction == "LEFT" or direction == "DOWN" or direction == "UP" then
            self.db.profile.anchorGrowth = direction
            self:Print("Growth direction set to: " .. direction)
            if self.Icons then
                self.Icons:RefreshAllDisplays()
            end
        else
            self:Print("Invalid direction. Use: RIGHT, LEFT, DOWN, or UP")
        end
        return
    end

    if cmd == "offset" then
        local x = tonumber(args[2])
        local y = tonumber(args[3])

        if not x or not y then
            self:Print(string.format("Current offset: X=%d, Y=%d",
                self.db.profile.anchorOffsetX, self.db.profile.anchorOffsetY))
            self:Print("Usage: /rat offset <x> <y>")
            return
        end

        self.db.profile.anchorOffsetX = x
        self.db.profile.anchorOffsetY = y
        self:Print(string.format("Offset set to: X=%d, Y=%d", x, y))
        if self.Icons then
            self.Icons:PositionAnchors()
        end
        return
    end

    if cmd == "status" then
        self:Print("=== RAT Status ===")
        local numParty = GetNumPartyMembers()
        local numRaid = GetNumRaidMembers()
        self:Print(string.format("Party members: %d, Raid members: %d", numParty, numRaid))
        if numRaid > 0 then
            self:Print("In RAID - party spells disabled")
        end
        self:Print(string.format("Anchor: %s, Growth: %s, Offset: %d,%d",
            self.db.profile.anchorPoint, self.db.profile.anchorGrowth,
            self.db.profile.anchorOffsetX, self.db.profile.anchorOffsetY))

        self:Print("ElvUI frames:")
        for i = 1, 5 do
            local frame = _G["ElvUF_PartyGroup1UnitButton" .. i]
            if frame and frame.unit then
                self:Print(string.format("  Button%d: %s", i, frame.unit))
            end
        end

        self:Print("Tracked anchors:")
        for i = 1, 5 do
            local anchor = self.State.partyAnchors[i]
            if anchor then
                local unit = self:GetUnitFromIndex(i)
                self:Print(string.format("  [%d] %s: class=%s, guid=%s",
                    i, unit or "?", anchor.class or "nil",
                    anchor.guid or "nil"))
            end
        end
        return
    end

    self:Print("Unknown command: " .. cmd)
    self:Print("Type /rat help for available commands")
end

--------------------------------------------------------------------------------
-- Profile Management
--------------------------------------------------------------------------------

function RAT:RefreshConfig()
    self:Print("Profile changed, reloading...")

    if self.State.isInitialized then
        if self.Icons then
            self.Icons:RefreshAllDisplays()
        end
    end
end

--- Get list of all available profiles
-- @return table Array of profile names
function RAT:GetProfiles()
    local profiles = {}
    for name in pairs(self.db:GetProfiles({})) do
        tinsert(profiles, name)
    end
    table.sort(profiles)
    return profiles
end

--- Get current profile name
-- @return string Current profile name
function RAT:GetCurrentProfile()
    return self.db:GetCurrentProfile()
end

--- Switch to a different profile
-- @param profileName string Name of profile to switch to
-- @return boolean Success status
function RAT:SetProfile(profileName)
    if type(profileName) ~= "string" or profileName == "" then
        self:PrintError("Invalid profile name")
        return false
    end

    self.db:SetProfile(profileName)
    self:Print(string.format(L["PROFILE_SWITCHED"], profileName))
    return true
end

--- Reset current profile to defaults
-- @return boolean Success status
function RAT:ResetProfile()
    self.db:ResetProfile()
    self:Print("Profile reset to defaults")
    self:RefreshConfig()
    return true
end

--------------------------------------------------------------------------------
-- Settings Helpers
--------------------------------------------------------------------------------

--- Get a saved setting
-- @param key string Setting key (supports dot notation)
-- @return any Setting value or nil
function RAT:GetSetting(key)
    local parts = {strsplit(".", key)}
    local current = self.db.profile

    for _, part in ipairs(parts) do
        if type(current) == "table" then
            current = current[part]
        else
            return nil
        end
    end

    return current
end

--- Set a saved setting
-- @param key string Setting key
-- @param value any Value to save
function RAT:SetSetting(key, value)
    local parts = {strsplit(".", key)}
    local current = self.db.profile

    for i = 1, #parts - 1 do
        if type(current[parts[i]]) ~= "table" then
            current[parts[i]] = {}
        end
        current = current[parts[i]]
    end

    current[parts[#parts]] = value
end

--- Save position for an anchor
-- @param index number Anchor index (1-5), maps to ElvUI button index
-- @param point string Anchor point
-- @param x number X offset
-- @param y number Y offset
function RAT:SavePosition(index, point, x, y)
    if not self.db.profile.positions[index] then
        self.db.profile.positions[index] = {}
    end

    self.db.profile.positions[index].point = point
    self.db.profile.positions[index].x = x
    self.db.profile.positions[index].y = y

    self:DebugPrint(string.format("Saved position for anchor %d: %s %.1f, %.1f", index, point, x, y))
end

--- Get saved position for an anchor
-- @param index number Anchor index (1-5), maps to ElvUI button index
-- @return table|nil Position data or nil if not saved
function RAT:GetPosition(index)
    return self.db.profile.positions[index]
end

