-- Modules/Factory/BarFactory.lua
-- Factory for creating interrupt bar frames

local RAT = _G.RAT
RAT.BarFactory = {}

local BarFactory = RAT.BarFactory
local Constants = RAT.Constants

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local BAR_BG_COLOR = {0.1, 0.1, 0.1, 0.8}
local BAR_TEXT_COLOR = {1.0, 1.0, 1.0, 1.0}

local BAR_TEXTURES = {
    Blizzard = "Interface\\TargetingFrame\\UI-StatusBar",
    Smooth = "Interface\\Buttons\\WHITE8X8",
    Gradient = "Interface\\Tooltips\\UI-Tooltip-Background",
}

--------------------------------------------------------------------------------
-- Bar Frame Creation
--------------------------------------------------------------------------------

--- Create a new interrupt bar frame with icon, text, and progress indicators
-- @param barWidth number Bar width (default from settings)
-- @param barHeight number Bar height (default from settings)
-- @param textureName string Texture name ("Blizzard", "Smooth", "Gradient")
-- @return frame Bar frame
function BarFactory:CreateBarFrame(barWidth, barHeight, textureName)
    -- Use settings or defaults
    barWidth = barWidth or (RAT.db and RAT.db.profile.interruptBars.barWidth) or 200
    barHeight = barHeight or (RAT.db and RAT.db.profile.interruptBars.barHeight) or 20
    textureName = textureName or (RAT.db and RAT.db.profile.interruptBars.barTexture) or "Blizzard"

    local texturePath = BAR_TEXTURES[textureName] or BAR_TEXTURES.Blizzard

    local bar = CreateFrame("Frame", nil, UIParent)
    bar:SetWidth(barWidth)
    bar:SetHeight(barHeight)
    bar:SetFrameStrata("LOW")

    local border = bar:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetVertexColor(unpack(Constants.BORDER_COLOR))
    bar.border = border

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    bg:SetVertexColor(unpack(BAR_BG_COLOR))
    bar.bg = bg

    local fg = bar:CreateTexture(nil, "ARTWORK")
    fg:SetTexture(texturePath)
    fg:SetPoint("LEFT")
    fg:SetWidth(barWidth)
    fg:SetHeight(barHeight)
    bar.fg = fg

    local iconSize = barHeight
    local icon = bar:CreateTexture(nil, "OVERLAY")
    icon:SetWidth(iconSize)
    icon:SetHeight(iconSize)
    icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    bar.icon = icon

    local unitText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    unitText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    unitText:SetJustifyH("LEFT")
    unitText:SetTextColor(unpack(BAR_TEXT_COLOR))
    bar.unitText = unitText

    local cdText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cdText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    cdText:SetJustifyH("RIGHT")
    cdText:SetTextColor(unpack(BAR_TEXT_COLOR))
    bar.cdText = cdText

    return bar
end

--- Update bar dimensions (when settings change)
-- @param bar frame Bar frame
-- @param barWidth number New width
-- @param barHeight number New height
function BarFactory:UpdateBarDimensions(bar, barWidth, barHeight)
    if not bar then return end

    bar:SetWidth(barWidth)
    bar:SetHeight(barHeight)

    if bar.fg then
        bar.fg:SetWidth(barWidth)
        bar.fg:SetHeight(barHeight)
    end

    if bar.icon then
        local iconSize = barHeight
        bar.icon:SetWidth(iconSize)
        bar.icon:SetHeight(iconSize)
    end
end

--- Update bar texture (when settings change)
-- @param bar frame Bar frame
-- @param textureName string Texture name
function BarFactory:UpdateBarTexture(bar, textureName)
    if not bar or not bar.fg then return end

    local texturePath = BAR_TEXTURES[textureName] or BAR_TEXTURES.Blizzard
    bar.fg:SetTexture(texturePath)
end
