--!nonstrict

-- FSSFrontend
-- A dependency-free, subdivision-oriented Roblox GUI library.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIModule = {}

local Themes = {
	Dark = {
		Background = Color3.fromRGB(18, 20, 25),
		Surface = Color3.fromRGB(29, 32, 40),
		SurfaceHover = Color3.fromRGB(39, 43, 53),
		Text = Color3.fromRGB(241, 243, 248),
		MutedText = Color3.fromRGB(164, 170, 184),
		Accent = Color3.fromRGB(91, 135, 255),
		AccentHover = Color3.fromRGB(112, 151, 255),
		Input = Color3.fromRGB(22, 25, 31),
		Border = Color3.fromRGB(58, 63, 75),
		Danger = Color3.fromRGB(232, 82, 92),
		CornerRadius = UDim.new(0, 8),
		Padding = 10,
		Gap = 8,
		Font = Enum.Font.Gotham,
	},
	Light = {
		Background = Color3.fromRGB(239, 242, 247),
		Surface = Color3.fromRGB(255, 255, 255),
		SurfaceHover = Color3.fromRGB(244, 246, 251),
		Text = Color3.fromRGB(27, 30, 37),
		MutedText = Color3.fromRGB(99, 106, 120),
		Accent = Color3.fromRGB(61, 105, 225),
		AccentHover = Color3.fromRGB(79, 120, 230),
		Input = Color3.fromRGB(247, 248, 251),
		Border = Color3.fromRGB(210, 215, 224),
		Danger = Color3.fromRGB(207, 61, 74),
		CornerRadius = UDim.new(0, 8),
		Padding = 10,
		Gap = 8,
		Font = Enum.Font.Gotham,
	},
}

UIModule.Themes = Themes

local Node = {}
local Component = {}
local ListComponent = {}

local RESERVED_OPTIONS = {
	Callback = true,
	CornerRadius = true,
	Direction = true,
	Gap = true,
	ItemHeight = true,
	ItemPadding = true,
	Max = true,
	MaxVisibleItems = true,
	Min = true,
	Names = true,
	Padding = true,
	Properties = true,
	ScrollBarThickness = true,
	Step = true,
	TextSize = true,
	TextWrapped = true,
	TextXAlignment = true,
	TextYAlignment = true,
	ThemeRole = true,
	TrackHeight = true,
	Value = true,
	Weights = true,
}

local function shallowCopy(source)
	local result = {}
	for key, value in pairs(source or {}) do
		result[key] = value
	end
	return result
end

local function merge(base, overrides)
	local result = shallowCopy(base)
	for key, value in pairs(overrides or {}) do
		result[key] = value
	end
	return result
end

local function applyProperties(instance, properties, allowReserved)
	for property, value in pairs(properties or {}) do
		if property ~= "Properties" and (allowReserved or not RESERVED_OPTIONS[property]) then
			local ok, message = pcall(function()
				instance[property] = value
			end)
			if not ok then
				error(
					string.format("FSSFrontend: invalid %s property %q (%s)", instance.ClassName, property, message),
					3
				)
			end
		end
	end
	if properties and properties.Properties then
		applyProperties(instance, properties.Properties, true)
	end
end

local function corner(parent, radius)
	local object = Instance.new("UICorner")
	object.CornerRadius = radius
	object.Parent = parent
	return object
end

local function stroke(parent, color, transparency)
	local object = Instance.new("UIStroke")
	object.Color = color
	object.Transparency = transparency or 0
	object.Thickness = 1
	object.Parent = parent
	return object
end

local function padding(parent, value)
	local object = Instance.new("UIPadding")
	local amount = if typeof(value) == "UDim" then value else UDim.new(0, value)
	object.PaddingTop = amount
	object.PaddingBottom = amount
	object.PaddingLeft = amount
	object.PaddingRight = amount
	object.Parent = parent
	return object
end

local function normalizeDirection(direction)
	local value = string.upper(tostring(direction))
	if value == "H" or value == "HORIZONTAL" then
		return "H"
	elseif value == "V" or value == "VERTICAL" then
		return "V"
	end
	error('FSSFrontend: direction must be "H", "Horizontal", "V", or "Vertical"', 3)
end

local function resolveTheme(theme)
	if theme == nil then
		return shallowCopy(Themes.Dark)
	elseif type(theme) == "string" then
		local builtIn = Themes[theme]
		assert(builtIn, string.format("FSSFrontend: unknown theme %q", theme))
		return shallowCopy(builtIn)
	elseif type(theme) == "table" then
		return merge(Themes.Dark, theme)
	end
	error("FSSFrontend: Theme must be a theme name or a table", 3)
end

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(connections)
end

function Component:_new(node, instance, role)
	local object = setmetatable({
		Instance = instance,
		Node = node,
		Value = nil,
		_connections = {},
		_destroyed = false,
		_role = role,
	}, { __index = Component })
	table.insert(node._components, object)
	return object
end

function Component:GetInstance()
	return self.Instance
end

function Component:Set(properties)
	assert(not self._destroyed, "FSSFrontend: cannot modify a destroyed component")
	applyProperties(self.Instance, properties, true)
	return self
end

function Component:On(eventName, callback)
	assert(not self._destroyed, "FSSFrontend: cannot connect events on a destroyed component")
	assert(type(callback) == "function", "FSSFrontend: callback must be a function")
	local signal = self.Instance[eventName]
	assert(typeof(signal) == "RBXScriptSignal", string.format("FSSFrontend: %s is not an event", eventName))
	local connection = signal:Connect(callback)
	table.insert(self._connections, connection)
	return connection
end

function Component:SetValue(value, silent)
	assert(not self._destroyed, "FSSFrontend: cannot modify a destroyed component")
	assert(self._setValue, "FSSFrontend: this component does not hold a value")
	self._setValue(value, silent == true)
	return self
end

function Component:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	disconnectAll(self._connections)
	if self.Instance then
		self.Instance:Destroy()
	end
end

local function nodeIndex(self, key)
	if type(key) == "number" then
		return self._children[key]
	end
	if key == "Parent" then
		return rawget(self, "_parent")
	end
	local method = Node[key]
	if method ~= nil then
		return method
	end
	if rawget(self, "_parent") == nil then
		local references = rawget(self, "_references")
		return if references then references[key] else nil
	end
	return nil
end

local function newNode(root, parentNode, frame, surface)
	local object = setmetatable({
		Gui = frame,
		_parent = parentNode,
		_root = root,
		_children = {},
		_components = {},
		_connections = {},
		_managed = {},
		_referenceNames = {},
		_destroyed = false,
		_surface = surface == true,
	}, { __index = nodeIndex })

	root = root or object
	object._root = root
	root._nodes = root._nodes or {}
	root._nodes[object] = true
	return object
end

local function themeComponent(component)
	local instance = component.Instance
	if not instance or not instance.Parent then
		return
	end
	local theme = component.Node._root._theme
	if component._themeUpdater then
		component._themeUpdater(theme)
		return
	end
	local role = component._role
	if role == "Text" then
		instance.TextColor3 = theme.Text
		instance.Font = theme.Font
	elseif role == "MutedText" then
		instance.TextColor3 = theme.MutedText
		instance.Font = theme.Font
	elseif role == "Button" then
		instance.BackgroundColor3 = theme.Accent
		instance.TextColor3 = theme.Text
		instance.Font = theme.Font
	elseif role == "Input" then
		instance.BackgroundColor3 = theme.Input
		instance.TextColor3 = theme.Text
		instance.Font = theme.Font
		if instance:IsA("TextBox") then
			instance.PlaceholderColor3 = theme.MutedText
		end
	elseif role == "ProgressTrack" then
		instance.BackgroundColor3 = theme.Input
	elseif role == "ProgressFill" then
		instance.BackgroundColor3 = theme.Accent
	end
end

function Node:_applyTheme()
	if self.Gui and self.Gui.Parent then
		if self.Parent == nil then
			self.Gui.BackgroundColor3 = self._root._theme.Background
		elseif self._surface then
			self.Gui.BackgroundColor3 = self._root._theme.Surface
		end
	end
	for _, component in ipairs(self._components) do
		if not component._destroyed then
			themeComponent(component)
		end
	end
end

function Node:Get(index)
	return self._children[index]
end

function Node:GetChildren()
	return table.clone(self._children)
end

function Node:GetInstance()
	return self.Gui
end

function Node:GetGui()
	return self._root._screenGui
end

function Node:GetPath()
	local parts = {}
	local current = self
	while current and current.Parent do
		table.insert(parts, 1, tostring(current._index))
		current = current.Parent
	end
	return #parts == 0 and "root" or "root[" .. table.concat(parts, "][") .. "]"
end

function Node:Reference(name)
	assert(not self._destroyed, "FSSFrontend: cannot reference a destroyed node")
	assert(type(name) == "string" and name ~= "", "FSSFrontend: reference name must be a non-empty string")

	local root = self._root
	assert(Node[name] == nil, string.format("FSSFrontend: reference name %q conflicts with a region method", name))
	assert(name ~= "Parent", 'FSSFrontend: reference name "Parent" is reserved')
	assert(
		rawget(root, name) == nil,
		string.format("FSSFrontend: reference name %q conflicts with an internal field", name)
	)

	local existing = root._references[name]
	if existing ~= nil and existing ~= self then
		error(string.format("FSSFrontend: reference name %q is already assigned to %s", name, existing:GetPath()), 2)
	end
	root._references[name] = self
	self._referenceNames[name] = true
	return self
end

function Node:GetReference(name)
	assert(self.Parent == nil, "FSSFrontend: GetReference must be called on the root UI")
	return self._references[name]
end

function Node:Unreference(name)
	if name ~= nil then
		assert(type(name) == "string", "FSSFrontend: reference name must be a string")
		if self._root._references[name] == self then
			self._root._references[name] = nil
			self._referenceNames[name] = nil
		end
		return self
	end

	for referenceName in pairs(self._referenceNames) do
		if self._root._references[referenceName] == self then
			self._root._references[referenceName] = nil
		end
	end
	table.clear(self._referenceNames)
	return self
end

function Node:Style(properties)
	applyProperties(self.Gui, properties, true)
	return self
end

function Node:Show()
	self.Gui.Visible = true
	return self
end

function Node:Hide()
	self.Gui.Visible = false
	return self
end

function Node:SetVisible(visible)
	self.Gui.Visible = visible == true
	return self
end

function Node:Clear()
	for _, child in ipairs(self._children) do
		child:Destroy()
	end
	table.clear(self._children)

	for _, component in ipairs(self._components) do
		component:Destroy()
	end
	table.clear(self._components)

	for _, object in ipairs(self._managed) do
		if object.Parent then
			object:Destroy()
		end
	end
	table.clear(self._managed)
	return self
end

function Node:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:Unreference()
	self:Clear()
	disconnectAll(self._connections)
	self._root._nodes[self] = nil

	if self.Parent == nil and self._screenGui then
		self._screenGui:Destroy()
	elseif self.Gui then
		self.Gui:Destroy()
	end
end

function Node:Subdivide(direction, count, options)
	assert(not self._destroyed, "FSSFrontend: cannot subdivide a destroyed node")
	assert(type(count) == "number" and count >= 1 and count % 1 == 0, "FSSFrontend: count must be a positive integer")
	direction = normalizeDirection(direction)
	options = options or {}
	self:Clear()

	local gap = options.Gap
	if gap == nil then
		gap = self._root._theme.Gap
	end
	assert(type(gap) == "number" and gap >= 0, "FSSFrontend: Gap must be a non-negative number")

	local layout = Instance.new("UIGridLayout")
	layout.Name = "SubdivisionLayout"
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	if direction == "H" then
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.FillDirectionMaxCells = count
		layout.CellPadding = UDim2.new(0, gap, 0, 0)
		layout.CellSize = UDim2.new(1 / count, -gap * (count - 1) / count, 1, 0)
	else
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.FillDirectionMaxCells = count
		layout.CellPadding = UDim2.new(0, 0, 0, gap)
		layout.CellSize = UDim2.new(1, 0, 1 / count, -gap * (count - 1) / count)
	end
	layout.Parent = self.Gui
	table.insert(self._managed, layout)

	for index = 1, count do
		local frame = Instance.new("Frame")
		frame.Name = if options.Names and options.Names[index]
			then tostring(options.Names[index])
			else "Section" .. index
		frame.LayoutOrder = index
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = self._root._theme.Surface
		frame.ClipsDescendants = options.ClipsDescendants == true
		frame.Parent = self.Gui
		corner(frame, self._root._theme.CornerRadius)

		local child = newNode(self._root, self, frame, true)
		child._index = index
		table.insert(self._children, child)
	end
	return self
end

function Node:Padding(value)
	local object = padding(self.Gui, value or self._root._theme.Padding)
	table.insert(self._managed, object)
	return self
end

function Node:Create(className, properties)
	assert(type(className) == "string", "FSSFrontend: className must be a string")
	local instance = Instance.new(className)
	instance.Name = className
	local instanceProperties = shallowCopy(properties)
	instanceProperties.ThemeRole = nil
	applyProperties(instance, instanceProperties, true)
	instance.Parent = self.Gui
	return Component:_new(self, instance, properties and properties.ThemeRole)
end

function Node:Text(value, options)
	options = options or {}
	local theme = self._root._theme
	local label = Instance.new("TextLabel")
	label.Name = options.Name or "Text"
	label.BackgroundTransparency = 1
	label.Size = options.Size or UDim2.fromScale(1, 1)
	label.Position = options.Position or UDim2.fromScale(0, 0)
	label.Font = theme.Font
	label.Text = tostring(value or "")
	label.TextColor3 = theme.Text
	label.TextSize = options.TextSize or 16
	label.TextWrapped = options.TextWrapped ~= false
	label.TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left
	label.TextYAlignment = options.TextYAlignment or Enum.TextYAlignment.Center
	applyProperties(label, options)
	label.Parent = self.Gui
	return Component:_new(self, label, "Text")
end

local function connectButtonEffects(component)
	local button = component.Instance
	table.insert(
		component._connections,
		button.MouseEnter:Connect(function()
			local theme = component.Node._root._theme
			TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = theme.AccentHover }):Play()
		end)
	)
	table.insert(
		component._connections,
		button.MouseLeave:Connect(function()
			local theme = component.Node._root._theme
			TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = theme.Accent }):Play()
		end)
	)
end

function Node:Button(text, callback, options)
	options = options or {}
	local theme = self._root._theme
	local button = Instance.new("TextButton")
	button.Name = options.Name or tostring(text or "Button")
	button.AutoButtonColor = false
	button.BackgroundColor3 = theme.Accent
	button.BorderSizePixel = 0
	button.Size = options.Size or UDim2.fromScale(1, 1)
	button.Position = options.Position or UDim2.fromScale(0, 0)
	button.Font = theme.Font
	button.Text = tostring(text or "Button")
	button.TextColor3 = theme.Text
	button.TextSize = options.TextSize or 15
	button.TextWrapped = true
	applyProperties(button, options)
	button.Parent = self.Gui
	corner(button, options.CornerRadius or theme.CornerRadius)

	local component = Component:_new(self, button, "Button")
	connectButtonEffects(component)
	if callback then
		assert(type(callback) == "function", "FSSFrontend: button callback must be a function")
		table.insert(
			component._connections,
			button.Activated:Connect(function(...)
				callback(button, ...)
			end)
		)
	end
	return component
end

function Node:Click(callback, options)
	options = options or {}
	options.Name = options.Name or "ClickTarget"
	options.BackgroundTransparency = options.BackgroundTransparency or 1
	options.Text = ""
	options.ZIndex = options.ZIndex or 100
	local component = self:Button("", callback, options)
	component._role = nil
	return component
end

function Node:Input(placeholder, callback, options)
	options = options or {}
	local theme = self._root._theme
	local box = Instance.new("TextBox")
	box.Name = options.Name or "Input"
	box.BackgroundColor3 = theme.Input
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = options.ClearTextOnFocus == true
	box.Size = options.Size or UDim2.fromScale(1, 1)
	box.Position = options.Position or UDim2.fromScale(0, 0)
	box.Font = theme.Font
	box.PlaceholderText = tostring(placeholder or "")
	box.PlaceholderColor3 = theme.MutedText
	box.Text = options.Text or ""
	box.TextColor3 = theme.Text
	box.TextSize = options.TextSize or 15
	box.TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left
	applyProperties(box, options)
	box.Parent = self.Gui
	corner(box, options.CornerRadius or theme.CornerRadius)
	local inset = padding(box, options.Padding or theme.Padding)
	inset.PaddingTop = UDim.new()
	inset.PaddingBottom = UDim.new()

	local component = Component:_new(self, box, "Input")
	component.Value = box.Text
	component._setValue = function(value, silent)
		box.Text = tostring(value or "")
		component.Value = box.Text
		if callback and not silent then
			callback(component.Value, false, box)
		end
	end
	if callback then
		assert(type(callback) == "function", "FSSFrontend: input callback must be a function")
		table.insert(
			component._connections,
			box.FocusLost:Connect(function(enterPressed, inputObject)
				component.Value = box.Text
				callback(box.Text, enterPressed, box, inputObject)
			end)
		)
	end
	return component
end

function Node:Toggle(text, initialValue, callback, options)
	options = options or {}
	local theme = self._root._theme
	local button = Instance.new("TextButton")
	button.Name = options.Name or "Toggle"
	button.AutoButtonColor = false
	button.BackgroundColor3 = theme.Input
	button.BorderSizePixel = 0
	button.Size = options.Size or UDim2.fromScale(1, 1)
	button.Position = options.Position or UDim2.fromScale(0, 0)
	button.Font = theme.Font
	button.TextColor3 = theme.Text
	button.TextSize = options.TextSize or 15
	button.TextXAlignment = Enum.TextXAlignment.Left
	applyProperties(button, options)
	button.Parent = self.Gui
	corner(button, options.CornerRadius or theme.CornerRadius)
	padding(button, options.Padding or theme.Padding)

	local component = Component:_new(self, button, "Input")
	local function setValue(value, silent)
		local currentTheme = self._root._theme
		component.Value = value == true
		button.Text = string.format("%s  %s", component.Value and "●" or "○", tostring(text or "Toggle"))
		button.TextColor3 = component.Value and currentTheme.Accent or currentTheme.Text
		if callback and not silent then
			callback(component.Value, button)
		end
	end
	component._setValue = setValue
	component._themeUpdater = function(currentTheme)
		button.BackgroundColor3 = currentTheme.Input
		button.Font = currentTheme.Font
		setValue(component.Value, true)
	end
	setValue(initialValue == true, true)
	table.insert(
		component._connections,
		button.Activated:Connect(function()
			setValue(not component.Value, false)
		end)
	)
	return component
end

Node.Checkbox = Node.Toggle

function Node:Slider(text, minimum, maximum, initialValue, callback, options)
	options = options or {}
	minimum = minimum or 0
	maximum = maximum or 100
	assert(
		type(minimum) == "number" and type(maximum) == "number" and maximum > minimum,
		"FSSFrontend: slider maximum must be greater than minimum"
	)
	local step = options.Step or 1
	assert(type(step) == "number" and step > 0, "FSSFrontend: slider Step must be greater than zero")
	local theme = self._root._theme

	local container = Instance.new("Frame")
	container.Name = options.Name or "Slider"
	container.BackgroundTransparency = 1
	container.Size = options.Size or UDim2.fromScale(1, 1)
	container.Position = options.Position or UDim2.fromScale(0, 0)
	applyProperties(container, options)
	container.Parent = self.Gui

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0.45, 0)
	label.Font = theme.Font
	label.TextColor3 = theme.Text
	label.TextSize = options.TextSize or 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.AutoButtonColor = false
	track.BackgroundColor3 = theme.Input
	track.BorderSizePixel = 0
	track.Position = UDim2.new(0, 0, 0.68, 0)
	track.Size = UDim2.new(1, 0, 0, options.TrackHeight or 8)
	track.Text = ""
	track.Parent = container
	corner(track, UDim.new(1, 0))

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = theme.Accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	corner(fill, UDim.new(1, 0))

	local component = Component:_new(self, container)
	local dragging = false
	local function setValue(value, silent)
		value = math.clamp(tonumber(value) or minimum, minimum, maximum)
		value = math.round((value - minimum) / step) * step + minimum
		value = math.clamp(value, minimum, maximum)
		component.Value = value
		local alpha = (value - minimum) / (maximum - minimum)
		fill.Size = UDim2.fromScale(alpha, 1)
		label.Text = string.format("%s: %s", tostring(text or "Value"), tostring(value))
		if callback and not silent then
			callback(value, container)
		end
	end
	local function setFromX(x)
		if track.AbsoluteSize.X > 0 then
			local alpha = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			setValue(minimum + (maximum - minimum) * alpha, false)
		end
	end
	component._setValue = setValue
	component._themeUpdater = function(currentTheme)
		label.Font = currentTheme.Font
		label.TextColor3 = currentTheme.Text
		track.BackgroundColor3 = currentTheme.Input
		fill.BackgroundColor3 = currentTheme.Accent
	end
	setValue(initialValue or minimum, true)
	table.insert(
		component._connections,
		track.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				setFromX(input.Position.X)
			end
		end)
	)
	table.insert(
		component._connections,
		UserInputService.InputChanged:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				setFromX(input.Position.X)
			end
		end)
	)
	table.insert(
		component._connections,
		UserInputService.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = false
			end
		end)
	)
	return component
end

function Node:Progress(value, options)
	options = options or {}
	local theme = self._root._theme
	local track = Instance.new("Frame")
	track.Name = options.Name or "Progress"
	track.BackgroundColor3 = theme.Input
	track.BorderSizePixel = 0
	track.Size = options.Size or UDim2.new(1, 0, 0, 10)
	track.Position = options.Position or UDim2.new(0, 0, 0.5, -5)
	applyProperties(track, options)
	track.Parent = self.Gui
	corner(track, UDim.new(1, 0))

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = theme.Accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, UDim.new(1, 0))

	local component = Component:_new(self, track, "ProgressTrack")
	local function setValue(newValue)
		component.Value = math.clamp(tonumber(newValue) or 0, 0, 1)
		fill.Size = UDim2.fromScale(component.Value, 1)
	end
	component._setValue = setValue
	component._themeUpdater = function(currentTheme)
		track.BackgroundColor3 = currentTheme.Input
		fill.BackgroundColor3 = currentTheme.Accent
	end
	setValue(value)
	return component
end

local function normalizeListItem(item, index)
	if type(item) == "table" then
		return {
			Name = tostring(item.Name or item.Text or index),
			Text = tostring(item.Text or item.Name or index),
			Value = if item.Value ~= nil then item.Value else item,
			Disabled = item.Disabled == true,
		}
	end
	return { Name = tostring(item), Text = tostring(item), Value = item, Disabled = false }
end

function ListComponent:SetItems(items)
	assert(not self._destroyed, "FSSFrontend: cannot modify a destroyed list")
	assert(type(items) == "table", "FSSFrontend: list items must be a table")
	for _, item in ipairs(self.Items) do
		item:Destroy()
	end
	table.clear(self.Items)

	local theme = self.Node._root._theme
	for index, rawItem in ipairs(items) do
		local item = normalizeListItem(rawItem, index)
		local instance = Instance.new(self.Kind == "Buttons" and "TextButton" or "TextLabel")
		instance.Name = item.Name
		instance.BackgroundColor3 = theme.Input
		instance.BackgroundTransparency = self.Kind == "Labels" and 0.35 or 0
		instance.BorderSizePixel = 0
		instance.Size = UDim2.new(1, 0, 0, self.ItemHeight)
		instance.Font = theme.Font
		instance.Text = item.Text
		instance.TextColor3 = item.Disabled and theme.MutedText or theme.Text
		instance.TextSize = self.Options.TextSize or 14
		instance.TextXAlignment = self.Options.TextXAlignment or Enum.TextXAlignment.Left
		instance.LayoutOrder = index
		if instance:IsA("TextButton") then
			instance.AutoButtonColor = false
			instance.Active = not item.Disabled
		end
		instance.Parent = self.Instance
		corner(instance, self.Options.CornerRadius or theme.CornerRadius)
		padding(instance, self.Options.ItemPadding or theme.Padding)

		local itemComponent = Component:_new(self.Node, instance)
		itemComponent.Value = item.Value
		itemComponent._themeUpdater = function(currentTheme)
			instance.BackgroundColor3 = currentTheme.Input
			instance.Font = currentTheme.Font
			instance.TextColor3 = item.Disabled and currentTheme.MutedText or currentTheme.Text
		end
		if instance:IsA("TextButton") and self.Callback and not item.Disabled then
			table.insert(
				itemComponent._connections,
				instance.Activated:Connect(function()
					self.Callback(instance, index, item.Value)
				end)
			)
		end
		table.insert(self.Items, itemComponent)
	end
	return self
end

function ListComponent:Destroy()
	for _, item in ipairs(self.Items) do
		item:Destroy()
	end
	table.clear(self.Items)
	Component.Destroy(self)
end

function Node:List(kind, items, callback, options)
	options = options or {}
	kind = tostring(kind or "Buttons")
	assert(kind == "Buttons" or kind == "Labels", 'FSSFrontend: list kind must be "Buttons" or "Labels"')
	assert(type(items) == "table", "FSSFrontend: list items must be a table")
	if callback ~= nil then
		assert(type(callback) == "function", "FSSFrontend: list callback must be a function")
	end
	local theme = self._root._theme
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = options.Name or kind .. "List"
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.BackgroundTransparency = options.BackgroundTransparency or 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarImageColor3 = theme.MutedText
	scroll.ScrollBarThickness = options.ScrollBarThickness or 4
	scroll.Size = options.Size or UDim2.fromScale(1, 1)
	scroll.Position = options.Position or UDim2.fromScale(0, 0)
	applyProperties(scroll, options)
	scroll.Parent = self.Gui

	local layout = Instance.new("UIListLayout")
	layout.Name = "ListLayout"
	layout.Padding = UDim.new(0, options.Gap or theme.Gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	local inset = padding(scroll, options.Padding or 0)
	inset.PaddingRight = UDim.new(0, (options.Padding or 0) + scroll.ScrollBarThickness + 2)

	local component = Component:_new(self, scroll)
	setmetatable(component, {
		__index = function(_, key)
			return ListComponent[key] or Component[key]
		end,
	})
	component.Kind = kind
	component.Callback = callback
	component.Options = options
	component.ItemHeight = options.ItemHeight or 36
	component.Items = {}
	component._themeUpdater = function(currentTheme)
		scroll.ScrollBarImageColor3 = currentTheme.MutedText
	end
	component:SetItems(items)
	return component
end

function Node:Dropdown(items, callback, options)
	options = options or {}
	assert(type(items) == "table" and #items > 0, "FSSFrontend: dropdown requires at least one item")
	local theme = self._root._theme
	local container = Instance.new("Frame")
	container.Name = options.Name or "Dropdown"
	container.BackgroundTransparency = 1
	container.Size = options.Size or UDim2.fromScale(1, 1)
	container.Position = options.Position or UDim2.fromScale(0, 0)
	applyProperties(container, options)
	container.Parent = self.Gui

	local selected = Instance.new("TextButton")
	selected.Name = "Selected"
	selected.AutoButtonColor = false
	selected.BackgroundColor3 = theme.Input
	selected.BorderSizePixel = 0
	selected.Size = UDim2.new(1, 0, 0, options.ItemHeight or 36)
	selected.Font = theme.Font
	selected.TextColor3 = theme.Text
	selected.TextSize = options.TextSize or 14
	selected.TextXAlignment = Enum.TextXAlignment.Left
	selected.ZIndex = options.ZIndex or 10
	selected.Parent = container
	corner(selected, theme.CornerRadius)
	padding(selected, options.Padding or theme.Padding)

	local menu = Instance.new("ScrollingFrame")
	menu.Name = "Menu"
	menu.AutomaticCanvasSize = Enum.AutomaticSize.Y
	menu.BackgroundColor3 = theme.Surface
	menu.BorderSizePixel = 0
	menu.CanvasSize = UDim2.new()
	menu.Position = UDim2.new(0, 0, 0, (options.ItemHeight or 36) + (options.Gap or 4))
	menu.ScrollBarImageColor3 = theme.MutedText
	menu.ScrollBarThickness = options.ScrollBarThickness or 4
	menu.ScrollingDirection = Enum.ScrollingDirection.Y
	menu.Size = UDim2.new(1, 0, 0, math.min(#items, options.MaxVisibleItems or 5) * (options.ItemHeight or 36))
	menu.Visible = false
	menu.ZIndex = (options.ZIndex or 10) + 1
	menu.Parent = container
	corner(menu, theme.CornerRadius)
	local menuStroke = stroke(menu, theme.Border)

	local menuList = Instance.new("UIListLayout")
	menuList.SortOrder = Enum.SortOrder.LayoutOrder
	menuList.Parent = menu

	local component = Component:_new(self, container)
	component.Items = {}
	component._themeUpdater = function(currentTheme)
		selected.BackgroundColor3 = currentTheme.Input
		selected.Font = currentTheme.Font
		selected.TextColor3 = currentTheme.Text
		menu.BackgroundColor3 = currentTheme.Surface
		menu.ScrollBarImageColor3 = currentTheme.MutedText
		menuStroke.Color = currentTheme.Border
		for _, button in ipairs(component.Items) do
			button.Font = currentTheme.Font
			button.TextColor3 = if button:GetAttribute("FSSDisabled") then currentTheme.MutedText else currentTheme.Text
		end
	end
	local function selectItem(rawItem, index, silent)
		local item = normalizeListItem(rawItem, index)
		component.Value = item.Value
		selected.Text = item.Text .. "  ▾"
		menu.Visible = false
		if callback and not silent then
			callback(item.Value, index, selected)
		end
	end
	component._setValue = function(value, silent)
		for index, item in ipairs(items) do
			local normalized = normalizeListItem(item, index)
			if normalized.Value == value or normalized.Name == value then
				selectItem(item, index, silent)
				return
			end
		end
		error("FSSFrontend: dropdown value was not found", 2)
	end
	table.insert(
		component._connections,
		selected.Activated:Connect(function()
			menu.Visible = not menu.Visible
		end)
	)
	for index, rawItem in ipairs(items) do
		local item = normalizeListItem(rawItem, index)
		local button = Instance.new("TextButton")
		button.Name = item.Name
		button.AutoButtonColor = true
		button.BackgroundTransparency = 1
		button.Size = UDim2.new(1, 0, 0, options.ItemHeight or 36)
		button.Font = theme.Font
		button.Text = item.Text
		button.TextColor3 = item.Disabled and theme.MutedText or theme.Text
		button.TextSize = options.TextSize or 14
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.ZIndex = menu.ZIndex + 1
		button.Active = not item.Disabled
		button:SetAttribute("FSSDisabled", item.Disabled)
		button.Parent = menu
		padding(button, options.Padding or theme.Padding)
		table.insert(component.Items, button)
		if not item.Disabled then
			table.insert(
				component._connections,
				button.Activated:Connect(function()
					selectItem(rawItem, index, false)
				end)
			)
		end
	end
	local initialItem = if options.Value ~= nil then options.Value else items[1]
	if options.Value ~= nil then
		component:SetValue(options.Value, true)
	else
		selectItem(initialItem, 1, true)
	end
	return component
end

function Node:SetTheme(theme)
	assert(self.Parent == nil, "FSSFrontend: SetTheme must be called on the root UI")
	self._theme = resolveTheme(theme)
	for node in pairs(self._nodes) do
		node:_applyTheme()
	end
	return self
end

function UIModule:Create(options)
	options = options or {}
	local parent = options.Parent
	if parent == nil then
		local player = Players.LocalPlayer
		assert(player, "FSSFrontend: Create() must run on the client unless Parent is provided")
		parent = player:WaitForChild("PlayerGui")
	end

	local theme = resolveTheme(options.Theme)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = options.Name or "FSSFrontend"
	screenGui.DisplayOrder = options.DisplayOrder or 0
	screenGui.IgnoreGuiInset = options.IgnoreGuiInset == true
	screenGui.ResetOnSpawn = options.ResetOnSpawn == true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = options.Enabled ~= false

	local rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.AnchorPoint = options.AnchorPoint or Vector2.zero
	rootFrame.BackgroundColor3 = theme.Background
	rootFrame.BackgroundTransparency = options.BackgroundTransparency or 0
	rootFrame.BorderSizePixel = 0
	rootFrame.Position = options.Position or UDim2.fromScale(0, 0)
	rootFrame.Size = options.Size or UDim2.fromScale(1, 1)
	rootFrame.ClipsDescendants = options.ClipsDescendants == true
	rootFrame.Parent = screenGui

	local root = newNode(nil, nil, rootFrame, false)
	root._screenGui = screenGui
	root._theme = theme
	root._references = {}
	root._isRoot = true
	screenGui.Parent = parent
	return root
end

return UIModule
