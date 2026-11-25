-- WorldBuilder (ModuleScript)
-- Location: ServerScriptService > Services > WorldBuilder
--
-- Builds PLACEHOLDER world geometry when the game starts:
--   Workspace > Hub          (Olympus Plaza, spawn, columns, area markers)
--   Workspace > TemplePlots  (Plot1..Plot8)
-- If you later build your own Hub or TemplePlots by hand with the same
-- names, this script leaves them alone.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local CombatConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatConfig"))

local WorldBuilder = {}

local MARBLE = Color3.fromRGB(236, 232, 224)
local GOLD = Color3.fromRGB(212, 175, 55)

-- Creates an anchored part. `props` is a table of property = value.
function WorldBuilder.MakePart(parent, props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.Marble
	part.Color = MARBLE
	if props.Shape then
		part.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Shape" then
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Floating text above a part. Returns the TextLabel (named "Text").
function WorldBuilder.AddLabel(part, text, color, heightOffset)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(240, 56)
	billboard.StudsOffset = Vector3.new(0, heightOffset or 4, 0)
	billboard.MaxDistance = 220
	billboard.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard

	billboard.Parent = part
	return label
end

local function buildHub()
	local hub = Instance.new("Folder")
	hub.Name = "Hub"

	-- Plaza floor (top surface at Y = 1)
	WorldBuilder.MakePart(hub, {
		Name = "PlazaFloor",
		Size = Vector3.new(140, 1, 140),
		Position = Vector3.new(0, 0.5, 0),
	})

	-- Spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- no force field
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 1.5, -35)
	spawn.Material = Enum.Material.Marble
	spawn.Color = GOLD
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = hub

	-- Central statue placeholder
	WorldBuilder.MakePart(hub, {
		Name = "StatuePedestal",
		Size = Vector3.new(10, 6, 10),
		Position = Vector3.new(0, 4, 0),
	})
	local statue = WorldBuilder.MakePart(hub, {
		Name = "StatuePlaceholder",
		Size = Vector3.new(4, 12, 4),
		Position = Vector3.new(0, 13, 0),
		Material = Enum.Material.Metal,
		Color = GOLD,
	})
	WorldBuilder.AddLabel(statue, "Olympus Plaza", GOLD, 9)

	-- Ring of columns (gaps at +Z for the Temple District and -Z for the Practice Field)
	for i = 0, 11 do
		local angle = math.rad(i * 30)
		local x, z = math.cos(angle) * 62, math.sin(angle) * 62
		if not (math.abs(z) > 55 and math.abs(x) < 20) then
			WorldBuilder.MakePart(hub, {
				Name = "Column",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(24, 4, 4),
				CFrame = CFrame.new(x, 13, z) * CFrame.Angles(0, 0, math.rad(90)),
			})
		end
	end

	-- Future area markers
	local areas = {
		-- Hall of the Gods is built by GodService (Phase 3).
		{ "Arena Gate", "Phase 5", Vector3.new(-40, 1.2, 0), Color3.fromRGB(220, 80, 60) },
		{ "Titan Gate", "Phase 5", Vector3.new(-40, 1.2, 35), Color3.fromRGB(150, 70, 200) },
		{ "Divine Forge", "Phase 7", Vector3.new(40, 1.2, -35), Color3.fromRGB(255, 140, 40) },
		{ "Ascension Chamber", "Phase 6", Vector3.new(40, 1.2, 0), Color3.fromRGB(120, 200, 255) },
	}
	for _, area in areas do
		local pad = WorldBuilder.MakePart(hub, {
			Name = area[1],
			Size = Vector3.new(14, 0.4, 14),
			Position = area[3],
			Material = Enum.Material.Neon,
			Color = area[4],
			Transparency = 0.35,
			CanCollide = false,
		})
		WorldBuilder.AddLabel(pad, area[1] .. "\n(coming in " .. area[2] .. ")", area[4], 5)
	end

	-- Path to the Temple District
	local path = WorldBuilder.MakePart(hub, {
		Name = "DistrictPath",
		Size = Vector3.new(16, 1, 100),
		Position = Vector3.new(0, 0.5, 120),
		Color = Color3.fromRGB(215, 205, 185),
	})
	WorldBuilder.AddLabel(path, "Temple District", GOLD, 6)

	-- Phase 4: Practice Field behind the spawn, for fighting before arenas exist.
	local field = CombatConfig.PracticeField
	local plazaEdge = -70
	local fieldNear = field.Center.Z + field.Size.Z / 2
	local practicePath = WorldBuilder.MakePart(hub, {
		Name = "PracticePath",
		Size = Vector3.new(16, 1, plazaEdge - fieldNear),
		Position = Vector3.new(0, 0.5, (plazaEdge + fieldNear) / 2),
		Color = Color3.fromRGB(215, 205, 185),
	})
	WorldBuilder.AddLabel(practicePath, "Practice Field", Color3.fromRGB(255, 140, 110), 6)
	local practiceFloor = WorldBuilder.MakePart(hub, {
		Name = "PracticeField",
		Size = field.Size,
		Position = field.Center - Vector3.new(0, 0.5, 0),
		Material = Enum.Material.Sandstone,
		Color = Color3.fromRGB(196, 170, 125),
	})
	WorldBuilder.AddLabel(practiceFloor, "Practice Field", Color3.fromRGB(255, 140, 110), 12)
	WorldBuilder.MakePart(hub, {
		Name = "PracticeSpawn",
		Size = Vector3.new(6, 0.2, 6),
		Position = Vector3.new(field.Center.X, field.Center.Y + 0.1, fieldNear - 6),
		Color = Color3.fromRGB(255, 140, 110),
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		CanCollide = false,
	})

	hub.Parent = Workspace
end

local function buildPlots()
	local cfg = GameConfig.Plots
	local folder = Instance.new("Folder")
	folder.Name = "TemplePlots"

	for i = 1, cfg.Count do
		local row = math.floor((i - 1) / cfg.Columns)
		local col = (i - 1) % cfg.Columns

		local plot = Instance.new("Model")
		plot.Name = "Plot" .. i

		local base = WorldBuilder.MakePart(plot, {
			Name = "Base",
			Size = cfg.Size,
			Position = cfg.Origin + Vector3.new(col * cfg.Spacing, 0, row * cfg.Spacing),
			Material = Enum.Material.Sandstone,
			Color = Color3.fromRGB(205, 192, 160),
		})
		plot.PrimaryPart = base

		local sign = WorldBuilder.MakePart(plot, {
			Name = "Sign",
			Size = Vector3.new(1, 1, 1),
			Position = base.Position + Vector3.new(0, 1, -cfg.Size.Z / 2 + 3),
			Transparency = 1,
			CanCollide = false,
		})
		WorldBuilder.AddLabel(sign, "Unclaimed Temple", Color3.new(1, 1, 1), 8)

		local buildings = Instance.new("Folder")
		buildings.Name = "Buildings"
		buildings.Parent = plot

		plot:SetAttribute("PlotIndex", i)
		plot:SetAttribute("OwnerUserId", 0)
		plot.Parent = folder
	end

	folder.Parent = Workspace
end

function WorldBuilder.Build()
	if not Workspace:FindFirstChild("Hub") then
		buildHub()
	end
	if not Workspace:FindFirstChild("TemplePlots") then
		buildPlots()
	end
end

return WorldBuilder
