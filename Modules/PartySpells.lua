-- Modules/PartySpells.lua
-- Handles spell icon display for individual party members (unit anchors 1-5)

local RAT = _G.RAT
RAT.PartySpells = {}

local PartySpells = RAT.PartySpells

function PartySpells:Initialize()
end

--- Update icons for a specific unit anchor
-- @param index number Anchor index (1-5)
function PartySpells:UpdateAnchorIcons(index)
    local anchor = RAT.Anchors:GetAnchor(index)
    if not anchor then return end

    if not RAT.db.profile.partySpells.enabled then
        self:HideAnchorIcons(index)
        return
    end

    if RAT.db.profile.partySpells.hideInRaid and RAT.Units:IsInRaid() then
        self:HideAnchorIcons(index)
        return
    end

    local partyData = RAT.State.partyAnchors[index]
    if not partyData then
        self:HideAnchorIcons(index)
        return
    end

    local guid = partyData.guid

    local spells = {}
    if RAT.Spells then
        spells = RAT.Spells:GetSpellsForGUID(guid)
    end

    local filteredSpells = {}
    for _, spellInfo in ipairs(spells) do
        if RAT.IconHelpers:IsSpellEnabledForGroup("party", spellInfo.name) then
            table.insert(filteredSpells, spellInfo)
        end
    end

    RAT:DebugPrint(string.format("PartySpells:UpdateAnchorIcons(%d) - Got %d spells for GUID %s (%d after filtering)",
        index, #spells, guid or "nil", #filteredSpells))

    self:UpdateAnchorIconDisplay(index, anchor, guid, filteredSpells)
end

--- Update icon display for an anchor
-- @param index number Anchor index (1-5)
-- @param anchor frame Anchor frame
-- @param guid string Player GUID
-- @param spells table Array of {name, cd, spellData, guid, unit} tables
function PartySpells:UpdateAnchorIconDisplay(index, anchor, guid, spells)
    local iconsPerRow = RAT.db.profile.partySpells.iconsPerRow
    local spacing = RAT.db.profile.partySpells.spacing
    local scale = RAT.db.profile.partySpells.scale

    local baseFrame = anchor
    local targetUnit = RAT:GetUnitFromIndex(index)

    if targetUnit then
        for buttonIndex = 1, 5 do
            local elvFrame = _G["ElvUF_PartyGroup1UnitButton" .. buttonIndex]
            if elvFrame and elvFrame.unit == targetUnit then
                baseFrame = elvFrame
                RAT:DebugPrint(string.format("Icons for %s will anchor to ElvUI Button%d", targetUnit, buttonIndex))
                break
            end
        end
    end

    if not anchor.icons then
        anchor.icons = {}
    end

    local spellListChanged = RAT.IconHelpers:HasSpellListChanged(anchor, spells, false)

    if spellListChanged then
        RAT:DebugPrint(string.format("Spell list changed for anchor %d - recreating icons", index))
        RAT.IconHelpers:ReleaseAllIcons(anchor)
    else
        RAT.IconHelpers:UpdateIconsCooldownState(anchor, spells, function(spellInfo)
            return guid
        end)
        return
    end

    local growth = RAT.db.profile.anchorGrowth or "RIGHT"
    local offsetX = RAT.db.profile.anchorOffsetX or 0
    local offsetY = RAT.db.profile.anchorOffsetY or 0

    for i, spellInfo in ipairs(spells) do
        local icon = RAT.Icons:AcquireIcon()

        icon.spellName = spellInfo.name
        icon.spellID = spellInfo.spellData.id
        icon.buffDuration = spellInfo.spellData.duration
        icon.guid = guid
        icon.anchorIndex = index

        RAT.IconHelpers:SetSpellTexture(icon, spellInfo.name, spellInfo.spellData)

        if i == 1 then
            local firstPoint, firstRelPoint, firstX, firstY =
                RAT.IconHelpers:CalculateFirstIconPosition(growth, offsetX, offsetY)

            icon:SetPoint(firstPoint, baseFrame, firstRelPoint, firstX, firstY)
        else
            local point, relPoint, xOff, yOff, isNewRow =
                RAT.IconHelpers:CalculateIconPosition(i, growth, iconsPerRow, spacing)

            if isNewRow then
                local prevRowIcon = anchor.icons[i - iconsPerRow]
                icon:SetPoint(point, prevRowIcon, relPoint, xOff, yOff)
            else
                local prevIcon = anchor.icons[i - 1]
                icon:SetPoint(point, prevIcon, relPoint, xOff, yOff)
            end
        end

        icon:SetScale(scale)

        RAT.IconHelpers:ApplyCooldownState(icon, guid, spellInfo.name,
            function(obj, start, dur) RAT.Icons:StartIconCooldown(obj, start, dur) end,
            function(obj) RAT.Icons:SetIconReady(obj) end
        )

        icon:Show()

        table.insert(anchor.icons, icon)
    end
end

--- Hide icons for a specific anchor
-- @param index number Anchor index (1-5)
function PartySpells:HideAnchorIcons(index)
    local anchor = RAT.Anchors:GetAnchor(index)
    if not anchor then return end

    RAT.IconHelpers:ReleaseAllIcons(anchor)
end

