-- AbilityController (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > AbilityController
--
-- Phase 4B, the device side of god abilities:
--   * Ability buttons with cooldown countdowns. Touch screens: round buttons
--     around the Attack button. Keyboard/controller: a bar above the health bar.
--     Keys: Q, E, R, T (Form); controller L1, R1, Y, D-pad up.
--   * Only abilities whose blessing you have unlocked (for your current god) show.
--   * Plays your own ability animation immediately and asks the server to use it;
--     the server decides whether it happens and what it hits.
--   * Draws ability effects for everyone: lightning bolts, chain lightning,
--     shockwaves, the cleave arc, dash trails and auras.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbilityConfig = require(Shared:WaitForChild("AbilityConfig"))
local GodConfig = require(Shared:WaitForChild("GodConfig"))
local SwordAnimator = require(Shared:WaitForChild("SwordAnimator"))

local AimHelper = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AimHelper"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local abilityRemote = Remotes:WaitForChild("UseAbility")
local fxRemote = Remotes:WaitForChild("CombatFX")

local SLOTS = AbilityConfig.SlotOrder

--------------------------------------------------------------------------
-- Which ability is in each slot right now
--------------------------------------------------------------------------
local function abilityForSlot(slot)
	local god = GodConfig.Gods[player:GetAttribute("SelectedGod") or ""]
	if not god then
		return nil
	end
	for _, blessing in god.Blessings do
		if blessing.Ability == slot then
			local level = player:GetAttribute("Blessing_" .. blessing.Id) or 0
			if level >= 1 then
				return blessing, AbilityConfig.Abilities[blessing.Id], level
			end
			return nil
		end
	end
	return nil
end

local function cooldownLeft(slot)
	return math.max(0, (player:GetAttribute("Cooldown_" .. slot) or 0) - Workspace:GetServerTimeNow())
end

local function alive()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local localReadyAt = {} -- stops double-presses before the server's answer arrives

local function useSlot(slot)
	if player:GetAttribute("DataLoaded") ~= true or not alive() or player:GetAttribute("Blocking") == true then
		return
	end
	local blessing, cfg = abilityForSlot(slot)
	if not blessing or not cfg then
		return
	end
	local now = os.clock()
	if cooldownLeft(slot) > 0.15 or now < (localReadyAt[slot] or 0) then
		return
	end
	localReadyAt[slot] = now + 0.5
	local character = player.Character
	local aim = AimHelper.FaceAim(character and character:FindFirstChild("HumanoidRootPart")) -- face the centre dot
	if cfg.Move then
		SwordAnimator.Play(player.Character, cfg.Move)
	end
	abilityRemote:FireServer(slot, aim)
end

--------------------------------------------------------------------------
-- Buttons
--------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "AbilityButtons"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = playerGui

local buttons = {}

local function makeButton(slot)
	local b = Instance.new("TextButton")
	b.Name = slot
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	b.BackgroundTransparency = 0.2
	b.Text = ""
	b.AutoButtonColor = false
	b.Visible = false
	b.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b

	-- Dark cover that shrinks as the cooldown runs out.
	local cover = Instance.new("Frame")
	cover.Name = "Cooldown"
	cover.AnchorPoint = Vector2.new(0.5, 1)
	cover.Position = UDim2.fromScale(0.5, 1)
	cover.Size = UDim2.fromScale(1, 0)
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BackgroundTransparency = 0.45
	cover.ZIndex = 2
	cover.Parent = b
	local coverCorner = Instance.new("UICorner")
	coverCorner.CornerRadius = UDim.new(1, 0)
	coverCorner.Parent = cover

	local name = Instance.new("TextLabel")
	name.Name = "AbilityName"
	name.AnchorPoint = Vector2.new(0.5, 0.5)
	name.Position = UDim2.fromScale(0.5, 0.5)
	name.Size = UDim2.fromScale(0.86, 0.5)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.ZIndex = 3
	name.Parent = b

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.AnchorPoint = Vector2.new(0.5, 0)
	key.Position = UDim2.fromScale(0.5, 0.04)
	key.Size = UDim2.fromScale(0.5, 0.22)
	key.BackgroundTransparency = 1
	key.Font = Enum.Font.GothamBlack
	key.TextScaled = true
	key.TextColor3 = Color3.fromRGB(255, 230, 150)
	key.TextStrokeTransparency = 0.4
	key.Text = AbilityConfig.KeyLabels[slot]
	key.ZIndex = 3
	key.Parent = b

	local timer = Instance.new("TextLabel")
	timer.Name = "Timer"
	timer.AnchorPoint = Vector2.new(0.5, 1)
	timer.Position = UDim2.fromScale(0.5, 0.96)
	timer.Size = UDim2.fromScale(0.6, 0.26)
	timer.BackgroundTransparency = 1
	timer.Font = Enum.Font.GothamBlack
	timer.TextScaled = true
	timer.TextColor3 = Color3.new(1, 1, 1)
	timer.TextStrokeTransparency = 0.2
	timer.Text = ""
	timer.ZIndex = 4
	timer.Parent = b

	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			useSlot(slot)
		end
	end)
	buttons[slot] = { Button = b, Stroke = stroke, Cover = cover, Name = name, Key = key, Timer = timer }
end
for _, slot in SLOTS do
	makeButton(slot)
end

-- Short names that fit on a round button.
local function shortName(blessingName)
	local words = string.split(blessingName, " ")
	if #words >= 3 then
		return words[1] .. "\n" .. words[2]
	end
	return table.concat(words, "\n")
end

local function layout()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local touch = UserInputService.TouchEnabled
	for _, b in buttons do
		b.Key.Visible = not touch
	end
	if touch then
		-- Same jump-button geometry as the Attack/Block/Dash buttons.
		local big = math.min(viewport.X, viewport.Y) > 500
		local jumpSize = if big then 120 else 70
		local jumpLeft = if big then 170 else 95
		local jumpTop = if big then 210 else 90
		local jumpCenterY = jumpTop - jumpSize / 2
		local gap = if big then 16 else 10
		local attackSize = math.floor(jumpSize * 1.05)
		local size = math.floor(jumpSize * 0.75)
		local attackX = jumpLeft + gap + attackSize / 2 -- distance from the right edge
		local qX = attackX + attackSize / 2 + gap + size / 2
		local rX = qX + size + gap
		local lowY = jumpCenterY
		local highY = jumpCenterY + size + gap
		local spots = { Q = { qX, lowY }, E = { qX, highY }, R = { rX, lowY }, Form = { rX, highY } }
		for slot, b in buttons do
			b.Button.Size = UDim2.fromOffset(size, size)
			b.Button.Position = UDim2.new(1, -spots[slot][1], 1, -spots[slot][2])
		end
	else
		-- A bar above the health bar (bottom centre).
		local size = 68
		local gap = 12
		local total = #SLOTS * size + (#SLOTS - 1) * gap
		for i, slot in SLOTS do
			local b = buttons[slot].Button
			b.Size = UDim2.fromOffset(size, size)
			b.Position = UDim2.new(0.5, -total / 2 + (i - 1) * (size + gap) + size / 2, 1, -(24 + 24 + 14 + size / 2))
		end
	end
end
layout()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end

local function refresh()
	local god = GodConfig.Gods[player:GetAttribute("SelectedGod") or ""]
	local color = if god then god.Colors.Primary else Color3.fromRGB(212, 175, 55)
	for slot, b in buttons do
		local blessing = abilityForSlot(slot)
		b.Button.Visible = blessing ~= nil
		if blessing then
			b.Name.Text = shortName(blessing.Name)
			b.Stroke.Color = color
		end
	end
	gui.Enabled = player:GetAttribute("DataLoaded") == true
end

local watched = { "SelectedGod", "DataLoaded" }
for blessingId in GodConfig.BlessingsById do
	table.insert(watched, "Blessing_" .. blessingId)
end
for _, attribute in watched do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end
refresh()

-- Cooldown countdowns
task.spawn(function()
	while true do
		task.wait(0.1)
		for slot, b in buttons do
			if b.Button.Visible then
				local _, cfg = abilityForSlot(slot)
				local left = cooldownLeft(slot)
				local total = if cfg then cfg.Cooldown else 1
				b.Cover.Size = UDim2.fromScale(1, math.clamp(left / total, 0, 1))
				b.Timer.Text = if left > 0.05 then tostring(math.ceil(left)) else ""
			end
		end
	end
end)

-- Keyboard and controller keys (touch uses the buttons above).
for _, slot in SLOTS do
	ContextActionService:BindAction("OlympusAbility" .. slot, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			useSlot(slot)
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(AbilityConfig.Keys[slot]))
end

--------------------------------------------------------------------------
-- Effects (drawn on this device)
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

local function fadeOut(part, time)
	TweenService:Create(part, TweenInfo.new(time), { Transparency = 1 }):Play()
	Debris:AddItem(part, time + 0.05)
end

-- A jagged lightning bolt from a to b.
local function bolt(a, b, color, thickness, life)
	local segments = math.max(3, math.floor((b - a).Magnitude / 4))
	local points = { a }
	for i = 1, segments - 1 do
		local t = i / segments
		local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3
		table.insert(points, a:Lerp(b, t) + jitter)
	end
	table.insert(points, b)
	for i = 1, #points - 1 do
		local p0, p1 = points[i], points[i + 1]
		local length = (p1 - p0).Magnitude
		local seg = effectPart({
			Size = Vector3.new(thickness, thickness, length),
			CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
			Color = color,
		})
		fadeOut(seg, life)
	end
end

local function lightFlash(position, color, range)
	local holder = effectPart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = position })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 4
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 0 }):Play()
	Debris:AddItem(holder, 0.4)
end

local function groundY(position)
	return position.Y - 2.9 -- character roots sit about 3 studs above the ground
end

local function shockwave(position, color, radius)
	local ring = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2, 2),
		CFrame = CFrame.new(position.X, groundY(position), position.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.25,
	})
	TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.45)
end

local function sparks(position, color, count)
	local holder = effectPart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = position })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(8, 18)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.45, 0)
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)
	Debris:AddItem(holder, 1)
end

local auras = {}

local function aura(character, color, duration)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if auras[character] then
		auras[character]:Destroy()
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "AbilityAura"
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Rate = 30
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 6, 0)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Parent = attachment
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 2
	light.Parent = attachment
	auras[character] = attachment
	task.delay(duration, function()
		if auras[character] == attachment then
			auras[character] = nil
		end
		attachment:Destroy()
	end)
end

fxRemote.OnClientEvent:Connect(function(kind, position, color, extra, extra2)
	if typeof(color) ~= "Color3" then
		return
	end
	if kind == "Lightning" then
		local radius = if typeof(extra) == "number" then extra else 4
		if extra2 == true then
			-- A straight beam from the sky (sunbeams).
			local top = position + Vector3.new(0, 45, 0)
			local beam = effectPart({ Size = Vector3.new(1.6, 1.6, 45), CFrame = CFrame.lookAt((top + position) / 2, position), Color = color, Transparency = 0.2 })
			TweenService:Create(beam, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(0.3, 0.3, 45) }):Play()
			Debris:AddItem(beam, 0.45)
		else
			bolt(position + Vector3.new(math.random(-4, 4), 45, math.random(-4, 4)), position, color, 0.6, 0.3)
		end
		lightFlash(position, color, 24)
		sparks(position, color, 20)
		shockwave(position, color, radius)
	elseif kind == "Chain" and type(extra) == "table" then
		for i = 1, #extra - 1 do
			if typeof(extra[i]) == "Vector3" and typeof(extra[i + 1]) == "Vector3" then
				bolt(extra[i], extra[i + 1], color, 0.4, 0.35)
				sparks(extra[i + 1], color, 10)
			end
		end
		lightFlash(position, color, 16)
	elseif kind == "Shockwave" then
		shockwave(position, color, if typeof(extra) == "number" then extra else 10)
		sparks(position, color, 16)
	elseif kind == "Cleave" and typeof(extra) == "Vector3" then
		local look = Vector3.new(extra.X, 0, extra.Z).Unit
		local range = if typeof(extra2) == "number" then extra2 else 10
		local base = CFrame.lookAt(position, position + look)
		for i = -5, 5 do
			local angle = math.rad(i * 18)
			local spot = (base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -range * 0.75)).Position
			local piece = effectPart({
				Size = Vector3.new(range * 0.32, 0.25, 0.6),
				CFrame = CFrame.lookAt(spot, position) * CFrame.Angles(0, math.rad(90), 0),
				Color = color,
				Transparency = 0.15,
			})
			task.delay((i + 5) * 0.012, function()
				fadeOut(piece, 0.3)
			end)
		end
		sparks(position + look * range * 0.6, color, 18)
	elseif kind == "DashTrail" and typeof(extra) == "Vector3" then
		bolt(position, extra, color, 0.5, 0.4)
		bolt(position + Vector3.new(0, 1, 0), extra + Vector3.new(0, 1, 0), color, 0.3, 0.3)
		sparks(extra, color, 14)
	elseif kind == "Beam" and typeof(extra) == "Vector3" then
		-- A straight blast (water, spear, sunlight arrow).
		local width = if typeof(extra2) == "number" then extra2 else 2
		local length = (extra - position).Magnitude
		local beam = effectPart({ Size = Vector3.new(width * 0.6, width * 0.6, length), CFrame = CFrame.lookAt((position + extra) / 2, extra), Color = color, Transparency = 0.15 })
		TweenService:Create(beam, TweenInfo.new(0.35), { Transparency = 1, Size = Vector3.new(0.2, 0.2, length) }):Play()
		Debris:AddItem(beam, 0.4)
		sparks(extra, color, 12)
	elseif kind == "Vortex" then
		-- A spinning ring for the whirlpool's duration.
		local radius = if typeof(extra) == "number" then extra else 10
		local life = if typeof(extra2) == "number" then extra2 else 2.5
		local ring = effectPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, radius * 2, radius * 2),
			CFrame = CFrame.new(position.X, groundY(position) + 0.2, position.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Transparency = 0.45,
		})
		local inner = effectPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, radius, radius),
			CFrame = ring.CFrame,
			Color = Color3.new(1, 1, 1),
			Transparency = 0.6,
		})
		local spin = Instance.new("NumberValue")
		spin.Changed:Connect(function(angle)
			inner.CFrame = CFrame.new(position.X, groundY(position) + 0.25, position.Z) * CFrame.Angles(math.rad(angle), 0, math.rad(90))
		end)
		TweenService:Create(spin, TweenInfo.new(life), { Value = 720 }):Play()
		TweenService:Create(inner, TweenInfo.new(life, Enum.EasingStyle.Linear), { Size = Vector3.new(0.5, 1, 1) }):Play()
		task.delay(life - 0.3, function()
			fadeOut(ring, 0.3)
			fadeOut(inner, 0.3)
		end)
		Debris:AddItem(spin, life + 0.1)
	elseif kind == "Wave" and typeof(extra) == "Vector3" then
		-- A wall of water rushing forward.
		local look = Vector3.new(extra.X, 0, extra.Z).Unit
		local range = if typeof(extra2) == "number" then extra2 else 20
		local base = CFrame.lookAt(position, position + look)
		local wall = effectPart({ Size = Vector3.new(6, 5, 1.5), CFrame = base * CFrame.new(0, 0, -2), Color = color, Transparency = 0.25 })
		TweenService:Create(wall, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = base * CFrame.new(0, 0, -range),
			Size = Vector3.new(range * 1.1, 7, 1.5),
			Transparency = 0.9,
		}):Play()
		Debris:AddItem(wall, 0.55)
		sparks(position + look * range * 0.6, color, 25)
	elseif kind == "Dome" then
		-- A see-through shield dome.
		local radius = if typeof(extra) == "number" then extra else 12
		local life = if typeof(extra2) == "number" then extra2 else 5
		local dome = effectPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2, 2, 2),
			Position = position,
			Material = Enum.Material.ForceField,
			Color = color,
			Transparency = 0,
		})
		TweenService:Create(dome, TweenInfo.new(0.3), { Size = Vector3.new(radius * 2, radius * 2, radius * 2) }):Play()
		task.delay(life - 0.4, function()
			fadeOut(dome, 0.4)
		end)
	elseif kind == "HealBurst" then
		local radius = if typeof(extra) == "number" then extra else 15
		shockwave(position, Color3.fromRGB(120, 255, 140), radius)
		sparks(position + Vector3.new(0, 2, 0), color, 30)
		lightFlash(position, color, 20)
	elseif kind == "Aura" and typeof(extra) == "Instance" and extra:IsA("Player") then
		aura(extra.Character, color, if typeof(extra2) == "number" then extra2 else 10)
	end
end)
