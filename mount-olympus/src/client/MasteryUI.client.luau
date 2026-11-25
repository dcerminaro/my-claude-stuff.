-- MasteryUI (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > MasteryUI
--
-- Phase 7E part 3:
--   * "Mastery" button (left, under Quests) -> Divine Mastery panel: your
--     god's mastery level, XP bar, bonuses, cosmetic unlocks, every god's
--     level, and Divine Incarnation info.
--   * Incarnate button (Elder God): fills with Divine Energy; when full, tap
--     it (or press T) to transform. Sits above the ability buttons.
-- Display only: the server tracks everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MasteryConfig = require(Shared:WaitForChild("MasteryConfig"))
local GodConfig = require(Shared:WaitForChild("GodConfig"))
local Progression = require(Shared:WaitForChild("Progression"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local incarnationRemote = Remotes:WaitForChild("IncarnationAction")

local INC = MasteryConfig.Incarnation

local THEME = {
	Marble = Color3.fromRGB(246, 242, 232),
	MarbleDark = Color3.fromRGB(228, 220, 204),
	Gold = Color3.fromRGB(212, 175, 55),
	Bronze = Color3.fromRGB(140, 92, 45),
	Text = Color3.fromRGB(58, 44, 28),
	SubText = Color3.fromRGB(110, 95, 75),
	White = Color3.new(1, 1, 1),
	Ready = Color3.fromRGB(70, 150, 70),
	Locked = Color3.fromRGB(150, 150, 158),
	Bar = Color3.fromRGB(200, 190, 170),
	Mastery = Color3.fromRGB(120, 80, 170),
	Dark = Color3.fromRGB(35, 30, 45),
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


local gui = create("ScreenGui", { Name = "MasteryUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 8, Enabled = false, Parent = playerGui })
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


local function readMastery()
	local raw = player:GetAttribute("MasteryJson")
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and type(decoded) == "table" then decoded else { God = "", Level = 0, XP = 0, Need = 0, Levels = {} }
end

local function godColors()
	local god = readMastery().God
	return GodConfig.GetColors(god or "")
end

--------------------------------------------------------------------------
-- 1. Mastery button and panel
--------------------------------------------------------------------------
local openButton = button({
	Position = UDim2.fromOffset(12, 306), Size = UDim2.fromOffset(290, 40),
	BackgroundColor3 = THEME.Mastery, Text = "Divine Mastery", TextSize = 17, Parent = gui,
})
stroke(THEME.Bronze, 2).Parent = openButton

local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(680, 520),
	BackgroundColor3 = THEME.Marble, Visible = false, Parent = gui,
}, { corner(12), stroke(THEME.Mastery, 3), padding(14) })
local title = text({ Size = UDim2.new(1, -50, 0, 36), Font = Enum.Font.Garamond, TextSize = 32, Text = "Divine Mastery", Parent = panel })
local closeButton = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = THEME.Bronze, Text = "X", TextSize = 20, Parent = panel })
local xpBack = create("Frame", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = THEME.Bar, BorderSizePixel = 0, Parent = panel }, { corner(6) })
local xpFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.Mastery, BorderSizePixel = 0, Parent = xpBack }, { corner(6) })
local xpText = text({ Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 18), TextSize = 13, TextColor3 = THEME.SubText, Text = "", Parent = panel })
local bonusText = text({ Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 20), Font = Enum.Font.GothamBold, TextSize = 15, Text = "", Parent = panel })

local list = create("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 1, -108), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, ScrollBarImageColor3 = THEME.Bronze, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel,
}, { create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }), create("UIPadding", { PaddingRight = UDim.new(0, 10) }) })

local function section(name, order)
	text({ Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.Garamond, TextSize = 22, TextColor3 = THEME.Bronze, Text = name, LayoutOrder = order, Parent = list })
end

local function renderPanel()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local m = readMastery()
	local god = GodConfig.Gods[m.God]
	local godName = if god then god.DisplayName else "your god"
	if not god then
		title.Text = "Divine Mastery"
		xpFill.Size = UDim2.fromScale(0, 1)
		xpText.Text = "Choose a god in the Hall of the Gods to start earning mastery."
		bonusText.Text = ""
		return
	end
	title.Text = ("%s Mastery   Lv %d/%d"):format(godName, m.Level, MasteryConfig.MaxLevel)
	if m.Level >= MasteryConfig.MaxLevel then
		xpFill.Size = UDim2.fromScale(1, 1)
		xpText.Text = "Mastery complete!"
	else
		xpFill.Size = UDim2.fromScale(math.clamp(m.XP / math.max(1, m.Need), 0, 1), 1)
		xpText.Text = ("%s / %s mastery XP · earn it by defeating enemies, winning arenas and challenges, worshipping and using %s's abilities"):format(
			Progression.FormatNumber(m.XP), Progression.FormatNumber(m.Need), godName)
	end
	xpFill.BackgroundColor3 = godColors().Accent
	bonusText.Text = ("Bonus: +%.1f%% attack, +%.1f%% health (max +%d%% at level %d)"):format(
		m.Level * MasteryConfig.AttackPercentPerLevel, m.Level * MasteryConfig.HealthPercentPerLevel,
		MasteryConfig.MaxLevel * MasteryConfig.AttackPercentPerLevel, MasteryConfig.MaxLevel)

	local order = 0
	order += 1
	section("Unlocks for " .. godName, order)
	for _, unlock in MasteryConfig.Unlocks do
		order += 1
		local done = m.Level >= unlock.Level
		local row = create("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = THEME.MarbleDark, LayoutOrder = order, Parent = list }, { corner(8), padding(6) })
		text({ Size = UDim2.new(1, -110, 0, 18), Font = Enum.Font.GothamBold, TextSize = 15, Text = unlock.Name, Parent = row })
		text({ Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, -110, 0, 16), TextSize = 12, TextColor3 = THEME.SubText, TextTruncate = Enum.TextTruncate.AtEnd, Text = unlock.Description:gsub("<God>", godName), Parent = row })
		text({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(105, 20), Font = Enum.Font.GothamBold, TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = if done then THEME.Ready else THEME.Locked,
			Text = if done then "Unlocked" else ("Level %d"):format(unlock.Level), Parent = row })
	end

	order += 1
	section("Divine Incarnation", order)
	local form = MasteryConfig.Forms[m.God] or MasteryConfig.DefaultForm
	local unlocked = player:GetAttribute("IncarnationUnlocked") == true
	local seconds = INC.BaseDuration + INC.DurationPerMastery * m.Level
	order += 1
	text({
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 14, TextWrapped = true, LayoutOrder = order, Parent = list,
		Text = ("%s: %s\nFill Divine Energy by hitting and defeating enemies (bosses give a lot), then press Incarnate%s. You transform for %.0f seconds: an opening blast, +%d%% health back, +%d%% attack, +%d%% speed, %d%% less damage taken. Higher mastery = longer."):format(
			form.Name, if unlocked then "unlocked!" else "unlocks at Elder God",
			if UserInputService.KeyboardEnabled then " (or press T)" else "",
			seconds, INC.HealPercent, form.AttackPercent or 0, form.SpeedPercent or 0, math.floor((1 - (form.DamageTaken or 1)) * 100 + 0.5)),
	})

	order += 1
	section("All gods", order)
	for godId, info in GodConfig.Gods do
		order += 1
		local level = (m.Levels and m.Levels[godId]) or 1
		text({ Size = UDim2.new(1, 0, 0, 20), TextSize = 14, LayoutOrder = order, Parent = list,
			Text = ("%s  ·  mastery level %d%s"):format(info.DisplayName, level, if godId == m.God then "  (current)" else "") })
	end
end

openButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		renderPanel()
	end
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
player:GetAttributeChangedSignal("MasteryJson"):Connect(function()
	if panel.Visible then
		renderPanel()
	end
end)

--------------------------------------------------------------------------
-- 2. Incarnate button (above the ability buttons)
--------------------------------------------------------------------------
local incGui = create("ScreenGui", { Name = "IncarnationUI", ResetOnSpawn = false, DisplayOrder = 7, Parent = playerGui })
local incButton = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = THEME.Dark, AutoButtonColor = false, Text = "", Visible = false, Parent = incGui,
}, { corner(10), stroke(THEME.Gold, 2) })
local incFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.Gold, BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = incButton }, { corner(10) })
local incLabel = create("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = THEME.White,
	TextStrokeTransparency = 0.4, Text = "", ZIndex = 2, Parent = incButton,
}, { create("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }) })

local function layout()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	if UserInputService.TouchEnabled then
		-- Same geometry as AbilityController's touch buttons, one row above them.
		local big = math.min(viewport.X, viewport.Y) > 500
		local jumpSize = if big then 120 else 70
		local jumpLeft = if big then 170 else 95
		local jumpTop = if big then 210 else 90
		local jumpCenterY = jumpTop - jumpSize / 2
		local gap = if big then 16 else 10
		local attackSize = math.floor(jumpSize * 1.05)
		local size = math.floor(jumpSize * 0.75)
		local qX = jumpLeft + gap + attackSize + gap + size / 2
		local rX = qX + size + gap
		local highY = jumpCenterY + size + gap
		local height = math.floor(size * 0.55)
		incButton.Size = UDim2.fromOffset(size * 2 + gap, height)
		incButton.Position = UDim2.new(1, -(qX + rX) / 2, 1, -(highY + size / 2 + gap + height / 2))
	else
		incButton.Size = UDim2.fromOffset(220, 40)
		incButton.Position = UDim2.new(0.5, 0, 1, -(24 + 24 + 14 + 68 + 12 + 20))
	end
end
layout()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end

local function activate()
	if player:GetAttribute("IncarnationUnlocked") == true then
		incarnationRemote:FireServer("Activate")
	end
end
incButton.Activated:Connect(activate)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == INC.Key then
		activate()
	end
end)

RunService.Heartbeat:Connect(function()
	local unlocked = player:GetAttribute("IncarnationUnlocked") == true and player:GetAttribute("DataLoaded") == true
	incButton.Visible = unlocked
	if not unlocked then
		return
	end
	local left = (player:GetAttribute("IncarnationUntil") or 0) - Workspace:GetServerTimeNow()
	local colors = godColors()
	if left > 0 then
		incFill.Size = UDim2.fromScale(math.clamp(left / (INC.BaseDuration + INC.DurationPerMastery * MasteryConfig.MaxLevel), 0, 1), 1)
		incFill.BackgroundColor3 = colors.Glow or colors.Accent
		incLabel.Text = ("%s  %ds"):format(player:GetAttribute("IncarnationForm") or "Divine Form", math.ceil(left))
		return
	end
	local value = player:GetAttribute("DivineEnergy") or 0
	local full = value >= INC.EnergyMax
	incFill.Size = UDim2.fromScale(math.clamp(value / INC.EnergyMax, 0, 1), 1)
	incFill.BackgroundColor3 = if full then THEME.Gold else colors.Accent
	incFill.BackgroundTransparency = if full then 0.1 + 0.25 * math.abs(math.sin(os.clock() * 4)) else 0.35
	incLabel.Text = if full then "INCARNATE!" else ("Divine Energy %d%%"):format(math.floor(value / INC.EnergyMax * 100))
end)

-- Big title when you transform
local banner = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(700, 70),
	BackgroundTransparency = 1, Font = Enum.Font.Garamond, TextSize = 56, TextColor3 = THEME.Gold, TextStrokeTransparency = 0.2,
	TextTransparency = 1, TextStrokeColor3 = Color3.new(0, 0, 0), Text = "", Parent = incGui,
})
local lastUntil = 0
player:GetAttributeChangedSignal("IncarnationUntil"):Connect(function()
	local untilTime = player:GetAttribute("IncarnationUntil") or 0
	if untilTime > lastUntil and untilTime > Workspace:GetServerTimeNow() then
		local colors = godColors()
		banner.Text = string.upper(player:GetAttribute("IncarnationForm") or "Divine Form")
		banner.TextColor3 = colors.Accent
		banner.TextTransparency = 0
		banner.TextStrokeTransparency = 0.2
		TweenService:Create(banner, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end
	lastUntil = untilTime
end)
