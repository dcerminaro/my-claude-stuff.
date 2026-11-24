-- PlotService (ModuleScript)
-- Location: ServerScriptService > Services > PlotService
--
-- Gives each player one free temple plot, builds the starting Ruined Shrine
-- on it, frees the plot when they leave, and handles Temple/Plaza teleports.
-- Ownership is stored on the plot as the attribute "OwnerUserId" (0 = free).
-- Phase 2 will use that attribute to stop anyone changing another player's temple.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local WorldBuilder = require(ServerScriptService:WaitForChild("Services"):WaitForChild("WorldBuilder"))

local PlotService = {}

local plotsFolder = nil
local plotByPlayer = {} -- [Player] = plot Model

local STONE = Color3.fromRGB(128, 122, 114)
local WORN_MARBLE = Color3.fromRGB(210, 205, 196)

local function setSign(plot, text)
	local sign = plot:FindFirstChild("Sign")
	local label = sign and sign:FindFirstChild("Label")
	local textLabel = label and label:FindFirstChild("Text")
	if textLabel then
		textLabel.Text = text
	end
end

-- Tier 1 placeholder: a small broken altar with crumbling columns.
local function buildRuinedShrine(plot)
	local buildings = plot:FindFirstChild("Buildings")
	local base = plot:FindFirstChild("Base")
	if not buildings or not base then
		return
	end
	buildings:ClearAllChildren()

	local model = Instance.new("Model")
	model.Name = "RuinedShrine"

	local top = base.Position.Y + base.Size.Y / 2
	local cx, cz = base.Position.X, base.Position.Z
	local MP = WorldBuilder.MakePart

	MP(model, {
		Name = "Foundation",
		Size = Vector3.new(22, 1, 22),
		Position = Vector3.new(cx, top + 0.5, cz),
		Material = Enum.Material.Slate,
		Color = STONE,
	})
	local floorY = top + 1

	MP(model, {
		Name = "Altar",
		Size = Vector3.new(6, 3, 3),
		Position = Vector3.new(cx, floorY + 1.5, cz),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(165, 160, 152),
	})
	MP(model, {
		Name = "BrokenAltarTop",
		Size = Vector3.new(4, 0.8, 3.2),
		CFrame = CFrame.new(cx + 1.5, floorY + 3.3, cz) * CFrame.Angles(0, 0, math.rad(-14)),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(150, 145, 138),
	})

	-- Column stumps: { x offset, z offset, height }
	local stumps = { { -8, -8, 7 }, { 8, -8, 3.5 }, { -8, 8, 2 }, { 8, 8, 9 } }
	for i, s in stumps do
		local height = s[3]
		MP(model, {
			Name = "ColumnStump" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 2.6, 2.6),
			CFrame = CFrame.new(cx + s[1], floorY + height / 2, cz + s[2]) * CFrame.Angles(0, 0, math.rad(90)),
			Color = WORN_MARBLE,
		})
	end

	MP(model, {
		Name = "FallenColumn",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(9, 2.4, 2.4),
		CFrame = CFrame.new(cx - 2, floorY + 1.2, cz - 6) * CFrame.Angles(0, math.rad(25), 0),
		Color = WORN_MARBLE,
	})

	-- Rubble: { x, z, size }
	local rubble = { { 4, -3, 1.2 }, { -4, 3, 0.9 }, { 6, 5, 1.5 }, { -6, -2, 0.8 } }
	for i, r in rubble do
		MP(model, {
			Name = "Rubble" .. i,
			Size = Vector3.new(r[3], r[3] * 0.7, r[3]),
			CFrame = CFrame.new(cx + r[1], floorY + r[3] * 0.35, cz + r[2]) * CFrame.Angles(0, math.rad(i * 37), 0),
			Material = Enum.Material.Slate,
			Color = STONE,
		})
	end

	model.Parent = buildings
end

function PlotService.Init()
	plotsFolder = Workspace:WaitForChild("TemplePlots")
	for _, plot in plotsFolder:GetChildren() do
		plot:SetAttribute("OwnerUserId", 0)
	end
end

function PlotService.GetPlot(player)
	return plotByPlayer[player]
end

-- Returns the plot, or nil if every plot is taken.
function PlotService.AssignPlot(player)
	if plotByPlayer[player] then
		return plotByPlayer[player]
	end
	for i = 1, GameConfig.Plots.Count do
		local plot = plotsFolder:FindFirstChild("Plot" .. i)
		if plot and (plot:GetAttribute("OwnerUserId") or 0) == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			plot:SetAttribute("OwnerName", player.DisplayName)
			plotByPlayer[player] = plot
			player:SetAttribute("PlotName", plot.Name)
			setSign(plot, player.DisplayName .. "'s Temple")
			-- Phase 2 replaces this with a rebuild from the player's saved temple data.
			buildRuinedShrine(plot)
			return plot
		end
	end
	warn("[PlotService] No free plot for " .. player.Name .. ". Is Max Players higher than GameConfig.Plots.Count?")
	return nil
end

-- Visual reset only. The player's saved upgrades are untouched.
function PlotService.ReleasePlot(player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	local buildings = plot:FindFirstChild("Buildings")
	if buildings then
		buildings:ClearAllChildren()
	end
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", nil)
	setSign(plot, "Unclaimed Temple")
end

-- destination: "Temple" or "Plaza". Validated by the caller.
function PlotService.TeleportPlayer(player, destination)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not character.PrimaryPart then
		return false
	end

	local target
	if destination == "Temple" then
		local plot = plotByPlayer[player]
		local base = plot and plot:FindFirstChild("Base")
		if not base then
			return false
		end
		local pos = Vector3.new(base.Position.X, base.Position.Y + base.Size.Y / 2 + 3, base.Position.Z - base.Size.Z / 2 + 8)
		target = CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
	elseif destination == "Plaza" then
		local hub = Workspace:FindFirstChild("Hub")
		local spawn = hub and hub:FindFirstChild("PlazaSpawn")
		if not spawn then
			return false
		end
		local pos = spawn.Position + Vector3.new(0, 4, 0)
		target = CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
	else
		return false
	end

	humanoid.Sit = false
	character:PivotTo(target)
	return true
end

return PlotService
