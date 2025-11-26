-- Modules/Icons.lua
-- Coordinator module for icon display system

local RAT = _G.RAT
RAT.Icons = {}

local Icons = RAT.Icons

--------------------------------------------------------------------------------
-- Local State
--------------------------------------------------------------------------------

local iconPool = {}          -- Reusable icon frames
local borderPool = {}        -- Reusable border frames
local updateFrame = nil      -- OnUpdate frame for icon cooldown updates
local updateThrottle = 0     -- Throttle timer for OnUpdate (run every 0.1s instead of every frame)

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local ICON_SIZE = 30
local BORDER_COLOR = {0.45, 0, 1}

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function Icons:Initialize()

    -- Create update frame (only for inspection queue and icon updates)
    if not updateFrame then
        updateFrame = CreateFrame("Frame")
        updateFrame:SetScript("OnUpdate", function(self, elapsed)
            Icons:OnUpdate(elapsed)
        end)
        updateFrame:Show()
        RAT:DebugPrint("OnUpdate frame created and started")
    end

    if RAT.Anchors then
        RAT.Anchors:Initialize()
    end

    if RAT.PartySpells then
        RAT.PartySpells:Initialize()
    end

    if RAT.ExtraSpells then
        RAT.ExtraSpells:Initialize()
    end

    if RAT.InterruptBars then
        RAT.InterruptBars:Initialize()
    end
end

--------------------------------------------------------------------------------
-- Icon Pool Management
--------------------------------------------------------------------------------

--- Create a new icon frame
-- @return frame Icon frame
-- @return frame Border frame
function Icons:CreateIcon()
    local icon = CreateFrame("Frame", nil, UIParent)
    icon:SetWidth(ICON_SIZE)
    icon:SetHeight(ICON_SIZE)
    icon:SetFrameStrata("HIGH")

    local texture = icon:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon.texture = texture

    local cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetReverse(false)
    cooldown:SetDrawEdge(true)
    icon.cooldown = cooldown

    local textFrame = CreateFrame("Frame", nil, icon)
    textFrame:SetAllPoints()
    textFrame:SetFrameLevel(icon:GetFrameLevel() + 2)
    local cooldownText = textFrame:CreateFontString(nil, "OVERLAY")
    cooldownText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    cooldownText:SetPoint("CENTER", 0, 0)
    cooldownText:SetTextColor(1, 1, 1, 1)
    cooldownText:Hide()
    icon.cooldownText = cooldownText
    icon.textFrame = textFrame

    -- Unit name label
    local unitNameText = textFrame:CreateFontString(nil, "OVERLAY")
    unitNameText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    unitNameText:SetPoint("BOTTOM", icon, "BOTTOM", 0, 1)
    unitNameText:Hide()
    icon.unitNameText = unitNameText

    icon:EnableMouse(true)

    icon:SetScript("OnEnter", function(self)
        if RAT.db.profile.showTooltips and self.spellID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:Show()
        end
    end)

    icon:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local backdrop = icon:CreateTexture(nil, "BORDER")
    backdrop:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    backdrop:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    backdrop:SetTexture("Interface\\Buttons\\WHITE8X8")
    backdrop:SetVertexColor(0, 0, 0, 1)
    icon.backdrop = backdrop

    local borderFrame = CreateFrame("Frame", nil, UIParent)
    borderFrame:SetWidth(ICON_SIZE)
    borderFrame:SetHeight(ICON_SIZE)
    borderFrame:SetFrameLevel(icon:GetFrameLevel() + 1)

    local border = borderFrame:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints()
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetVertexColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3])
    border:Hide()
    borderFrame.border = border

    icon.borderFrame = borderFrame
    icon.borderHideTime = nil

    return icon, borderFrame
end

--- Get or create an icon from the pool
-- @return frame Icon frame
-- @return frame Border frame
function Icons:AcquireIcon()
    local icon, border

    if #iconPool > 0 then
        icon = table.remove(iconPool)
        border = table.remove(borderPool)
    else
        icon, border = self:CreateIcon()
    end

    icon:Show()
    return icon, border
end

--- Return an icon to the pool
-- @param icon frame Icon frame to release
function Icons:ReleaseIcon(icon)
    if not icon then return end

    icon:Hide()
    icon:ClearAllPoints()
    icon.spellName = nil
    icon.spellID = nil
    icon.guid = nil
    icon.active = nil
    icon.startTime = nil
    icon.duration = nil
    icon.borderHideTime = nil
    icon.anchorIndex = nil
    icon.groupType = nil

    if icon.borderFrame then
        icon.borderFrame:Hide()
        icon.borderFrame:ClearAllPoints()
        table.insert(borderPool, icon.borderFrame)
    end

    table.insert(iconPool, icon)
end

--------------------------------------------------------------------------------
-- Coordination Functions
--------------------------------------------------------------------------------

--- Refresh all displays (anchors, party icons, and group displays)
-- Called when party changes or settings change
function Icons:RefreshAllDisplays()
    if RAT.Anchors then
        RAT.Anchors:UpdateUnitAnchorsVisibility()
        RAT.Anchors:UpdateGroupAnchorsVisibility()
    end

    for i = 1, 5 do
        if RAT.State.partyAnchors[i] then
            if RAT.PartySpells then
                RAT.PartySpells:UpdateAnchorIcons(i)
            end
        else
            if RAT.PartySpells then
                RAT.PartySpells:HideAnchorIcons(i)
            end
        end
    end

    if RAT.ExtraSpells then
        RAT.ExtraSpells:UpdateExtraSpells()
    end
end

--- Update icons for a specific anchor
-- @param index number Anchor index (1-5)
function Icons:UpdateAnchorIcons(index)
    if RAT.PartySpells then
        RAT.PartySpells:UpdateAnchorIcons(index)
    end
end

--- Hide icons for a specific anchor
-- @param index number Anchor index (1-5)
function Icons:HideAnchorIcons(index)
    if RAT.PartySpells then
        RAT.PartySpells:HideAnchorIcons(index)
    end
end

--- Position anchors
function Icons:PositionAnchors()
    if RAT.Anchors then
        RAT.Anchors:PositionAnchors()
        RAT.Anchors:PositionGroupAnchors()
    end
end

--- Reset positions and refresh all displays
function Icons:ResetAndRefreshAll()
    if RAT.Anchors then
        RAT.Anchors:ResetPositions()
    end
    self:RefreshAllDisplays()
end

--- Hide all icons
function Icons:HideAll()
    for i = 1, 5 do
        self:HideAnchorIcons(i)
        RAT.Anchors:HideAnchor(i)
    end

    if RAT.ExtraSpells then
        RAT.ExtraSpells:HideGroupAnchorIcons("cc")
        RAT.ExtraSpells:HideGroupAnchorIcons("external")
    end

    if RAT.InterruptBars then
        RAT.InterruptBars:HideBars()
    end
end

--------------------------------------------------------------------------------
-- Cooldown Display
--------------------------------------------------------------------------------

--- Start cooldown animation on an icon
-- @param icon frame Icon frame
-- @param startTime number Cooldown start time (GetTime())
-- @param duration number Cooldown duration in seconds
function Icons:StartIconCooldown(icon, startTime, duration)
    if not icon or not icon.cooldown then return end

    icon.active = true
    icon.startTime = startTime
    icon.duration = duration

    icon.cooldown:SetCooldown(startTime, duration)

    icon.texture:SetDesaturated(true)

    if icon.borderFrame and icon.borderFrame.border then
        icon.borderFrame.border:Show()
        icon.borderHideTime = GetTime() + 0.8
    end
end

--- Set icon to ready state
-- @param icon frame Icon frame
function Icons:SetIconReady(icon)
    if not icon then return end

    icon.active = false
    icon.startTime = nil
    icon.duration = nil

    if icon.cooldown then
        icon.cooldown:SetCooldown(0, 0)
    end

    icon.texture:SetDesaturated(false)

    if icon.borderFrame and icon.borderFrame.border then
        icon.borderFrame.border:Hide()
    end
    icon.borderHideTime = nil
end

--- Stop all active cooldowns
function Icons:StopAllCooldowns()
    for i = 1, 5 do
        local anchor = RAT.Anchors:GetAnchor(i)
        if anchor and anchor.icons then
            for _, icon in ipairs(anchor.icons) do
                self:SetIconReady(icon)
            end
        end
    end

    local groupTypes = {"cc", "interrupt", "external"}
    for _, groupType in ipairs(groupTypes) do
        local anchor = RAT.Anchors:GetGroupAnchor(groupType)
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
function Icons:OnUpdate(elapsed)
    updateThrottle = updateThrottle + elapsed
    if updateThrottle < 0.1 then
        return
    end
    updateThrottle = 0

    local now = GetTime()

    for i = 1, 5 do
        local anchor = RAT.Anchors:GetAnchor(i)
        if anchor and anchor.icons then
            for _, icon in ipairs(anchor.icons) do
                self:UpdateIconState(icon, now)
            end
        end
    end

    local groupTypes = {"cc", "external", "trinket"}
    for _, groupType in ipairs(groupTypes) do
        local anchor = RAT.Anchors:GetGroupAnchor(groupType)
        if anchor and anchor.icons then
            for _, icon in ipairs(anchor.icons) do
                if icon:IsShown() then
                    self:UpdateIconState(icon, now)
                end
            end
        end
    end

    if RAT.InterruptBars then
        RAT.InterruptBars:UpdateAllBars()
    end
end

--- Update icon state (borders and cooldown expiration)
-- @param icon frame Icon frame
-- @param now number Current time
function Icons:UpdateIconState(icon, now)
    if icon.borderHideTime and now >= icon.borderHideTime then
        if icon.borderFrame and icon.borderFrame.border:IsShown() then
            icon.borderFrame.border:Hide()
        end
        icon.borderHideTime = nil
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
function Icons:FormatCooldownTime(seconds)
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

