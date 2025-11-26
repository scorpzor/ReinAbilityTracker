-- Modules/IconHelpers.lua
-- Helper functions for icon positioning and management (DRY principle)

local RAT = _G.RAT
RAT.IconHelpers = {}

local IconHelpers = RAT.IconHelpers

--------------------------------------------------------------------------------
-- Icon Positioning Helpers
--------------------------------------------------------------------------------

--- Calculate position for an icon based on index and growth direction
-- @param index number Icon index (1-based)
-- @param growth string Growth direction ("RIGHT", "LEFT", "DOWN", "UP")
-- @param iconsPerRow number Icons per row (0 = unlimited)
-- @param spacing number Spacing between icons
-- @return string point Point to anchor to
-- @return string relPoint Relative point on previous icon/anchor
-- @return number xOff X offset
-- @return number yOff Y offset
-- @return boolean isNewRow Whether this starts a new row
function IconHelpers:CalculateIconPosition(index, growth, iconsPerRow, spacing)
    if index == 1 then
        local firstPoint, firstRelPoint, firstX, firstY

        if growth == "RIGHT" then
            firstPoint, firstRelPoint = "LEFT", "RIGHT"
            firstX, firstY = 0, 0
        elseif growth == "LEFT" then
            firstPoint, firstRelPoint = "RIGHT", "LEFT"
            firstX, firstY = 0, 0
        elseif growth == "DOWN" then
            firstPoint, firstRelPoint = "TOP", "BOTTOM"
            firstX, firstY = 0, 0
        elseif growth == "UP" then
            firstPoint, firstRelPoint = "BOTTOM", "TOP"
            firstX, firstY = 0, 0
        else
            firstPoint, firstRelPoint = "LEFT", "RIGHT"
            firstX, firstY = 0, 0
        end

        return firstPoint, firstRelPoint, firstX, firstY, false
    elseif iconsPerRow > 0 and (index - 1) % iconsPerRow == 0 then
        local rowPoint, rowRelPoint, xOff, yOff

        if growth == "RIGHT" or growth == "LEFT" then
            rowPoint, rowRelPoint, xOff, yOff = "TOP", "BOTTOM", 0, -spacing
        else
            rowPoint, rowRelPoint, xOff, yOff = "LEFT", "RIGHT", spacing, 0
        end

        return rowPoint, rowRelPoint, xOff, yOff, true
    else
        local sameRowPoint, sameRowRelPoint, xOff, yOff

        if growth == "RIGHT" then
            sameRowPoint, sameRowRelPoint, xOff, yOff = "LEFT", "RIGHT", spacing, 0
        elseif growth == "LEFT" then
            sameRowPoint, sameRowRelPoint, xOff, yOff = "RIGHT", "LEFT", -spacing, 0
        elseif growth == "DOWN" then
            sameRowPoint, sameRowRelPoint, xOff, yOff = "TOP", "BOTTOM", 0, -spacing
        elseif growth == "UP" then
            sameRowPoint, sameRowRelPoint, xOff, yOff = "BOTTOM", "TOP", 0, spacing
        end

        return sameRowPoint, sameRowRelPoint, xOff, yOff, false
    end
end

--- Calculate first icon position with offsets (for party anchors)
-- @param growth string Growth direction
-- @param offsetX number X offset from anchor
-- @param offsetY number Y offset from anchor
-- @return string point Point to anchor to
-- @return string relPoint Relative point on anchor frame
-- @return number x X offset
-- @return number y Y offset
function IconHelpers:CalculateFirstIconPosition(growth, offsetX, offsetY)
    local firstPoint, firstRelPoint, firstX, firstY

    if growth == "RIGHT" then
        firstPoint, firstRelPoint = "LEFT", "RIGHT"
        firstX, firstY = offsetX, offsetY
    elseif growth == "LEFT" then
        firstPoint, firstRelPoint = "RIGHT", "LEFT"
        firstX, firstY = offsetX, offsetY
    elseif growth == "DOWN" then
        firstPoint, firstRelPoint = "TOP", "BOTTOM"
        firstX, firstY = offsetX, offsetY
    elseif growth == "UP" then
        firstPoint, firstRelPoint = "BOTTOM", "TOP"
        firstX, firstY = offsetX, offsetY
    else
        firstPoint, firstRelPoint = "LEFT", "RIGHT"
        firstX, firstY = offsetX, offsetY
    end

    return firstPoint, firstRelPoint, firstX, firstY
end

--------------------------------------------------------------------------------
-- Spell Collection Helpers
--------------------------------------------------------------------------------

--- Check if a spell is enabled in settings
-- @param category string Category name (class or race)
-- @param spellName string Spell name
-- @return boolean True if spell is enabled
function IconHelpers:IsSpellEnabled(category, spellName)
    if not RAT.db or not RAT.db.profile.enabledSpells then
        return true
    end

    local categorySpells = RAT.db.profile.enabledSpells[category]
    if not categorySpells then
        return true
    end

    if categorySpells[spellName] ~= nil then
        return categorySpells[spellName]
    end

    return true
end

--- Check if a spell is enabled for a specific display group
-- @param groupType string Group type ("party", "cc", "interrupt", "external", "trinket")
-- @param spellName string Spell name
-- @return boolean True if enabled for this group
function IconHelpers:IsSpellEnabledForGroup(groupType, spellName)
    if not RAT.db or not RAT.db.profile.spellGroupFilters then
        return true
    end

    local groupFilters = RAT.db.profile.spellGroupFilters[groupType]
    if not groupFilters then
        return true
    end

    if groupFilters[spellName] ~= nil then
        return groupFilters[spellName]
    end

    return true
end

--------------------------------------------------------------------------------
-- Icon Update Helpers
--------------------------------------------------------------------------------

--- Check if spell list has changed compared to existing icons
-- @param anchor table Anchor frame with .icons array
-- @param spells table New spell list array
-- @param checkGuid boolean If true, also compare icon.guid with spellInfo.guid
-- @return boolean True if spell list changed
function IconHelpers:HasSpellListChanged(anchor, spells, checkGuid)
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
function IconHelpers:UpdateIconsCooldownState(anchor, spells, guidResolver)
    if not anchor.icons then
        return false
    end

    for i, spellInfo in ipairs(spells) do
        local icon = anchor.icons[i]
        if icon then
            local guid = guidResolver and guidResolver(spellInfo) or spellInfo.guid
            local cdInfo = RAT.Tracker:GetCooldownInfo(guid, spellInfo.name)

            if cdInfo then
                if not icon.active then
                    RAT.Icons:StartIconCooldown(icon, cdInfo.startTime, cdInfo.duration)
                end
            else
                RAT.Icons:SetIconReady(icon)
            end
        end
    end

    return true
end

--- Release all icons from an anchor
-- @param anchor table Anchor frame with icons array
function IconHelpers:ReleaseAllIcons(anchor)
    if not anchor.icons then
        anchor.icons = {}
        return
    end

    for _, icon in ipairs(anchor.icons) do
        RAT.Icons:ReleaseIcon(icon)
    end
    anchor.icons = {}
end

--- Set texture for an icon or bar from spell data
-- @param iconOrBar table Icon frame or bar frame with .icon texture
-- @param spellName string Spell name
-- @param spellData table Spell data with .id field
-- @return boolean True if texture was set successfully
function IconHelpers:SetSpellTexture(iconOrBar, spellName, spellData)
    local texture = iconOrBar.texture or iconOrBar.icon
    if not texture then
        return false
    end

    -- Try cached spell icon first
    local spellIcon = RAT.Data:GetSpellIcon(spellName)
    if spellIcon then
        texture:SetTexture(spellIcon)
        return true
    end

    -- Fallback: direct lookup by spell ID
    if spellData and spellData.id then
        spellIcon = GetSpellTexture(spellData.id)
        if spellIcon then
            texture:SetTexture(spellIcon)
            return true
        end
    end

    -- Trinket fallback: use item icon if spell has no texture
    if spellData and spellData.category == "trinket" and spellData.itemID then
        spellIcon = GetItemIcon(spellData.itemID)
        if spellIcon then
            RAT:DebugPrint(string.format("Using item icon for trinket '%s' (itemID=%d)", spellName, spellData.itemID))
            texture:SetTexture(spellIcon)
            return true
        end
    end

    -- Fallback: question mark
    RAT:DebugPrint(string.format("Using question mark icon for spell '%s' (id=%s)", spellName, tostring(spellData and spellData.id)))
    texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    return false
end

--- Apply cooldown state to an icon or bar (generic helper)
-- @param object table Icon frame or bar frame with active/startTime/duration fields
-- @param guid string Unit GUID
-- @param spellName string Spell name
-- @param startMethod function Method to call for starting cooldown (receives object, startTime, duration)
-- @param readyMethod function Method to call for ready state (receives object)
function IconHelpers:ApplyCooldownState(object, guid, spellName, startMethod, readyMethod)
    local cdInfo = RAT.Tracker:GetCooldownInfo(guid, spellName)
    if cdInfo then
        object.active = true
        startMethod(object, cdInfo.startTime, cdInfo.duration)
    else
        object.active = false
        readyMethod(object)
    end
end

