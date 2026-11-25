-- Intro (LocalScript)
-- Location: ReplicatedFirst > Intro
--
-- Phase 8: the title screen. Runs before anything else loads:
--   1. A starry night with "MOUNT OLYMPUS - Rise of the Gods" in shimmering
--      gold while the game downloads.
--   2. When the world and your save are ready, the sky clears and the
--      camera glides around the summit of Olympus.
--   3. Tap "Enter Olympus" and the camera swoops down to your character.
-- The rest of the interface is hidden while the title screen is up.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local GOLD = Color3.fromRGB(212, 175, 55)
local CREAM = Color3.fromRGB(246, 238, 220)

local gui = Instance.new("ScreenGui")
gui.Name = "IntroScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 200
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function new(className, props)
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

-- Night sky backdrop
local backdrop = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 12, 30), BorderSizePixel = 0, Parent = gui })
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 30, 80), Color3.fromRGB(10, 8, 22)), Parent = backdrop })
local stars = {}
local random = Random.new()
for _ = 1, 90 do
	local size = random:NextInteger(1, 3)
	local star = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(random:NextNumber(), random:NextNumber() * 0.85),
		Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.fromRGB(255, 250, 230), BorderSizePixel = 0, Parent = backdrop,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = star })
	table.insert(stars, { Frame = star, Phase = random:NextNumber(0, 6.28), Speed = random:NextNumber(0.8, 2.2) })
end

-- Vignette shown during the fly-over (dark edges, clear centre)
local vignette = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
new("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.35, 1), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0.2) }),
	Parent = vignette,
})

-- Title
local title = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.86, 0.17),
	BackgroundTransparency = 1, Font = Enum.Font.Garamond, Text = "MOUNT OLYMPUS", TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 1, Parent = gui,
})
local titleShine = new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 140, 40)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 225, 140)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 252, 230)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 225, 140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 140, 40)),
	}),
	Parent = title,
})
new("UIStroke", { Color = Color3.fromRGB(60, 35, 10), Thickness = 2, Transparency = 0.2, Parent = title })
local subtitle = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromScale(0.5, 0.055),
	BackgroundTransparency = 1, Font = Enum.Font.Garamond, Text = "R I S E   O F   T H E   G O D S", TextScaled = true,
	TextColor3 = CREAM, Parent = gui,
})
new("UIStroke", { Color = Color3.fromRGB(20, 15, 30), Thickness = 1.5, Transparency = 0.3, Parent = subtitle })
for _, side in { -1, 1 } do
	local line = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + side * 0.33, 0.48), Size = UDim2.new(0.12, 0, 0, 2),
		BackgroundColor3 = GOLD, BorderSizePixel = 0, Parent = gui,
	})
	new("UIGradient", { Transparency = NumberSequence.new(if side < 0 then 1 else 0, if side < 0 then 0 else 1), Parent = line })
end

local status = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromScale(0.6, 0.035),
	BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, Text = "Ascending to the heavens...", TextScaled = true,
	TextColor3 = Color3.fromRGB(200, 190, 220), Parent = gui,
})
local enter = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromOffset(300, 64),
	BackgroundColor3 = GOLD, AutoButtonColor = true, Font = Enum.Font.Garamond, Text = "ENTER OLYMPUS", TextSize = 32,
	TextColor3 = Color3.fromRGB(40, 25, 10), Visible = false, Parent = gui,
})
new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = enter })
new("UIStroke", { Color = Color3.fromRGB(255, 240, 190), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = enter })
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 236, 160), Color3.fromRGB(200, 150, 50)), Parent = enter })

-- Animate stars, title shine and the button's pulse
local active = true
local renderConnection = RunService.RenderStepped:Connect(function()
	local t = os.clock()
	titleShine.Offset = Vector2.new(((t * 0.35) % 2) - 1, 0)
	for _, s in stars do
		s.Frame.BackgroundTransparency = 0.25 + 0.6 * (0.5 + 0.5 * math.sin(t * s.Speed + s.Phase))
	end
	if enter.Visible then
		local pulse = 1 + 0.04 * math.sin(t * 3)
		enter.Size = UDim2.fromOffset(300 * pulse, 64 * pulse)
	end
end)

-- Hide the rest of the interface while the title screen is up
local hidden = {}
task.spawn(function()
	while active do
		for _, other in playerGui:GetChildren() do
			if other:IsA("ScreenGui") and other ~= gui and other.Enabled then
				other.Enabled = false
				hidden[other] = true
			end
		end
		task.wait(0.15)
	end
end)

-- If anything goes wrong, never leave the player stuck on the title screen.
local function cleanup()
	active = false
	for other in hidden do
		if other.Parent then
			other.Enabled = true
		end
	end
	renderConnection:Disconnect()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
	if gui.Parent then
		gui:Destroy()
	end
end

local camera, orbitStart, orbiting, orbitConnection
local ok, err = pcall(function()
-- Wait for the world and the save
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local deadline = os.clock() + 25
while player:GetAttribute("DataLoaded") ~= true and os.clock() < deadline do
	task.wait(0.2)
end
Workspace:WaitForChild("Hub", 20)
task.wait(0.5)

-- Fly-over: clear the sky and circle the summit
camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
orbitStart = os.clock()
orbiting = true
orbitConnection = RunService.RenderStepped:Connect(function()
	if not orbiting then
		return
	end
	local t = os.clock() - orbitStart
	local angle = -0.9 + t * 0.07
	local position = Vector3.new(math.cos(angle) * 175, 78 + math.sin(t * 0.3) * 6, 40 + math.sin(angle) * 175)
	camera.CFrame = CFrame.lookAt(position, Vector3.new(0, 16, 30))
end)
TweenService:Create(backdrop, TweenInfo.new(2.5), { BackgroundTransparency = 1 }):Play()
for _, s in stars do
	TweenService:Create(s.Frame, TweenInfo.new(1.5), { Size = UDim2.fromOffset(0, 0) }):Play()
end
TweenService:Create(vignette, TweenInfo.new(2.5), { BackgroundTransparency = 0 }):Play()
TweenService:Create(title, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5, 0.2) }):Play()
TweenService:Create(subtitle, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5, 0.31) }):Play()
for _, child in gui:GetChildren() do
	if child:IsA("Frame") and child.Size.Y.Offset == 2 then
		TweenService:Create(child, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Position = UDim2.new(child.Position.X.Scale, 0, 0.31, 0) }):Play()
	end
end
status.Visible = false
enter.Position = UDim2.fromScale(0.5, 0.82)
enter.Visible = true

end)
if not ok then
	warn("[Intro] " .. tostring(err))
	cleanup()
	return
end

local entered = false
enter.Activated:Connect(function()
	if entered then
		return
	end
	entered = true
	enter.Visible = false
	local success = pcall(function()
	pcall(function()
		local Sfx = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Sfx"))
		Sfx.Play("Chimes")
	end)
	-- Swoop down to the character
	orbiting = false
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root then
		local target = CFrame.lookAt((root.CFrame * CFrame.new(0, 6, 14)).Position, root.Position + Vector3.new(0, 2, 0))
		local tween = TweenService:Create(camera, TweenInfo.new(1.6, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), { CFrame = target })
		tween:Play()
	end
	for _, item in gui:GetDescendants() do
		if item:IsA("TextLabel") or item:IsA("TextButton") then
			TweenService:Create(item, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
		elseif item:IsA("Frame") then
			TweenService:Create(item, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		end
	end
	task.wait(1.6)
	orbitConnection:Disconnect()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	end)
	if not success and orbitConnection then
		orbitConnection:Disconnect()
	end
	cleanup()
end)
