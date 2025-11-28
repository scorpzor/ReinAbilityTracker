-- Modules/Display/InterruptBarDisplay.lua
-- Displays interrupt cooldowns as horizontal bars that grow upward from anchor

local RAT = _G.RAT
RAT.InterruptBarDisplay = {}

local InterruptBarDisplay = RAT.InterruptBarDisplay
local Constants = RAT.Constants

local barPool = {}
local activeInterruptAnchor = nil

-- Constants
local BAR_SPACING = Constants.BAR_SPACING
local BAR_COOLDOWN_ALPHA = 0.5   -- Alpha for cooldown state
local BAR_READY_ALPHA = 1.0      -- Alpha for ready state

function InterruptBarDisplay:Initialize()
end

--- Create a new bar frame
-- @return frame Bar frame
function InterruptBarDisplay:CreateBar()
    return RAT.BarFactory:CreateBarFrame()
end

--- Get or create a bar from the pool
-- @return frame Bar frame
function InterruptBarDisplay:AcquireBar()
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
function InterruptBarDisplay:ReleaseBar(bar)
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
function InterruptBarDisplay:UpdateBars(interruptSpells)
    local anchor = RAT.AnchorDisplay:GetGroupAnchor("interrupt")
    if not anchor then return end

    if RAT.db.profile.interruptBars.hideInRaid and RAT.UnitsManager:IsInRaid() then
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
        local aCdInfo = RAT.TrackerManager:GetCooldownInfo(a.guid, a.name)
        local bCdInfo = RAT.TrackerManager:GetCooldownInfo(b.guid, b.name)

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

        -- Set bar icon texture (bars use .icon instead of .texture)
        if bar.icon then
            local tempIcon = {texture = bar.icon}
            RAT.IconFactory:SetIconTexture(tempIcon, spellInfo.name, spellInfo.spellData)
        end

        bar.unitText:SetText(unitName)

        bar:ClearAllPoints()
        if i == 1 then
            bar:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 0)
        else
            local prevBar = anchor.bars[i - 1]
            bar:SetPoint("BOTTOMLEFT", prevBar, "TOPLEFT", 0, BAR_SPACING)
        end

        bar.classColor = classColor

        local self = InterruptBarDisplay
        RAT.IconManager:ApplyCooldownState(bar, spellInfo.guid, spellInfo.name,
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
function InterruptBarDisplay:UpdateBarCooldownState(guid, spellName)
    local anchor = RAT.AnchorDisplay:GetGroupAnchor("interrupt")
    if not anchor or not anchor.bars then return false end

    for _, bar in ipairs(anchor.bars) do
        if bar.guid == guid and bar.spellName == spellName then
            local self = InterruptBarDisplay
            RAT.IconManager:ApplyCooldownState(bar, guid, spellName,
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
function InterruptBarDisplay:UpdateBarCooldown(bar)
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
function InterruptBarDisplay:SetBarReady(bar)
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
function InterruptBarDisplay:UpdateAllBars()
    local anchor = RAT.AnchorDisplay:GetGroupAnchor("interrupt")
    if not anchor or not anchor.bars then return end

    for _, bar in ipairs(anchor.bars) do
        if bar.startTime and bar.duration then
            self:UpdateBarCooldown(bar)
        end
    end
end

function InterruptBarDisplay:HideBars()
    local anchor = RAT.AnchorDisplay:GetGroupAnchor("interrupt")
    if not anchor or not anchor.bars then return end

    for _, bar in ipairs(anchor.bars) do
        self:ReleaseBar(bar)
    end
    anchor.bars = {}
end

