-- Utils/PositioningHelpers.lua
-- Pure positioning calculation functions (extracted from IconHelpers.lua)

local RAT = _G.RAT
RAT.PositioningHelpers = {}

local PositioningHelpers = RAT.PositioningHelpers

--------------------------------------------------------------------------------
-- Icon Positioning Calculations
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
function PositioningHelpers:CalculateIconPosition(index, growth, iconsPerRow, spacing)
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
function PositioningHelpers:CalculateFirstIconPosition(growth, offsetX, offsetY)
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
