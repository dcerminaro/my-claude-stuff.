-- RankOutfits (ModuleScript)
-- Location: ReplicatedStorage > Shared > RankOutfits
--
-- Builds the rank outfit out of parts and welds it OVER the player's own
-- avatar (their look is kept). Each rank adds pieces; materials improve:
-- leather (Warrior) -> bronze (Champion, Hero) -> steel (Demigod) -> gold.
-- Pieces are sized from the body part they sit on, so they fit any avatar.
-- RankOutfits.Apply(character, rankIndex, godColor) replaces any old outfit.

local AscensionConfig = require(script.Parent:WaitForChild("AscensionConfig"))

local RankOutfits = {}

RankOutfits.Name = "RankOutfit"

local LEATHER = { Color3.fromRGB(110, 72, 40), Enum.Material.Leather }
local BRONZE = { Color3.fromRGB(176, 112, 56), Enum.Material.Metal }
local STEEL = { Color3.fromRGB(200, 205, 215), Enum.Material.Metal }
local GOLD = { Color3.fromRGB(226, 186, 72), Enum.Material.Metal }
local HERO_RED = Color3.fromRGB(165, 30, 35)

local function armour(rank)
	if rank >= 6 then
		return GOLD
	elseif rank >= 5 then
		return STEEL
	elseif rank >= 3 then
		return BRONZE
	end
	return LEATHER
end

local function piece(model, bodyPart, name, size, offset, look, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = look[1]
	p.Material = look[2]
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props or {} do
		p[key] = value
	end
	p.CFrame = bodyPart.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bodyPart
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

function RankOutfits.Apply(character, rank, godColor)
	local old = character:FindFirstChild(RankOutfits.Name)
	if old then
		old:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local oldAura = root and root:FindFirstChild("RankAura")
	if oldAura then
		oldAura:Destroy()
	end
	if rank < 2 then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = RankOutfits.Name
	local metal = armour(rank)
	local trim = if rank >= 5 then GOLD else metal
	local glow = { godColor, Enum.Material.Neon }
	local function part(name)
		return character:FindFirstChild(name)
	end

	-- Warrior: shoulder pads, bracers, belt
	for _, side in { "Left", "Right" } do
		local upper = part(side .. "UpperArm")
		if upper then
			local s = upper.Size
			piece(model, upper, side .. "ShoulderPad", Vector3.new(s.X * 1.45, 0.32, s.Z * 1.4), CFrame.new(0, s.Y / 2 - 0.08, 0), metal)
			if rank >= 5 then
				piece(model, upper, side .. "ShoulderTrim", Vector3.new(s.X * 1.5, 0.1, s.Z * 1.45), CFrame.new(0, s.Y / 2 - 0.26, 0), trim)
			end
		end
		local lower = part(side .. "LowerArm")
		if lower then
			local s = lower.Size
			piece(model, lower, side .. "Bracer", Vector3.new(s.X * 1.2, s.Y * 0.55, s.Z * 1.2), CFrame.new(0, -s.Y * 0.12, 0), metal)
		end
	end
	local lowerTorso = part("LowerTorso")
	if lowerTorso then
		local s = lowerTorso.Size
		piece(model, lowerTorso, "Belt", Vector3.new(s.X * 1.08, s.Y * 0.38, s.Z * 1.12), CFrame.new(0, s.Y * 0.12, 0), if rank >= 5 then GOLD else LEATHER)
		piece(model, lowerTorso, "Buckle", Vector3.new(s.X * 0.22, s.Y * 0.3, 0.1), CFrame.new(0, s.Y * 0.12, -s.Z * 0.56 - 0.03), trim)
	end

	-- Champion: chest plate, greaves
	local upperTorso = part("UpperTorso")
	if rank >= 3 then
		if upperTorso then
			local s = upperTorso.Size
			piece(model, upperTorso, "ChestPlate", Vector3.new(s.X * 1.06, s.Y * 0.82, s.Z * 1.16), CFrame.new(0, s.Y * 0.04, 0), metal)
			piece(model, upperTorso, "ChestRidge", Vector3.new(s.X * 0.12, s.Y * 0.7, 0.08), CFrame.new(0, s.Y * 0.04, -s.Z * 0.58 - 0.02), trim)
		end
		for _, side in { "Left", "Right" } do
			local leg = part(side .. "LowerLeg")
			if leg then
				local s = leg.Size
				piece(model, leg, side .. "Greave", Vector3.new(s.X * 1.18, s.Y * 0.72, s.Z * 1.18), CFrame.new(0, s.Y * 0.06, 0), metal)
			end
		end
	end

	-- Hero: cape (red, then the god's colour from Lesser God)
	if rank >= 4 and upperTorso then
		local s = upperTorso.Size
		local length = s.Y * 2.3
		piece(model, upperTorso, "Cape", Vector3.new(s.X * 0.95, length, 0.1),
			CFrame.new(0, s.Y / 2 - length / 2 + 0.05, s.Z / 2 + 0.12) * CFrame.Angles(math.rad(-6), 0, 0),
			{ if rank >= 6 then godColor else HERO_RED, Enum.Material.Fabric })
	end

	-- Demigod: glowing chest gem
	if rank >= 5 and upperTorso then
		local s = upperTorso.Size
		piece(model, upperTorso, "ChestGem", Vector3.new(0.38, 0.38, 0.38), CFrame.new(0, s.Y * 0.18, -s.Z * 0.58 - 0.08), glow, { Shape = Enum.PartType.Ball })
	end

	-- Lesser God: laurel wreath
	local head = part("Head")
	if rank >= 6 and head then
		local s = head.Size
		local radius = math.max(s.X, s.Z) * 0.55
		for i = 0, 11 do
			local angle = (i / 12) * math.pi * 2
			if i ~= 0 and i ~= 11 then -- gap at the front
				piece(model, head, "Leaf" .. i, Vector3.new(0.12, 0.16, 0.42),
					CFrame.new(math.sin(angle) * radius, s.Y * 0.22, -math.cos(angle) * radius) * CFrame.Angles(0, -angle, math.rad(25)),
					{ Color3.fromRGB(200, 170, 60), Enum.Material.Metal })
			end
		end
	end

	-- Olympian: wings of light, three fanned feathers per side
	if rank >= 7 and upperTorso then
		local s = upperTorso.Size
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				local length = s.Y * (1.25 - i * 0.25)
				local angle = 25 + i * 22 -- tilt outwards from straight up
				local base = CFrame.new(side * s.X * 0.18, s.Y * 0.28, s.Z / 2 + 0.18)
				piece(model, upperTorso, ("Wing%s%d"):format(if side < 0 then "L" else "R", i),
					Vector3.new(s.X * 0.32, length, 0.06),
					base * CFrame.Angles(math.rad(-18), 0, math.rad(-side * angle)) * CFrame.new(0, length / 2, 0),
					glow, { Transparency = 0.3 })
			end
		end
	end

	-- Elder God: halo
	if rank >= 8 and head then
		local s = head.Size
		local radius = math.max(s.X, s.Z) * 0.5
		for i = 0, 15 do
			local angle = (i / 16) * math.pi * 2
			piece(model, head, "Halo" .. i, Vector3.new(0.12, 0.08, radius * 0.42),
				CFrame.new(math.sin(angle) * radius, s.Y / 2 + 0.55, -math.cos(angle) * radius) * CFrame.Angles(0, -angle + math.pi / 2, 0),
				{ Color3.fromRGB(255, 236, 160), Enum.Material.Neon })
		end
	end

	model.Parent = character

	-- Aura from Demigod upwards
	local rate = AscensionConfig.AuraRate[rank]
	if rate and root then
		local attachment = Instance.new("Attachment")
		attachment.Name = "RankAura"
		attachment.Parent = root
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(godColor)
		emitter.LightEmission = 1
		emitter.Rate = rate
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(1, 2.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, 3, 0)
		emitter.Size = NumberSequence.new(0.35, 0)
		emitter.Parent = attachment
	end
	return model
end

return RankOutfits
