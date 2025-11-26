-----------------------------------------------------------------------
-- LibDBIcon-1.0
--
-- Allows addons to register to recieve a lightweight minimap icon as an alternative to more heavy LDB displays.
--

local DBICON10 = "LibDBIcon-1.0"
local DBICON10_MINOR = 44 -- Bump on changes
if not LibStub then error(DBICON10 .. " requires LibStub.") end
local ldb = LibStub("LibDataBroker-1.1", true)
if not ldb then error(DBICON10 .. " requires LibDataBroker-1.1.") end
local lib = LibStub:NewLibrary(DBICON10, DBICON10_MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbackRegistered = lib.callbackRegistered or nil
lib.callbacks = lib.callbacks or LibStub:GetLibrary("CallbackHandler-1.0"):New(lib)
lib.notCreated = lib.notCreated or {}
lib.radius = lib.radius or 5
lib.tooltip = lib.tooltip or CreateFrame("GameTooltip", "LibDBIconTooltip", UIParent, "GameTooltipTemplate")
local next, Minimap, type = next, Minimap, type
local draggingButton = nil

function lib:IconCallback(event, name, key, value)
	if lib.objects[name] then
		if key == "icon" then
			lib.objects[name].icon:SetTexture(value)
		elseif key == "iconCoords" then
			lib.objects[name].icon:UpdateCoord()
		elseif key == "iconR" then
			local _, g, b = lib.objects[name].icon:GetVertexColor()
			lib.objects[name].icon:SetVertexColor(value, g, b)
		elseif key == "iconG" then
			local r, _, b = lib.objects[name].icon:GetVertexColor()
			lib.objects[name].icon:SetVertexColor(r, value, b)
		elseif key == "iconB" then
			local r, g = lib.objects[name].icon:GetVertexColor()
			lib.objects[name].icon:SetVertexColor(r, g, value)
		end
	end
end
if not lib.callbackRegistered then
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__icon", "IconCallback")
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__iconCoords", "IconCallback")
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__iconR", "IconCallback")
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__iconG", "IconCallback")
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__iconB", "IconCallback")
	lib.callbackRegistered = true
end

local function updatePosition(button, position)
	local angle = math.rad(position or 225)
	local x = math.cos(angle) * (lib.radius + 5)
	local y = math.sin(angle) * (lib.radius + 5)
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function onClick(self, b)
	if self.dataObject.OnClick then
		self.dataObject.OnClick(self, b)
	end
end

local function onMouseDown(self)
	self.isMouseDown = true
	self.icon:UpdateCoord()
end

local function onMouseUp(self)
	self.isMouseDown = false
	self.icon:UpdateCoord()
end

local onDragStart, onDragStop

local function onEnter(self)
	if self.dataObject.OnTooltipShow then
		lib.tooltip:SetOwner(self, "ANCHOR_NONE")
		lib.tooltip:SetPoint("TOPLEFT", self, "BOTTOMRIGHT")
		self.dataObject.OnTooltipShow(lib.tooltip)
		lib.tooltip:Show()
	elseif self.dataObject.OnEnter then
		self.dataObject.OnEnter(self)
	end
	
	if self.draggable then
		self:SetScript("OnDragStart", onDragStart)
		self:SetScript("OnDragStop", onDragStop)
	end
end

local function onLeave(self)
	lib.tooltip:Hide()
	if self.dataObject.OnLeave then
		self.dataObject.OnLeave(self)
	end
end

onDragStart = function(self)
	draggingButton = self
	self:LockHighlight()
	self.isMouseDown = true
	self.icon:UpdateCoord()
	self:SetScript("OnUpdate", lib.onUpdate)
	lib.tooltip:Hide()
end

onDragStop = function(self)
	draggingButton = nil
	self:SetScript("OnUpdate", nil)
	self.isMouseDown = false
	self.icon:UpdateCoord()
	self:UnlockHighlight()
end

lib.onUpdate = function(self)
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	px, py = px / scale, py / scale
	local pos = 225
	if self.db then
		pos = math.deg(math.atan2(py - my, px - mx)) % 360
		self.db.minimapPos = pos
	else
		pos = math.deg(math.atan2(py - my, px - mx)) % 360
		self.minimapPos = pos
	end
	updatePosition(self, pos)
end

local function createButton(name, object, db)
	local button = CreateFrame("Button", "LibDBIcon10_" .. name, Minimap)
	button.dataObject = object
	button.db = db
	button:SetFrameStrata("MEDIUM")
	button:SetWidth(31)
	button:SetHeight(31)
	button:SetFrameLevel(8)
	button:RegisterForClicks("anyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetWidth(53)
	overlay:SetHeight(53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint("TOPLEFT")
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetWidth(20)
	background:SetHeight(20)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetPoint("TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(17)
	icon:SetHeight(17)
	icon:SetTexture(object.icon)
	icon:SetPoint("TOPLEFT", 7, -6)
	button.icon = icon
	button.isMouseDown = false
	
	local r, g, b = icon:GetVertexColor()
	icon.UpdateCoord = function()
		local coords = object.iconCoords or {0, 1, 0, 1}
		if button.isMouseDown then
			icon:SetTexCoord(coords[1] + 0.05, coords[2] - 0.05, coords[3] + 0.05, coords[4] - 0.05)
		else
			icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		end
		icon:SetVertexColor(object.iconR or r, object.iconG or g, object.iconB or b)
	end
	icon:UpdateCoord()
	
	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", onLeave)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnMouseDown", onMouseDown)
	button:SetScript("OnMouseUp", onMouseUp)
	
	button.draggable = true
	
	if not db or not db.hide then
		button:Show()
	else
		button:Hide()
	end
	return button
end

function lib:Register(name, object, db)
	if not object.icon then error("Can't register LDB objects without icons set!") end
	if lib.objects[name] or lib.notCreated[name] then error("Already registered name:", name) end
	if not db or not db.hide then
		local button = createButton(name, object, db)
		lib.objects[name] = button
		if db then
			updatePosition(button, db.minimapPos or 225)
		else
			updatePosition(button, object.minimapPos or 225)
		end
		lib.callbacks:Fire("LibDBIcon_IconCreated", button, name)
	else
		lib.notCreated[name] = {object, db}
	end
end

function lib:Hide(name)
	if lib.objects[name] then
		lib.objects[name]:Hide()
	elseif lib.notCreated[name] then
		lib.notCreated[name].db.hide = true
	end
end

function lib:Show(name)
	if lib.objects[name] then
		lib.objects[name]:Show()
		local db = lib.objects[name].db
		updatePosition(lib.objects[name], db and db.minimapPos or lib.objects[name].minimapPos or 225)
	elseif lib.notCreated[name] then
		local obj, db = unpack(lib.notCreated[name])
		db.hide = false
		lib.notCreated[name] = nil
		lib:Register(name, obj, db)
	end
end

function lib:GetMinimapButton(name)
	return lib.objects[name]
end

function lib:IsRegistered(name)
	return lib.objects[name] and true or false
end

local function OnMinimapEnter()
	if draggingButton then return end
	for _, button in next, lib.objects do
		button:Show()
	end
end

local function OnMinimapLeave()
	if draggingButton then return end
	for _, button in next, lib.objects do
		if button.db and button.db.hide then
			button:Hide()
		end
	end
end

Minimap:HookScript("OnEnter", OnMinimapEnter)
Minimap:HookScript("OnLeave", OnMinimapLeave)

function lib:Refresh(name, db)
	local button = lib.objects[name]
	if button then
		button.db = db
		if db.hide then
			button:Hide()
		else
			button:Show()
			updatePosition(button, db.minimapPos or button.minimapPos or 225)
		end
	end
end

function lib:GetPosition(name)
	local button = lib.objects[name]
	if button then
		return button.db and button.db.minimapPos or button.minimapPos or 225
	end
end

function lib:SetPosition(name, pos)
	local button = lib.objects[name]
	if button then
		if button.db then
			button.db.minimapPos = pos
		else
			button.minimapPos = pos
		end
		updatePosition(button, pos)
	end
end

