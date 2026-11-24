-- CombatController (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > CombatController
--
-- The client side of combat. It only handles input, animation and effects;
-- the server decides hits, damage, cooldowns and rewards.
--   Attack: left mouse button / R2 / on-screen "Attack" button (hold to keep swinging)
--   Block:  hold F / L2 / hold on-screen "Block" button
--   Dash:   Left Shift / B / on-screen "Dash" button
-- On touch screens the buttons are laid out around Roblox's jump button.
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
-- Roblox's own default R15 sword animations (free for every game).
local SLASH_ANIMATION = "rbxassetid://522635514"
local LUNGE_ANIMATION = "rbxassetid://522638767"
local COMBO_RESET = 1.2 -- seconds; the combo starts over after a pause
local LUNGE_SPEED = 24  -- small step forward on the 3rd hit of the combo

-- Our own health bar replaces Roblox's default one, and the sword is always
-- held, so the backpack bar isn't needed.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

--------------------------------------------------------------------------
-- Character helpers
--------------------------------------------------------------------------
local comboTracks = {} -- slash, slash, lunge
local comboIndex = 0
local lastAttackAt = 0

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
	comboTracks = {}
	comboIndex = 0
	local humanoid = character:WaitForChild("Humanoid", 10)
	local animator = humanoid and humanoid:WaitForChild("Animator", 10)
	if not animator then
		return
	end
	local function load(id)
		local ok, track = pcall(function()
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local t = animator:LoadAnimation(animation)
			t.Priority = Enum.AnimationPriority.Action
			return t
		end)
		return if ok then track else nil
	end
	local slash = load(SLASH_ANIMATION)
	comboTracks = { slash, slash, load(LUNGE_ANIMATION) }
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

-- Show the sword's light trail straight away on your own screen
-- (the server turns it on for everyone else).
local function flashTrail()
	local character = player.Character
	local tool = character and character:FindFirstChild("DivineSword")
	local handle = tool and tool:FindFirstChild("Handle")
	local trail = handle and handle:FindFirstChild("SwingTrail")
	if trail then
		trail.Enabled = true
		task.delay(0.3, function()
			trail.Enabled = false
		end)
	end
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
	KnockedOut = Color3.fromRGB(255, 255, 255),
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
		local label = if style == "Dodged"
			then "Dodged!"
			elseif style == "KnockedOut" then "Knocked out!"
			elseif style == "Blocked" then ("%d (blocked)"):format(value)
			else tostring(value)
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

	-- Combo: slash, slash, lunge. Starts over after a short pause.
	if now - lastAttackAt > COMBO_RESET then
		comboIndex = 0
	end
	lastAttackAt = now
	comboIndex = comboIndex % 3 + 1
	local track = comboTracks[comboIndex]
	if track then
		track:Play(0.05, 1, 1.15)
	end
	if comboIndex == 3 then
		-- A small step forward on the lunge.
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local push = Instance.new("LinearVelocity")
		push.Attachment0 = attachment
		push.RelativeTo = Enum.ActuatorRelativeTo.World
		push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		push.PrimaryTangentAxis = Vector3.xAxis
		push.SecondaryTangentAxis = Vector3.zAxis
		local look = root.CFrame.LookVector
		push.PlaneVelocity = Vector2.new(look.X, look.Z).Unit * LUNGE_SPEED
		push.MaxForce = 60000
		push.Parent = root
		Debris:AddItem(push, 0.12)
		Debris:AddItem(attachment, 0.12)
	end
	flashTrail()
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

-- Keyboard and controller (no Roblox touch buttons: we draw our own below).
ContextActionService:BindAction("OlympusAttack", onAttack, false, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("OlympusBlock", onBlock, false, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
ContextActionService:BindAction("OlympusDash", onDash, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonB)

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

--------------------------------------------------------------------------
-- Touch buttons (phones and tablets), placed around the jump button
--------------------------------------------------------------------------
local touchGui = Instance.new("ScreenGui")
touchGui.Name = "CombatTouchButtons"
touchGui.ResetOnSpawn = false
touchGui.Enabled = false
touchGui.Parent = playerGui

local function touchButton(name, label, color)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.BackgroundColor3 = color
	b.BackgroundTransparency = 0.25
	b.Text = label
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0) -- round
	c.Parent = b
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(212, 175, 55)
	st.Thickness = 2
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.18, 0)
	pad.PaddingRight = UDim.new(0.18, 0)
	pad.PaddingTop = UDim.new(0.3, 0)
	pad.PaddingBottom = UDim.new(0.3, 0)
	pad.Parent = b
	b.Parent = touchGui
	return b
end

local attackButton = touchButton("Attack", "Attack", Color3.fromRGB(170, 60, 45))
local blockButton = touchButton("Block", "Block", Color3.fromRGB(60, 110, 180))
local dashButton = touchButton("Dash", "Dash", Color3.fromRGB(90, 140, 70))

-- Roblox's jump button: 120 px on big screens (bottom-right corner 170 px in,
-- 210 px up), 70 px on small screens (95 px in, 90 px up). Our buttons go
-- to its left and above it so they never overlap.
local function layoutTouchButtons()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local big = math.min(viewport.X, viewport.Y) > 500
	local jumpSize = if big then 120 else 70
	local jumpLeft = if big then 170 else 95 -- distance from the right edge to the jump button's left side
	local jumpTop = if big then 210 else 90 -- distance from the bottom edge to the jump button's top
	local jumpCenterX = jumpLeft - jumpSize / 2
	local jumpCenterY = jumpTop - jumpSize / 2
	local gap = if big then 16 else 10

	local attackSize = math.floor(jumpSize * 1.05)
	local smallSize = math.floor(jumpSize * 0.75)

	attackButton.Size = UDim2.fromOffset(attackSize, attackSize)
	attackButton.Position = UDim2.new(1, -(jumpLeft + gap + attackSize / 2), 1, -jumpCenterY)

	dashButton.Size = UDim2.fromOffset(smallSize, smallSize)
	dashButton.Position = UDim2.new(1, -jumpCenterX, 1, -(jumpTop + gap + smallSize / 2))

	blockButton.Size = UDim2.fromOffset(smallSize, smallSize)
	blockButton.Position = UDim2.new(1, -(jumpLeft + gap + attackSize / 2), 1, -(jumpCenterY + attackSize / 2 + gap + smallSize / 2))
end
layoutTouchButtons()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutTouchButtons)
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

-- Attack: tap, or hold to keep swinging.
local attackInput = nil
attackButton.InputBegan:Connect(function(input)
	if isPress(input) and not attackInput then
		attackInput = input
		task.spawn(function()
			while attackInput == input do
				attack()
				task.wait(0.1)
			end
		end)
	end
end)

-- Block: held for as long as your finger stays down.
local blockInput = nil
blockButton.InputBegan:Connect(function(input)
	if isPress(input) and not blockInput then
		blockInput = input
		setBlock(true)
		blockButton.BackgroundTransparency = 0
	end
end)

dashButton.InputBegan:Connect(function(input)
	if isPress(input) then
		dash()
	end
end)

-- A finger lifted anywhere ends the hold, even if it slid off the button.
UserInputService.InputEnded:Connect(function(input)
	if input == attackInput then
		attackInput = nil
	end
	if input == blockInput then
		blockInput = nil
		setBlock(false)
		blockButton.BackgroundTransparency = 0.25
	end
end)

-- Dim the Dash button while it recharges.
task.spawn(function()
	while true do
		task.wait(0.1)
		dashButton.BackgroundTransparency = if os.clock() < nextDashAt then 0.7 else 0.25
	end
end)

local function updateEnabled()
	local loaded = player:GetAttribute("DataLoaded") == true
	gui.Enabled = loaded
	touchGui.Enabled = loaded and UserInputService.TouchEnabled
end
player:GetAttributeChangedSignal("DataLoaded"):Connect(updateEnabled)
updateEnabled()
