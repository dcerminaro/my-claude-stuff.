-- HubDecor (ModuleScript)
-- Location: ServerScriptService > Services > HubDecor
--
-- Phase 8: makes Olympus Plaza and the summit look the part.
--   * Plaza: gold and marble inlays, a stepped foundation, column capitals,
--     the "Heart of Olympus" fountain with a floating orb and spinning rings,
--     golden motes drifting in the air.
--   * Six colossal god statues (real posed R15 bodies turned to marble) with
--     their weapons, on plinths with braziers in each god's colours.
--   * Grand gateways and lamp-lit paths to the Temple District and the
--     Practice Field.
--   * The summit: cypress and olive trees, ancient ruins, flowers, boulders.
--   * Floating sky islands with little temples and waterfalls of light.
-- Spinning / bobbing is done on each player's screen (client/DecorAnimator)
-- using the tags "OlympusSpin" and "OlympusBob".
-- Built once when the server starts. Everything is anchored.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GodConfig = require(Shared:WaitForChild("GodConfig"))
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))
local SwordBuilder = require(Shared:WaitForChild("SwordBuilder"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))

local HubDecor = {}

local MP = WorldBuilder.MakePart
local M = Enum.Material
local MARBLE = Color3.fromRGB(236, 232, 224)
local MARBLE_DARK = Color3.fromRGB(196, 188, 176)
local MARBLE_WARM = Color3.fromRGB(240, 226, 206)
local GOLD = Color3.fromRGB(212, 175, 55)
local BRONZE = Color3.fromRGB(150, 100, 50)
local STONE = Color3.fromRGB(150, 145, 138)
local WATER = Color3.fromRGB(110, 200, 240)
local FLOOR_TOP = 1   -- plaza floor top
local GROUND = -2     -- the summit terrain surface

local rng = Random.new(4242)

--------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------
local function cyl(parent, name, position, height, diameter, props)
	local p = { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)) }
	for k, v in props or {} do
		p[k] = v
	end
	return MP(parent, p)
end

local function ballPart(parent, name, position, diameter, props)
	local p = { Name = name, Shape = Enum.PartType.Ball, Size = Vector3.new(diameter, diameter, diameter), Position = position }
	for k, v in props or {} do
		p[k] = v
	end
	return MP(parent, p)
end

local function noCollide(props)
	props = props or {}
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return props
end

local function light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = part
	return l
end

local function fire(part, color, secondary, size)
	local f = Instance.new("Fire")
	f.Color = color
	f.SecondaryColor = secondary or color
	f.Size = size or 5
	f.Heat = 9
	f.Parent = part
	return f
end

local function sparkles(part, color, rate, size, speed)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Rate = rate or 6
	e.Lifetime = NumberRange.new(1.5, 3)
	e.Speed = NumberRange.new(speed or 1, (speed or 1) * 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(size or 0.25, 0)
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Parent = part
	return e
end

-- A ring of short segments (flat, around the Y axis).
local function ring(parent, name, center, radius, count, thickness, props, tilt)
	local model = Instance.new("Model")
	model.Name = name
	local base = CFrame.new(center) * (tilt or CFrame.identity)
	for i = 1, count do
		local angle = i / count * math.pi * 2
		local p = { Name = name .. "Seg", Size = Vector3.new(2 * math.pi * radius / count * 1.06, thickness, thickness),
			CFrame = base * CFrame.Angles(0, -angle, 0) * CFrame.new(0, 0, radius) }
		for k, v in props or {} do
			p[k] = v
		end
		MP(model, p)
	end
	model.Parent = parent
	return model
end

local function brazier(parent, position, flameColor, secondary, scale)
	scale = scale or 1
	cyl(parent, "BrazierStand", position + Vector3.new(0, 1.6 * scale, 0), 3.2 * scale, 0.7 * scale, { Material = M.Metal, Color = BRONZE })
	cyl(parent, "BrazierFoot", position + Vector3.new(0, 0.2 * scale, 0), 0.4 * scale, 1.8 * scale, { Material = M.Metal, Color = BRONZE })
	local bowl = cyl(parent, "BrazierBowl", position + Vector3.new(0, 3.4 * scale, 0), 0.9 * scale, 2.6 * scale, { Material = M.Metal, Color = GOLD })
	fire(bowl, flameColor, secondary, 4 * scale)
	light(bowl, flameColor, 16 * scale, 1.4)
	return bowl
end

local function tag(instance, tagName, attributes)
	for k, v in attributes or {} do
		instance:SetAttribute(k, v)
	end
	CollectionService:AddTag(instance, tagName)
end

--------------------------------------------------------------------------
-- 1. Plaza
--------------------------------------------------------------------------
local function buildPlaza(hub, folder)
	for _, name in { "StatuePlaceholder", "StatuePedestal", "Olympus Market" } do
		local old = hub:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	-- Stepped foundation under the plaza (it sits on the summit)
	MP(folder, { Name = "Foundation1", Size = Vector3.new(146, 2.4, 146), Position = Vector3.new(0, -1.2, 0), Color = MARBLE_DARK })
	MP(folder, { Name = "Foundation2", Size = Vector3.new(154, 1.2, 154), Position = Vector3.new(0, -2.4, 0), Color = STONE, Material = M.Slate })
	for _, side in { { 0, 71 }, { 0, -71 }, { 71, 0 }, { -71, 0 } } do
		local alongX = side[2] ~= 0
		MP(folder, noCollide({ Name = "GoldTrim", Size = if alongX then Vector3.new(142, 0.6, 0.3) else Vector3.new(0.3, 0.6, 142),
			Position = Vector3.new(side[1] * 1.0, 0.4, side[2] * 1.0), Material = M.Metal, Color = GOLD }))
	end

	-- Floor inlays: gold rings and marble rays
	local inlay = Instance.new("Model")
	inlay.Name = "FloorInlay"
	ring(inlay, "InlayRingInner", Vector3.new(0, FLOOR_TOP + 0.03, 0), 18, 36, 0.06, { Material = M.Metal, Color = GOLD, CanCollide = false })
	ring(inlay, "InlayRingOuter", Vector3.new(0, FLOOR_TOP + 0.03, 0), 46, 64, 0.06, { Material = M.Metal, Color = GOLD, CanCollide = false })
	for i = 1, 16 do
		local angle = i / 16 * math.pi * 2
		local mid = 32
		MP(inlay, { Name = "Ray", Size = Vector3.new(26, 0.06, if i % 2 == 0 then 3 else 1.4), CanCollide = false,
			CFrame = CFrame.new(math.cos(angle) * mid, FLOOR_TOP + 0.03, math.sin(angle) * mid) * CFrame.Angles(0, -angle, 0),
			Color = if i % 2 == 0 then MARBLE_DARK else GOLD, Material = if i % 2 == 0 then M.Marble else M.Metal })
	end
	inlay.Parent = folder

	-- Column capitals, bases and floating flames on the existing column ring
	for _, column in hub:GetChildren() do
		if column.Name == "Column" and column:IsA("BasePart") and column.Position.X > -56 and column.Position.X < -28 and column.Position.Z > -52 and column.Position.Z < -18 then
			column:Destroy() -- the Hall of the Gods' roof stands here now
		elseif column.Name == "Column" and column:IsA("BasePart") then
			local p = column.Position
			cyl(folder, "ColumnBase", Vector3.new(p.X, FLOOR_TOP + 0.6, p.Z), 1.2, 5.6, { Color = MARBLE_DARK })
			MP(folder, { Name = "ColumnCapital", Size = Vector3.new(5.6, 1.2, 5.6), Position = Vector3.new(p.X, p.Y + 12.6, p.Z), Color = MARBLE_WARM })
			cyl(folder, "ColumnGold", Vector3.new(p.X, p.Y + 11.9, p.Z), 0.3, 4.6, { Material = M.Metal, Color = GOLD })
			local bowl = cyl(folder, "ColumnFlame", Vector3.new(p.X, p.Y + 13.7, p.Z), 1, 3, { Material = M.Metal, Color = GOLD })
			fire(bowl, Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 120, 40), 4)
			light(bowl, Color3.fromRGB(255, 190, 120), 20, 1.2)
		end
	end

	-- Heart of Olympus: a fountain with a floating orb and golden rings
	local heart = Instance.new("Model")
	heart.Name = "HeartOfOlympus"
	cyl(heart, "BasinWall", Vector3.new(0, FLOOR_TOP + 1, 0), 2, 26, { Color = MARBLE_WARM })
	cyl(heart, "BasinRim", Vector3.new(0, FLOOR_TOP + 2.1, 0), 0.4, 27, { Material = M.Metal, Color = GOLD })
	cyl(heart, "Water", Vector3.new(0, FLOOR_TOP + 1.7, 0), 0.4, 24.4, noCollide({ Material = M.Glass, Color = WATER, Transparency = 0.35 }))
	cyl(heart, "Dais1", Vector3.new(0, FLOOR_TOP + 2.5, 0), 2, 10, { Color = MARBLE })
	cyl(heart, "Dais2", Vector3.new(0, FLOOR_TOP + 4.25, 0), 1.5, 7, { Color = MARBLE_WARM })
	cyl(heart, "DaisGold", Vector3.new(0, FLOOR_TOP + 5.1, 0), 0.3, 7.4, { Material = M.Metal, Color = GOLD })
	-- Four golden arms rising to hold the orb
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		local base = Vector3.new(math.cos(angle) * 3, FLOOR_TOP + 5, math.sin(angle) * 3)
		local top = Vector3.new(math.cos(angle) * 1.4, FLOOR_TOP + 13, math.sin(angle) * 1.4)
		local length = (top - base).Magnitude
		MP(heart, { Name = "Arm", Size = Vector3.new(0.6, length, 0.6), CFrame = CFrame.lookAt((base + top) / 2, top) * CFrame.Angles(math.rad(90), 0, 0), Material = M.Metal, Color = GOLD })
	end
	local orb = ballPart(heart, "Orb", Vector3.new(0, FLOOR_TOP + 15, 0), 4.4, noCollide({ Material = M.Neon, Color = Color3.fromRGB(255, 236, 170) }))
	light(orb, Color3.fromRGB(255, 225, 160), 40, 2.5)
	sparkles(orb, Color3.fromRGB(255, 225, 140), 14, 0.35, 2)
	local glowShell = ballPart(heart, "OrbGlow", Vector3.new(0, FLOOR_TOP + 15, 0), 6.5, noCollide({ Material = M.Neon, Color = Color3.fromRGB(255, 210, 120), Transparency = 0.75 }))
	glowShell.CastShadow = false
	local orbCenter = Vector3.new(0, FLOOR_TOP + 15, 0)
	for i, spec in { { 5, 0.35, 20, 0.6 }, { 6.6, 0.3, 26, -0.4 }, { 8.4, 0.25, 32, 0.3 } } do
		local r = ring(heart, "OrbRing" .. i, orbCenter, spec[1], spec[3], spec[2], noCollide({ Material = M.Neon, Color = GOLD }),
			CFrame.Angles(math.rad(25 * i), 0, math.rad(-15 * i)))
		tag(r, "OlympusSpin", { Speed = spec[4], Pivot = orbCenter })
	end
	-- Water jets around the dais
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2
		local spout = cyl(heart, "Spout", Vector3.new(math.cos(angle) * 9.5, FLOOR_TOP + 2.2, math.sin(angle) * 9.5), 0.6, 1, noCollide({ Material = M.Metal, Color = GOLD }))
		local jet = Instance.new("ParticleEmitter")
		jet.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
		jet.LightEmission = 0.4
		jet.Rate = 30
		jet.Lifetime = NumberRange.new(0.8, 1.1)
		jet.Speed = NumberRange.new(9, 11)
		jet.Acceleration = Vector3.new(0, -22, 0)
		jet.SpreadAngle = Vector2.new(4, 4)
		jet.EmissionDirection = Enum.NormalId.Top
		jet.Size = NumberSequence.new(0.35, 0.1)
		jet.Transparency = NumberSequence.new(0.2, 0.9)
		jet.Parent = spout
	end
	-- Eight braziers around the fountain
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2 + math.pi / 8
		brazier(heart, Vector3.new(math.cos(angle) * 17, FLOOR_TOP, math.sin(angle) * 17), Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 120, 40), 0.9)
	end
	local nameplate = MP(heart, noCollide({ Name = "Nameplate", Size = Vector3.new(1, 1, 1), Position = Vector3.new(0, FLOOR_TOP + 22, 0), Transparency = 1 }))
	WorldBuilder.AddLabel(nameplate, "Olympus Plaza", GOLD, 7)
	heart.Parent = folder

	-- Golden motes drifting over the plaza
	local motes = MP(folder, noCollide({ Name = "Motes", Size = Vector3.new(130, 24, 130), Position = Vector3.new(0, 14, 0), Transparency = 1 }))
	local e = sparkles(motes, Color3.fromRGB(255, 220, 140), 22, 0.18, 0.4)
	e.Lifetime = NumberRange.new(5, 8)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
end

--------------------------------------------------------------------------
-- 2. God statues
--------------------------------------------------------------------------
local STATUES = {
	{ God = "Zeus", Angle = 0, Weapon = "Bolt", Pose = { RightShoulder = { 165, 0, 20 }, RightElbow = { 15, 0, 0 }, LeftShoulder = { 25, 0, -25 }, LeftElbow = { 30, 0, 0 } }, Beard = true, Crown = true },
	{ God = "Poseidon", Angle = 45, Weapon = "TridentOfPoseidon", Pose = { RightShoulder = { 30, 0, 12 }, RightElbow = { 65, 0, 0 }, RightWrist = { -25, 0, 0 }, LeftShoulder = { 15, 0, -20 } }, Beard = true, Crown = true },
	{ God = "Athena", Angle = 135, Weapon = "AegisSpear", Pose = { RightShoulder = { 30, 0, 12 }, RightElbow = { 65, 0, 0 }, RightWrist = { -25, 0, 0 }, LeftShoulder = { 55, 0, 15 }, LeftElbow = { 70, 0, 0 } }, Helmet = Color3.fromRGB(80, 120, 200), Shield = true },
	{ God = "Ares", Angle = 180, Weapon = "SpartanBlade", Pose = { RightShoulder = { 120, 0, 25 }, RightElbow = { 15, 0, 0 }, LeftShoulder = { 55, 0, 15 }, LeftElbow = { 70, 0, 0 }, Waist = { 0, -10, 0 } }, Helmet = Color3.fromRGB(190, 40, 40), Shield = true },
	{ God = "Hades", Angle = 225, Weapon = "HellfireBlade", Pose = { RightShoulder = { 30, 0, 12 }, RightElbow = { 65, 0, 0 }, RightWrist = { -25, 0, 0 }, LeftShoulder = { 40, 0, -30 }, LeftElbow = { 50, 0, 0 } }, Beard = true, Crown = true, Dark = true },
	{ God = "Apollo", Angle = 315, Weapon = "BowOfApollo", Pose = { RightShoulder = { 90, 0, 0 }, RightElbow = { 5, 0, 0 }, LeftShoulder = { 90, 0, 35 }, LeftElbow = { 110, 0, 0 } }, Laurel = true, Halo = true },
}
local STATUE_SCALE = 4.2
local STATUE_RADIUS = 94

-- Puts every limb where its joints say (no physics needed).
local function solveRig(rig)
	local root = rig:FindFirstChild("HumanoidRootPart")
	local joints = {}
	for _, joint in rig:GetDescendants() do
		if joint:IsA("Motor6D") then
			table.insert(joints, joint)
		end
	end
	local done = { [root] = true }
	local changed = true
	while changed do
		changed = false
		for _, joint in joints do
			if done[joint.Part0] and not done[joint.Part1] then
				joint.Part1.CFrame = joint.Part0.CFrame * joint.C0 * joint.C1:Inverse()
				done[joint.Part1] = true
				changed = true
			end
		end
	end
end

local function boltModel(color)
	local model = Instance.new("Model")
	model.Name = "Bolt"
	local points = { Vector3.new(0, -0.6, 0), Vector3.new(0.35, 0.6, 0), Vector3.new(-0.3, 1.6, 0), Vector3.new(0.4, 2.8, 0), Vector3.new(-0.2, 3.8, 0), Vector3.new(0.3, 5, 0) }
	local grip
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = MP(model, noCollide({ Name = "BoltSeg", Size = Vector3.new(0.35, (b - a).Magnitude + 0.15, 0.35),
			CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(math.rad(90), 0, 0), Material = M.Neon, Color = color }))
		if i == 1 then
			grip = seg
		end
	end
	model.PrimaryPart = grip
	return model
end

local function buildStatue(folder, spec)
	local god = GodConfig.Gods[spec.God]
	local colors = GodConfig.GetColors(spec.God)
	local angle = math.rad(spec.Angle)
	local base = Vector3.new(math.cos(angle) * STATUE_RADIUS, GROUND, math.sin(angle) * STATUE_RADIUS)
	local facing = CFrame.lookAt(base, Vector3.new(0, GROUND, 0))
	local statueModel = Instance.new("Model")
	statueModel.Name = "Statue_" .. spec.God

	-- Plinth
	local plinthTop = GROUND + 7
	cyl(statueModel, "PlinthBase", base + Vector3.new(0, 1, 0), 2, 18, { Color = MARBLE_DARK })
	cyl(statueModel, "PlinthMid", base + Vector3.new(0, 4, 0), 4, 14, { Color = MARBLE })
	cyl(statueModel, "PlinthGold", base + Vector3.new(0, 6.2, 0), 0.4, 14.6, { Material = M.Metal, Color = GOLD })
	cyl(statueModel, "PlinthTop", base + Vector3.new(0, 6.6, 0), 0.8, 15, { Color = MARBLE_WARM })
	local emblemPos = (facing * CFrame.new(0, 0, -7.2)).Position
	local emblem = ballPart(statueModel, "Emblem", Vector3.new(emblemPos.X, GROUND + 4, emblemPos.Z), 2, noCollide({ Material = M.Neon, Color = colors.Glow or colors.Accent }))
	light(emblem, colors.Glow or colors.Accent, 14, 1.5)
	for _, side in { -1, 1 } do
		local p = (facing * CFrame.new(side * 9.5, 0, -3)).Position
		brazier(statueModel, Vector3.new(p.X, GROUND, p.Z), colors.Fire or colors.Accent, colors.Accent, 1.2)
	end
	local label = MP(statueModel, noCollide({ Name = "NameTag", Size = Vector3.new(1, 1, 1), Position = (facing * CFrame.new(0, 10, -8)).Position, Transparency = 1 }))
	WorldBuilder.AddLabel(label, god and god.DisplayName or spec.God, colors.Accent, 4)

	-- The figure: a real R15 body, posed, then turned to marble.
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		statueModel.Parent = folder
		return
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	for _, joint in rig:GetDescendants() do
		if joint:IsA("Motor6D") then
			local e = spec.Pose[joint.Name]
			if e then
				joint.C0 = joint.C0 * CFrame.Angles(math.rad(e[1]), math.rad(e[2]), math.rad(e[3]))
			end
		end
	end
	root.CFrame = CFrame.new(0, 3, 0)
	solveRig(rig)

	local skin = if spec.Dark then Color3.fromRGB(70, 68, 78) else MARBLE
	local trim = if spec.Dark then Color3.fromRGB(120, 90, 160) else GOLD
	local head = rig:FindFirstChild("Head")
	-- Robe (chiton) from the waist to the knees
	local lower = rig:FindFirstChild("LowerTorso")
	if lower then
		MP(rig, { Name = "Robe", Size = Vector3.new(2.3, 2.6, 1.35), CFrame = lower.CFrame * CFrame.new(0, -1.25, 0), Color = skin, Material = M.Marble })
		MP(rig, { Name = "RobeBelt", Size = Vector3.new(2.4, 0.3, 1.45), CFrame = lower.CFrame * CFrame.new(0, 0.05, 0), Color = trim, Material = M.Metal })
	end
	local upper = rig:FindFirstChild("UpperTorso")
	if upper then
		MP(rig, { Name = "Sash", Size = Vector3.new(0.4, 2.4, 1.25), CFrame = upper.CFrame * CFrame.Angles(0, 0, math.rad(35)), Color = trim, Material = M.Metal })
	end
	if head then
		for _, item in head:GetChildren() do
			if item:IsA("Decal") then
				item:Destroy() -- statues have no painted face
			end
		end
		if spec.Beard then
			MP(rig, { Name = "Beard", Size = Vector3.new(0.9, 0.7, 0.4), CFrame = head.CFrame * CFrame.new(0, -0.55, -0.45), Color = skin, Material = M.Marble })
		end
		if spec.Crown then
			ring(rig, "Crown", (head.CFrame * CFrame.new(0, 0.62, 0)).Position, 0.62, 10, 0.18, { Material = M.Metal, Color = trim })
		end
		if spec.Laurel then
			ring(rig, "Laurel", (head.CFrame * CFrame.new(0, 0.45, 0)).Position, 0.66, 12, 0.16, { Material = M.Metal, Color = GOLD })
		end
		if spec.Helmet then
			MP(rig, { Name = "Helmet", Size = Vector3.new(1.35, 0.7, 1.35), CFrame = head.CFrame * CFrame.new(0, 0.45, 0), Color = BRONZE, Material = M.Metal })
			MP(rig, { Name = "Crest", Size = Vector3.new(0.25, 0.8, 1.6), CFrame = head.CFrame * CFrame.new(0, 1.05, 0.1), Color = spec.Helmet, Material = M.Fabric })
		end
		if spec.Halo then
			local halo = ring(rig, "SunHalo", (head.CFrame * CFrame.new(0, 0.3, 0.75)).Position, 1.1, 16, 0.12, noCollide({ Material = M.Neon, Color = Color3.fromRGB(255, 210, 90) }), CFrame.Angles(math.rad(90), 0, 0))
			halo.Name = "SunHalo"
		end
	end
	-- Weapon in the right hand
	local hand = rig:FindFirstChild("RightHand")
	if hand then
		local weaponModel
		if spec.Weapon == "Bolt" then
			weaponModel = boltModel(Color3.fromRGB(255, 240, 120))
		else
			weaponModel = SwordBuilder.Build(colors.Glow or colors.Accent, WeaponConfig.Weapons[spec.Weapon])
		end
		local gripPoint = hand:FindFirstChild("RightGripAttachment")
		local offset = if gripPoint then CFrame.new(gripPoint.Position) else CFrame.new(0, -hand.Size.Y / 2, 0)
		weaponModel:PivotTo(hand.CFrame * offset * CFrame.Angles(math.rad(-90), 0, 0))
		weaponModel.Parent = rig
	end
	if spec.Shield then
		local leftHand = rig:FindFirstChild("LeftLowerArm") or rig:FindFirstChild("LeftHand")
		if leftHand then
			-- A disc whose face points out from the arm
			MP(rig, { Name = "Shield", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3, 3), CFrame = leftHand.CFrame * CFrame.new(-0.6, 0, 0), Color = BRONZE, Material = M.Metal })
			cyl(rig, "ShieldBoss", (leftHand.CFrame * CFrame.new(-0.8, 0, 0)).Position, 0.3, 0.9, { Material = M.Metal, Color = GOLD })
		end
	end

	-- Everything becomes an anchored marble statue.
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Destroy()
	end
	for _, item in rig:GetDescendants() do
		if item:IsA("Motor6D") or item:IsA("Weld") or item:IsA("WeldConstraint") or item:IsA("Script") or item:IsA("LocalScript") or item:IsA("Clothing") or item:IsA("ShirtGraphic") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.Massless = true
			if item.Material ~= M.Neon and item.Material ~= M.Metal and item.Material ~= M.Fabric and item.Parent == rig then
				item.Material = M.Marble
				item.Color = skin
			end
		end
	end
	if root then
		root.Transparency = 1
	end
	rig.Name = "Figure"
	rig:ScaleTo(STATUE_SCALE)
	-- Stand it on the plinth, facing the plaza
	local _, size = rig:GetBoundingBox()
	local feetY = math.huge
	for _, item in rig:GetDescendants() do
		if item:IsA("BasePart") and (item.Name == "LeftFoot" or item.Name == "RightFoot") then
			feetY = math.min(feetY, item.Position.Y - item.Size.Y / 2)
		end
	end
	if feetY == math.huge then
		feetY = rig:GetPivot().Position.Y - size.Y / 2
	end
	local pivot = rig:GetPivot()
	local lift = plinthTop - feetY
	rig:PivotTo(CFrame.new(base.X, pivot.Position.Y + lift, base.Z) * (facing - facing.Position) * (pivot - pivot.Position))
	rig.Parent = statueModel
	statueModel.Parent = folder
end

--------------------------------------------------------------------------
-- 3. Gateways and paths
--------------------------------------------------------------------------
local function gateway(folder, center, label, color)
	local model = Instance.new("Model")
	model.Name = "Gateway_" .. label:gsub(" ", "")
	for _, x in { -10, 10 } do
		cyl(model, "GatePillar", center + Vector3.new(x, 11, 0), 20, 3.2, { Color = MARBLE })
		MP(model, { Name = "GateBase", Size = Vector3.new(4.4, 1.4, 4.4), Position = center + Vector3.new(x, 0.7, 0), Color = MARBLE_DARK })
		MP(model, { Name = "GateCapital", Size = Vector3.new(4.4, 1, 4.4), Position = center + Vector3.new(x, 21.5, 0), Color = MARBLE_WARM })
	end
	MP(model, { Name = "Lintel", Size = Vector3.new(26, 2.4, 5), Position = center + Vector3.new(0, 23.2, 0), Color = MARBLE_WARM })
	MP(model, { Name = "LintelGold", Size = Vector3.new(26.4, 0.5, 5.2), Position = center + Vector3.new(0, 22.1, 0), Material = M.Metal, Color = GOLD })
	-- Triangular pediment
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Pediment"
		wedge.Anchored = true
		wedge.Material = M.Marble
		wedge.Color = MARBLE
		wedge.Size = Vector3.new(5, 4.5, 13)
		wedge.CFrame = CFrame.new(center + Vector3.new(side * 6.5, 26.65, 0)) * CFrame.Angles(0, math.rad(side * 90), 0)
		wedge.Parent = model
	end
	local sign = MP(model, noCollide({ Name = "GateSign", Size = Vector3.new(1, 1, 1), Position = center + Vector3.new(0, 31, 0), Transparency = 1 }))
	WorldBuilder.AddLabel(sign, label, color, 6)
	model.Parent = folder
end

local function lampRow(folder, fromZ, toZ, x)
	for z = fromZ, toZ, 18 do
		for _, side in { -1, 1 } do
			local position = Vector3.new(x + side * 11, FLOOR_TOP - 0.5, z)
			local post = cyl(folder, "LampPost", position + Vector3.new(0, 4, 0), 8, 0.6, { Material = M.Metal, Color = BRONZE })
			local lamp = ballPart(folder, "Lamp", position + Vector3.new(0, 8.6, 0), 1.4, noCollide({ Material = M.Neon, Color = Color3.fromRGB(255, 225, 160) }))
			light(lamp, Color3.fromRGB(255, 210, 140), 18, 1.2)
			post.CanCollide = true
		end
	end
end

local function decoratePaths(hub, folder)
	gateway(folder, Vector3.new(0, FLOOR_TOP - 0.5, 72), "Temple District", GOLD)
	gateway(folder, Vector3.new(0, FLOOR_TOP - 0.5, -72), "Practice Field", Color3.fromRGB(255, 150, 110))
	lampRow(folder, 80, 166, 0)
	lampRow(folder, -86, -78, 0)
	for _, name in { "DistrictPath", "PracticePath" } do
		local path = hub:FindFirstChild(name)
		if path then
			path.Material = M.Marble
			path.Color = MARBLE_WARM
			local s, p = path.Size, path.Position
			for _, side in { -1, 1 } do
				MP(folder, { Name = "PathEdge", Size = Vector3.new(0.6, 1.2, s.Z), Position = p + Vector3.new(side * (s.X / 2 + 0.3), 0.1, 0), Material = M.Metal, Color = GOLD })
			end
			MP(folder, { Name = "PathFoundation", Size = Vector3.new(s.X + 3, 3, s.Z), Position = p - Vector3.new(0, 2, 0), Color = MARBLE_DARK })
		end
	end
	-- Practice field: a low wall and banners around it
	local field = hub:FindFirstChild("PracticeField")
	if field then
		local c, s = field.Position, field.Size
		for _, side in { { 1, 0 }, { -1, 0 }, { 0, -1 } } do
			local alongZ = side[1] ~= 0
			local wallSize = if alongZ then Vector3.new(2, 3, s.Z) else Vector3.new(s.X, 3, 2)
			MP(folder, { Name = "FieldWall", Size = wallSize, Position = c + Vector3.new(side[1] * (s.X / 2 + 1), 1, side[2] * (s.Z / 2 + 1)), Color = Color3.fromRGB(190, 160, 120), Material = M.Sandstone })
		end
		for i = -2, 2 do
			local x = c.X + i * 18
			local pole = cyl(folder, "BannerPole", Vector3.new(x, c.Y + 6, c.Z - s.Z / 2 - 1), 12, 0.5, { Material = M.Metal, Color = BRONZE })
			MP(folder, noCollide({ Name = "Banner", Size = Vector3.new(3, 6, 0.15), Position = pole.Position + Vector3.new(1.7, 2, 0), Material = M.Fabric, Color = Color3.fromRGB(180, 50, 40) }))
		end
	end
end

--------------------------------------------------------------------------
-- 4. The summit: trees, ruins, flowers, boulders
--------------------------------------------------------------------------
local SUMMIT_CENTER = Vector3.new(0, 0, 90)
local SUMMIT_RADIUS = 380

local function isFree(x, z, margin)
	margin = margin or 0
	if (Vector3.new(x, 0, z) - SUMMIT_CENTER).Magnitude > SUMMIT_RADIUS - 20 then
		return false
	end
	if math.abs(x) < 82 + margin and math.abs(z) < 82 + margin then
		return false -- plaza
	end
	if math.abs(x) < 16 + margin and z > -175 and z < 175 then
		return false -- paths
	end
	if math.abs(x) < 52 + margin and z > -168 - margin and z < -84 then
		return false -- practice field
	end
	if math.abs(x) < 200 + margin and z > 150 - margin and z < 350 + margin then
		return false -- temple plots
	end
	for _, spec in STATUES do
		local a = math.rad(spec.Angle)
		if (Vector2.new(x, z) - Vector2.new(math.cos(a) * STATUE_RADIUS, math.sin(a) * STATUE_RADIUS)).Magnitude < 20 + margin then
			return false
		end
	end
	return true
end

local function cypress(folder, position, height)
	local model = Instance.new("Model")
	model.Name = "Cypress"
	cyl(model, "Trunk", position + Vector3.new(0, 1.5, 0), 3, 0.9, { Material = M.Wood, Color = Color3.fromRGB(95, 70, 50) })
	local layers = 6
	for i = 1, layers do
		local t = (i - 1) / (layers - 1)
		local width = 4.2 * (1 - t * 0.75)
		ballPart(model, "Leaves", position + Vector3.new(0, 2 + t * height, 0), width, { Material = M.Grass, Color = Color3.fromRGB(45 + i * 3, 85 + i * 4, 50), Size = Vector3.new(width, height / layers * 1.9, width) })
	end
	model.Parent = folder
end

local function olive(folder, position)
	local model = Instance.new("Model")
	model.Name = "OliveTree"
	local lean = rng:NextNumber(-0.25, 0.25)
	MP(model, { Name = "Trunk", Size = Vector3.new(1.2, 6, 1.2), CFrame = CFrame.new(position + Vector3.new(0, 3, 0)) * CFrame.Angles(lean, rng:NextNumber(0, 6), -lean), Material = M.Wood, Color = Color3.fromRGB(110, 95, 75) })
	for _ = 1, 4 do
		local offset = Vector3.new(rng:NextNumber(-2.5, 2.5), rng:NextNumber(5.5, 7.5), rng:NextNumber(-2.5, 2.5))
		local size = rng:NextNumber(3.5, 5)
		ballPart(model, "Canopy", position + offset, size, { Material = M.Grass, Color = Color3.fromRGB(120, 140, 100), Size = Vector3.new(size, size * 0.7, size) })
	end
	model.Parent = folder
end

local function ruin(folder, position)
	local model = Instance.new("Model")
	model.Name = "Ruin"
	local kind = rng:NextInteger(1, 3)
	if kind == 1 then -- broken column
		local h = rng:NextNumber(4, 11)
		cyl(model, "BrokenColumn", position + Vector3.new(0, h / 2, 0), h, 2.6, { Color = MARBLE_DARK })
		MP(model, { Name = "Base", Size = Vector3.new(3.4, 0.8, 3.4), Position = position + Vector3.new(0, 0.4, 0), Color = STONE })
	elseif kind == 2 then -- fallen column pieces
		for i = 0, 2 do
			local p = position + Vector3.new(i * 3.1, 1.2, rng:NextNumber(-0.4, 0.4))
			MP(model, { Name = "Drum", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 2.5, 2.5), CFrame = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), Color = MARBLE_DARK })
		end
	else -- a small arch
		for _, x in { -3, 3 } do
			cyl(model, "ArchPillar", position + Vector3.new(x, 4, 0), 8, 1.6, { Color = MARBLE_DARK })
		end
		MP(model, { Name = "ArchTop", Size = Vector3.new(8.4, 1.2, 2), Position = position + Vector3.new(0, 8.5, 0), Color = MARBLE_DARK })
	end
	local angle = rng:NextNumber(0, math.pi * 2)
	model:PivotTo(CFrame.new(model:GetPivot().Position) * CFrame.Angles(0, angle, 0))
	model.Parent = folder
end

local FLOWER_COLORS = { Color3.fromRGB(240, 90, 110), Color3.fromRGB(255, 220, 90), Color3.fromRGB(180, 120, 230), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 70) }
local function flowers(folder, position)
	local model = Instance.new("Model")
	model.Name = "Flowers"
	local color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
	for _ = 1, 7 do
		local p = position + Vector3.new(rng:NextNumber(-3, 3), 0.35, rng:NextNumber(-3, 3))
		ballPart(model, "Bloom", p, 0.7, noCollide({ Material = M.SmoothPlastic, Color = color }))
	end
	model.Parent = folder
end

local function boulder(folder, position)
	local size = rng:NextNumber(3, 8)
	ballPart(folder, "Boulder", position + Vector3.new(0, size * 0.25, 0), size, { Material = M.Rock, Color = Color3.fromRGB(140, 132, 122), Size = Vector3.new(size * 1.3, size * 0.8, size) })
end

local function buildSummit(folder)
	local placed = 0
	local tries = 0
	while placed < 230 and tries < 4000 do
		tries += 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = math.sqrt(rng:NextNumber()) * SUMMIT_RADIUS
		local x, z = SUMMIT_CENTER.X + math.cos(angle) * distance, SUMMIT_CENTER.Z + math.sin(angle) * distance
		if isFree(x, z, 4) then
			local position = Vector3.new(x, GROUND, z)
			local roll = rng:NextNumber()
			if roll < 0.3 then
				cypress(folder, position, rng:NextNumber(10, 18))
			elseif roll < 0.5 then
				olive(folder, position)
			elseif roll < 0.62 then
				ruin(folder, position)
			elseif roll < 0.85 then
				flowers(folder, position)
			else
				boulder(folder, position)
			end
			placed += 1
		end
	end
	-- An avenue of cypress trees around the plaza
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local x, z = math.cos(angle) * 112, math.sin(angle) * 112
		if isFree(x, z, 0) or (math.abs(z) < 150 and math.abs(x) > 20 and (Vector2.new(x, z)).Magnitude > 105) then
			local blocked = math.abs(x) < 20
			for _, spec in STATUES do
				local a = math.rad(spec.Angle)
				if (Vector2.new(x, z) - Vector2.new(math.cos(a) * STATUE_RADIUS, math.sin(a) * STATUE_RADIUS)).Magnitude < 24 then
					blocked = true
				end
			end
			if not blocked and not (math.abs(x) < 52 and z < -84) then
				cypress(folder, Vector3.new(x, GROUND, z), 16)
			end
		end
	end
end

--------------------------------------------------------------------------
-- 5. Floating sky islands with waterfalls of light
--------------------------------------------------------------------------
local function skyIsland(folder, center, size, withTemple)
	local model = Instance.new("Model")
	model.Name = "SkyIsland"
	-- Rocky underside: stacked shrinking discs
	for i = 0, 4 do
		local t = i / 4
		cyl(model, "Rock", center - Vector3.new(0, 2 + i * size * 0.18, 0), size * 0.2, size * (1 - t * 0.8), { Material = M.Rock, Color = Color3.fromRGB(130 - i * 8, 122 - i * 8, 115 - i * 6) })
	end
	cyl(model, "Grass", center, 1.4, size * 1.02, { Material = M.Grass, Color = Color3.fromRGB(110, 155, 80) })
	if withTemple then
		local s = size * 0.12
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			cyl(model, "TempleColumn", center + Vector3.new(c[1] * s, 4.5, c[2] * s), 8, 1.2, { Color = MARBLE })
		end
		MP(model, { Name = "TempleRoof", Size = Vector3.new(s * 2 + 3, 1.2, s * 2 + 3), Position = center + Vector3.new(0, 9.2, 0), Color = MARBLE_WARM })
		local gem = ballPart(model, "TempleGem", center + Vector3.new(0, 4, 0), 2, noCollide({ Material = M.Neon, Color = Color3.fromRGB(150, 210, 255) }))
		light(gem, Color3.fromRGB(150, 210, 255), 24, 2)
	else
		cypress(model, center + Vector3.new(size * 0.15, 0.7, 0), 12)
		olive(model, center + Vector3.new(-size * 0.15, 0.7, size * 0.1))
	end
	-- Waterfall of light pouring off the edge into the clouds
	local edge = center + Vector3.new(size * 0.48, 0, 0)
	local fallHeight = center.Y + 250
	local fall = MP(model, noCollide({ Name = "LightFall", Size = Vector3.new(0.6, fallHeight, size * 0.22), Position = edge + Vector3.new(0.6, -fallHeight / 2, 0),
		Material = M.Neon, Color = Color3.fromRGB(190, 230, 255), Transparency = 0.45 }))
	fall.CastShadow = false
	local mist = sparkles(fall, Color3.fromRGB(220, 240, 255), 10, 0.6, 3)
	mist.Lifetime = NumberRange.new(2, 4)
	tag(model, "OlympusBob", { Amplitude = rng:NextNumber(1.5, 3), Period = rng:NextNumber(7, 12) })
	model.Parent = folder
end

local function buildSkyIslands(folder)
	local islands = {
		{ 560, 40, 70, true }, { 620, 95, 50, false }, { 520, 160, 60, false }, { 600, 210, 80, true },
		{ 560, 270, 55, false }, { 640, 320, 45, false }, { 540, 20, 40, false }, { 680, 140, 65, true },
	}
	for i, spec in islands do
		local angle = math.rad(spec[2])
		local center = SUMMIT_CENTER + Vector3.new(math.cos(angle) * spec[1], spec[3], math.sin(angle) * spec[1])
		skyIsland(folder, center, spec[4] and 34 or 24 + (i % 3) * 4, spec[4])
	end
end

--------------------------------------------------------------------------
-- 7. Plaza buildings: architecture around the working parts
--------------------------------------------------------------------------
local function wedgePair(parent, center, width, height, depth, facingX)
	-- A triangular pediment made of two wedges (facing +X or -X)
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Pediment"
		wedge.Anchored = true
		wedge.Material = M.Marble
		wedge.Color = MARBLE
		wedge.Size = Vector3.new(depth, height, width / 2)
		local yaw = if facingX then (if side < 0 then 0 else 180) else (if side < 0 then 90 else -90)
		local offset = if facingX then Vector3.new(0, 0, side * width / 4) else Vector3.new(side * width / 4, 0, 0)
		wedge.CFrame = CFrame.new(center + offset) * CFrame.Angles(0, math.rad(yaw), 0)
		wedge.Parent = parent
	end
end

local function hallOfTheGods(folder)
	local model = Instance.new("Model")
	model.Name = "HallArchitecture"
	local c = Vector3.new(-42, FLOOR_TOP, -35)
	local height = 15
	-- Colonnade along the back and the two ends (the front, facing the plaza, stays open)
	for z = -49, -21, 7 do
		cyl(model, "HallColumn", Vector3.new(c.X - 11, c.Y + height / 2, z), height, 2, { Color = MARBLE })
	end
	for _, z in { -49, -21 } do
		for _, x in { c.X - 3, c.X + 5, c.X + 11 } do
			cyl(model, "HallColumn", Vector3.new(x, c.Y + height / 2, z), height, 2, { Color = MARBLE })
		end
	end
	MP(model, { Name = "HallEntablature", Size = Vector3.new(25, 1.8, 31), Position = Vector3.new(c.X, c.Y + height + 0.9, c.Z), Color = MARBLE_WARM })
	MP(model, { Name = "HallFrieze", Size = Vector3.new(25.4, 0.5, 31.4), Position = Vector3.new(c.X, c.Y + height + 0.1, c.Z), Material = M.Metal, Color = GOLD })
	MP(model, { Name = "HallRoof", Size = Vector3.new(23, 1.2, 31), Position = Vector3.new(c.X, c.Y + height + 2.4, c.Z), Color = MARBLE })
	wedgePair(model, Vector3.new(c.X, c.Y + height + 5, c.Z), 31, 4.4, 23, false)
	for _, z in { -50.5, -19.5 } do
		brazier(model, Vector3.new(c.X + 13, c.Y, z), Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 120, 40), 1)
	end
	local sign = MP(model, noCollide({ Name = "HallSign", Size = Vector3.new(1, 1, 1), Position = Vector3.new(c.X + 6, c.Y + height + 8, c.Z), Transparency = 1 }))
	WorldBuilder.AddLabel(sign, "Hall of the Gods", GOLD, 6)
	model.Parent = folder
end

local function ascensionRotunda(folder)
	local model = Instance.new("Model")
	model.Name = "AscensionRotunda"
	local c = Vector3.new(44, FLOOR_TOP, 0)
	local radius, height = 13.5, 20
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		if math.cos(angle) > -0.85 then -- leave the side facing the plaza open
			local p = Vector3.new(c.X + math.cos(angle) * radius, c.Y + height / 2, c.Z + math.sin(angle) * radius)
			cyl(model, "RotundaColumn", p, height, 2.2, { Color = MARBLE })
			MP(model, { Name = "RotundaCapital", Size = Vector3.new(3, 0.8, 3), Position = p + Vector3.new(0, height / 2 + 0.4, 0), Color = MARBLE_WARM })
		end
	end
	ring(model, "RotundaRing", Vector3.new(c.X, c.Y + height + 1.2, c.Z), radius, 30, 1.6, { Color = MARBLE_WARM })
	ring(model, "RotundaGold", Vector3.new(c.X, c.Y + height + 0.3, c.Z), radius + 0.2, 30, 0.4, { Material = M.Metal, Color = GOLD })
	local crownCenter = Vector3.new(c.X, c.Y + height + 7, c.Z)
	local crown = ring(model, "AscensionCrown", crownCenter, 6, 24, 0.5, noCollide({ Material = M.Neon, Color = Color3.fromRGB(150, 210, 255) }), CFrame.Angles(math.rad(12), 0, 0))
	tag(crown, "OlympusSpin", { Speed = 0.12, Pivot = crownCenter })
	local crown2 = ring(model, "AscensionCrown2", crownCenter, 4.5, 20, 0.35, noCollide({ Material = M.Neon, Color = GOLD }), CFrame.Angles(math.rad(-20), 0, 0))
	tag(crown2, "OlympusSpin", { Speed = -0.18, Pivot = crownCenter })
	local motes = MP(model, noCollide({ Name = "AscensionMotes", Size = Vector3.new(20, 18, 20), Position = c + Vector3.new(0, 10, 0), Transparency = 1 }))
	local e = sparkles(motes, Color3.fromRGB(170, 220, 255), 10, 0.25, 1.5)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Top
	model.Parent = folder
end

local function arenaGateFrame(folder)
	local model = Instance.new("Model")
	model.Name = "ArenaGateFrame"
	local c = Vector3.new(-44, FLOOR_TOP, 0)
	local stoneRed = Color3.fromRGB(150, 95, 70)
	for _, z in { -9.5, 9.5 } do
		MP(model, { Name = "Pylon", Size = Vector3.new(6, 22, 5), Position = Vector3.new(c.X, c.Y + 11, c.Z + z), Color = Color3.fromRGB(205, 180, 150), Material = M.Sandstone })
		MP(model, { Name = "PylonCap", Size = Vector3.new(7, 1.4, 6), Position = Vector3.new(c.X, c.Y + 22.7, c.Z + z), Color = stoneRed, Material = M.Sandstone })
		MP(model, noCollide({ Name = "GateBanner", Size = Vector3.new(0.2, 11, 3.6), Position = Vector3.new(c.X + 3.15, c.Y + 13, c.Z + z), Material = M.Fabric, Color = Color3.fromRGB(190, 45, 35) }))
		MP(model, noCollide({ Name = "BannerEmblem", Size = Vector3.new(0.25, 2, 2), Position = Vector3.new(c.X + 3.2, c.Y + 15, c.Z + z), Material = M.Metal, Color = GOLD }))
		brazier(model, Vector3.new(c.X + 6, c.Y, c.Z + z * 1.25), Color3.fromRGB(255, 140, 60), Color3.fromRGB(255, 70, 30), 1.1)
	end
	MP(model, { Name = "GateBeam", Size = Vector3.new(5, 3, 25), Position = Vector3.new(c.X, c.Y + 19.5, c.Z), Color = Color3.fromRGB(205, 180, 150), Material = M.Sandstone })
	-- Steps up to the portal
	for i = 1, 2 do
		MP(model, { Name = "GateStep", Size = Vector3.new(3, 0.4 * i, 16 - i * 2), Position = Vector3.new(c.X + 5 - i * 1.5, c.Y + 0.2 * i, c.Z), Color = MARBLE_DARK })
	end
	model.Parent = folder
end

local function forgeSmithy(folder)
	local model = Instance.new("Model")
	model.Name = "ForgeSmithy"
	local c = Vector3.new(42, FLOOR_TOP, -36)
	local wood = Color3.fromRGB(105, 75, 50)
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		MP(model, { Name = "ForgePost", Size = Vector3.new(1.2, 17, 1.2), Position = Vector3.new(c.X + corner[1] * 9.5, c.Y + 8.5, c.Z + corner[2] * 8.5), Material = M.Wood, Color = wood })
	end
	-- Sloped roof (two tilted planks) with a ridge beam
	for _, side in { -1, 1 } do
		MP(model, { Name = "ForgeRoof", Size = Vector3.new(21, 0.6, 10.5),
			CFrame = CFrame.new(c.X, c.Y + 18.4, c.Z + side * 4.7) * CFrame.Angles(math.rad(side * 22), 0, 0),
			Material = M.WoodPlanks, Color = Color3.fromRGB(140, 70, 50) })
	end
	MP(model, { Name = "RidgeBeam", Size = Vector3.new(21.5, 0.8, 0.8), Position = Vector3.new(c.X, c.Y + 20.3, c.Z), Material = M.Wood, Color = wood })
	-- Chimney with smoke
	local chimney = MP(model, { Name = "Chimney", Size = Vector3.new(3, 8, 3), Position = Vector3.new(c.X + 6, c.Y + 21.5, c.Z + 4), Material = M.Brick, Color = Color3.fromRGB(130, 80, 60) })
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(90, 85, 85)
	smoke.Opacity = 0.18
	smoke.RiseVelocity = 6
	smoke.Size = 3
	smoke.Parent = chimney
	-- Glowing lava trough
	local trough = MP(model, { Name = "LavaTrough", Size = Vector3.new(2.2, 1.2, 8), Position = Vector3.new(c.X - 7, c.Y + 0.6, c.Z), Material = M.Slate, Color = Color3.fromRGB(70, 60, 60) })
	local lava = MP(model, noCollide({ Name = "Lava", Size = Vector3.new(1.6, 0.2, 7.4), Position = trough.Position + Vector3.new(0, 0.55, 0), Material = M.Neon, Color = Color3.fromRGB(255, 110, 30) }))
	light(lava, Color3.fromRGB(255, 120, 50), 16, 2)
	-- Sparks at the anvil
	local sparkPoint = MP(model, noCollide({ Name = "AnvilSparks", Size = Vector3.new(1, 1, 1), Position = Vector3.new(42, c.Y + 3.6, -38), Transparency = 1 }))
	local sp = Instance.new("ParticleEmitter")
	sp.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 90, 20))
	sp.LightEmission = 1
	sp.Rate = 8
	sp.Lifetime = NumberRange.new(0.3, 0.7)
	sp.Speed = NumberRange.new(6, 12)
	sp.SpreadAngle = Vector2.new(60, 60)
	sp.EmissionDirection = Enum.NormalId.Top
	sp.Acceleration = Vector3.new(0, -30, 0)
	sp.Size = NumberSequence.new(0.18, 0)
	sp.Parent = sparkPoint
	-- Weapon rack with a few weapons on display
	MP(model, { Name = "Rack", Size = Vector3.new(0.6, 0.6, 9), Position = Vector3.new(c.X + 9, c.Y + 5, c.Z), Material = M.Wood, Color = wood })
	for i, weaponId in { "IronSword", "HopliteSpear", "MinotaursLabrys", "SilverLongbow" } do
		local ok, weaponModel = pcall(SwordBuilder.Build, Color3.fromRGB(255, 200, 120), WeaponConfig.Weapons[weaponId])
		if ok and weaponModel then
			weaponModel:PivotTo(CFrame.new(c.X + 8.6, c.Y + 3.4, c.Z - 3.6 + (i - 1) * 2.4) * CFrame.Angles(0, 0, math.rad(8)))
			for _, item in weaponModel:GetDescendants() do
				if item:IsA("BasePart") then
					item.Anchored = true
					item.CanCollide = false
				elseif item:IsA("Trail") then
					item.Enabled = false
				end
			end
			weaponModel.Parent = model
		end
	end
	model.Parent = folder
end

--------------------------------------------------------------------------
-- 6. Temple plots: border, corner obelisks, entrance arch, walkway
--------------------------------------------------------------------------
local function decoratePlot(folder, plot)
	local base = plot:FindFirstChild("Base")
	if not base then
		return
	end
	local c = base.Position
	local half = base.Size.X / 2
	local top = c.Y + base.Size.Y / 2
	local model = Instance.new("Model")
	model.Name = "PlotDecor_" .. plot.Name
	-- Foundation and a marble curb around the edge (gap at the front entrance)
	MP(model, { Name = "PlotFoundation", Size = Vector3.new(base.Size.X + 4, 3, base.Size.Z + 4), Position = Vector3.new(c.X, top - 2.6, c.Z), Color = MARBLE_DARK })
	for _, side in { "Left", "Right", "Back", "FrontLeft", "FrontRight" } do
		local size, pos
		if side == "Left" or side == "Right" then
			local x = if side == "Left" then -half + 0.6 else half - 0.6
			size, pos = Vector3.new(1.2, 1, base.Size.Z), Vector3.new(c.X + x, top + 0.5, c.Z)
		elseif side == "Back" then
			size, pos = Vector3.new(base.Size.X, 1, 1.2), Vector3.new(c.X, top + 0.5, c.Z + half - 0.6)
		else
			local x = if side == "FrontLeft" then -(half + 10) / 2 else (half + 10) / 2
			size, pos = Vector3.new(half - 10, 1, 1.2), Vector3.new(c.X + x, top + 0.5, c.Z - half + 0.6)
		end
		MP(model, { Name = "Curb", Size = size, Position = pos, Color = MARBLE })
		MP(model, { Name = "CurbGold", Size = size + Vector3.new(0.1, -0.7, 0.1), Position = pos + Vector3.new(0, 0.55, 0), Material = M.Metal, Color = GOLD, CanCollide = false })
	end
	-- Corner obelisks with braziers
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local p = Vector3.new(c.X + corner[1] * (half - 2.5), top, c.Z + corner[2] * (half - 2.5))
		MP(model, { Name = "ObeliskBase", Size = Vector3.new(4, 1.2, 4), Position = p + Vector3.new(0, 0.6, 0), Color = MARBLE_DARK })
		MP(model, { Name = "Obelisk", Size = Vector3.new(2.4, 9, 2.4), Position = p + Vector3.new(0, 5.7, 0), Color = MARBLE })
		local bowl = cyl(model, "ObeliskFlame", p + Vector3.new(0, 10.7, 0), 1, 3.2, { Material = M.Metal, Color = GOLD })
		fire(bowl, Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 120, 40), 4)
		light(bowl, Color3.fromRGB(255, 190, 120), 18, 1.2)
	end
	-- Entrance arch at the front
	local front = Vector3.new(c.X, top, c.Z - half + 0.6)
	for _, x in { -8, 8 } do
		cyl(model, "ArchPillar", front + Vector3.new(x, 7, 0), 14, 1.8, { Color = MARBLE })
	end
	MP(model, { Name = "ArchTop", Size = Vector3.new(19, 1.6, 2.6), Position = front + Vector3.new(0, 14.6, 0), Color = MARBLE_WARM })
	MP(model, { Name = "ArchGold", Size = Vector3.new(19.4, 0.4, 2.8), Position = front + Vector3.new(0, 13.7, 0), Material = M.Metal, Color = GOLD })
	-- A marble walkway from the entrance towards the temple
	MP(model, { Name = "Walkway", Size = Vector3.new(7, 0.12, half - 4), Position = Vector3.new(c.X, top + 0.06, c.Z - half / 2 - 2), Color = MARBLE_WARM, CanCollide = false })
	model.Parent = folder
end

--------------------------------------------------------------------------
function HubDecor.Build()
	local hub = Workspace:WaitForChild("Hub")
	local old = Workspace:FindFirstChild("OlympusDecor")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "OlympusDecor"
	folder.Parent = Workspace

	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = folder
	buildPlaza(hub, plaza)
	task.wait()

	local statues = Instance.new("Folder")
	statues.Name = "Statues"
	statues.Parent = folder
	for _, spec in STATUES do
		local ok, err = pcall(buildStatue, statues, spec)
		if not ok then
			warn("[HubDecor] statue " .. spec.God .. ": " .. tostring(err))
		end
		task.wait()
	end

	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = folder
	for _, builder in { hallOfTheGods, ascensionRotunda, arenaGateFrame, forgeSmithy } do
		local ok, err = pcall(builder, buildings)
		if not ok then
			warn("[HubDecor] building: " .. tostring(err))
		end
	end
	task.wait()

	local paths = Instance.new("Folder")
	paths.Name = "Paths"
	paths.Parent = folder
	decoratePaths(hub, paths)
	task.wait()

	local summit = Instance.new("Folder")
	summit.Name = "Summit"
	summit.Parent = folder
	buildSummit(summit)
	task.wait()

	local sky = Instance.new("Folder")
	sky.Name = "SkyIslands"
	sky.Parent = folder
	buildSkyIslands(sky)
	task.wait()

	local plots = Workspace:FindFirstChild("TemplePlots")
	if plots then
		local plotDecor = Instance.new("Folder")
		plotDecor.Name = "Plots"
		plotDecor.Parent = folder
		for _, plot in plots:GetChildren() do
			decoratePlot(plotDecor, plot)
		end
	end
end

return HubDecor
