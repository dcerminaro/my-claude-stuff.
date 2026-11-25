-- EnvironmentService (ModuleScript)
-- Location: ServerScriptService > Services > EnvironmentService
--
-- Phase 8: the look of Mount Olympus.
--   * Lighting: golden late-afternoon sun, atmosphere haze, bloom, sun rays,
--     colour grading and drifting sky clouds.
--   * Terrain: the summit of Mount Olympus right under the plaza, practice
--     field and temple district (a rocky plateau with grass, cliffs falling
--     away, snow on the upper slopes), plus distant peaks rising out of the
--     clouds.
--   * A sea of clouds far below that stretches to the horizon.
-- Everything is generated when the server starts (nothing to upload).
-- Settings are at the top of this file.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local EnvironmentService = {}

local SUMMIT_CENTER = Vector3.new(0, 0, 90)  -- under the plaza + temple district
local SUMMIT_RADIUS = 390                    -- flat top covers everything built
local SUMMIT_TOP = -4.5                      -- under the floors (terrain voxels round up ~2.5 studs)
local MOUNTAIN_DEPTH = 300                   -- the cliffs go down into the clouds
local CLOUD_Y = -270                         -- height of the cloud sea
local CLOUD_EXTENT = 7000                    -- how far the cloud sea reaches

-- Distant peaks (X, Z, height above the clouds, base radius). Kept away from
-- the arenas (which float at Z = 1500).
local PEAKS = {
	{ -1300, 600, 380, 420 },
	{ 1250, 300, 300, 360 },
	{ -700, -1200, 260, 330 },
	{ 1100, -1000, 420, 460 },
	{ -1800, -300, 220, 300 },
	{ 2000, 1300, 340, 380 },
	{ -1400, 2100, 300, 360 },
}

--------------------------------------------------------------------------
-- Lighting and sky
--------------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 16.6               -- golden late afternoon
	Lighting.GeographicLatitude = 38          -- Greece
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(70, 60, 75)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 135, 150)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ExposureCompensation = 0.15

	for _, item in Lighting:GetChildren() do
		if item:IsA("Sky") or item:IsA("Atmosphere") or item:IsA("PostEffect") then
			item:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.Name = "OlympusSky"
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 4000
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "OlympusAir"
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(255, 226, 200)   -- warm haze
	atmosphere.Decay = Color3.fromRGB(150, 120, 190)   -- violet distance
	atmosphere.Glare = 0.6
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "DivineBloom"
	bloom.Intensity = 0.9
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Name = "DivineRays"
	rays.Intensity = 0.12
	rays.Spread = 0.8
	rays.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DivineGrade"
	grade.Brightness = 0.02
	grade.Contrast = 0.12
	grade.Saturation = 0.12
	grade.TintColor = Color3.fromRGB(255, 246, 236)
	grade.Parent = Lighting

	-- Drifting clouds in the sky above
	local terrain = Workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.5
	clouds.Color = Color3.fromRGB(255, 240, 235)
	clouds.Parent = terrain
end

--------------------------------------------------------------------------
-- Terrain
--------------------------------------------------------------------------
local rng = Random.new(1821) -- fixed seed: the mountain looks the same every server

local function ball(terrain, position, radius, material)
	terrain:FillBall(position, radius, material)
end

-- A craggy cone made of overlapping rock balls (only the outer shell is
-- filled, so it stays light): from `topY` down to `bottomY`.
local function craggyCone(terrain, center, topY, bottomY, topRadius, bottomRadius, materials)
	local height = topY - bottomY
	local layers = math.max(3, math.floor(height / 26))
	for layer = 0, layers do
		local t = layer / layers -- 0 at the top, 1 at the bottom
		local y = topY - t * height
		local radius = topRadius + (bottomRadius - topRadius) * (t ^ 0.8)
		local blob = 18 + 14 * t + rng:NextNumber(0, 6)
		local count = math.max(6, math.floor(2 * math.pi * radius / (blob * 1.6)))
		local twist = rng:NextNumber(0, math.pi * 2)
		for i = 1, count do
			local angle = twist + i / count * math.pi * 2
			local wobble = rng:NextNumber(-0.06, 0.08) * radius
			local r = radius + wobble
			local position = Vector3.new(center.X + math.cos(angle) * r, y + rng:NextNumber(-6, 6), center.Z + math.sin(angle) * r)
			local material = materials(t, rng)
			ball(terrain, position, blob * rng:NextNumber(0.85, 1.2), material)
		end
	end
end

local function summitMaterial(t, random)
	if t < 0.12 then
		return if random:NextNumber() < 0.55 then Enum.Material.Grass else Enum.Material.Rock
	elseif t < 0.45 then
		local roll = random:NextNumber()
		if roll < 0.35 then
			return Enum.Material.Snow
		elseif roll < 0.5 then
			return Enum.Material.Glacier
		end
		return Enum.Material.Rock
	elseif t < 0.75 then
		return if random:NextNumber() < 0.6 then Enum.Material.Slate else Enum.Material.Rock
	end
	return Enum.Material.Basalt
end

local function peakMaterial(t, random)
	if t < 0.3 then
		return if random:NextNumber() < 0.7 then Enum.Material.Snow else Enum.Material.Glacier
	elseif t < 0.6 then
		return if random:NextNumber() < 0.3 then Enum.Material.Snow else Enum.Material.Rock
	end
	return Enum.Material.Slate
end

local function buildTerrain()
	local terrain = Workspace.Terrain
	terrain:Clear()
	terrain.WaterWaveSize = 0
	terrain.Decoration = true -- grass blades on Grass
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(120, 160, 80))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 140, 130))
	terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(120, 115, 120))
	terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(245, 248, 255))

	-- The summit plateau: a flat slab with a grassy top, under everything.
	local c = SUMMIT_CENTER
	local slabThickness = 24
	terrain:FillCylinder(CFrame.new(c.X, SUMMIT_TOP - slabThickness / 2, c.Z), slabThickness, SUMMIT_RADIUS, Enum.Material.Rock)
	terrain:FillCylinder(CFrame.new(c.X, SUMMIT_TOP - 2, c.Z), 4, SUMMIT_RADIUS - 6, Enum.Material.Grass)
	-- Worn paths of stone in the grass
	for _ = 1, 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(60, SUMMIT_RADIUS - 30)
		terrain:FillCylinder(CFrame.new(c.X + math.cos(angle) * r, SUMMIT_TOP - 2, c.Z + math.sin(angle) * r), 4.2, rng:NextNumber(8, 22), Enum.Material.Rock)
	end
	task.wait()

	-- Boulders and a rocky rim around the edge of the plateau
	for i = 1, 70 do
		local angle = i / 70 * math.pi * 2 + rng:NextNumber(-0.03, 0.03)
		local r = SUMMIT_RADIUS + rng:NextNumber(-2, 10)
		local size = rng:NextNumber(8, 18)
		ball(terrain, Vector3.new(c.X + math.cos(angle) * r, SUMMIT_TOP + size * 0.25, c.Z + math.sin(angle) * r), size, if rng:NextNumber() < 0.3 then Enum.Material.Snow else Enum.Material.Rock)
	end
	task.wait()

	-- The mountain falling away below the plateau, down into the clouds
	craggyCone(terrain, c, SUMMIT_TOP - 10, SUMMIT_TOP - MOUNTAIN_DEPTH, SUMMIT_RADIUS + 8, SUMMIT_RADIUS + 360, summitMaterial)
	task.wait()

	-- Distant peaks
	for _, peak in PEAKS do
		local center = Vector3.new(peak[1], 0, peak[2])
		local top = CLOUD_Y + peak[3]
		craggyCone(terrain, center, top, CLOUD_Y - 25, 18, peak[4], peakMaterial)
		ball(terrain, Vector3.new(center.X, top + 6, center.Z), 26, Enum.Material.Snow) -- the snowy tip
		task.wait()
	end
end

--------------------------------------------------------------------------
-- Sea of clouds
--------------------------------------------------------------------------
local function buildCloudSea()
	local old = Workspace:FindFirstChild("CloudSea")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "CloudSea"

	local function cloudPart(size, position, transparency, color)
		local part = Instance.new("Part")
		part.Name = "Cloud"
		part.Shape = Enum.PartType.Ball
		part.Size = size
		part.Position = position
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = color
		part.Transparency = transparency
		part.Parent = folder
		return part
	end

	-- A flat floor of cloud so there are never holes (parts max 2048 studs).
	local tile = 2048
	local tiles = math.ceil(CLOUD_EXTENT * 2 / tile)
	for ix = 0, tiles - 1 do
		for iz = 0, tiles - 1 do
			local part = Instance.new("Part")
			part.Name = "CloudFloor"
			part.Size = Vector3.new(tile, 2, tile)
			part.Position = Vector3.new(-CLOUD_EXTENT + tile / 2 + ix * tile, CLOUD_Y - 22, 900 - CLOUD_EXTENT + tile / 2 + iz * tile)
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.fromRGB(246, 236, 240)
			part.Parent = folder
		end
	end

	-- Puffy cloud mounds: big near the mountain, spread to the horizon.
	local cloudRng = Random.new(77)
	local colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 244, 238), Color3.fromRGB(246, 236, 248), Color3.fromRGB(255, 236, 220) }
	for _ = 1, 420 do
		local distance = 300 + cloudRng:NextNumber() ^ 1.4 * (CLOUD_EXTENT - 400)
		local angle = cloudRng:NextNumber(0, math.pi * 2)
		local width = cloudRng:NextNumber(160, 420) * (1 + distance / 4000)
		local position = Vector3.new(math.cos(angle) * distance, CLOUD_Y + cloudRng:NextNumber(-18, 22), 90 + math.sin(angle) * distance)
		cloudPart(Vector3.new(width, width * cloudRng:NextNumber(0.18, 0.3), width), position, cloudRng:NextNumber(0, 0.15), colors[cloudRng:NextInteger(1, #colors)])
	end
	-- Wisps hugging the mountain's sides
	for i = 1, 60 do
		local angle = i / 60 * math.pi * 2
		local distance = SUMMIT_RADIUS + cloudRng:NextNumber(120, 380)
		local width = cloudRng:NextNumber(90, 200)
		cloudPart(Vector3.new(width, width * 0.25, width * 0.7), Vector3.new(math.cos(angle) * distance, CLOUD_Y + cloudRng:NextNumber(20, 120), 90 + math.sin(angle) * distance), cloudRng:NextNumber(0.35, 0.6), colors[1])
	end
	folder.Parent = Workspace
end

function EnvironmentService.Build()
	setupLighting()
	buildCloudSea()
	task.spawn(buildTerrain) -- takes a few seconds; players can already play
end

return EnvironmentService
