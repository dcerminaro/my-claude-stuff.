-- SwordBuilder (ModuleScript)
-- Location: ReplicatedStorage > Shared > SwordBuilder
--
-- Builds the placeholder "Divine Sword" out of parts and welds it into a
-- character's right hand. The blade's glowing core, the guard gems and the
-- swing trail use the player's god colour. Real weapons come in Phase 7.
--
-- Sword space: the grip is at the origin and the blade points along +Y.
-- In the hand, the blade points the way the knuckles face, so with the arm
-- hanging down it points forward, and with the forearm forward it points up.

local SwordBuilder = {}

SwordBuilder.Name = "DivineSword"

local GOLD = Color3.fromRGB(212, 175, 55)
local STEEL = Color3.fromRGB(214, 220, 230)
local LEATHER = Color3.fromRGB(100, 62, 38)

local function part(model, name, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

function SwordBuilder.Build(glowColor)
	local model = Instance.new("Model")
	model.Name = SwordBuilder.Name
	local M = Enum.Material

	local grip = part(model, "Grip", Vector3.new(0.24, 1.0, 0.24), CFrame.new(), LEATHER, M.Fabric)
	part(model, "Pommel", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, -0.62, 0), GOLD, M.Metal, Enum.PartType.Ball)
	part(model, "Guard", Vector3.new(1.5, 0.2, 0.32), CFrame.new(0, 0.6, 0), GOLD, M.Metal)
	part(model, "GuardEndL", Vector3.new(0.3, 0.3, 0.3), CFrame.new(-0.75, 0.6, 0), GOLD, M.Metal, Enum.PartType.Ball)
	part(model, "GuardEndR", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0.75, 0.6, 0), GOLD, M.Metal, Enum.PartType.Ball)
	part(model, "Gem", Vector3.new(0.26, 0.26, 0.4), CFrame.new(0, 0.6, 0), glowColor, M.Neon, Enum.PartType.Ball)
	local blade = part(model, "Blade", Vector3.new(0.4, 3.0, 0.09), CFrame.new(0, 2.2, 0), STEEL, M.Metal)
	part(model, "Fuller", Vector3.new(0.1, 2.5, 0.12), CFrame.new(0, 2.05, 0), glowColor, M.Neon)
	-- A small diamond turned 45 degrees makes the point of the blade.
	part(model, "Tip", Vector3.new(0.283, 0.283, 0.09), CFrame.new(0, 3.7, 0) * CFrame.Angles(0, 0, math.rad(45)), STEEL, M.Metal)

	for _, item in model:GetChildren() do
		if item ~= grip then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = grip
			weld.Part1 = item
			weld.Parent = item
		end
	end

	-- Light trail from just above the guard to the tip, shown while swinging.
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailBase"
	a0.Position = Vector3.new(0, -1.2, 0)
	a0.Parent = blade
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailTip"
	a1.Position = Vector3.new(0, 1.6, 0)
	a1.Parent = blade
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.18
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(glowColor)
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Enabled = false
	trail.Parent = blade

	model.PrimaryPart = grip
	return model
end

-- Welds a new sword into the character's right hand. Returns the sword.
function SwordBuilder.Attach(character, glowColor)
	local existing = character:FindFirstChild(SwordBuilder.Name)
	if existing then
		return existing
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return nil
	end
	local sword = SwordBuilder.Build(glowColor)
	local gripPoint = hand:FindFirstChild("RightGripAttachment")
	local offset = if gripPoint then CFrame.new(gripPoint.Position) else CFrame.new(0, -hand.Size.Y / 2, 0)
	local c0 = offset * CFrame.Angles(math.rad(-90), 0, 0) -- blade (+Y) -> knuckle direction (-Z)
	sword:PivotTo(hand.CFrame * c0)

	local weld = Instance.new("Weld")
	weld.Name = "SwordGrip"
	weld.Part0 = hand
	weld.Part1 = sword.PrimaryPart
	weld.C0 = c0
	weld.Parent = sword.PrimaryPart
	sword.Parent = character
	return sword
end

function SwordBuilder.SetColor(sword, glowColor)
	for _, name in { "Gem", "Fuller" } do
		local p = sword:FindFirstChild(name)
		if p then
			p.Color = glowColor
		end
	end
	local blade = sword:FindFirstChild("Blade")
	local trail = blade and blade:FindFirstChild("SwingTrail")
	if trail then
		trail.Color = ColorSequence.new(glowColor)
	end
end

function SwordBuilder.GetTrail(character)
	local sword = character and character:FindFirstChild(SwordBuilder.Name)
	local blade = sword and sword:FindFirstChild("Blade")
	return blade and blade:FindFirstChild("SwingTrail")
end

return SwordBuilder
