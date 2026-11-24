-- TempleUI (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > TempleUI
--
-- The "Temple" button and the Temple Upgrades menu.
-- Display only: it reads the values the server publishes as Player
-- Attributes and SENDS upgrade requests. The server decides everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TempleConfig = require(Shared:WaitForChild("TempleConfig"))
local Progression = require(Shared:WaitForChild("Progression"))

local upgradeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestUpgrade")

local THEME = {
	Marble = Color3.fromRGB(246, 242, 232),
	MarbleDark = Color3.fromRGB(228, 220, 204),
	Gold = Color3.fromRGB(212, 175, 55),
	Bronze = Color3.fromRGB(140, 92, 45),
	Text = Color3.fromRGB(58, 44, 28),
	SubText = Color3.fromRGB(110, 95, 75),
	White = Color3.new(1, 1, 1),
	Ready = Color3.fromRGB(70, 150, 70),
	TooExpensive = Color3.fromRGB(175, 80, 55),
	Locked = Color3.fromRGB(130, 130, 140),
	Warning = Color3.fromRGB(175, 55, 35),
}
local TITLE_FONT = Enum.Font.Garamond
local BODY_FONT = Enum.Font.GothamBold
local SMALL_FONT = Enum.Font.Gotham

--------------------------------------------------------------------------
-- Small UI helpers
--------------------------------------------------------------------------
local function create(className, props, children)
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color, thickness)
	return create("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function padding(px)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

local function text(props)
	props.BackgroundTransparency = 1
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextColor3 = props.TextColor3 or THEME.Text
	return create("TextLabel", props)
end

--------------------------------------------------------------------------
-- Screen + scaling (same rules as the HUD)
--------------------------------------------------------------------------
local gui = create("ScreenGui", {
	Name = "TempleUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
	Enabled = false, -- shown once data has loaded
	Parent = playerGui,
})
local uiScale = create("UIScale", { Parent = gui })

local function updateScale()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	uiScale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.7, 1.2)
end
updateScale()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local function updateEnabled()
	gui.Enabled = player:GetAttribute("DataLoaded") == true
end
player:GetAttributeChangedSignal("DataLoaded"):Connect(updateEnabled)
updateEnabled()

--------------------------------------------------------------------------
-- Open button (under the HUD's travel buttons)
--------------------------------------------------------------------------
local openButton = create("TextButton", {
	Name = "OpenTemple",
	Position = UDim2.fromOffset(12, 162),
	Size = UDim2.fromOffset(290, 40),
	BackgroundColor3 = THEME.Gold,
	Text = "Temple Upgrades",
	Font = BODY_FONT,
	TextSize = 17,
	TextColor3 = THEME.Text,
	AutoButtonColor = true,
	Parent = gui,
}, { corner(8), stroke(THEME.Bronze, 2) })

--------------------------------------------------------------------------
-- Menu panel
--------------------------------------------------------------------------
local panel = create("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(600, 460),
	BackgroundColor3 = THEME.Marble,
	Visible = false,
	Parent = gui,
}, { corner(12), stroke(THEME.Gold, 3), padding(14) })

text({
	Name = "Title",
	Size = UDim2.new(1, -50, 0, 34),
	Text = "Temple Upgrades",
	Font = TITLE_FONT,
	TextSize = 32,
	Parent = panel,
})

local closeButton = create("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = THEME.Bronze,
	Text = "X",
	Font = BODY_FONT,
	TextSize = 20,
	TextColor3 = THEME.White,
	Parent = panel,
}, { corner(8) })

local tierLabel = text({
	Name = "Tier",
	Position = UDim2.fromOffset(0, 38),
	Size = UDim2.new(1, -50, 0, 22),
	Text = "",
	Font = BODY_FONT,
	TextSize = 17,
	TextColor3 = THEME.Bronze,
	Parent = panel,
})

local incomeLabel = text({
	Name = "Income",
	Position = UDim2.fromOffset(0, 62),
	Size = UDim2.new(1, 0, 0, 20),
	Text = "",
	Font = SMALL_FONT,
	TextSize = 15,
	TextColor3 = THEME.SubText,
	Parent = panel,
})

local list = create("ScrollingFrame", {
	Name = "List",
	Position = UDim2.fromOffset(0, 90),
	Size = UDim2.new(1, 0, 1, -90),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = THEME.Bronze,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	Parent = panel,
}, {
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
})

-- One row per building
local rows = {}
for order, id in TempleConfig.BuildingOrder do
	local info = TempleConfig.Buildings[id]
	local row = create("Frame", {
		Name = id,
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundColor3 = THEME.MarbleDark,
		LayoutOrder = order,
		Parent = list,
	}, { corner(8), padding(8) })

	local nameLabel = text({
		Name = "Name",
		Size = UDim2.new(1, -150, 0, 22),
		Font = BODY_FONT,
		TextSize = 18,
		Text = info.DisplayName,
		Parent = row,
	})
	text({
		Name = "Description",
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, -150, 0, 18),
		Font = SMALL_FONT,
		TextSize = 13,
		TextColor3 = THEME.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = info.Description,
		Parent = row,
	})
	local effectLabel = text({
		Name = "Effect",
		Position = UDim2.fromOffset(0, 41),
		Size = UDim2.new(1, -150, 0, 18),
		Font = SMALL_FONT,
		TextSize = 14,
		Text = "",
		Parent = row,
	})
	local statusLabel = text({
		Name = "Status",
		Position = UDim2.fromOffset(0, 59),
		Size = UDim2.new(1, -150, 0, 16),
		Font = BODY_FONT,
		TextSize = 13,
		TextColor3 = THEME.Warning,
		Text = "",
		Parent = row,
	})
	local button = create("TextButton", {
		Name = "Upgrade",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(136, 56),
		BackgroundColor3 = THEME.Locked,
		Text = "",
		Font = BODY_FONT,
		TextSize = 16,
		TextColor3 = THEME.White,
		Parent = row,
	}, { corner(8) })

	button.Activated:Connect(function()
		upgradeRemote:FireServer(id) -- the server checks cost, requirements and ownership
	end)

	rows[id] = { Name = nameLabel, Effect = effectLabel, Status = statusLabel, Button = button }
end

--------------------------------------------------------------------------
-- Refresh from attributes
--------------------------------------------------------------------------
local function formatEffect(id, level)
	local info = TempleConfig.Buildings[id]
	if info.IsCore then
		local tier = TempleConfig.TierFromCoreLevel(level)
		if level >= TempleConfig.MaxBuildingLevel then
			return "Temple: " .. TempleConfig.GetTierName(tier)
		end
		return ("Temple: %s -> %s"):format(TempleConfig.GetTierName(tier), TempleConfig.GetTierName(tier + 1))
	end
	local now = TempleConfig.GetEffectValue(id, level)
	if level >= TempleConfig.MaxBuildingLevel then
		return ("%s: %s"):format(info.EffectLabel, Progression.FormatNumber(now))
	end
	local nextValue = TempleConfig.GetEffectValue(id, level + 1)
	return ("%s: %s -> %s"):format(info.EffectLabel, Progression.FormatNumber(now), Progression.FormatNumber(nextValue))
end

local function refresh()
	local tier = player:GetAttribute("TempleTier") or 1
	local gold = player:GetAttribute("Gold") or 0
	local playerLevel = player:GetAttribute("Level") or 1

	tierLabel.Text = ("Tier %d: %s"):format(tier, TempleConfig.GetTierName(tier))
	incomeLabel.Text = ("Income while you play: +%s Gold/min   +%s Favor/min"):format(
		Progression.FormatNumber(player:GetAttribute("GoldPerMinute") or 0),
		Progression.FormatNumber(player:GetAttribute("FavorPerMinute") or 0)
	)

	for id, row in rows do
		local info = TempleConfig.Buildings[id]
		local level = player:GetAttribute("Temple_" .. id) or 0
		local upgrade = TempleConfig.GetUpgradeInfo(id, level, tier, playerLevel)

		row.Name.Text = ("%s   Lv %d/%d"):format(info.DisplayName, level, TempleConfig.MaxBuildingLevel)
		row.Effect.Text = formatEffect(id, level)

		if upgrade.Maxed then
			row.Status.Text = ""
			row.Button.Text = "MAX"
			row.Button.BackgroundColor3 = THEME.Gold
			row.Button.AutoButtonColor = false
		elseif upgrade.Blocked then
			row.Status.Text = "Locked: " .. upgrade.Blocked
			row.Button.Text = "Locked"
			row.Button.BackgroundColor3 = THEME.Locked
			row.Button.AutoButtonColor = false
		else
			local canAfford = gold >= upgrade.Cost
			row.Status.Text = if canAfford then "" else "Not enough Gold yet"
			row.Button.Text = (if level == 0 then "Build" else "Upgrade") .. "\n" .. Progression.FormatNumber(upgrade.Cost) .. " Gold"
			row.Button.BackgroundColor3 = if canAfford then THEME.Ready else THEME.TooExpensive
			row.Button.AutoButtonColor = true
		end
	end
end

local watched = { "TempleTier", "Gold", "Level", "GoldPerMinute", "FavorPerMinute" }
for _, id in TempleConfig.BuildingOrder do
	table.insert(watched, "Temple_" .. id)
end
for _, attribute in watched do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end
refresh()

--------------------------------------------------------------------------
-- Open / close
--------------------------------------------------------------------------
openButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		refresh()
	end
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
