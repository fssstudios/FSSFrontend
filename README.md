# FSSFrontend

FSSFrontend is a small, dependency-free Roblox/Luau GUI module for rapidly building functional developer interfaces. Its central idea is a recursively subdividable canvas: split a region, index into any resulting region, and place controls there.

```luau
local UIModule = require(game.ReplicatedStorage.FSSFrontend)

local SettingsGUI = UIModule:Create()
SettingsGUI:Subdivide("H", 2)
SettingsGUI[1]:Subdivide("V", 2)

SettingsGUI[1][2]:Text("Bottom-left")
SettingsGUI[2]:Reference("SaveButton")
SettingsGUI.SaveButton:Button("Save", function(button)
	print(button.Name)
end)
```

The module provides subdivisions, buttons, click targets, text labels, scrolling lists, text input, toggles, sliders, dropdowns, progress bars, themes, raw-instance escape hatches, and automatic event cleanup.

## Layout model

`Subdivide(direction, count)` replaces a region's current contents with equally sized child regions.

| Direction | Meaning | Child order |
| --- | --- | --- |
| `"H"` or `"Horizontal"` | Arrange regions horizontally | left to right |
| `"V"` or `"Vertical"` | Arrange regions vertically | top to bottom |

The direction describes the **arrangement** of the new regions. Consequently:

```luau
SettingsGUI:Subdivide("H", 2) -- left and right
SettingsGUI[1]:Subdivide("V", 2) -- top-left and bottom-left

local bottomLeft = SettingsGUI[1][2]
```

Regions are one-indexed, like normal Luau arrays. Nest subdivisions to create any grid or panel arrangement:

```text
SettingsGUI
├── [1] left
│   ├── [1] top-left
│   └── [2] bottom-left
└── [2] right
```

## Installation

### Rojo

Copy this repository into your project and point your Rojo tree at `src`:

```json
{
  "ReplicatedStorage": {
    "FSSFrontend": {
      "$path": "path/to/FSSFrontend/src"
    }
  }
}
```

This repository also includes a complete `default.project.json`. From the repository directory:

```sh
aftman install
rojo serve
```

Connect Roblox Studio with the Rojo plugin. The module appears at `ReplicatedStorage.FSSFrontend`, and the included example appears in `StarterPlayerScripts`.

### Manual Roblox Studio install

Create a `ModuleScript` named `FSSFrontend` in `ReplicatedStorage`, then paste the contents of `src/init.luau` into it.

FSSFrontend creates interface instances and listens for player input, so require and use it from a `LocalScript`. Supplying an explicit `Parent` allows construction under another GUI container.

## Creating a UI

```luau
local UI = UIModule:Create({
	Name = "AdminPanel",
	Parent = game.Players.LocalPlayer.PlayerGui, -- defaults to LocalPlayer.PlayerGui
	Theme = "Dark", -- "Dark", "Light", or a custom theme table
	Size = UDim2.fromOffset(800, 500),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	DisplayOrder = 10,
	IgnoreGuiInset = false,
	ResetOnSpawn = false,
	Enabled = true,
	BackgroundTransparency = 0,
	ClipsDescendants = false,
})
```

All fields are optional. `Create()` returns the root region. `root:GetGui()` returns the generated `ScreenGui`; `root:GetInstance()` returns its root `Frame`.

## Subdividing regions

```luau
region:Subdivide("H", 3, {
	Gap = 12,
	Names = { "Sidebar", "Workspace", "Inspector" },
	ClipsDescendants = false,
})
```

`Subdivide` returns the same region for chaining. It clears the region's existing controls and child subdivisions before constructing the new layout. `count` must be a positive integer.

Access children with either syntax:

```luau
local sidebar = region[1]
local workspace = region:Get(2)
local children = region:GetChildren() -- a copy of the child array
print(workspace:GetPath()) -- for example, root[2]
```

### Named references

Call `Reference(name)` on any subdivision to expose it as a named property of the root UI:

```luau
GUI[1][2][3][2][1]:Reference("StartButton")

GUI.StartButton:Button("Start", function()
	print("Starting")
end)
```

`Reference` returns the same region, so it can be chained:

```luau
GUI[1][2]:Reference("StatusPanel"):Text("Ready")
```

Reference names must be non-empty strings and cannot conflict with region methods or internal root fields. A name can point to only one region, although one region may have multiple names. Use a valid Luau identifier when accessing a reference with dot syntax; any string can be accessed with brackets:

```luau
GUI[2]:Reference("player-actions")
GUI["player-actions"]:List("Buttons", { "Kick", "Teleport" })
```

References can also be retrieved or removed explicitly:

```luau
local startRegion = GUI:GetReference("StartButton")
startRegion:Unreference("StartButton") -- remove one name
startRegion:Unreference() -- remove every name assigned to this region
```

References remain valid when their region's contents are replaced. They are removed automatically if the referenced region or one of its ancestors is destroyed or subdivided.

## Controls

Controls return a component handle. Every component exposes:

```luau
component.Instance                 -- underlying Roblox instance
component:GetInstance()            -- same instance
component:Set({ Visible = false }) -- set Roblox properties; returns component
component:On("MouseEnter", fn)     -- connect any event
component:Destroy()                -- disconnect events and destroy the instance
component:SetValue(value)          -- controls with a value only
component.Value                    -- current value, when applicable
```

Most control option tables accept Roblox properties directly. Use `Properties = { ... }` if a property name needs to be grouped explicitly.

### Text

```luau
local heading = region:Text("Server tools", {
	Name = "Heading",
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Color3.fromRGB(255, 220, 120),
})

heading:Set({ Text = "Developer tools" })
```

By default a text label fills its region, wraps text, and aligns left/center vertically.

### Button

```luau
local save = region:Button("Save", function(button, inputObject)
	print("Clicked", button.Name, inputObject)
end, {
	Name = "SaveButton",
	TextSize = 16,
})
```

Buttons fill their region and include accent hover animation. The callback's first argument is the underlying `TextButton`.

### Click target

`Click` places a transparent button over a region. It is useful when the region already contains visual content.

```luau
local connectionTarget = region:Click(function(button)
	print("Region clicked", button.Parent.Name)
end)
```

The click target uses `ZIndex = 100` by default. Override it through the options table when the interface has a custom Z-index hierarchy.

### Text input

```luau
local nameInput = region:Input("Player name", function(text, enterPressed, textBox)
	if enterPressed then
		print("Submitted", text)
	end
end, {
	Name = "PlayerName",
	ClearTextOnFocus = false,
})

nameInput:SetValue("Builderman")
print(nameInput.Value)
```

The callback runs on `FocusLost` with `(text, enterPressed, textBox, inputObject)`.

### Toggle / checkbox

```luau
local enabled = region:Toggle("Enable shadows", true, function(value, button)
	print("Shadows enabled:", value)
end)

enabled:SetValue(false)
```

`Checkbox` is an alias for `Toggle`.

### Slider

```luau
local volume = region:Slider("Volume", 0, 100, 50, function(value, container)
	print("Volume:", value)
end, {
	Step = 5,
	TrackHeight = 8,
})

volume:SetValue(75)
```

Sliders support mouse and touch input. Values are clamped to the supplied minimum and maximum and rounded to `Step`.

### Dropdown

```luau
local quality = region:Dropdown({
	"Low",
	"Medium",
	{ Name = "HighOption", Text = "High", Value = 3 },
	{ Name = "UltraOption", Text = "Ultra", Value = 4, Disabled = true },
}, function(value, index, selectedButton)
	print(value, index)
end, {
	Value = 3,
	ItemHeight = 36,
	MaxVisibleItems = 5,
})

quality:SetValue("Medium")
```

Dropdown values can be selected by their `Value` or `Name`. The first item is selected when `Value` is omitted.

### Progress bar

```luau
local progress = region:Progress(0.25)
progress:SetValue(0.8) -- accepts values from 0 to 1 and clamps automatically
```

### Lists

```luau
local actions = region:List("Buttons", {
	"Kick",
	"Teleport",
	{ Name = "Shutdown", Text = "Shut down server", Value = "shutdown" },
	{ Name = "Unavailable", Disabled = true },
}, function(button, index, value)
	print(button.Name, index, value)
end, {
	ItemHeight = 38,
	Gap = 6,
	Padding = 8,
	ItemPadding = 10,
})

actions:SetItems({ "New item A", "New item B" })
```

Supported list kinds are `"Buttons"` and `"Labels"`. Lists use a `ScrollingFrame` with automatic vertical canvas sizing. A string/number item uses that value for its name, text, and callback value. A table item may contain:

| Field | Purpose |
| --- | --- |
| `Name` | Roblox instance name |
| `Text` | Visible text |
| `Value` | Value passed to the callback |
| `Disabled` | Disables a button item |

The button-list callback is `(buttonInstance, index, value)`, so the short form requested by the library's original design works directly:

```luau
region:List("Buttons", { "ButtonA", "ButtonB" }, function(button)
	print(button.Name)
end)
```

## Raw Roblox instances

Use `Create` when a specialized Roblox GUI object is not covered by a convenience method:

```luau
local image = region:Create("ImageLabel", {
	Name = "Avatar",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Image = "rbxassetid://123456789",
})

image:Set({ ImageTransparency = 0.2 })
```

`Create` accepts any valid instance class and property table. Invalid properties produce a descriptive error rather than being silently ignored.

For direct access, use `region:GetInstance()` or `component.Instance`.

## Region styling and visibility

```luau
region:Style({
	BackgroundColor3 = Color3.fromRGB(40, 44, 52),
	BackgroundTransparency = 0.1,
})

region:Padding(12)
region:Hide()
region:Show()
region:SetVisible(false)
```

`Padding` adds a `UIPadding` to a region. Add it before controls that should respect it. Avoid adding more than one padding object to the same region.

## Themes

Two built-in themes are included:

```luau
local darkUI = UIModule:Create({ Theme = "Dark" })
local lightUI = UIModule:Create({ Theme = "Light" })
```

Pass a table to override any part of the dark theme:

```luau
local UI = UIModule:Create({
	Theme = {
		Background = Color3.fromRGB(12, 18, 26),
		Surface = Color3.fromRGB(20, 30, 42),
		SurfaceHover = Color3.fromRGB(30, 42, 56),
		Text = Color3.fromRGB(245, 250, 255),
		MutedText = Color3.fromRGB(150, 165, 180),
		Accent = Color3.fromRGB(0, 170, 255),
		AccentHover = Color3.fromRGB(45, 188, 255),
		Input = Color3.fromRGB(15, 23, 33),
		Border = Color3.fromRGB(55, 72, 90),
		Danger = Color3.fromRGB(230, 70, 80),
		CornerRadius = UDim.new(0, 6),
		Padding = 10,
		Gap = 8,
		Font = Enum.Font.Gotham,
	},
})
```

Change an existing UI from its root:

```luau
UI:SetTheme("Light")
```

`UIModule.Themes.Dark` and `UIModule.Themes.Light` are available for inspection. Theme tables are copied when applied, so changing the built-in table is unnecessary.

## Cleanup and replacement behavior

```luau
region:Clear() -- removes controls and child subdivisions in this region
UI:Destroy()   -- disconnects all managed events and destroys the ScreenGui
```

FSSFrontend tracks the connections created by its controls. Destroying a component, clearing a region, or destroying the root disconnects those connections.

The following operations intentionally replace runtime UI content:

- `region:Subdivide(...)` clears the region before adding child regions.
- `list:SetItems(...)` destroys and rebuilds that list's item instances.
- `UI:Destroy()` removes the generated `ScreenGui`.

## Complete settings example

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIModule = require(ReplicatedStorage.FSSFrontend)

local SettingsGUI = UIModule:Create({
	Name = "Settings",
	Theme = "Dark",
	Size = UDim2.fromOffset(720, 440),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
})

SettingsGUI:Subdivide("H", 2, { Names = { "Navigation", "Controls" } })
SettingsGUI[1]:Subdivide("V", 2)

SettingsGUI[1][1]:Text("Settings", {
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Center,
})

SettingsGUI[1][2]:List("Buttons", { "Graphics", "Audio", "Controls" }, function(button)
	print("Open category:", button.Name)
end, { Padding = 8 })

SettingsGUI[2]:Subdivide("V", 4)
SettingsGUI[2][1]:Toggle("Fullscreen", false, function(value)
	print("Fullscreen:", value)
end)
SettingsGUI[2][2]:Slider("Volume", 0, 100, 75, function(value)
	print("Volume:", value)
end)
SettingsGUI[2][3]:Dropdown({ "Low", "Medium", "High", "Ultra" }, function(value)
	print("Quality:", value)
end, { Value = "High" })
SettingsGUI[2][4]:Reference("SaveButton")
SettingsGUI.SaveButton:Button("Save settings", function()
	print("Saved")
end)
```

The same example is available as `examples/Settings.client.luau` and is included by the repository's Rojo project.

## API summary

### Module

| API | Result |
| --- | --- |
| `UIModule:Create(options?)` | Creates and returns a root region |
| `UIModule.Themes` | Built-in `Dark` and `Light` theme tables |

### Region

| API | Result |
| --- | --- |
| `region:Subdivide(direction, count, options?)` | Replaces contents with indexed child regions |
| `region[index]`, `region:Get(index)` | Gets one child region |
| `region:GetChildren()` | Returns a copy of all child regions |
| `region:GetPath()` | Returns a readable indexed path |
| `region:Reference(name)` | Exposes the region as `root[name]` / `root.Name` |
| `root:GetReference(name)` | Gets a named region explicitly |
| `region:Unreference(name?)` | Removes one or all names for the region |
| `region:GetInstance()` | Returns the backing `Frame` |
| `region:GetGui()` | Returns the root `ScreenGui` |
| `region:Style(properties)` | Sets backing-frame properties |
| `region:Padding(value?)` | Adds uniform padding |
| `region:Show()`, `Hide()`, `SetVisible(bool)` | Controls visibility |
| `region:Text(text, options?)` | Creates a text label |
| `region:Button(text, callback?, options?)` | Creates a button |
| `region:Click(callback, options?)` | Creates a transparent click target |
| `region:Input(placeholder, callback?, options?)` | Creates a text input |
| `region:Toggle(text, initial, callback?, options?)` | Creates a toggle |
| `region:Checkbox(...)` | Alias for `Toggle` |
| `region:Slider(text, min, max, initial, callback?, options?)` | Creates a slider |
| `region:Dropdown(items, callback?, options?)` | Creates a dropdown |
| `region:Progress(value, options?)` | Creates a progress bar |
| `region:List(kind, items, callback?, options?)` | Creates a scrolling list |
| `region:Create(className, properties?)` | Creates a raw Roblox instance |
| `region:Clear()` | Removes managed contents and subdivisions |
| `region:Destroy()` | Destroys the region; on root, destroys the full UI |
| `root:SetTheme(theme)` | Applies a built-in or custom theme |

## License

FSSFrontend is available under the [MIT License](LICENSE).
