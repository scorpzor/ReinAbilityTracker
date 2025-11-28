-- Modules/Display/AnchorDisplay.lua
-- Manages anchor frames for both unit anchors (1-5) and group anchors (cc, interrupt, external)

local RAT = _G.RAT
RAT.AnchorDisplay = {}

local AnchorDisplay = RAT.AnchorDisplay

local anchorFrames = {}
local groupAnchors = {}

function AnchorDisplay:Initialize()
    self:CreateAnchors()
    self:CreateGroupAnchors()
end

--------------------------------------------------------------------------------
-- Unit Anchor Management (1-5)
--------------------------------------------------------------------------------

function AnchorDisplay:CreateAnchors()
    for i = 1, 5 do
        if not anchorFrames[i] then
            anchorFrames[i] = RAT.AnchorFactory:CreateUnitAnchor(i, function()
                Anchors:SaveAnchorPosition(i)
            end)
        end
    end

    -- Position anchors immediately for initial visibility OnPartyChanged will reposition them with proper frame detection
    self:PositionAnchors()

    self:UpdateAnchorsLockState()
    self:UpdateUnitAnchorsVisibility()
end

function AnchorDisplay:PositionAnchors()
    for i = 1, 5 do
        local anchor = anchorFrames[i]
        if anchor then
            local savedPos = RAT:GetPosition(i)

            if savedPos then
                anchor:ClearAllPoints()
                anchor:SetPoint(savedPos.point or "TOPLEFT", UIParent, "TOPLEFT", savedPos.x or 0, savedPos.y or 0)
            else
                anchor:ClearAllPoints()

                local targetUnit = RAT:GetUnitFromIndex(i)
                if not targetUnit then
                    local defaultY = -250 - (i - 1) * 110
                    anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, defaultY)
                else
                    local elvuiFrame = nil
                    for buttonIndex = 1, 5 do
                        local frame = _G["ElvUF_PartyGroup1UnitButton" .. buttonIndex]
                        if frame and frame.unit then
                            if frame.unit == targetUnit then
                                elvuiFrame = frame
                                RAT:DebugPrint(string.format("Found ElvUI Button%d for %s (our index %d)",
                                    buttonIndex, targetUnit, i))
                                break
                            end
                        end
                    end

                    if elvuiFrame then
                        local anchorPoint = RAT.db.profile.anchorPoint or "TOPLEFT"
                        local offsetX = RAT.db.profile.anchorOffsetX or 0
                        local offsetY = RAT.db.profile.anchorOffsetY or 0

                        anchor:SetPoint(anchorPoint, elvuiFrame, anchorPoint, offsetX, offsetY)
                        RAT:DebugPrint(string.format("Anchored to %s at %s with offset %d,%d",
                            elvuiFrame:GetName(), anchorPoint, offsetX, offsetY))
                    else
                        local defaultY = -250 - (i - 1) * 110
                        anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, defaultY)
                        RAT:DebugPrint(string.format("No ElvUI frame found for %s (index %d), using default position",
                            targetUnit, i))
                    end
                end
            end
        end
    end
end

--- Save anchor position to database
-- @param index number Anchor index (1-5)
function AnchorDisplay:SaveAnchorPosition(index)
    local anchor = anchorFrames[index]
    if not anchor then return end

    local left = anchor:GetLeft()
    local top = anchor:GetTop()

    if not left or not top then
        RAT:DebugPrint(string.format("Warning: Could not get position for anchor %d", index))
        return
    end

    local x = left
    local y = top - GetScreenHeight()

    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)

    RAT:SavePosition(index, "TOPLEFT", x, y)
    RAT:DebugPrint(string.format("Saved position for anchor %d: TOPLEFT %.1f, %.1f", index, x, y))
end

function AnchorDisplay:ResetPositions()
    RAT:ResetAllPositions()
end

function AnchorDisplay:UpdateAnchorsLockState()
    local locked = RAT.db.profile.lockPositions

    for i = 1, 5 do
        local anchor = anchorFrames[i]
        if anchor then
            if locked then
                anchor:EnableMouse(false)
            else
                anchor:EnableMouse(true)
            end
        end
    end
end

--- Get unit anchor frame
-- @param index number Anchor index (1-5)
-- @return frame|nil Anchor frame
function AnchorDisplay:GetAnchor(index)
    return anchorFrames[index]
end

--- Show unit anchor (respects showAnchors setting)
-- @param index number Anchor index (1-5)
function AnchorDisplay:ShowAnchor(index)
    if anchorFrames[index] then
        -- Only show if showAnchors setting is enabled
        if RAT.db.profile.showAnchors then
            anchorFrames[index]:Show()
        end
    end
end

--- Hide unit anchor
-- @param index number Anchor index (1-5)
function AnchorDisplay:HideAnchor(index)
    if anchorFrames[index] then
        anchorFrames[index]:Hide()
    end
end

--------------------------------------------------------------------------------
-- Group Anchor Management
--------------------------------------------------------------------------------

function AnchorDisplay:CreateGroupAnchors()
    local groupTypes = RAT.Constants.GROUP_TYPES

    for _, groupType in ipairs(groupTypes) do
        if not groupAnchors[groupType] then
            groupAnchors[groupType] = RAT.AnchorFactory:CreateGroupAnchor(groupType, function()
                Anchors:SaveGroupAnchorPosition(groupType)
            end)
        end
    end

    self:PositionGroupAnchors()

    self:UpdateGroupAnchorsVisibility()
end

function AnchorDisplay:PositionGroupAnchors()
    local groupTypes = RAT.Constants.GROUP_TYPES
    local defaultY = -200

    for idx, groupType in ipairs(groupTypes) do
        local anchor = groupAnchors[groupType]
        if anchor then
            local savedPos = RAT.db.profile.groupAnchors.positions[groupType]

            if savedPos then
                anchor:ClearAllPoints()
                anchor:SetPoint(savedPos.point or "TOPLEFT", UIParent, "TOPLEFT", savedPos.x or 0, savedPos.y or 0)
            else
                anchor:ClearAllPoints()
                local yOffset = defaultY - ((idx - 1) * 120)
                anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, yOffset)
            end
        end
    end
end

--- Save group anchor position to database
-- @param groupType string Group type ("cc", "interrupt", "external")
function AnchorDisplay:SaveGroupAnchorPosition(groupType)
    local anchor = groupAnchors[groupType]
    if not anchor then return end

    local left = anchor:GetLeft()
    local top = anchor:GetTop()

    if not left or not top then
        RAT:DebugPrint(string.format("Warning: Could not get position for group anchor '%s'", groupType))
        return
    end

    local x = left
    local y = top - GetScreenHeight()

    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)

    if not RAT.db.profile.groupAnchors.positions[groupType] then
        RAT.db.profile.groupAnchors.positions[groupType] = {}
    end

    RAT.db.profile.groupAnchors.positions[groupType].point = "TOPLEFT"
    RAT.db.profile.groupAnchors.positions[groupType].x = x
    RAT.db.profile.groupAnchors.positions[groupType].y = y

    RAT:DebugPrint(string.format("Saved position for group anchor '%s': TOPLEFT %.1f, %.1f", groupType, x, y))
end

function AnchorDisplay:UpdateGroupAnchorsVisibility()
    if not RAT.db.profile.showAnchors then
        for _, anchor in pairs(groupAnchors) do
            anchor:Hide()
        end
        return
    end

    if groupAnchors.cc then
        if RAT.db.profile.groupAnchors.showCC then
            groupAnchors.cc:Show()
        else
            groupAnchors.cc:Hide()
        end
    end

    if groupAnchors.interrupt then
        if RAT.db.profile.groupAnchors.showInterrupt then
            groupAnchors.interrupt:Show()
        else
            groupAnchors.interrupt:Hide()
        end
    end

    if groupAnchors.external then
        if RAT.db.profile.groupAnchors.showExternal then
            groupAnchors.external:Show()
        else
            groupAnchors.external:Hide()
        end
    end

    if groupAnchors.trinket then
        if RAT.db.profile.groupAnchors.showTrinket then
            groupAnchors.trinket:Show()
        else
            groupAnchors.trinket:Hide()
        end
    end
end

function AnchorDisplay:UpdateUnitAnchorsVisibility()
    if not RAT.db.profile.showAnchors then
        for i = 1, 5 do
            if anchorFrames[i] then
                anchorFrames[i]:Hide()
            end
        end
    else
        for i = 1, 5 do
            if anchorFrames[i] then
                anchorFrames[i]:Show()
            end
        end
    end
end

--- Get group anchor frame
-- @param groupType string Group type ("cc", "interrupt", "external")
-- @return frame|nil Anchor frame
function AnchorDisplay:GetGroupAnchor(groupType)
    return groupAnchors[groupType]
end

