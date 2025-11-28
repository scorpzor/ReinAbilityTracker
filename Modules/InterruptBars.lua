-- Modules/InterruptBars.lua
-- Displays interrupt cooldowns as horizontal bars that grow upward from anchor

local RAT = _G.RAT
RAT.InterruptBars = {}

local InterruptBars = RAT.InterruptBars

local barPool = {}
local activeInterruptAnchor = nil

local BAR_SPACING = 2
local BAR_BG_COLOR = {0.1, 0.1, 0.1, 0.8}    -- Dark background
local BAR_COOLDOWN_ALPHA = 0.5               -- Alpha for cooldown state
local BAR_READY_ALPHA = 1.0                  -- Alpha for ready state
local BAR_TEXT_COLOR = {1.0, 1.0, 1.0, 1.0}  -- White text

local BAR_TEXTURES = {
    Blizzard = "Interface\\TargetingFrame\\UI-StatusBar",
    Smooth = "Interface\\Buttons\\WHITE8X8",
    Gradient = "Interface\\Tooltips\\UI-Tooltip-Background",
}

function InterruptBars:Initialize()
end

--- Create a new bar frame
-- @return frame Bar frame
function InterruptBars:CreateBar()
    local barWidth = RAT.db.profile.interruptBars.barWidth or 200
    local barHeight = RAT.db.profile.interruptBars.barHeight or 20
    local textureName = RAT.db.profile.interruptBars.barTexture or "Blizzard"
    local texturePath = BAR_TEXTURES[textureName] or BAR_TEXTURES.Blizzard

    local bar = CreateFrame("Frame", nil, UIParent)
    bar:SetWidth(barWidth)
    bar:SetHeight(barHeight)
    bar:SetFrameStrata("LOW")

    local border = bar:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetVertexColor(0, 0, 0, 1)  -- Black
    bar.border = border

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    bg:SetVertexColor(BAR_BG_COLOR[1], BAR_BG_COLOR[2], BAR_BG_COLOR[3], BAR_BG_COLOR[4])
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
    unitText:SetTextColor(BAR_TEXT_COLOR[1], BAR_TEXT_COLOR[2], BAR_TEXT_COLOR[3], BAR_TEXT_COLOR[4])
    bar.unitText = unitText

    local cdText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cdText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    cdText:SetJustifyH("RIGHT")
    cdText:SetTextColor(BAR_TEXT_COLOR[1], BAR_TEXT_COLOR[2], BAR_TEXT_COLOR[3], BAR_TEXT_COLOR[4])
    bar.cdText = cdText

    return bar
end

--- Get or create a bar from the pool
-- @return frame Bar frame
function InterruptBars:AcquireBar()
    local bar
    if #barPool > 0 then
        bar = table.remove(barPool)
    else
        bar = self:CreateBar()
    end
    bar:Show()
    return bar
end

--- Return a bar to the pool
-- @param bar frame Bar frame
function InterruptBars:ReleaseBar(bar)
    if not bar then return end

    bar:Hide()
    bar:ClearAllPoints()
    bar.spellName = nil
    bar.guid = nil
    bar.startTime = nil
    bar.duration = nil

    table.insert(barPool, bar)
end

--------------------------------------------------------------------------------
-- Bar Updates
--------------------------------------------------------------------------------

--- Update interrupt bars display
-- @param interruptSpells table Array of {name, cd, spellData, guid, unit} tables
function InterruptBars:UpdateBars(interruptSpells)
    local anchor = RAT.Anchors:GetGroupAnchor("interrupt")
    if not anchor then return end

    if RAT.db.profile.interruptBars.hideInRaid and RAT.Units:IsInRaid() then
        self:HideBars()
        return
    end

    activeInterruptAnchor = anchor

    if not anchor.bars then
        anchor.bars = {}
    end

    for _, bar in ipairs(anchor.bars) do
        self:ReleaseBar(bar)
    end
    anchor.bars = {}

    table.sort(interruptSpells, function(a, b)
        local aCdInfo = RAT.Tracker:GetCooldownInfo(a.guid, a.name)
        local bCdInfo = RAT.Tracker:GetCooldownInfo(b.guid, b.name)

        if aCdInfo and not bCdInfo then return false end
        if not aCdInfo and bCdInfo then return true end
        if aCdInfo and bCdInfo then
            local aRemaining = (aCdInfo.startTime + aCdInfo.duration) - GetTime()
            local bRemaining = (bCdInfo.startTime + bCdInfo.duration) - GetTime()
            return aRemaining < bRemaining
        end
        return a.name < b.name
    end)

    for i, spellInfo in ipairs(interruptSpells) do
        local bar = self:AcquireBar()

        bar.spellName = spellInfo.name
        bar.guid = spellInfo.guid
        bar.spellData = spellInfo.spellData

        local unitName = ""
        local classColor = nil
        if spellInfo.unit then
            unitName = UnitName(spellInfo.unit) or ""
        end

        if spellInfo.class and RAID_CLASS_COLORS[spellInfo.class] then
            local color = RAID_CLASS_COLORS[spellInfo.class]
            classColor = {color.r, color.g, color.b}
        end

        RAT.IconHelpers:SetSpellTexture(bar, spellInfo.name, spellInfo.spellData)

        bar.unitText:SetText(unitName)

        bar:ClearAllPoints()
        if i == 1 then
            bar:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 0)
        else
            local prevBar = anchor.bars[i - 1]
            bar:SetPoint("BOTTOMLEFT", prevBar, "TOPLEFT", 0, BAR_SPACING)
        end

        bar.classColor = classColor

        local self = InterruptBars
        RAT.IconHelpers:ApplyCooldownState(bar, spellInfo.guid, spellInfo.name,
            function(obj, start, dur)
                obj.startTime = start
                obj.duration = dur
                self:UpdateBarCooldown(obj)
            end,
            function(obj)
                self:SetBarReady(obj)
            end
        )

        table.insert(anchor.bars, bar)
    end
end

--- Update cooldown state for a specific spell (without rebuilding all bars)
-- @param guid string Player GUID
-- @param spellName string Spell name
-- @return boolean True if bar was found and updated
function InterruptBars:UpdateBarCooldownState(guid, spellName)
    local anchor = RAT.Anchors:GetGroupAnchor("interrupt")
    if not anchor or not anchor.bars then return false end

    for _, bar in ipairs(anchor.bars) do
        if bar.guid == guid and bar.spellName == spellName then
            local self = InterruptBars
            RAT.IconHelpers:ApplyCooldownState(bar, guid, spellName,
                function(obj, start, dur)
                    obj.startTime = start
                    obj.duration = dur
                    self:UpdateBarCooldown(obj)
                end,
                function(obj)
                    self:SetBarReady(obj)
                end
            )
            return true
        end
    end

    return false
end

--- Update bar appearance for cooldown state
-- @param bar frame Bar frame
function InterruptBars:UpdateBarCooldown(bar)
    if not bar.startTime or not bar.duration then
        self:SetBarReady(bar)
        return
    end

    local now = GetTime()
    local elapsed = now - bar.startTime
    local remaining = bar.duration - elapsed

    if remaining <= 0 then
        self:SetBarReady(bar)
        return
    end

    local fillDirection = RAT.db.profile.interruptBars.fillDirection or "LEFT_TO_RIGHT"

    local progress
    if fillDirection == "RIGHT_TO_LEFT" then
        progress = 1 - (elapsed / bar.duration)
    else
        progress = elapsed / bar.duration
    end

    local barWidth = bar:GetWidth()
    bar.fg:SetWidth(barWidth * progress)

    if bar.classColor then
        bar.fg:SetVertexColor(bar.classColor[1], bar.classColor[2], bar.classColor[3], BAR_COOLDOWN_ALPHA)
    else
        bar.fg:SetVertexColor(0.6, 0.6, 0.6, BAR_COOLDOWN_ALPHA)
    end

    if remaining >= 60 then
        bar.cdText:SetText(string.format("%.1fm", remaining / 60))
    else
        bar.cdText:SetText(string.format("%.0fs", remaining))
    end
    bar.cdText:Show()
end

--- Set bar to ready state (full, no cooldown)
-- @param bar frame Bar frame
function InterruptBars:SetBarReady(bar)
    bar.startTime = nil
    bar.duration = nil

    local barWidth = bar:GetWidth()
    bar.fg:SetWidth(barWidth)
    if bar.classColor then
        bar.fg:SetVertexColor(bar.classColor[1], bar.classColor[2], bar.classColor[3], BAR_READY_ALPHA)
    else
        bar.fg:SetVertexColor(0.2, 1.0, 0.2, BAR_READY_ALPHA)
    end

    bar.cdText:SetText("READY")
    bar.cdText:Show()
end

--- Update all active bars
function InterruptBars:UpdateAllBars()
    local anchor = RAT.Anchors:GetGroupAnchor("interrupt")
    if not anchor or not anchor.bars then return end

    for _, bar in ipairs(anchor.bars) do
        if bar.startTime and bar.duration then
            self:UpdateBarCooldown(bar)
        end
    end
end

function InterruptBars:HideBars()
    local anchor = RAT.Anchors:GetGroupAnchor("interrupt")
    if not anchor or not anchor.bars then return end

    for _, bar in ipairs(anchor.bars) do
        self:ReleaseBar(bar)
    end
    anchor.bars = {}
end

