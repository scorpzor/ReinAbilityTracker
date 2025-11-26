-- Core/Init.lua
-- Addon initialization with Ace3 framework

local ADDON_NAME = "ReinAbilityTracker"
local RAT = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

_G.RAT = RAT

RAT.Version = GetAddOnMetadata(ADDON_NAME, "Version") or "0.1.0"
RAT.AddonName = ADDON_NAME
RAT.Debug = false

--------------------------------------------------------------------------------
-- Runtime State Management
--------------------------------------------------------------------------------

RAT.State = {
    isInitialized = false,           -- Whether addon has finished loading
    partyAnchors = {},               -- Table of party anchors (1-5), indices map to party button indices, tracks any unit shown
    activeGUIDs = {},                -- Active cooldowns by GUID: [guid][spellName] = {startTime, cooldown}
    inspectedTalents = {},           -- Inspected talent data by GUID: [guid][spellName] = spellID
    inspectedTrinkets = {},          -- Inspected trinket data by GUID: [guid] = {{spellID, spellName, itemID, cooldown}, ...}
    inspectedMysticEnchants = {},    -- Inspected mystic enchant data by GUID: [guid] = {{spellID, spellName, cooldown}, ...}
    syncedPartyMembers = {},         -- Track which party members we've synced with via addon comm: [guid] = true
    pendingTimers = {},              -- Active timers for cancellation (race condition protection)
}

--------------------------------------------------------------------------------
-- Ace3 Lifecycle Callbacks
--------------------------------------------------------------------------------

function RAT:OnInitialize()
end

function RAT:OnEnable()
    if self.Data then
        self.Data:Initialize()
    end

    self:RegisterEvent("PARTY_MEMBERS_CHANGED", "OnPartyChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("PLAYER_LEAVING_WORLD", "OnPlayerLeavingWorld")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "OnTalentUpdate")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnSpellCastSucceeded")
    self:RegisterEvent("UNIT_INVENTORY_CHANGED", "OnInventoryChanged")

    if self.Units then
        self.Units:Initialize()
    end

    if self.Comm then
        self.Comm:Initialize()
    end

    if self.Inspection then
        self.Inspection:Initialize()
    end

    if self.Spells then
        self.Spells:Initialize()
    end

    if self.Icons then
        self.Icons:Initialize()
    end

    if self.Tracker then
        self.Tracker:Initialize()
    end

    self:SetupOptions()

    self.State.isInitialized = true

    if self.Inspection then
        self.Inspection:InspectPlayer()
    end

    self:OnPartyChanged()

    self:Print(string.format(L["ADDON_LOADED"], self.Version))
end

function RAT:OnDisable()
    if self.Icons then
        self.Icons:HideAll()
    end

    -- Clear state
    wipe(self.State.partyAnchors)
    wipe(self.State.activeGUIDs)
    wipe(self.State.inspectedTalents)
    wipe(self.State.inspectedTrinkets)
    wipe(self.State.inspectedMysticEnchants)
    wipe(self.State.syncedPartyMembers)

    self:CancelPendingTimers()
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

function RAT:OnPartyChanged()

    if not self.State.isInitialized then return end

    -- Update centralized unit tracking
    if self.Units then
        self.Units:Update()
    end

    -- Update spell cache for all tracked units
    if self.Spells then
        self.Spells:UpdateAllUnitSpells()
    end

    -- Check if we're in test mode
    local inTestMode = self.db.profile.testMode

    -- Check if we're in a raid group
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        if self.Icons then
            for i = 1, 5 do
                self.Icons:HideAnchorIcons(i)
            end
        end

        wipe(self.State.partyAnchors)

        if self.Icons then
            self.Icons:RefreshAllDisplays()
        end

        return
    end

    local numParty = GetNumPartyMembers()

    -- Hide all current icons before clearing anchors
    if self.Icons then
        for i = 1, 5 do
            self.Icons:HideAnchorIcons(i)
        end
    end

    wipe(self.State.partyAnchors)

    -- If not in a party and not in test mode, stop here
    if numParty == 0 and not inTestMode then
        if self.Icons then
            self.Icons:RefreshAllDisplays()
        end
        return
    end

    local unitsToTrack = {}

    -- Check ElvUI party frames
    for i = 1, 5 do
        local frame = _G["ElvUF_PartyGroup1UnitButton" .. i]
        if frame and frame.unit and UnitExists(frame.unit) then
            local unit = frame.unit
            -- Track whatever unit ElvUI is showing (player or party1-4)
            -- Use the ElvUI button index (i) directly as our anchor index
            table.insert(unitsToTrack, {unit = unit, index = i})
        end
    end

    -- If no ElvUI frames found, fallback
    if #unitsToTrack == 0 then
        if inTestMode then
            table.insert(unitsToTrack, {unit = "player", index = 1})
        else
            local numParty = GetNumPartyMembers()
            if numParty > 0 then
                for i = 1, numParty do
                    local unit = "party" .. i
                    if UnitExists(unit) then
                        table.insert(unitsToTrack, {unit = unit, index = i})
                    end
                end
            end
        end
    end

    for _, unitInfo in ipairs(unitsToTrack) do
        local unit = unitInfo.unit
        local index = unitInfo.index

        if not self.State.partyAnchors[index] then
            self.State.partyAnchors[index] = {}
        end

        local anchor = self.State.partyAnchors[index]
        anchor.guid = UnitGUID(unit)
        anchor.class = select(2, UnitClass(unit))
        anchor.race = select(2, UnitRace(unit))
    end

    -- ElvUI needs a moment to update its frames when party composition changes
    -- OmniCD uses 0.4s delay for this, which seems to work reliably
    self:ScheduleTimer("party_update_delay", 0.4, function()
        if RAT.Icons then
            RAT.Icons:PositionAnchors()
        end

        if RAT.Icons then
            RAT.Icons:RefreshAllDisplays()
        end

        -- Inspect self and request builds from party
        RAT:ScheduleTimer("party_comm_delay", 0.6, function()
            if RAT.Inspection then
                RAT.Inspection:InspectPlayer()
            end

            if RAT.Comm then
                RAT.Comm:RequestBuilds()
            end
        end)
    end)
end

function RAT:OnPlayerEnteringWorld()
    local instanceType = select(2, IsInInstance())
    if instanceType == "arena" then
        wipe(self.State.activeGUIDs)
        if self.Icons then
            self.Icons:StopAllCooldowns()
        end
    end

    if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then
        self:OnPartyChanged()
    end
end

function RAT:OnPlayerLeavingWorld()
    if self.Comm then
        self.Comm:SendDesync()
    end
end

function RAT:OnTalentUpdate()
    if not self.State.isInitialized then return end

    self:DebugPrint("Talent update detected, re-inspecting and broadcasting")

    if self.Inspection then
        self.Inspection:InspectPlayer()
    end

    self:ScheduleTimer("talent_update_broadcast", 0.5, function()
        if self.Comm then
            self.Comm:BroadcastBuild()
        end
    end)
end

function RAT:OnSpellCastSucceeded(event, unit, spellName)
    if not self.Units or not self.Units:GetUnitByID(unit) then
        return
    end

    self:DebugPrint(string.format("Spell cast: %s by %s", tostring(spellName), tostring(unit)))

    if self.Tracker then
        self.Tracker:OnAbilityUsed(unit, spellName)
    end
end

function RAT:OnInventoryChanged(event, unit)
    if not UnitIsUnit(unit, "player") then
        return
    end

    self:DebugPrint(string.format("Player inventory changed, debouncing..."))

    -- Debounce with 0.1s
    if not self.equipmentTimer then
        self.equipmentTimer = true
        self:ScheduleTimer("equipment_change_delay", 0.1, function()
            self.equipmentTimer = nil

            self:DebugPrint("Equipment change debounce complete, re-inspecting player")

            if self.Inspection then
                self.Inspection:InspectPlayer()
            end

            self:ScheduleTimer("equipment_change_broadcast", 0.3, function()
                if self.Comm then
                    self.Comm:BroadcastBuild()
                end
            end)
        end)
    end
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

--- Print message to chat with addon prefix
-- @param msg string Message to print
-- @param r number Red component (0-1, optional)
-- @param g number Green component (0-1, optional)
-- @param b number Blue component (0-1, optional)
function RAT:Print(msg, r, g, b)
    if msg then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFB3[RAT]|r " .. tostring(msg), r or 1, g or 1, b or 1)
    end
end

--- Print debug message to chat
-- @param msg string Debug message to print
function RAT:DebugPrint(msg)
    if self.db and self.db.profile.debug then
        self:Print("|cFF888888[DEBUG]|r " .. tostring(msg), 0.7, 0.7, 0.7)
    end
end

--- Print error message to chat
-- @param msg string Error message to print
function RAT:PrintError(msg)
    self:Print("|cFFFF0000[ERROR]|r " .. tostring(msg), 1, 0.3, 0.3)
end

--- Print warning message to chat
-- @param msg string Warning message to print
function RAT:PrintWarning(msg)
    self:Print("|cFFFFAA00[WARNING]|r " .. tostring(msg), 1, 0.7, 0)
end

--- Get anchor index from unit ID by looking up which anchor is tracking that unit
-- @param unit string Unit ID (e.g., "party1", "party2", "player")
-- @return number|nil Anchor index (1-5) or nil if unit not tracked
function RAT:GetIndexFromUnit(unit)
    if not unit then return nil end

    local guid = UnitGUID(unit)
    if not guid then return nil end

    for i = 1, 5 do
        local anchor = self.State.partyAnchors[i]
        if anchor and anchor.guid == guid then
            return i
        end
    end

    return nil
end

--- Get unit ID from anchor index by checking what unit we're currently tracking
-- @param index number Anchor index (1-5)
-- @return string|nil Unit ID (e.g., "party1", "player") or nil if invalid
function RAT:GetUnitFromIndex(index)
    if type(index) ~= "number" then
        return nil
    end

    local anchor = self.State.partyAnchors[index]
    if not anchor or not anchor.guid then
        return nil
    end

    if UnitGUID("player") == anchor.guid then
        return "player"
    end

    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and UnitGUID(unit) == anchor.guid then
            return unit
        end
    end

    return nil
end

--------------------------------------------------------------------------------
-- Timer Management
--------------------------------------------------------------------------------

--- Cancel all pending timers
function RAT:CancelPendingTimers()
    for timerKey, timerHandle in pairs(self.State.pendingTimers) do
        if timerHandle and timerHandle.SetScript then
            timerHandle:SetScript("OnUpdate", nil)
            timerHandle:Hide()
        end
        self.State.pendingTimers[timerKey] = nil
    end
end

--- Cancel a specific pending timer
-- @param timerKey string Identifier for the timer
function RAT:CancelTimer(timerKey)
    local timerHandle = self.State.pendingTimers[timerKey]
    if timerHandle and timerHandle.SetScript then
        timerHandle:SetScript("OnUpdate", nil)
        timerHandle:Hide()
    end
    self.State.pendingTimers[timerKey] = nil
end

--- Schedule a delayed function call
-- @param timerKey string Identifier for the timer (existing timers with same key will be cancelled)
-- @param delay number Delay in seconds
-- @param func function Function to call after delay
-- @return frame Timer handle
function RAT:ScheduleTimer(timerKey, delay, func)
    if timerKey then
        self:CancelTimer(timerKey)
    end

    local timerFrame = CreateFrame("Frame")
    local elapsed = 0

    timerFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            RAT.State.pendingTimers[timerKey] = nil
            func()
        end
    end)

    if timerKey then
        self.State.pendingTimers[timerKey] = timerFrame
    end

    return timerFrame
end

