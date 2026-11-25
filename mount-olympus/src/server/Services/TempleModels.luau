-- TempleModels (ModuleScript)
-- Location: ServerScriptService > Services > TempleModels
--
-- Builds the PLACEHOLDER 3D models for the Temple Tycoon out of simple parts:
--   TempleModels.Temple(tier, origin, colors, prestige)     -> the main temple (tiers 1-7; prestige 0-10 decorations)
--   TempleModels.Building(buildingId, level, origin, colors) -> one of the 5 buildings (levels 1-6)
-- `colors` = the god's { Accent, Glow, Fire } from GodConfig (optional).
--   TempleModels.AnimateIn(model)                    -> "rise from the ground" construction effect
-- `origin` is a CFrame at ground level in the centre of the building's slot.
-- Models are returned un-parented; the caller parents them.
-- Replace these with proper models during Phase 8 polish.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldBuilder = require(ServerScriptService:WaitForChild("Services"):WaitForChild("WorldBuilder"))

local TempleModels = {}

local MARBLE = Color3.fromRGB(236, 232, 224)
local WORN_MARBLE = Color3.fromRGB(210, 205, 196)
local STONE = Color3.fromRGB(128, 122, 114)
local GOLD = Color3.fromRGB(212, 175, 55)
local WATER = Color3.fromRGB(80, 190, 230)
local SAND = Color3.fromRGB(214, 190, 140)
local WOOD = Color3.fromRGB(120, 85, 55)
local IRON = Color3.fromRGB(120, 120, 125)
local DIVINE_BLUE = Color3.fromRGB(110, 170, 255)

-- Phase 3: trims, glows and flames follow the player's god (GodConfig colours).
local DEFAULT_COLORS = { Accent = GOLD, Glow = DIVINE_BLUE }
local pal = DEFAULT_COLORS -- set at the start of each Temple()/Building() call

--------------------------------------------------------------------------
-- Part helpers (all positions are relative to `origin`)
--------------------------------------------------------------------------
local function block(model, origin, name, size, offset, props)
	local p = { Name = name, Size = size, CFrame = origin * CFrame.new(offset) }
	for key, value in props or {} do
		p[key] = value
	end
	return WorldBuilder.MakePart(model, p)
end

-- Vertical cylinder standing on `baseY`.
local function column(model, origin, name, x, baseY, z, height, diameter, props)
	local p = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = origin * CFrame.new(x, baseY + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
	}
	for key, value in props or {} do
		p[key] = value
	end
	return WorldBuilder.MakePart(model, p)
end

-- Flat disc (a short vertical cylinder) centred at height y.
local function disc(model, origin, name, x, y, z, thickness, diameter, props)
	return column(model, origin, name, x, y - thickness / 2, z, thickness, diameter, props)
end

local function ball(model, origin, name, diameter, offset, props)
	local p = { Name = name, Shape = Enum.PartType.Ball, Size = Vector3.new(diameter, diameter, diameter), CFrame = origin * CFrame.new(offset) }
	for key, value in props or {} do
		p[key] = value
	end
	return WorldBuilder.MakePart(model, p)
end

local function addLight(part, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 12
	light.Brightness = brightness or 1.5
	light.Parent = part
	return light
end

local function addFire(part, size)
	local fire = Instance.new("Fire")
	fire.Size = size or 5
	fire.Heat = 8
	if pal.Fire then
		fire.Color = pal.Fire
		fire.SecondaryColor = pal.Accent
	end
	fire.Parent = part
	return fire
end

-- Evenly spaced positions from a to b (inclusive), at least 2.
local function spread(a, b, spacing)
	local count = math.max(2, math.floor(math.abs(b - a) / spacing) + 1)
	local list = {}
	for i = 0, count - 1 do
		table.insert(list, a + (b - a) * i / (count - 1))
	end
	return list
end

--------------------------------------------------------------------------
-- Main temple
--------------------------------------------------------------------------
local function buildRuinedShrine(model, origin)
	block(model, origin, "Foundation", Vector3.new(22, 1, 22), Vector3.new(0, 0.5, 0), { Material = Enum.Material.Slate, Color = STONE })
	local floorY = 1

	block(model, origin, "Altar", Vector3.new(6, 3, 3), Vector3.new(0, floorY + 1.5, 0), { Material = Enum.Material.Slate, Color = Color3.fromRGB(165, 160, 152) })
	WorldBuilder.MakePart(model, {
		Name = "BrokenAltarTop",
		Size = Vector3.new(4, 0.8, 3.2),
		CFrame = origin * CFrame.new(1.5, floorY + 3.3, 0) * CFrame.Angles(0, 0, math.rad(-14)),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(150, 145, 138),
	})

	-- Column stumps: { x, z, height }
	for i, s in { { -8, -8, 7 }, { 8, -8, 3.5 }, { -8, 8, 2 }, { 8, 8, 9 } } do
		column(model, origin, "ColumnStump" .. i, s[1], floorY, s[2], s[3], 2.6, { Color = WORN_MARBLE })
	end

	WorldBuilder.MakePart(model, {
		Name = "FallenColumn",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(9, 2.4, 2.4),
		CFrame = origin * CFrame.new(-2, floorY + 1.2, -6) * CFrame.Angles(0, math.rad(25), 0),
		Color = WORN_MARBLE,
	})

	-- Rubble: { x, z, size }
	for i, r in { { 4, -3, 1.2 }, { -4, 3, 0.9 }, { 6, 5, 1.5 }, { -6, -2, 0.8 } } do
		WorldBuilder.MakePart(model, {
			Name = "Rubble" .. i,
			Size = Vector3.new(r[3], r[3] * 0.7, r[3]),
			CFrame = origin * CFrame.new(r[1], floorY + r[3] * 0.35, r[2]) * CFrame.Angles(0, math.rad(i * 37), 0),
			Material = Enum.Material.Slate,
			Color = STONE,
		})
	end
end

-- Look of each tier from 2 upwards. W = width (X), D = depth (Z).
local TEMPLE_STYLES = {
	[2] = { W = 20, D = 20, ColH = 9, Spacing = 6.5 },
	[3] = { W = 22, D = 26, ColH = 12, Spacing = 5.5, Cella = true, Roof = true },
	[4] = { W = 24, D = 28, ColH = 14, Spacing = 5, Cella = true, Roof = true, GoldTrim = true, Braziers = true },
	[5] = { W = 26, D = 28, ColH = 15, Spacing = 4.6, Cella = true, Roof = true, GoldTrim = true, Braziers = true, Dome = true, Statues = true },
	[6] = { W = 26, D = 28, ColH = 15, Spacing = 4.6, Cella = true, Roof = true, GoldTrim = true, Braziers = true, Dome = true, Statues = true, Floating = true },
	[7] = { W = 32, D = 34, ColH = 19, Spacing = 4.4, Cella = true, Roof = true, GoldTrim = true, Braziers = true, Dome = true, Statues = true, Floating = true, GoldColumns = true, Citadel = true },
}

-- Phase 7E: ring of small blocks (a halo) centred at `center`, flat.
local function ring(model, origin, name, center, radius, count, props)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local arc = 2 * math.pi * radius / count
		local p = {
			Name = name .. i,
			Size = Vector3.new(arc * 1.05, 0.5, 0.9),
			CFrame = origin * CFrame.new(center) * CFrame.Angles(0, -angle, 0) * CFrame.new(0, 0, radius) ,
			CanCollide = false,
		}
		for key, value in props or {} do
			p[key] = value
		end
		WorldBuilder.MakePart(model, p)
	end
end

-- Divine Citadel extras (tier 7): corner towers, a central spire and crown.
local function buildCitadel(model, origin, s, topY)
	local W, D = s.W, s.D
	local towerH = s.ColH + 14
	local gold = { Material = Enum.Material.Metal, Color = pal.Accent }
	for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local x, z = c[1] * (W / 2 - 1), c[2] * (D / 2 - 1)
		column(model, origin, "Tower" .. i, x, 0, z, towerH, 5, { Color = MARBLE, Material = Enum.Material.Marble })
		disc(model, origin, "TowerRim" .. i, x, towerH, z, 1, 6.4, gold)
		column(model, origin, "TowerRoof" .. i, x, towerH + 0.5, z, 4, 3.2, gold)
		local orb = ball(model, origin, "TowerOrb" .. i, 2.2, Vector3.new(x, towerH + 6, z), { Material = Enum.Material.Neon, Color = pal.Glow })
		addLight(orb, pal.Glow, 20, 2)
	end
	-- Walls between the towers at the back and sides (front stays open)
	block(model, origin, "WallBack", Vector3.new(W - 4, 8, 1.6), Vector3.new(0, 4, D / 2 - 1))
	block(model, origin, "WallLeft", Vector3.new(1.6, 8, D - 4), Vector3.new(-W / 2 + 1, 4, 0))
	block(model, origin, "WallRight", Vector3.new(1.6, 8, D - 4), Vector3.new(W / 2 - 1, 4, 0))
	-- Central spire rising out of the dome with a glowing crown
	local spireBase = topY + W * 0.2
	column(model, origin, "Spire", 0, spireBase, 4, 16, 2, gold)
	ring(model, origin, "Crown", Vector3.new(0, spireBase + 16.5, 4), 2.6, 10, { Material = Enum.Material.Neon, Color = pal.Accent })
	local crown = ball(model, origin, "CrownGem", 2.6, Vector3.new(0, spireBase + 18, 4), { Material = Enum.Material.Neon, Color = pal.Glow })
	addLight(crown, pal.Glow, 40, 3)
	-- Grand stairway at the front
	block(model, origin, "Stair1", Vector3.new(12, 0.6, 3), Vector3.new(0, 0.3, -D / 2 - 3.5))
	block(model, origin, "Stair2", Vector3.new(10, 0.6, 2), Vector3.new(0, 0.9, -D / 2 - 2.5))
	return spireBase + 18
end

-- Temple Prestige decorations (Phase 7E). See TempleConfig.Prestige.Looks.
local function buildPrestige(model, origin, s, topY, crownY, prestige)
	local W, D = s.W, s.D
	local gold = { Material = Enum.Material.Metal, Color = pal.Accent }
	local glow = { Material = Enum.Material.Neon, Color = pal.Glow, CanCollide = false }
	if prestige >= 1 then -- banners
		for i, x in { -W / 2 + 4, -W / 6, W / 6, W / 2 - 4 } do
			block(model, origin, "Banner" .. i, Vector3.new(2.4, 7, 0.2), Vector3.new(x, s.ColH - 2, -D / 2 - 0.4), { Color = pal.Accent, Material = Enum.Material.Fabric, CanCollide = false })
		end
	end
	if prestige >= 2 then -- ring of glowing pillars
		for i = 1, 8 do
			local angle = i / 8 * math.pi * 2
			local x, z = math.cos(angle) * (W / 2 + 6), math.sin(angle) * (D / 2 + 6) + 0
			if z > -D / 2 - 2 then -- keep the entrance clear
				column(model, origin, "PrestigePillar" .. i, x, 0, z, 6, 1, glow)
			end
		end
	end
	if prestige >= 3 then
		ring(model, origin, "Halo", Vector3.new(0, topY + W * 0.35, 4), W * 0.3, 20, glow)
	end
	if prestige >= 4 then -- stars on the front
		for i = 1, math.min(prestige, 10) do
			local x = (i - (math.min(prestige, 10) + 1) / 2) * 2.2
			ball(model, origin, "Star" .. i, 1.2, Vector3.new(x, s.ColH + 4.2, -D / 2 - 0.6), glow)
		end
	end
	if prestige >= 5 then -- beam of light into the sky
		column(model, origin, "SkyBeam", 0, crownY, 4, 120, 3, { Material = Enum.Material.Neon, Color = pal.Glow, Transparency = 0.6, CanCollide = false, CastShadow = false })
	end
	if prestige >= 6 then
		local skyY = topY + 12
		for i, pos in { Vector3.new(-22, skyY + 4, 16), Vector3.new(22, skyY + 6, 16) } do
			block(model, origin, "PrestigeIsland" .. i, Vector3.new(7, 1.2, 7), pos)
			block(model, origin, "PrestigeIslandGold" .. i, Vector3.new(7.4, 0.4, 7.4), pos - Vector3.new(0, 0.8, 0), gold)
			local orb = ball(model, origin, "PrestigeOrb" .. i, 1.6, pos + Vector3.new(0, 3, 0), glow)
			addLight(orb, pal.Glow, 14, 2)
		end
	end
	if prestige >= 7 then -- flames on the towers
		for _, item in model:GetChildren() do
			if item.Name:match("^TowerRoof") then
				addFire(item, 6)
			end
		end
	end
	if prestige >= 8 then
		ring(model, origin, "GreatHalo", Vector3.new(0, topY + W * 0.55, 4), W * 0.5, 28, { Material = Enum.Material.Neon, Color = pal.Accent, CanCollide = false })
	end
	if prestige >= 9 then -- golden statues at the gates
		for i, x in { -9, 9 } do
			block(model, origin, "GatePedestal" .. i, Vector3.new(3, 2, 3), Vector3.new(x, 1, -D / 2 - 7))
			block(model, origin, "GateStatueBody" .. i, Vector3.new(2, 5, 1.4), Vector3.new(x, 4.5, -D / 2 - 7), gold)
			ball(model, origin, "GateStatueHead" .. i, 1.6, Vector3.new(x, 7.8, -D / 2 - 7), gold)
		end
	end
	if prestige >= 10 then -- radiant: marble glows faintly in the god's colour
		for _, item in model:GetChildren() do
			if item:IsA("BasePart") and item.Material == Enum.Material.Marble then
				item.Color = item.Color:Lerp(pal.Glow, 0.25)
			end
		end
		local radiance = model:FindFirstChild("CrownGem")
		if radiance then
			addLight(radiance, pal.Accent, 60, 4)
		end
	end
end

local function buildTempleStyle(model, origin, s, prestige)
	local W, D = s.W, s.D

	-- Two-step platform
	block(model, origin, "Step", Vector3.new(W + 4, 0.8, D + 4), Vector3.new(0, 0.4, 0))
	block(model, origin, "Platform", Vector3.new(W, 1.2, D), Vector3.new(0, 1.4, 0))
	local floorY = 2

	-- Perimeter columns
	local columnColor = if s.GoldColumns then pal.Accent else MARBLE
	local columnMaterial = if s.GoldColumns then Enum.Material.Metal else Enum.Material.Marble
	local x0, x1 = -W / 2 + 1.6, W / 2 - 1.6
	local z0, z1 = -D / 2 + 1.6, D / 2 - 1.6
	local n = 0
	local function addColumn(x, z)
		n += 1
		column(model, origin, "Column" .. n, x, floorY, z, s.ColH, 2.2, { Color = columnColor, Material = columnMaterial })
	end
	for _, x in spread(x0, x1, s.Spacing) do
		addColumn(x, z0)
		addColumn(x, z1)
	end
	local sideZ = spread(z0, z1, s.Spacing)
	for i = 2, #sideZ - 1 do
		addColumn(x0, sideZ[i])
		addColumn(x1, sideZ[i])
	end

	-- Inner chamber (cella)
	if s.Cella then
		block(model, origin, "Cella", Vector3.new(W - 8, s.ColH, D - 10), Vector3.new(0, floorY + s.ColH / 2, 2), { Color = Color3.fromRGB(225, 218, 205) })
	end

	-- Altar in front of the chamber
	local altar = block(model, origin, "Altar", Vector3.new(5, 2.5, 2.5), Vector3.new(0, floorY + 1.25, -D / 2 + 5))
	if s.GoldTrim then
		block(model, origin, "AltarGold", Vector3.new(5.4, 0.4, 2.9), Vector3.new(0, floorY + 2.7, -D / 2 + 5), { Material = Enum.Material.Metal, Color = pal.Accent })
	end
	if s.Braziers then
		addFire(altar, 3)
	end

	local topY = floorY + s.ColH
	if s.Roof then
		block(model, origin, "Entablature", Vector3.new(W, 1.6, D), Vector3.new(0, topY + 0.8, 0))
		if s.GoldTrim then
			block(model, origin, "GoldTrim", Vector3.new(W + 0.4, 0.5, D + 0.4), Vector3.new(0, topY + 0.25, 0), { Material = Enum.Material.Metal, Color = pal.Accent })
		end
		-- Stepped roof
		block(model, origin, "Roof1", Vector3.new(W - 2, 1.2, D), Vector3.new(0, topY + 2.2, 0))
		block(model, origin, "Roof2", Vector3.new(W * 0.6, 1.2, D), Vector3.new(0, topY + 3.4, 0))
		block(model, origin, "Roof3", Vector3.new(W * 0.25, 1.2, D), Vector3.new(0, topY + 4.6, 0))
		topY += 5.2
	else
		-- Tier 2: restored columns with a simple marble ring on top
		block(model, origin, "LintelFront", Vector3.new(W, 1, 2.4), Vector3.new(0, topY + 0.5, z0))
		block(model, origin, "LintelBack", Vector3.new(W, 1, 2.4), Vector3.new(0, topY + 0.5, z1))
		block(model, origin, "LintelLeft", Vector3.new(2.4, 1, D), Vector3.new(x0, topY + 0.5, 0))
		block(model, origin, "LintelRight", Vector3.new(2.4, 1, D), Vector3.new(x1, topY + 0.5, 0))
	end

	if s.Braziers then
		for i, x in { -W / 2 + 2, W / 2 - 2 } do
			local bowl = disc(model, origin, "Brazier" .. i, x, 1.6, -D / 2 - 1.5, 0.8, 2.4, { Material = Enum.Material.Metal, Color = pal.Accent })
			column(model, origin, "BrazierStand" .. i, x, 0, -D / 2 - 1.5, 1.2, 0.6, { Material = Enum.Material.Metal, Color = IRON })
			addFire(bowl, 4)
		end
	end

	if s.Dome then
		local dome = ball(model, origin, "Dome", W * 0.45, Vector3.new(0, topY, 4), { Material = Enum.Material.Metal, Color = pal.Accent })
		addLight(dome, pal.Accent, 18, 1)
	end

	if s.Statues then
		for i, x in { -6, 6 } do
			block(model, origin, "StatuePedestal" .. i, Vector3.new(2.4, 2, 2.4), Vector3.new(x, 1, -D / 2 - 4))
			local figure = block(model, origin, "Statue" .. i, Vector3.new(1.4, 5, 1.4), Vector3.new(x, 4.5, -D / 2 - 4), { Material = Enum.Material.Neon, Color = pal.Glow })
			addLight(figure, pal.Glow, 12, 1.5)
		end
	end

	if s.Citadel then
		local crownY = buildCitadel(model, origin, s, topY)
		buildPrestige(model, origin, s, topY, crownY, prestige or 0)
	end

	if s.Floating then
		local skyY = topY + 8
		for i, pos in { Vector3.new(-16, skyY, -4), Vector3.new(16, skyY + 2, -4), Vector3.new(0, skyY + 5, 20) } do
			block(model, origin, "SkyIsland" .. i, Vector3.new(8, 1.2, 8), pos)
			block(model, origin, "SkyIslandGold" .. i, Vector3.new(8.4, 0.4, 8.4), pos - Vector3.new(0, 0.8, 0), { Material = Enum.Material.Metal, Color = pal.Accent })
			column(model, origin, "SkyColumn" .. i, pos.X, pos.Y + 0.6, pos.Z, 5, 1.4, { Color = MARBLE })
			local orb = ball(model, origin, "SkyOrb" .. i, 1.6, pos + Vector3.new(0, 7, 0), { Material = Enum.Material.Neon, Color = pal.Accent })
			addLight(orb, pal.Accent, 16, 2)
		end
	end
end

function TempleModels.Temple(tier, origin, colors, prestige)
	pal = colors or DEFAULT_COLORS
	local model = Instance.new("Model")
	model.Name = "Temple"
	if tier <= 1 then
		buildRuinedShrine(model, origin)
	else
		buildTempleStyle(model, origin, TEMPLE_STYLES[math.min(tier, 7)], prestige)
	end
	return model
end

--------------------------------------------------------------------------
-- Buildings (each fits inside a 14 x 14 stud slot)
--------------------------------------------------------------------------
local BUILDERS = {}

BUILDERS.GoldTreasury = function(model, o, level)
	block(model, o, "Floor", Vector3.new(12, 0.6, 12), Vector3.new(0, 0.3, 0))
	local floorY = 0.6
	local w, h = 5 + level, 3 + level
	block(model, o, "Vault", Vector3.new(w, h, w), Vector3.new(0, floorY + h / 2, 0))
	block(model, o, "VaultDoor", Vector3.new(2, 2.5, 0.3), Vector3.new(0, floorY + 1.25, -w / 2 - 0.15), { Material = Enum.Material.Metal, Color = GOLD })
	block(model, o, "VaultTop", Vector3.new(w + 0.6, 0.5, w + 0.6), Vector3.new(0, floorY + h + 0.25, 0), { Material = Enum.Material.Metal, Color = GOLD })

	local piles = { { -4.8, -4.8 }, { 4.8, -4.8 }, { -4.8, 4.8 }, { 4.8, 4.8 }, { 2.8, -5 } }
	for i = 1, level do
		ball(model, o, "GoldPile" .. i, 1.6, Vector3.new(piles[i][1], floorY + 0.4, piles[i][2]), { Material = Enum.Material.Metal, Color = GOLD })
	end
	if level >= 3 then
		for i, c in { { -5.4, -5.4 }, { 5.4, -5.4 }, { -5.4, 5.4 }, { 5.4, 5.4 } } do
			column(model, o, "Column" .. i, c[1], floorY, c[2], 4 + level, 1.2)
		end
	end
	if level >= 5 then
		local dome = ball(model, o, "GoldDome", 4, Vector3.new(0, floorY + h + 1.5, 0), { Material = Enum.Material.Metal, Color = GOLD })
		addLight(dome, GOLD, 14, 1.5)
	end
end

BUILDERS.MainAltar = function(model, o, level)
	-- One stone step per level
	for i = 1, level do
		local size = 12 - (i - 1) * 1.6
		block(model, o, "Step" .. i, Vector3.new(size, 0.6, size), Vector3.new(0, (i - 0.5) * 0.6, 0))
	end
	local top = level * 0.6
	local altar = block(model, o, "Altar", Vector3.new(4, 2.5, 2), Vector3.new(0, top + 1.25, 0))
	if level >= 2 then
		addFire(altar, 4)
	end
	if level >= 3 then
		block(model, o, "AltarGold", Vector3.new(4.4, 0.4, 2.4), Vector3.new(0, top + 2.7, 0), { Material = Enum.Material.Metal, Color = pal.Accent })
	end
	if level >= 4 then
		local orb = ball(model, o, "FavorOrb", 1.6, Vector3.new(0, top + 6, 0), { Material = Enum.Material.Neon, Color = pal.Glow })
		addLight(orb, pal.Glow, 14, 2)
	end
	if level >= 5 then
		for i, x in { -4, 4 } do
			column(model, o, "GoldColumn" .. i, x, top, 0, 8, 1.4, { Material = Enum.Material.Metal, Color = pal.Accent })
		end
	end
end

BUILDERS.DivineFountain = function(model, o, level)
	local d = 7 + level
	disc(model, o, "BaseDisc", 0, 0.15, 0, 0.3, d + 1.2, if level >= 5
		then { Material = Enum.Material.Metal, Color = pal.Accent }
		else nil)
	disc(model, o, "Basin", 0, 0.9, 0, 1.2, d)
	local water = disc(model, o, "Water", 0, 1.35, 0, 0.3, d - 1, {
		Material = Enum.Material.Glass,
		Color = WATER,
		Transparency = 0.3,
		CanCollide = false,
	})
	local pillarHeight = 1 + level * 1.2
	column(model, o, "Pillar", 0, 1.5, 0, pillarHeight, 1.2)
	local topY = 1.5 + pillarHeight
	if level >= 2 then
		local bowl = disc(model, o, "TopBowl", 0, topY, 0, 0.5, 3)
		if level >= 3 then
			local spray = Instance.new("ParticleEmitter")
			spray.Color = ColorSequence.new(WATER)
			spray.LightEmission = 0.4
			spray.Rate = 30
			spray.Lifetime = NumberRange.new(0.8, 1.2)
			spray.Speed = NumberRange.new(5, 7)
			spray.SpreadAngle = Vector2.new(25, 25)
			spray.Acceleration = Vector3.new(0, -20, 0)
			spray.Size = NumberSequence.new(0.3)
			spray.EmissionDirection = Enum.NormalId.Right -- the cylinder's local +X points up
			spray.Parent = bowl
		end
	end
	if level >= 4 then
		addLight(water, WATER, 14, 1.5)
	end
end

BUILDERS.TrainingGrounds = function(model, o, level)
	block(model, o, "SandFloor", Vector3.new(14, 0.4, 14), Vector3.new(0, 0.2, 0), { Material = Enum.Material.Sand, Color = SAND })
	local floorY = 0.4
	local dummies = { { -4, -3 }, { 0, -3 }, { 4, -3 }, { -2, 2 }, { 2, 2 } }
	for i = 1, level do
		local x, z = dummies[i][1], dummies[i][2]
		column(model, o, "DummyPost" .. i, x, floorY, z, 4, 0.8, { Material = Enum.Material.Wood, Color = WOOD })
		block(model, o, "DummyArms" .. i, Vector3.new(2.6, 0.4, 0.4), Vector3.new(x, floorY + 3, z), { Material = Enum.Material.Wood, Color = WOOD })
		ball(model, o, "DummyHead" .. i, 1.4, Vector3.new(x, floorY + 4.5, z), { Material = Enum.Material.Fabric, Color = SAND })
	end
	if level >= 3 then
		block(model, o, "RackBar", Vector3.new(6, 0.4, 0.4), Vector3.new(0, floorY + 2.5, 5.5), { Material = Enum.Material.Wood, Color = WOOD })
		for i, x in { -2.8, 2.8 } do
			column(model, o, "RackPost" .. i, x, floorY, 5.5, 3, 0.4, { Material = Enum.Material.Wood, Color = WOOD })
		end
		for i, x in { -1.5, 0, 1.5 } do
			block(model, o, "Spear" .. i, Vector3.new(0.2, 4.5, 0.2), Vector3.new(x, floorY + 2.25, 5.8), { Material = Enum.Material.Metal, Color = IRON })
		end
	end
	if level >= 4 then
		local posts = { { -6.6, -6.6 }, { 0, -6.6 }, { 6.6, -6.6 }, { -6.6, 0 }, { 6.6, 0 }, { -6.6, 6.6 }, { 0, 6.6 }, { 6.6, 6.6 } }
		for i, p in posts do
			column(model, o, "FencePost" .. i, p[1], floorY, p[2], 2.5, 0.6, { Material = Enum.Material.Wood, Color = WOOD })
		end
	end
	if level >= 5 then
		column(model, o, "BannerPole", -5, floorY, 5, 9, 0.5, { Material = Enum.Material.Metal, Color = GOLD })
		block(model, o, "Banner", Vector3.new(0.2, 3, 2.4), Vector3.new(-5, floorY + 7, 6.3), { Material = Enum.Material.Fabric, Color = pal.Glow })
	end
end

BUILDERS.StatueHall = function(model, o, level)
	block(model, o, "Floor", Vector3.new(14, 0.6, 12), Vector3.new(0, 0.3, 0))
	local floorY = 0.6
	local golden = level >= 5
	for i = 1, level do
		local x = -6 + (i - 1) * 3
		block(model, o, "Pedestal" .. i, Vector3.new(2, 1.5, 2), Vector3.new(x, floorY + 0.75, 2))
		local h = 3.5 + 0.3 * i
		local figure = block(model, o, "Statue" .. i, Vector3.new(1.2, h, 1.2), Vector3.new(x, floorY + 1.5 + h / 2, 2), if golden
			then { Material = Enum.Material.Metal, Color = pal.Accent }
			else nil)
		ball(model, o, "StatueHead" .. i, 1.2, Vector3.new(x, floorY + 1.5 + h + 0.5, 2), if golden
			then { Material = Enum.Material.Metal, Color = pal.Accent }
			else nil)
		if golden then
			addLight(figure, pal.Accent, 8, 1)
		end
	end
	if level >= 3 then
		block(model, o, "BackWall", Vector3.new(14, 7, 1), Vector3.new(0, floorY + 3.5, 5.5))
		block(model, o, "WallGold", Vector3.new(14.2, 0.4, 1.2), Vector3.new(0, floorY + 7.2, 5.5), { Material = Enum.Material.Metal, Color = pal.Accent })
	end
	if level >= 4 then
		for i, x in { -6.5, 6.5 } do
			column(model, o, "FrontColumn" .. i, x, floorY, -5.3, 7.4, 1.2)
		end
		block(model, o, "Roof", Vector3.new(14.6, 0.8, 12.6), Vector3.new(0, floorY + 7.8, 0))
	end
end

function TempleModels.Building(buildingId, level, origin, colors)
	pal = colors or DEFAULT_COLORS
	local builder = BUILDERS[buildingId]
	if not builder or level <= 0 then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = buildingId
	builder(model, origin, math.clamp(level, 1, 5))
	if level >= 6 then
		-- Phase 7E "Divine" level: a floating halo and glow above the building.
		local _, size = model:GetBoundingBox()
		local height = size.Y + 2.5
		ring(model, origin, "DivineHalo", Vector3.new(0, height, 0), 4, 14, { Material = Enum.Material.Neon, Color = pal.Accent })
		local gem = ball(model, origin, "DivineGem", 1.4, Vector3.new(0, height + 1.5, 0), { Material = Enum.Material.Neon, Color = pal.Glow, CanCollide = false })
		addLight(gem, pal.Glow, 16, 2)
	end
	return model
end

--------------------------------------------------------------------------
-- Construction animation: every part rises out of the ground and fades in.
-- Call BEFORE parenting the model (same frame), so players never see the
-- finished building flash before the animation starts.
--------------------------------------------------------------------------
function TempleModels.AnimateIn(model, duration)
	duration = duration or 1.2
	local _, size = model:GetBoundingBox()
	local drop = size.Y + 2
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local targetCFrame, targetTransparency = item.CFrame, item.Transparency
			item.CFrame = targetCFrame - Vector3.new(0, drop, 0)
			item.Transparency = 1
			TweenService:Create(item, info, { CFrame = targetCFrame, Transparency = targetTransparency }):Play()
		elseif (item:IsA("Fire") or item:IsA("ParticleEmitter") or item:IsA("PointLight")) and item.Enabled then
			item.Enabled = false
			task.delay(duration, function()
				if item.Parent then
					item.Enabled = true
				end
			end)
		end
	end

	-- Golden sparkle burst at the building's base
	local center = model:GetBoundingBox()
	local sparkle = Instance.new("Part")
	sparkle.Name = "ConstructionSparkle"
	sparkle.Anchored = true
	sparkle.CanCollide = false
	sparkle.CanQuery = false
	sparkle.Transparency = 1
	sparkle.Size = Vector3.new(math.max(size.X, 4), 1, math.max(size.Z, 4))
	sparkle.CFrame = CFrame.new(center.Position.X, center.Position.Y - size.Y / 2 + 0.5, center.Position.Z)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(GOLD)
	emitter.LightEmission = 1
	emitter.Rate = 60
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(4, 8)
	emitter.Size = NumberSequence.new(0.4, 0)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = sparkle
	task.delay(duration, function()
		emitter.Enabled = false
	end)
	sparkle.Parent = model
	Debris:AddItem(sparkle, duration + 1.5)
end

return TempleModels
