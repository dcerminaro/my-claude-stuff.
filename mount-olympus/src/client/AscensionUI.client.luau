-- AscensionUI (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > AscensionUI
--
-- Phase 6 interface:
--   * Ascension screen (from the altar in the Ascension Chamber): all 8 ranks
--     with what each one gives, your next trial, its requirements, and the
--     "Begin Trial" button.
--   * Lights up the chamber's rank pillars you have reached (on your screen).
--   * The rank-up effect: a pillar of light and a burst, seen by everyone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Progression = require(Shared:WaitForChild("Progression"))
local AscensionConfig = require(Shared:WaitForChild("AscensionConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ascensionRemote = Remotes:WaitForChild("AscensionAction")
local notifyRemote = Remotes:WaitForChild("Notify")
local fxRemote = Remotes:WaitForChild("CombatFX")

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
	Sky = Color3.fromRGB(120, 200, 255),
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

local gui = create("ScreenGui", { Name = "AscensionUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 8, Parent = playerGui })
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

--------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------
local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(660, 520),
	BackgroundColor3 = THEME.Marble,
	Visible = false,
	Parent = gui,
}, { corner(12), stroke(THEME.Sky, 3), padding(14) })
text({ Size = UDim2.new(1, -50, 0, 36), Font = Enum.Font.Garamond, TextSize = 34, Text = "Ascension", Parent = panel })
local closeButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = THEME.Bronze, Text = "X", Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = THEME.White, Parent = panel,
}, { corner(8) })

-- Next trial box
local trialBox = create("Frame", {
	Position = UDim2.fromOffset(0, 44),
	Size = UDim2.new(1, 0, 0, 104),
	BackgroundColor3 = Color3.fromRGB(222, 236, 248),
	Parent = panel,
}, { corner(10), padding(10) })
local trialTitle = text({ Size = UDim2.new(1, -170, 0, 24), Font = Enum.Font.GothamBold, TextSize = 18, Text = "", Parent = trialBox })
local trialDesc = text({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -170, 0, 36), TextSize = 14, TextColor3 = THEME.SubText, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Text = "", Parent = trialBox })
local trialReq = text({ Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, -170, 0, 20), Font = Enum.Font.GothamBold, TextSize = 14, Text = "", Parent = trialBox })
local trialButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(150, 56),
	BackgroundColor3 = THEME.Ready, Text = "Begin Trial", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = THEME.White, Parent = trialBox,
}, { corner(8) })

-- Rank list
local list = create("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 158),
	Size = UDim2.new(1, 0, 1, -158),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = THEME.Bronze,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = panel,
}, { create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }), create("UIPadding", { PaddingRight = UDim.new(0, 10) }) })

local rows = {}
for i, rank in GameConfig.Ranks do
	local row = create("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = THEME.MarbleDark, LayoutOrder = i, Parent = list }, { corner(8), padding(6) })
	create("Frame", { Size = UDim2.fromOffset(10, 40), BackgroundColor3 = rank.Color, Parent = row }, { corner(4) })
	text({ Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -150, 0, 20), Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = rank.Color, Text = ("%s   (levels %d-%d)"):format(rank.Name, rank.MinLevel, rank.MaxLevel), Parent = row })
	text({ Position = UDim2.fromOffset(18, 21), Size = UDim2.new(1, -150, 0, 18), TextSize = 13, TextColor3 = THEME.SubText, TextTruncate = Enum.TextTruncate.AtEnd, Text = AscensionConfig.Perks[i] or "", Parent = row })
	local status = text({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(130, 24), Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = row })
	rows[i] = status
end

local function refresh()
	local rankIndex = player:GetAttribute("RankIndex") or 1
	local level = player:GetAttribute("Level") or 1
	for i, status in rows do
		if i < rankIndex then
			status.Text = "Achieved"
			status.TextColor3 = THEME.Ready
		elseif i == rankIndex then
			status.Text = "Your rank"
			status.TextColor3 = THEME.Sky
		elseif i == rankIndex + 1 then
			status.Text = "Next"
			status.TextColor3 = THEME.Bronze
		else
			status.Text = "Locked"
			status.TextColor3 = THEME.Locked
		end
	end

	if rankIndex >= #GameConfig.Ranks then
		trialTitle.Text = "You are an Elder God!"
		trialDesc.Text = "You have completed every ascension."
		trialReq.Text = ""
		trialButton.Visible = false
		return
	end
	local nextRank = GameConfig.Ranks[rankIndex + 1]
	local trial = AscensionConfig.Trials[rankIndex + 1]
	local cap = Progression.GetLevelCap(rankIndex)
	trialTitle.Text = ("Become a %s: %s"):format(nextRank.Name, trial.Name)
	trialTitle.TextColor3 = nextRank.Color
	trialDesc.Text = trial.Description or ""
	local ready = level >= cap and trial.Available
	if level < cap then
		trialReq.Text = ("Reach level %d (you are level %d)"):format(cap, level)
		trialReq.TextColor3 = Color3.fromRGB(175, 55, 35)
	elseif not trial.Available then
		trialReq.Text = "This trial arrives in Phase 7"
		trialReq.TextColor3 = Color3.fromRGB(175, 55, 35)
	else
		trialReq.Text = "You are ready!"
		trialReq.TextColor3 = THEME.Ready
	end
	trialButton.Visible = true
	trialButton.BackgroundColor3 = if ready then THEME.Ready else THEME.Locked
	trialButton.AutoButtonColor = ready
end

for _, attribute in { "RankIndex", "Level" } do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end
refresh()

trialButton.Activated:Connect(function()
	ascensionRemote:FireServer("StartTrial") -- the server checks everything again
	panel.Visible = false
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)

notifyRemote.OnClientEvent:Connect(function(kind)
	if kind == "OpenAscension" then
		refresh()
		panel.Visible = true
	end
end)

--------------------------------------------------------------------------
-- Chamber pillars: the ranks you have reached glow in their colour
--------------------------------------------------------------------------
local function colourPillars()
	local hub = Workspace:FindFirstChild("Hub")
	local chamber = hub and hub:FindFirstChild("AscensionChamber")
	if not chamber then
		return
	end
	local rankIndex = player:GetAttribute("RankIndex") or 1
	for _, part in chamber:GetChildren() do
		local index = part:GetAttribute("RankIndex")
		if index then
			part.Color = if index <= rankIndex then GameConfig.Ranks[index].Color else Color3.fromRGB(150, 150, 160)
			part.Transparency = if index <= rankIndex then 0 else 0.4
		end
	end
end
player:GetAttributeChangedSignal("RankIndex"):Connect(colourPillars)
task.spawn(function()
	local hub = Workspace:WaitForChild("Hub", 30)
	if hub then
		hub:WaitForChild("AscensionChamber", 30)
		colourPillars()
	end
end)

--------------------------------------------------------------------------
-- Rank-up effect
--------------------------------------------------------------------------
local fxFolder = Workspace:FindFirstChild("ClientEffects") or Instance.new("Folder")
fxFolder.Name = "ClientEffects"
fxFolder.Parent = Workspace

local function effectPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	for key, value in props do
		part[key] = value
	end
	part.Parent = fxFolder
	return part
end

fxRemote.OnClientEvent:Connect(function(kind, position, color)
	if kind ~= "Ascend" or typeof(position) ~= "Vector3" or typeof(color) ~= "Color3" then
		return
	end
	local ground = position - Vector3.new(0, 3, 0)
	local pillar = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(80, 2, 2),
		CFrame = CFrame.new(ground + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 240, 190),
		Transparency = 0.2,
	})
	TweenService:Create(pillar, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(80, 9, 9) }):Play()
	task.delay(0.5, function()
		TweenService:Create(pillar, TweenInfo.new(1.4), { Transparency = 1, Size = Vector3.new(80, 12, 12) }):Play()
	end)
	Debris:AddItem(pillar, 2)

	local ring = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2, 2),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.2,
	})
	TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, 40, 40), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.9)

	local holder = effectPart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = position })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, Color3.fromRGB(255, 240, 190))
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.8, 1.5)
	emitter.Speed = NumberRange.new(10, 25)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 8, 0)
	emitter.Size = NumberSequence.new(0.6, 0)
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(60)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 240, 190)
	light.Range = 40
	light.Brightness = 5
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(1.5), { Brightness = 0 }):Play()
	Debris:AddItem(holder, 2)
end)
