-- CombatController (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > CombatController
--
-- The client side of combat. It only handles input, animation and effects;
-- the server decides hits, damage, cooldowns and rewards.
--   Attack: left mouse button / R2 / on-screen "Attack" button
--   Block:  hold F / L2 / hold on-screen "Block" button
--   Dash:   Left Shift / B / on-screen "Dash" button
-- Also draws the health bar, swing effects, damage numbers and reward text.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local GodConfig = require(Shared:WaitForChild("GodConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local attackRemote = Remotes:WaitForChild("CombatAttack")
local blockRemote = Remotes:WaitForChild("CombatBlock")
local dashRemote = Remotes:WaitForChild("CombatDash")
local fxRemote = Remotes:WaitForChild("CombatFX")

local CFG = CombatConfig.Player
local ATTACK_ANIMATION = "rbxassetid://522635514" -- Roblox's default R15 sword slash

-- Our own health bar replaces Roblox's default one.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

--------------------------------------------------------------------------
-- Character helpers
--------------------------------------------------------------------------
local attackTrack = nil

local function getParts()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return character, humanoid, root
	end
	return nil
end

local function godColor()
	return GodConfig.GetColors(player:GetAttribute("SelectedGod") or "").Primary
end

local function loadAttackTrack(character)
	attackTrack = nil
	local humanoid = character:WaitForChild("Humanoid", 10)
	local animator = humanoid and humanoid:WaitForChild("Animator", 10)
	if animator then
		pcall(function()
			local animation = Instance.new("Animation")
			animation.AnimationId = ATTACK_ANIMATION
			attackTrack = animator:LoadAnimation(animation)
		end)
	end
end
player.CharacterAdded:Connect(loadAttackTrack)
if player.Character then
	task.spawn(loadAttackTrack, player.Character)
end

--------------------------------------------------------------------------
-- Effects folder (client only)
--------------------------------------------------------------------------
local fxFolder = Instance.new("Folder")
fxFolder.Name = "ClientEffects"
fxFolder.Parent = Workspace

local function anchoredPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	for key, value in props do
		part[key] = value
	end
	part.Parent = fxFolder
	return part
end

-- A glowing arc sweeping in front of the player.
local function slashEffect(root)
	local color = godColor()
	local pivot = root.CFrame * CFrame.new(0, 0.3, 0)
	local blade = anchoredPart({
		Size = Vector3.new(0.2, 0.3, CFG.BasicAttack.Range),
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.2,
	})
	local startAngle, endAngle = math.rad(70), math.rad(-70)
	local value = Instance.new("NumberValue")
	value.Value = startAngle
	value.Changed:Connect(function(angle)
		blade.CFrame = pivot * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -CFG.BasicAttack.Range / 2)
	end)
	blade.CFrame = pivot * CFrame.Angles(0, startAngle, 0) * CFrame.new(0, 0, -CFG.BasicAttack.Range / 2)
	TweenService:Create(value, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Value = endAngle }):Play()
	TweenService:Create(blade, TweenInfo.new(0.25), { Transparency = 1 }):Play()
	Debris:AddItem(blade, 0.3)
	Debris:AddItem(value, 0.3)
end

local function burst(position, color, count, speed)
	local holder = anchoredPart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = position })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Lifetime = NumberRange.new(0.25, 0.5)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.35, 0)
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)
	Debris:AddItem(holder, 1)
end

local DAMAGE_COLORS = {
	Enemy = Color3.fromRGB(255, 235, 120),
	Player = Color3.fromRGB(255, 80, 70),
	Blocked = Color3.fromRGB(120, 190, 255),
	Dodged = Color3.fromRGB(200, 255, 200),
}

local function floatingText(position, textValue, color, size, rise)
	local holder = anchoredPart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = position })
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 40)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = textValue
	label.Parent = billboard
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffset = Vector3.new(0, rise, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(holder, 1)
end

fxRemote.OnClientEvent:Connect(function(kind, position, value, style)
	if typeof(position) ~= "Vector3" then
		return
	end
	if kind == "Damage" then
		local jitter = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 2
		local label = if style == "Dodged" then "Dodged!" elseif style == "Blocked" then ("%d (blocked)"):format(value) else tostring(value)
		floatingText(position + jitter, label, DAMAGE_COLORS[style] or DAMAGE_COLORS.Enemy, if style == "Enemy" then 26 else 22, 3)
	elseif kind == "Hit" then
		burst(position, godColor(), 12, 14)
	elseif kind == "Death" then
		burst(position, Color3.fromRGB(230, 230, 230), 30, 10)
	elseif kind == "Reward" then
		floatingText(position + Vector3.new(0, 4, 0), tostring(value), Color3.fromRGB(212, 175, 55), 24, 4)
	end
end)

--------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------
local nextAttackAt, nextDashAt = 0, 0
local blocking = false

local function canAct()
	return player:GetAttribute("DataLoaded") == true and getParts() ~= nil
end

local function attack()
	if not canAct() or blocking then
		return
	end
	local now = os.clock()
	if now < nextAttackAt then
		return
	end
	nextAttackAt = now + CFG.BasicAttack.Cooldown
	local _, _, root = getParts()
	if attackTrack then
		attackTrack:Play(0.05)
	end
	slashEffect(root)
	attackRemote:FireServer()
end

local function setBlock(on)
	if on == blocking then
		return
	end
	if on and not canAct() then
		return
	end
	blocking = on
	blockRemote:FireServer(on)
end

local function dash()
	if not canAct() or blocking then
		return
	end
	local now = os.clock()
	if now < nextDashAt then
		return
	end
	nextDashAt = now + CFG.Dash.Cooldown
	local _, humanoid, root = getParts()
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit

	-- Your own character is simulated on your device, so the push happens here.
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.new(direction.X, direction.Z) * CFG.Dash.Speed
	velocity.MaxForce = 100000
	velocity.Parent = root
	Debris:AddItem(velocity, CFG.Dash.Duration)
	Debris:AddItem(attachment, CFG.Dash.Duration)

	burst(root.Position, godColor(), 16, 8)
	dashRemote:FireServer()
end

--------------------------------------------------------------------------
-- Input bindings (keyboard, controller and touch buttons)
--------------------------------------------------------------------------
local function onAttack(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		attack()
	end
	return Enum.ContextActionResult.Sink
end

local function onBlock(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		setBlock(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		setBlock(false)
	end
	return Enum.ContextActionResult.Sink
end

local function onDash(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		dash()
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("OlympusAttack", onAttack, true, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("OlympusBlock", onBlock, true, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
ContextActionService:BindAction("OlympusDash", onDash, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonB)
ContextActionService:SetTitle("OlympusAttack", "Attack")
ContextActionService:SetTitle("OlympusBlock", "Block")
ContextActionService:SetTitle("OlympusDash", "Dash")
-- Touch buttons sit around the jump button (bottom right).
ContextActionService:SetPosition("OlympusAttack", UDim2.new(1, -170, 1, -150))
ContextActionService:SetPosition("OlympusBlock", UDim2.new(1, -240, 1, -95))
ContextActionService:SetPosition("OlympusDash", UDim2.new(1, -110, 1, -210))

-- Left mouse button attacks, unless the click was on a menu or button.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
		attack()
	end
end)

-- Releasing block if the character dies or respawns.
player.CharacterRemoving:Connect(function()
	blocking = false
end)

--------------------------------------------------------------------------
-- Health bar (bottom centre)
--------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "CombatHUD"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = playerGui

local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function updateScale()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	uiScale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.7, 1.2)
end
updateScale()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local barBack = Instance.new("Frame")
barBack.Name = "HealthBar"
barBack.AnchorPoint = Vector2.new(0.5, 1)
barBack.Position = UDim2.new(0.5, 0, 1, -24)
barBack.Size = UDim2.fromOffset(340, 24)
barBack.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
barBack.Parent = gui
local backCorner = Instance.new("UICorner")
backCorner.CornerRadius = UDim.new(0, 8)
backCorner.Parent = barBack
local backStroke = Instance.new("UIStroke")
backStroke.Color = Color3.fromRGB(212, 175, 55)
backStroke.Thickness = 2
backStroke.Parent = barBack

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = Color3.fromRGB(200, 55, 50)
barFill.Parent = barBack
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 8)
fillCorner.Parent = barFill

local barText = Instance.new("TextLabel")
barText.Size = UDim2.fromScale(1, 1)
barText.BackgroundTransparency = 1
barText.Font = Enum.Font.GothamBold
barText.TextSize = 15
barText.TextColor3 = Color3.new(1, 1, 1)
barText.TextStrokeTransparency = 0.4
barText.ZIndex = 2
barText.Parent = barBack

local healthConnections = {}
local function trackHumanoid(humanoid)
	for _, c in healthConnections do
		c:Disconnect()
	end
	healthConnections = {}
	local function update()
		local ratio = if humanoid.MaxHealth > 0 then math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) else 0
		TweenService:Create(barFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(ratio, 1) }):Play()
		barText.Text = ("HP %d / %d"):format(math.ceil(humanoid.Health), humanoid.MaxHealth)
	end
	table.insert(healthConnections, humanoid.HealthChanged:Connect(update))
	table.insert(healthConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update))
	update()
end

local function onCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		trackHumanoid(humanoid)
	end
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

local function updateEnabled()
	gui.Enabled = player:GetAttribute("DataLoaded") == true
end
player:GetAttributeChangedSignal("DataLoaded"):Connect(updateEnabled)
updateEnabled()
