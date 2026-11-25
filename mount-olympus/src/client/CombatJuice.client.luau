-- CombatJuice (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > CombatJuice
--
-- Phase 8: feedback that makes combat feel powerful (your screen only):
--   * Camera shake on heavy hits, nearby slams/explosions and your crits.
--   * A red flash at the screen edges when you are hurt, and a slow red
--     pulse while your health is low.
--   * Level up / rank up: golden flash, a ring of light at your feet and
--     sparkles rising around you.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local fxRemote = Remotes:WaitForChild("CombatFX")
local notifyRemote = Remotes:WaitForChild("Notify")

local function getParts()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

--------------------------------------------------------------------------
-- Camera shake (through Humanoid.CameraOffset, so the normal camera works)
--------------------------------------------------------------------------
local shake = 0
local function addShake(amount)
	shake = math.min(1.4, shake + amount)
end

local random = Random.new()
RunService.RenderStepped:Connect(function(dt)
	local _, humanoid = getParts()
	if not humanoid then
		return
	end
	if shake > 0.01 then
		humanoid.CameraOffset = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1)) * shake * 0.35
		shake = math.max(0, shake - dt * 3.2)
	elseif humanoid.CameraOffset ~= Vector3.zero then
		humanoid.CameraOffset = Vector3.zero
		shake = 0
	end
end)

--------------------------------------------------------------------------
-- Screen-edge flashes
--------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "CombatJuice"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 4
gui.Parent = playerGui

local function edgeFrame(color)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.22, 0.85), NumberSequenceKeypoint.new(0.78, 0.85), NumberSequenceKeypoint.new(1, 0),
	})
	gradient.Parent = frame
	local gradient2 = gradient:Clone()
	gradient2.Rotation = 90
	local inner = frame:Clone()
	gradient2.Parent = inner
	inner.Parent = frame
	frame.Parent = gui
	return frame, inner
end

local hurtFrame, hurtInner = edgeFrame(Color3.fromRGB(200, 20, 20))
local goldFrame, goldInner = edgeFrame(Color3.fromRGB(255, 210, 90))

local function flash(frame, inner, strength, duration)
	frame.BackgroundTransparency = 1 - strength
	inner.BackgroundTransparency = 1 - strength
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(inner, info, { BackgroundTransparency = 1 }):Play()
end

-- Low health: slow red pulse
local lowFrame, lowInner = edgeFrame(Color3.fromRGB(150, 0, 0))
RunService.Heartbeat:Connect(function()
	local _, humanoid = getParts()
	local ratio = if humanoid and humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
	local target = 1
	if ratio > 0 and ratio < 0.3 then
		target = 1 - (0.25 + 0.2 * math.sin(os.clock() * 5)) * (1 - ratio / 0.3)
	end
	lowFrame.BackgroundTransparency = target
	lowInner.BackgroundTransparency = target
end)

--------------------------------------------------------------------------
-- Reacting to combat events
--------------------------------------------------------------------------
local BIG_KINDS = { Shockwave = 0.5, Lightning = 0.25, Chain = 0.15, Cleave = 0.12, Wave = 0.2, Dome = 0.25 }

fxRemote.OnClientEvent:Connect(function(kind, position, a, b)
	local _, humanoid, root = getParts()
	if not root or typeof(position) ~= "Vector3" then
		return
	end
	local distance = (position - root.Position).Magnitude
	if kind == "Damage" then
		local style = b
		if style == "Player" and distance < 6 and humanoid and type(a) == "number" and a > 0 then
			local share = math.clamp(a / math.max(1, humanoid.MaxHealth), 0.05, 0.6)
			flash(hurtFrame, hurtInner, 0.35 + share, 0.5)
			addShake(0.2 + share * 2)
		elseif style == "Crit" and distance < 20 then
			addShake(0.15)
		end
	elseif BIG_KINDS[kind] and distance < 45 then
		addShake(BIG_KINDS[kind] * (1 - distance / 45))
	end
end)

-- Level up / rank up celebration
local function celebrate(big)
	local _, _, root = getParts()
	flash(goldFrame, goldInner, if big then 0.8 else 0.55, if big then 1.6 else 1)
	if not root then
		return
	end
	-- An expanding ring of light at your feet
	local ringPart = Instance.new("Part")
	ringPart.Name = "LevelRing"
	ringPart.Shape = Enum.PartType.Cylinder
	ringPart.Anchored = true
	ringPart.CanCollide = false
	ringPart.CanQuery = false
	ringPart.CanTouch = false
	ringPart.Material = Enum.Material.Neon
	ringPart.Color = Color3.fromRGB(255, 215, 110)
	ringPart.Transparency = 0.2
	ringPart.Size = Vector3.new(0.2, 2, 2)
	ringPart.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ringPart.Parent = Workspace
	local size = if big then 40 else 24
	TweenService:Create(ringPart, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Size = Vector3.new(0.2, size, size), Transparency = 1 }):Play()
	Debris:AddItem(ringPart, 1.2)
	-- Rising sparkles around you
	local attachment = Instance.new("Attachment")
	attachment.Name = "LevelSparkles"
	attachment.Parent = root
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140))
	sparkles.LightEmission = 1
	sparkles.Rate = 0
	sparkles.Lifetime = NumberRange.new(1, 1.8)
	sparkles.Speed = NumberRange.new(6, 12)
	sparkles.SpreadAngle = Vector2.new(35, 35)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Acceleration = Vector3.new(0, -6, 0)
	sparkles.Size = NumberSequence.new(0.45, 0)
	sparkles.Parent = attachment
	sparkles:Emit(if big then 90 else 45)
	Debris:AddItem(attachment, 3)
	addShake(if big then 0.6 else 0.2)
end

notifyRemote.OnClientEvent:Connect(function(kind)
	if kind == "LevelUp" then
		celebrate(false)
	elseif kind == "RankUp" then
		celebrate(true)
	end
end)

-- Transforming (Divine Incarnation) shakes the heavens
player:GetAttributeChangedSignal("IncarnationUntil"):Connect(function()
	if (player:GetAttribute("IncarnationUntil") or 0) > Workspace:GetServerTimeNow() then
		addShake(1)
		flash(goldFrame, goldInner, 0.7, 1.2)
	end
end)
