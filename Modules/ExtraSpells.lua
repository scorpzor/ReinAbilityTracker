-- Modules/ExtraSpells.lua
-- Handles extra spell icon displays (categorized by type: cc, interrupt, external, trinket)
-- These are shown on separate "group anchors" independent of per-unit displays

local RAT = _G.RAT
RAT.ExtraSpells = {}

local ExtraSpells = RAT.ExtraSpells

function ExtraSpells:Initialize()
end

--------------------------------------------------------------------------------
-- Icon Updates
--------------------------------------------------------------------------------

function ExtraSpells:UpdateExtraSpells()
    RAT.Anchors:UpdateGroupAnchorsVisibility()

    local groupedSpells = {}
    if RAT.Spells then
        groupedSpells = RAT.Spells:GetGroupedSpells()
    end

    for groupType, spells in pairs(groupedSpells) do
        local anchor = RAT.Anchors:GetGroupAnchor(groupType)
        if anchor and (groupType == "cc" and RAT.db.profile.groupAnchors.showCC or
                      groupType == "interrupt" and RAT.db.profile.groupAnchors.showInterrupt or
                      groupType == "external" and RAT.db.profile.groupAnchors.showExternal or
                      groupType == "trinket" and RAT.db.profile.groupAnchors.showTrinket) then

            local filteredSpells = {}
            for _, spellInfo in ipairs(spells) do
                if RAT.IconHelpers:IsSpellEnabledForGroup(groupType, spellInfo.name) then
                    table.insert(filteredSpells, spellInfo)
                end
            end

            if groupType == "interrupt" and RAT.InterruptBars then
                RAT.InterruptBars:UpdateBars(filteredSpells)
            else
                self:UpdateGroupAnchorIcons(groupType, filteredSpells)
            end
        end
    end
end

--- Update icons for an extra spell display anchor
-- @param groupType string Group type ("cc", "interrupt", "external", "trinket")
-- @param spells table Array of {name, cd, spellData, guid, unit} tables
function ExtraSpells:UpdateGroupAnchorIcons(groupType, spells)
    local anchor = RAT.Anchors:GetGroupAnchor(groupType)
    if not anchor then return end

    if not anchor.icons then
        anchor.icons = {}
    end

    local spellListChanged = RAT.IconHelpers:HasSpellListChanged(anchor, spells, true)

    -- If spell list changed, recreate icons
    if spellListChanged then
        RAT:DebugPrint(string.format("Spell list changed for %s group - recreating icons", groupType))
        RAT.IconHelpers:ReleaseAllIcons(anchor)
    else
        -- Spell list unchanged - just update cooldown states in-place
        RAT.IconHelpers:UpdateIconsCooldownState(anchor, spells, nil)
        return
    end

    local groupSettings
    if groupType == "cc" then
        groupSettings = RAT.db.profile.groupAnchors.cc
    elseif groupType == "external" then
        groupSettings = RAT.db.profile.groupAnchors.external
    elseif groupType == "trinket" then
        groupSettings = RAT.db.profile.groupAnchors.trinket
    else
        groupSettings = RAT.db.profile.partySpells
    end

    local iconsPerRow = groupSettings.iconsPerRow or 0
    local spacing = groupSettings.spacing or 2
    local scale = groupSettings.scale or 1.0
    local growth = groupSettings.growth or "RIGHT"

    for i, spellInfo in ipairs(spells) do
        local icon, border = RAT.Icons:AcquireIcon()

        icon.spellName = spellInfo.name
        icon.spellID = spellInfo.spellData.id
        icon.guid = spellInfo.guid
        icon.groupType = groupType

        -- Set unit name label
        if icon.unitNameText and spellInfo.unit then
            local unitName = UnitName(spellInfo.unit) or "?"
            if string.len(unitName) > 5 then
                unitName = string.sub(unitName, 1, 5)
            end

            local classColor = RAID_CLASS_COLORS[spellInfo.class]
            if classColor then
                icon.unitNameText:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
            else
                icon.unitNameText:SetTextColor(1, 1, 1, 1)
            end

            icon.unitNameText:SetText(unitName)
            icon.unitNameText:Show()
        elseif icon.unitNameText then
            icon.unitNameText:Hide()
        end

        RAT.IconHelpers:SetSpellTexture(icon, spellInfo.name, spellInfo.spellData)

        local point, relPoint, xOff, yOff, isNewRow =
            RAT.IconHelpers:CalculateIconPosition(i, growth, iconsPerRow, spacing)

        if i == 1 then
            icon:SetPoint(point, anchor, relPoint, xOff, yOff)
            border:SetPoint(point, anchor, relPoint, xOff, yOff)
        elseif isNewRow then
            local prevRowIcon = anchor.icons[i - iconsPerRow]
            icon:SetPoint(point, prevRowIcon, relPoint, xOff, yOff)
            border:SetPoint(point, prevRowIcon, relPoint, xOff, yOff)
        else
            local prevIcon = anchor.icons[i - 1]
            icon:SetPoint(point, prevIcon, relPoint, xOff, yOff)
            border:SetPoint(point, prevIcon, relPoint, xOff, yOff)
        end

        icon:SetScale(scale)
        border:SetScale(scale)

        RAT.IconHelpers:ApplyCooldownState(icon, spellInfo.guid, spellInfo.name,
            function(obj, start, dur) RAT.Icons:StartIconCooldown(obj, start, dur) end,
            function(obj) RAT.Icons:SetIconReady(obj) end
        )

        icon:Show()
        border:Show()

        table.insert(anchor.icons, icon)
    end
end

--- Hide icons for an extra spell display anchor
-- @param groupType string Group type
function ExtraSpells:HideGroupAnchorIcons(groupType)
    local anchor = RAT.Anchors:GetGroupAnchor(groupType)
    if not anchor then return end

    RAT.IconHelpers:ReleaseAllIcons(anchor)
end

--- Refresh cooldown display for a specific spell (without recreating icons)
-- @param guid string Player GUID whose spells to update
-- @param spellName string Spell name to update
function ExtraSpells:RefreshCooldownForSpell(guid, spellName)
    local groupTypes = {"cc", "external"}
    for _, groupType in ipairs(groupTypes) do
        local anchor = RAT.Anchors:GetGroupAnchor(groupType)
        if anchor and anchor.icons then
            for _, icon in ipairs(anchor.icons) do
                if icon.guid == guid and icon.spellName == spellName then
                    RAT.IconHelpers:ApplyCooldownState(icon, guid, spellName,
                        function(obj, start, dur) RAT.Icons:StartIconCooldown(obj, start, dur) end,
                        function(obj) RAT.Icons:SetIconReady(obj) end
                    )
                end
            end
        end
    end
end

