-- Modules/Manager/IconManager.lua
-- Icon lifecycle, pool, and cooldown management

local RAT = _G.RAT
RAT.IconManager = {}

local IconManager = RAT.IconManager
local LibCustomGlow = LibStub("LibCustomGlow-1.0")

--------------------------------------------------------------------------------
-- Local State
--------------------------------------------------------------------------------

local iconPool = {}          -- Reusable icon frames
local borderPool = {}        -- Reusable border frames
local updateFrame = nil      -- OnUpdate frame for icon cooldown updates
local updateThrottle = 0     -- Throttle timer for OnUpdate (run every 0.1s instead of every frame)

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function IconManager:Initialize()
    if not updateFrame then
        updateFrame = CreateFrame("Frame")
        updateFrame:SetScript("OnUpdate", function(self, elapsed)
            IconManager:OnUpdate(elapsed)
        end)
        updateFrame:Show()
        RAT:DebugPrint("OnUpdate frame created and started")
    end

    if RAT.AnchorDisplay then
        RAT.AnchorDisplay:Initialize()
    end

    if RAT.PartySpellsDisplay then
        RAT.PartySpellsDisplay:Initialize()
    end

    if RAT.ExtraSpellsDisplay then
        RAT.ExtraSpellsDisplay:Initialize()
    end

    if RAT.InterruptBarDisplay then
        RAT.InterruptBarDisplay:Initialize()
    end
end

--------------------------------------------------------------------------------
-- Icon Pool Management
--------------------------------------------------------------------------------

--- Create a new icon frame
-- @return frame Icon frame
-- @return frame Border frame
function IconManager:CreateIcon()
    return RAT.IconFactory:CreateIconFrame(), nil
end

--- Get or create an icon from the pool
-- @return frame Icon frame
function IconManager:AcquireIcon()
    local icon

    if #iconPool > 0 then
        icon = table.remove(iconPool)
    else
        icon = self:CreateIcon()
    end

    icon:Show()
    return icon
end

--- Return an icon to the pool
-- @param icon frame Icon frame to release
function IconManager:ReleaseIcon(icon)
    if not icon then return end

    if LibCustomGlow then
        LibCustomGlow.PixelGlow_Stop(icon)
    end

    icon:Hide()
    icon:ClearAllPoints()
    icon.spellName = nil
    icon.spellID = nil
    icon.buffDuration = nil
    icon.guid = nil
    icon.active = nil
    icon.startTime = nil
    icon.duration = nil
    icon.buffHideTime = nil
    icon.anchorIndex = nil
    icon.groupType = nil

    if icon.unitNameText then
        icon.unitNameText:SetText("")
        icon.unitNameText:Hide()
    end

    table.insert(iconPool, icon)
end

--------------------------------------------------------------------------------
-- Coordination Functions
--------------------------------------------------------------------------------

--- Refresh all displays (anchors, party icons, and group displays)
-- Called when party changes or settings change
function IconManager:RefreshAllDisplays()
    if RAT.AnchorDisplay then
        RAT.AnchorDisplay:UpdateUnitAnchorsVisibility()
        RAT.AnchorDisplay:UpdateGroupAnchorsVisibility()
    end

    for i = 1, 5 do
        if RAT.State.partyAnchors[i] then
            if RAT.PartySpellsDisplay then
                RAT.PartySpellsDisplay:UpdateAnchorIcons(i)
            end
        else
            if RAT.PartySpellsDisplay then
                RAT.PartySpellsDisplay:HideAnchorIcons(i)
            end
        end
    end

    if RAT.ExtraSpellsDisplay then
        RAT.ExtraSpellsDisplay:UpdateExtraSpells()
    end
end

--- Update icons for a specific anchor
-- @param index number Anchor index (1-5)
function IconManager:UpdateAnchorIcons(index)
    if RAT.PartySpellsDisplay then
        RAT.PartySpellsDisplay:UpdateAnchorIcons(index)
    end
end

--- Hide icons for a specific anchor
-- @param index number Anchor index (1-5)
function IconManager:HideAnchorIcons(index)
    if RAT.PartySpellsDisplay then
        RAT.PartySpellsDisplay:HideAnchorIcons(index)
    end
end

--- Position anchors
function IconManager:PositionAnchors()
    if RAT.AnchorDisplay then
        RAT.AnchorDisplay:PositionAnchors()
        RAT.AnchorDisplay:PositionGroupAnchors()
    end
end

--- Reset positions and refresh all displays
function IconManager:ResetAndRefreshAll()
    if RAT.AnchorDisplay then
        RAT.AnchorDisplay:ResetPositions()
    end
    self:RefreshAllDisplays()
end

--- Hide all icons
function IconManager:HideAll()
    for i = 1, 5 do
        self:HideAnchorIcons(i)
        RAT.AnchorDisplay:HideAnchor(i)
    end

    if RAT.ExtraSpellsDisplay then
        RAT.ExtraSpellsDisplay:HideGroupAnchorIcons("cc")
        RAT.ExtraSpellsDisplay:HideGroupAnchorIcons("external")
    end

    if RAT.InterruptBarDisplay then
        RAT.InterruptBarDisplay:HideBars()
    end
end

--------------------------------------------------------------------------------
-- Cooldown Display
--------------------------------------------------------------------------------

--- Start cooldown animation on an icon
-- @param icon frame Icon frame
-- @param startTime number Cooldown start time (GetTime())
-- @param duration number Cooldown duration in seconds
function IconManager:StartIconCooldown(icon, startTime, duration)
    if not icon or not icon.cooldown then return end

    icon.active = true
    icon.startTime = startTime
    icon.duration = duration

    icon.cooldown:SetCooldown(startTime, duration)

    if LibCustomGlow and icon.buffDuration and icon.buffDuration > 0 then
        LibCustomGlow.PixelGlow_Start(icon, {1, 1, 1, 1}, 8, 0.25, nil, 2)
        icon.buffHideTime = GetTime() + icon.buffDuration
    else
        icon.texture:SetDesaturated(true)
        icon.buffHideTime = nil
    end
end

--- Set icon to ready state
-- @param icon frame Icon frame
function IconManager:SetIconReady(icon)
    if not icon then return end

    icon.active = false
    icon.startTime = nil
    icon.duration = nil

    if icon.cooldown then
        icon.cooldown:SetCooldown(0, 0)
    end

    icon.texture:SetDesaturated(false)

    if LibCustomGlow then
        LibCustomGlow.PixelGlow_Stop(icon)
    end
    icon.buffHideTime = nil
end

--- Stop all active cooldowns
function IconManager:StopAllCooldowns()
    for i = 1, 5 do
        local anchor = RAT.AnchorDisplay:GetAnchor(i)
        if anchor and anchor.icons then
            for _, icon in ipairs(anchor.icons) do
                self:SetIconReady(icon)
            end
        end
    end

    local groupTypes = {"cc", "interrupt", "external"}
    for _, groupType in ipairs(groupTypes) do
        local anchor = RAT.AnchorDisplay:GetGroupAnchor(groupType)
        if anchor and anchor.icons then
            for _, icon in ipairs(anchor.icons) do
                self:SetIconReady(icon)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- OnUpdate Handler
--------------------------------------------------------------------------------

--- OnUpdate handler for inspection queue and icon updates
-- @param elapsed number Time since last update
function IconManager:OnUpdate(elapsed)
    updateThrottle = updateThrottle + elapsed
    if updateThrottle < 0.1 then
        return
    end
    updateThrottle = 0

    local now = GetTime()

    for i = 1, 5 do
        local anchor = RAT.AnchorDisplay:GetAnchor(i)
        if anchor and anchor.icons then
            for _, icon in ipairs(anchor.icons) do
                self:UpdateIconState(icon, now)
            end
        end
    end

    local groupTypes = {"cc", "external", "trinket"}
    for _, groupType in ipairs(groupTypes) do
        local anchor = RAT.AnchorDisplay:GetGroupAnchor(groupType)
        if anchor and anchor.icons then
            for _, icon in ipairs(anchor.icons) do
                if icon:IsShown() then
                    self:UpdateIconState(icon, now)
                end
            end
        end
    end

    if RAT.InterruptBarDisplay then
        RAT.InterruptBarDisplay:UpdateAllBars()
    end
end

--- Update icon state (borders and cooldown expiration)
-- @param icon frame Icon frame
-- @param now number Current time
function IconManager:UpdateIconState(icon, now)
    if icon.buffHideTime and now >= icon.buffHideTime then
        if LibCustomGlow then
            LibCustomGlow.PixelGlow_Stop(icon)
        end
        icon.texture:SetDesaturated(true)
        icon.buffHideTime = nil
    end

    if icon.active and icon.startTime and icon.duration and icon.cooldownText then
        local remaining = (icon.startTime + icon.duration) - now
        if remaining > 0 then
            icon.cooldownText:SetText(self:FormatCooldownTime(remaining))
            if not icon.cooldownText:IsShown() then
                icon.cooldownText:Show()
            end
        else
            icon.cooldownText:Hide()
        end
    elseif icon.cooldownText and icon.cooldownText:IsShown() then
        icon.cooldownText:Hide()
    end

    if icon.active and icon.startTime and icon.duration then
        local endTime = icon.startTime + icon.duration
        if now >= endTime then
            self:SetIconReady(icon)
        end
    end
end

--- Format cooldown time for display
-- @param seconds number Remaining cooldown time in seconds
-- @return string Formatted time string
function IconManager:FormatCooldownTime(seconds)
    if seconds >= 600 then
        -- >= 10 minutes: show "10m" format
        return string.format("%dm", math.ceil(seconds / 60))
    elseif seconds >= 60 then
        -- 1-10 minutes: show "0:00" format
        local mins = math.floor(seconds / 60)
        local secs = math.ceil(seconds % 60)
        if secs == 60 then
            mins = mins + 1
            secs = 0
        end
        return string.format("%d:%02d", mins, secs)
    else
        -- < 1 minute: show "00" seconds format
        return string.format("%d", math.ceil(seconds))
    end
end

--------------------------------------------------------------------------------
-- Icon Lifecycle Helpers (moved from IconHelpers.lua)
--------------------------------------------------------------------------------

--- Check if spell list has changed compared to existing icons
-- @param anchor table Anchor frame with .icons array
-- @param spells table New spell list array
-- @param checkGuid boolean If true, also compare icon.guid with spellInfo.guid
-- @return boolean True if spell list changed
function IconManager:HasSpellListChanged(anchor, spells, checkGuid)
    if not anchor.icons or #anchor.icons ~= #spells then
        return true
    end

    for i, spellInfo in ipairs(spells) do
        local icon = anchor.icons[i]
        if not icon or icon.spellName ~= spellInfo.name then
            return true
        end
        if checkGuid and icon.guid ~= spellInfo.guid then
            return true
        end
    end

    return false
end

--- Update cooldown states for icons in-place (without recreation)
-- @param anchor table Anchor frame with .icons array
-- @param spells table Spell list array
-- @param guidResolver function Optional function(spellInfo) -> guid; if nil, uses spellInfo.guid
-- @return boolean True if update was performed
function IconManager:UpdateIconsCooldownState(anchor, spells, guidResolver)
    if not anchor.icons then
        return false
    end

    for i, spellInfo in ipairs(spells) do
        local icon = anchor.icons[i]
        if icon then
            local guid = guidResolver and guidResolver(spellInfo) or spellInfo.guid
            local cdInfo = RAT.TrackerManager:GetCooldownInfo(guid, spellInfo.name)

            if cdInfo then
                if not icon.active then
                    self:StartIconCooldown(icon, cdInfo.startTime, cdInfo.duration)
                end
            else
                self:SetIconReady(icon)
            end
        end
    end

    return true
end

--- Release all icons from an anchor
-- @param anchor table Anchor frame with icons array
function IconManager:ReleaseAllIcons(anchor)
    if not anchor.icons then
        anchor.icons = {}
        return
    end

    for _, icon in ipairs(anchor.icons) do
        self:ReleaseIcon(icon)
    end
    anchor.icons = {}
end

--- Apply cooldown state to an icon or bar (generic helper)
-- @param object table Icon frame or bar frame with active/startTime/duration fields
-- @param guid string Unit GUID
-- @param spellName string Spell name
-- @param startMethod function Method to call for starting cooldown (receives object, startTime, duration)
-- @param readyMethod function Method to call for ready state (receives object)
function IconManager:ApplyCooldownState(object, guid, spellName, startMethod, readyMethod)
    local cdInfo = RAT.TrackerManager:GetCooldownInfo(guid, spellName)
    if cdInfo then
        object.active = true
        startMethod(object, cdInfo.startTime, cdInfo.duration)
    else
        object.active = false
        readyMethod(object)
    end
end

