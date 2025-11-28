-- Modules/Factory/IconFactory.lua
-- Factory for creating icon frames with cooldown displays and tooltips

local RAT = _G.RAT
RAT.IconFactory = {}

local IconFactory = RAT.IconFactory
local Constants = RAT.Constants

--------------------------------------------------------------------------------
-- Icon Frame Creation
--------------------------------------------------------------------------------

--- Create a new icon frame with texture, cooldown, text overlays, and tooltip support
-- @return frame Icon frame
function IconFactory:CreateIconFrame()
    local icon = CreateFrame("Frame", nil, UIParent)
    icon:SetWidth(Constants.ICON_SIZE)
    icon:SetHeight(Constants.ICON_SIZE)
    icon:SetFrameStrata("LOW")

    local texture = icon:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon.texture = texture

    local cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetReverse(false)
    cooldown:SetDrawEdge(true)
    cooldown:SetFrameStrata("LOW")
    icon.cooldown = cooldown

    local textFrame = CreateFrame("Frame", nil, icon)
    textFrame:SetAllPoints()
    textFrame:SetFrameStrata("LOW")
    textFrame:SetFrameLevel(icon:GetFrameLevel() + 2)
    icon.textFrame = textFrame

    local cooldownText = textFrame:CreateFontString(nil, "OVERLAY")
    cooldownText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    cooldownText:SetPoint("CENTER", 0, 0)
    cooldownText:SetTextColor(1, 1, 1, 1)
    cooldownText:Hide()
    icon.cooldownText = cooldownText

    local unitNameText = textFrame:CreateFontString(nil, "OVERLAY")
    unitNameText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    unitNameText:SetPoint("BOTTOM", icon, "BOTTOM", 0, 1)
    unitNameText:Hide()
    icon.unitNameText = unitNameText

    local backdrop = icon:CreateTexture(nil, "BORDER")
    backdrop:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    backdrop:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    backdrop:SetTexture("Interface\\Buttons\\WHITE8X8")
    backdrop:SetVertexColor(unpack(Constants.BORDER_COLOR))
    icon.backdrop = backdrop

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

    icon.buffHideTime = nil

    return icon
end

--------------------------------------------------------------------------------
-- Texture Loading
--------------------------------------------------------------------------------

--- Set texture for an icon from spell data
-- @param icon frame Icon frame
-- @param spellName string Spell name
-- @param spellData table Spell data with .id, .category, .itemID, .enchantID fields
-- @return boolean True if texture was set successfully
function IconFactory:SetIconTexture(icon, spellName, spellData)
    local texture = icon.texture
    if not texture then
        return false
    end

    -- Try cached spell icon first
    local spellIcon = RAT.Data:GetSpellIcon(spellName)
    if spellIcon then
        texture:SetTexture(spellIcon)
        return true
    end

    -- Fallback
    if spellData and spellData.id then
        spellIcon = GetSpellTexture(spellData.id)
        if spellIcon then
            texture:SetTexture(spellIcon)
            return true
        end
    end

    -- Trinket fallback
    if spellData and spellData.category == "trinket" and spellData.itemID then
        spellIcon = GetItemIcon(spellData.itemID)
        if spellIcon then
            RAT:DebugPrint(string.format("Using item icon for trinket '%s' (itemID=%d)", spellName, spellData.itemID))
            texture:SetTexture(spellIcon)
            return true
        end
    end

    -- Mystic enchant fallback
    if spellData and spellData.category == "mystic_enchant" and spellData.enchantID then
        spellIcon = GetSpellTexture(spellData.enchantID)
        if not spellIcon then
            local _, _, icon = GetSpellInfo(spellData.enchantID)
            spellIcon = icon
        end

        if spellIcon then
            RAT:DebugPrint(string.format("Using enchant ID icon for mystic enchant '%s' (enchantID=%d)", spellName, spellData.enchantID))
            texture:SetTexture(spellIcon)
            return true
        end
    end

    -- Fallback
    if spellData then
        RAT:DebugPrint(string.format("Using question mark icon for spell '%s' (id=%s, category=%s, enchantID=%s)",
            spellName, tostring(spellData.id), tostring(spellData.category), tostring(spellData.enchantID)))
    else
        RAT:DebugPrint(string.format("Using question mark icon for spell '%s' (spellData=nil)", spellName))
    end
    texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    return false
end
