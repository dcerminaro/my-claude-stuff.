-- WeaponUI (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > WeaponUI
--
-- Phase 7C: the "Weapons" button and the weapons screen.
--   * My Weapons: everything you own, with stats; Equip (anywhere) and
--     Upgrade (at the Divine Forge).
--   * Forge: every weapon, its stats and where it comes from (craft cost or
--     boss drop); Craft at the Divine Forge.
-- Display only: the server checks costs, ownership and the forge distance.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))
local Progression = require(Shared:WaitForChild("Progression"))
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local weaponRemote = Remotes:WaitForChild("WeaponAction")
local notifyRemote = Remotes:WaitForChild("Notify")

local THEME = {
	Marble = Color3.fromRGB(246, 242, 232),
	MarbleDark = Color3.fromRGB(228, 220, 204),
	Gold = Color3.fromRGB(212, 175, 55),
	Bronze = Color3.fromRGB(140, 92, 45),
	Text = Color3.fromRGB(58, 44, 28),
	SubText = Color3.fromRGB(110, 95, 75),
	White = Color3.new(1, 1, 1),
	Ready = Color3.fromRGB(70, 150, 70),
	Locked = Color3.fromRGB(130, 130, 140),
	Forge = Color3.fromRGB(210, 110, 40),
}

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
local function corner(r)
	return create("UICorner", { CornerRadius = UDim.new(0, r) })
end
local function stroke(color, t)
	return create("UIStroke", { Color = color, Thickness = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function padding(px)
	return create("UIPadding", { PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px) })
end
local function text(props)
	props.BackgroundTransparency = 1
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextColor3 = props.TextColor3 or THEME.Text
	props.Font = props.Font or Enum.Font.Gotham
	return create("TextLabel", props)
end
local function button(props)
	props.AutoButtonColor = true
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or THEME.White
	props.TextSize = props.TextSize or 14
	return create("TextButton", props, { corner(8) })
end

local gui = create("ScreenGui", { Name = "WeaponUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 9, Enabled = false, Parent = playerGui })
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

-- Button under "Temple Upgrades"
local openButton = button({
	Position = UDim2.fromOffset(12, 210), Size = UDim2.fromOffset(290, 40),
	BackgroundColor3 = THEME.Forge, Text = "Weapons", TextSize = 17, Parent = gui,
})
stroke(THEME.Bronze, 2).Parent = openButton

local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 520),
	BackgroundColor3 = THEME.Marble, Visible = false, Parent = gui,
}, { corner(12), stroke(THEME.Forge, 3), padding(14) })
text({ Size = UDim2.new(1, -50, 0, 36), Font = Enum.Font.Garamond, TextSize = 34, Text = "Weapons", Parent = panel })
local closeButton = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = THEME.Bronze, Text = "X", TextSize = 20, Parent = panel })
local myTab = button({ Position = UDim2.fromOffset(0, 42), Size = UDim2.fromOffset(160, 34), BackgroundColor3 = THEME.Forge, Text = "My Weapons", Parent = panel })
local forgeTab = button({ Position = UDim2.fromOffset(170, 42), Size = UDim2.fromOffset(160, 34), BackgroundColor3 = THEME.Locked, Text = "Forge", Parent = panel })
text({ Position = UDim2.fromOffset(340, 46), Size = UDim2.new(1, -340, 0, 28), TextSize = 13, TextColor3 = THEME.SubText, TextWrapped = true, Text = "Crafting and upgrading happen at the Divine Forge (east of the plaza).", Parent = panel })

local list = create("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 1, -84), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, ScrollBarImageColor3 = THEME.Bronze, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel,
}, { create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }), create("UIPadding", { PaddingRight = UDim.new(0, 10) }) })

local currentTab = "Mine"

local function owned()
	local ok, items = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("WeaponsJson") or "[]")
	end)
	return if ok then items else {}
end

local function statsLine(weapon, level)
	local kind = WeaponConfig.Types[weapon.Type]
	local parts = {
		weapon.Type,
		("Power x%.2f"):format(WeaponConfig.Power(weapon.Id, level)),
		("Speed %.2fs"):format(kind.Cooldown * weapon.Speed),
		("Reach %d"):format(kind.Range),
	}
	local special = weapon.Special or {}
	if special.CritChance then
		table.insert(parts, ("Crit %d%%"):format(special.CritChance * 100))
	end
	if special.LifeSteal then
		table.insert(parts, ("Life steal %d%%"):format(special.LifeSteal * 100))
	end
	if special.Pierce then
		table.insert(parts, ("Pierces %d"):format(special.Pierce))
	end
	if special.ExtraTargets then
		table.insert(parts, ("+%d targets"):format(special.ExtraTargets))
	end
	return table.concat(parts, " · ")
end

local function costText(gold, ambrosia)
	local t = Progression.FormatNumber(gold) .. " Gold"
	if ambrosia and ambrosia > 0 then
		t ..= " + " .. ambrosia .. " Ambrosia"
	end
	return t
end

local function row(order, weapon, level, subtitle)
	local rarity = WeaponConfig.Rarities[weapon.Rarity]
	local frame = create("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = THEME.MarbleDark, LayoutOrder = order, Parent = list }, { corner(8), padding(8), stroke(rarity.Color, 2) })
	text({ Size = UDim2.new(1, -250, 0, 22), Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = rarity.Color,
		Text = weapon.Name .. (if level and level > 0 then (" +%d"):format(level) else "") .. "   (" .. rarity.Name .. ")", Parent = frame })
	text({ Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -250, 0, 18), TextSize = 13, Text = statsLine(weapon, level or 0), Parent = frame })
	text({ Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, -250, 0, 16), TextSize = 12, TextColor3 = THEME.SubText, Text = subtitle or "", Parent = frame })
	return frame
end

local function refresh()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	myTab.BackgroundColor3 = if currentTab == "Mine" then THEME.Forge else THEME.Locked
	forgeTab.BackgroundColor3 = if currentTab == "Forge" then THEME.Forge else THEME.Locked
	local items = owned()
	local equippedUid = player:GetAttribute("EquippedWeaponUid")
	local gold = player:GetAttribute("Gold") or 0
	local ambrosia = player:GetAttribute("Ambrosia") or 0
	local training = player:GetAttribute("Temple_TrainingGrounds") or 0

	if currentTab == "Mine" then
		table.sort(items, function(a, b)
			local wa, wb = WeaponConfig.Weapons[a.Id], WeaponConfig.Weapons[b.Id]
			return (wa and wa.Rarity or 0) > (wb and wb.Rarity or 0)
		end)
		for i, item in items do
			local weapon = WeaponConfig.Weapons[item.Id]
			if weapon then
				local maxLevel = WeaponConfig.Rarities[weapon.Rarity].MaxLevel
				local upGold, upAmbrosia = WeaponConfig.UpgradeCost(item.Id, item.Level, training)
				local frame = row(i, weapon, item.Level, if upGold then ("Next upgrade: %s (level %d/%d)"):format(costText(upGold, upAmbrosia), item.Level, maxLevel) else "Fully upgraded")
				local isEquipped = item.Uid == equippedUid
				local equip = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -124, 0.5, 0), Size = UDim2.fromOffset(110, 44),
					BackgroundColor3 = if isEquipped then THEME.Gold else THEME.Ready, Text = if isEquipped then "Equipped" else "Equip", Parent = frame })
				equip.Activated:Connect(function()
					if not isEquipped then
						weaponRemote:FireServer("Equip", item.Uid)
					end
				end)
				local canAfford = upGold ~= nil and gold >= upGold and ambrosia >= (upAmbrosia or 0)
				local upgrade = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(116, 44),
					BackgroundColor3 = if canAfford then THEME.Forge else THEME.Locked, Text = if upGold then "Upgrade" else "MAX", Parent = frame })
				upgrade.Activated:Connect(function()
					if upGold then
						weaponRemote:FireServer("Upgrade", item.Uid)
					end
				end)
			end
		end
	else
		local ownedIds = {}
		for _, item in items do
			ownedIds[item.Id] = true
		end
		for i, id in WeaponConfig.Order do
			local weapon = WeaponConfig.Weapons[id]
			local source
			if id == WeaponConfig.StarterWeapon then
				source = "Everyone starts with this."
			elseif weapon.Cost then
				source = "Craft: " .. costText(weapon.Cost.Gold or 0, weapon.Cost.Ambrosia)
			elseif weapon.Drop then
				local boss = CombatConfig.Enemies[weapon.Drop.Boss]
				source = ("Dropped by %s (%d%% when you win)"):format(boss and boss.DisplayName or weapon.Drop.Boss, weapon.Drop.Chance * 100)
			end
			local frame = row(i, weapon, 0, source)
			local have = ownedIds[id] == true
			if have then
				button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(116, 44), BackgroundColor3 = THEME.Gold, Text = "Owned", AutoButtonColor = false, Parent = frame })
			elseif weapon.Cost then
				local canAfford = gold >= (weapon.Cost.Gold or 0) and ambrosia >= (weapon.Cost.Ambrosia or 0)
				local craft = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(116, 44),
					BackgroundColor3 = if canAfford then THEME.Forge else THEME.Locked, Text = "Craft", Parent = frame })
				craft.Activated:Connect(function()
					weaponRemote:FireServer("Craft", id)
				end)
			end
		end
	end
end

for _, attribute in { "WeaponsJson", "EquippedWeaponUid", "Gold", "Ambrosia", "Temple_TrainingGrounds" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		if panel.Visible then
			refresh()
		end
	end)
end

local function open(tab)
	currentTab = tab
	refresh()
	panel.Visible = true
end
openButton.Activated:Connect(function()
	if panel.Visible then
		panel.Visible = false
	else
		open("Mine")
	end
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
myTab.Activated:Connect(function()
	open("Mine")
end)
forgeTab.Activated:Connect(function()
	open("Forge")
end)
notifyRemote.OnClientEvent:Connect(function(kind, tab)
	if kind == "OpenWeapons" then
		open(if tab == "Forge" then "Forge" else "Mine")
	end
end)
