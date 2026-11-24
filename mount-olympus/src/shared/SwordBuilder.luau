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

-- Phase 7C: `weapon` (a WeaponConfig entry) picks the type and colours.
-- Without it you get the original sword. The model's name stays
-- "DivineSword" so the animation and trail code work for every weapon.
function SwordBuilder.Build(glowColor, weapon)
	local model = Instance.new("Model")
	model.Name = SwordBuilder.Name
	model:SetAttribute("WeaponId", if weapon then weapon.Id else "")
	local M = Enum.Material
	local look = if weapon then weapon.Look or {} else {}
	local kind = if weapon then weapon.Type else "Sword"
	local metal = look.Blade or STEEL
	local handleColor = look.Handle or Color3.fromRGB(110, 75, 45)
	local glow = look.Glow or glowColor
	local L = look.Length or 3.0

	local grip = part(model, "Grip", Vector3.new(0.24, 1.0, 0.24), CFrame.new(), if kind == "Sword" then LEATHER else handleColor, if kind == "Sword" then M.Fabric else M.Wood)
	local blade

	if kind == "Sword" then
		part(model, "Pommel", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, -0.62, 0), GOLD, M.Metal, Enum.PartType.Ball)
		part(model, "Guard", Vector3.new(1.5, 0.2, 0.32), CFrame.new(0, 0.6, 0), GOLD, M.Metal)
		part(model, "GuardEndL", Vector3.new(0.3, 0.3, 0.3), CFrame.new(-0.75, 0.6, 0), GOLD, M.Metal, Enum.PartType.Ball)
		part(model, "GuardEndR", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0.75, 0.6, 0), GOLD, M.Metal, Enum.PartType.Ball)
		part(model, "Gem", Vector3.new(0.26, 0.26, 0.4), CFrame.new(0, 0.6, 0), glow, M.Neon, Enum.PartType.Ball)
		blade = part(model, "Blade", Vector3.new(0.4, L, 0.09), CFrame.new(0, 0.7 + L / 2, 0), metal, M.Metal)
		part(model, "Fuller", Vector3.new(0.1, L - 0.5, 0.12), CFrame.new(0, 0.55 + L / 2, 0), glow, M.Neon)
		-- A small diamond turned 45 degrees makes the point of the blade.
		part(model, "Tip", Vector3.new(0.283, 0.283, 0.09), CFrame.new(0, 0.7 + L, 0) * CFrame.Angles(0, 0, math.rad(45)), metal, M.Metal)
	elseif kind == "Axe" then
		part(model, "Haft", Vector3.new(0.22, L, 0.22), CFrame.new(0, L / 2 - 0.4, 0), handleColor, M.Wood)
		blade = part(model, "Blade", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, L - 0.9, 0), metal, M.Metal)
		for _, side in { -1, 1 } do
			part(model, "AxeHead", Vector3.new(1.1, 1.4, 0.12), CFrame.new(side * 0.6, L - 0.9, 0), metal, M.Metal)
			part(model, "AxeEdge", Vector3.new(0.14, 1.6, 0.16), CFrame.new(side * 1.15, L - 0.9, 0), glow, M.Neon)
		end
	elseif kind == "Spear" or kind == "Trident" then
		part(model, "Shaft", Vector3.new(0.2, L + 1.6, 0.2), CFrame.new(0, (L + 1.6) / 2 - 1.4, 0), handleColor, M.Wood)
		if kind == "Spear" then
			blade = part(model, "Blade", Vector3.new(0.55, 0.55, 0.1), CFrame.new(0, L, 0) * CFrame.Angles(0, 0, math.rad(45)), metal, M.Metal)
			part(model, "Point", Vector3.new(0.12, 0.9, 0.14), CFrame.new(0, L + 0.5, 0), glow, M.Neon)
		else
			part(model, "Crossbar", Vector3.new(1.3, 0.16, 0.16), CFrame.new(0, L - 0.6, 0), metal, M.Metal)
			for i, x in { -0.6, 0, 0.6 } do
				local prong = part(model, "Prong" .. i, Vector3.new(0.14, 1.3, 0.14), CFrame.new(x, L + 0.05, 0), metal, M.Metal)
				if i == 2 then
					blade = prong
				end
				part(model, "ProngTip" .. i, Vector3.new(0.16, 0.3, 0.16), CFrame.new(x, L + 0.8, 0), glow, M.Neon)
			end
		end
		part(model, "Band", Vector3.new(0.3, 0.25, 0.3), CFrame.new(0, L - 0.9, 0), glow, M.Neon)
	else -- Bow: a curved stave and a glowing string
		local half = L / 2
		local points = {}
		for i = 0, 6 do
			local y = -half + (i / 6) * L
			table.insert(points, Vector3.new(0, y, 0.55 * (y / half) ^ 2))
		end
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local seg = part(model, "Limb" .. i, Vector3.new(0.22, (b - a).Magnitude + 0.05, 0.18),
				CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(math.rad(90), 0, 0), metal, M.Wood)
			if i == 6 then
				blade = seg
			end
		end
		local top, bottom = points[#points], points[1]
		part(model, "String", Vector3.new(0.05, (top - bottom).Magnitude, 0.05), CFrame.new((top + bottom) / 2 + Vector3.new(0, 0, 0.05)), glow, M.Neon)
	end

	for _, item in model:GetChildren() do
		if item ~= grip then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = grip
			weld.Part1 = item
			weld.Parent = item
		end
	end

	-- Light trail along the striking end, shown while swinging.
	local reach = if kind == "Sword" then L / 2 + 0.1 else 0.6
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailBase"
	a0.Position = Vector3.new(0, -reach + 0.2, 0)
	a0.Parent = blade
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailTip"
	a1.Position = Vector3.new(0, reach, 0)
	a1.Parent = blade
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.18
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(glow)
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Enabled = false
	trail.Parent = blade

	model.PrimaryPart = grip
	return model
end

-- Welds a new weapon into the character's right hand. Returns it.
-- A different weapon than the one held is swapped out.
function SwordBuilder.Attach(character, glowColor, weapon)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local existing = character:FindFirstChild(SwordBuilder.Name)
	if existing and existing:GetAttribute("WeaponId") ~= (if weapon then weapon.Id else "") then
		existing:Destroy()
		existing = nil
	end
	if existing then
		-- Still properly held? (Avatar loading can replace the hand and break the weld.)
		local grip = existing.PrimaryPart
		local weld = grip and grip:FindFirstChild("SwordGrip")
		if weld and weld.Part0 == hand and hand ~= nil and hand.Parent == character then
			return existing
		end
		existing:Destroy()
	end
	if not hand then
		return nil
	end
	local sword = SwordBuilder.Build(glowColor, weapon)
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
	local weaponId = sword:GetAttribute("WeaponId")
	if weaponId and weaponId ~= "" and weaponId ~= "BronzeSword" then
		return -- weapons with their own glow keep it
	end
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
