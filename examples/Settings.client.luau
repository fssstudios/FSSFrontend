local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIModule = require(ReplicatedStorage:WaitForChild("FSSFrontend"))

local SettingsGUI = UIModule:Create({
	Name = "SettingsExample",
	Theme = "Dark",
	Size = UDim2.fromOffset(720, 440),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
})

-- H arranges sections left-to-right. V arranges them top-to-bottom.
SettingsGUI:Subdivide("H", 2, { Names = { "Navigation", "Content" } })
SettingsGUI[1]:Subdivide("V", 2)

SettingsGUI[1][1]:Text("Settings", {
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Center,
})

-- This is the bottom-left region.
SettingsGUI[1][2]:List("Buttons", { "Graphics", "Audio", "Controls" }, function(button)
	print("Selected:", button.Name)
end, { Padding = 8 })

SettingsGUI[2]:Subdivide("V", 4)
SettingsGUI[2][1]:Toggle("Fullscreen", false, function(enabled)
	print("Fullscreen:", enabled)
end)
SettingsGUI[2][2]:Slider("Volume", 0, 100, 75, function(value)
	print("Volume:", value)
end)
SettingsGUI[2][3]:Dropdown({ "Low", "Medium", "High", "Ultra" }, function(value)
	print("Quality:", value)
end, { Value = "High" })
SettingsGUI[2][4]:Reference("SaveButton")
SettingsGUI.SaveButton:Button("Save settings", function()
	print("Settings saved")
end)
