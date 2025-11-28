-- Modules/Factory/AnchorFactory.lua
-- Factory for creating anchor frames

local RAT = _G.RAT
RAT.AnchorFactory = {}

local AnchorFactory = RAT.AnchorFactory
local Constants = RAT.Constants

--------------------------------------------------------------------------------
-- Anchor Frame Creation
--------------------------------------------------------------------------------

--- Create a draggable anchor frame with border, background, and label
-- @param name string Unique frame name
-- @param width number Frame width
-- @param height number Frame height
-- @param labelText string Text to display in center
-- @param bgColor table Background color {r, g, b, a}
-- @param onDragStop function Callback when drag ends
-- @return frame Anchor frame
function AnchorFactory:CreateAnchorFrame(name, width, height, labelText, bgColor, onDragStop)
    local anchor = CreateFrame("Frame", name, UIParent)
    anchor:SetWidth(width)
    anchor:SetHeight(height)
    anchor:SetFrameStrata("MEDIUM")

    local border = anchor:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", anchor, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 1, -1)
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetVertexColor(unpack(Constants.BORDER_COLOR))
    anchor.border = border

    local bg = anchor:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    bg:SetVertexColor(unpack(bgColor))
    anchor.bg = bg

    local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText(labelText)
    anchor.label = label

    anchor:EnableMouse(true)
    anchor:SetMovable(true)
    anchor:RegisterForDrag("LeftButton")

    anchor:SetScript("OnDragStart", function(self)
        if not RAT.db.profile.lockPositions then
            self:StartMoving()
        end
    end)

    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if onDragStop then
            onDragStop(self)
        end
    end)

    return anchor
end

--- Create a unit anchor (party member anchor)
-- @param index number Anchor index (1-5)
-- @param onDragStop function Callback when drag ends
-- @return frame Unit anchor frame
function AnchorFactory:CreateUnitAnchor(index, onDragStop)
    return self:CreateAnchorFrame(
        "RATAnchor" .. index,
        Constants.ANCHOR_SIZE,
        Constants.ANCHOR_SIZE,
        tostring(index),
        Constants.ANCHOR_COLORS.UNIT,
        onDragStop
    )
end

--- Create a group anchor (cc, interrupt, external, trinket)
-- @param groupType string Group type
-- @param onDragStop function Callback when drag ends
-- @return frame Group anchor frame
function AnchorFactory:CreateGroupAnchor(groupType, onDragStop)
    local anchor = self:CreateAnchorFrame(
        "RATGroupAnchor_" .. groupType,
        20,
        20,
        groupType:upper():sub(1,1),
        Constants.ANCHOR_COLORS.GROUP,
        onDragStop
    )

    anchor.groupType = groupType
    return anchor
end
