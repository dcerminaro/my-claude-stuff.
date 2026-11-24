-- PlotService (ModuleScript)
-- Location: ServerScriptService > Services > PlotService
--
-- Gives each player one free temple plot, frees it when they leave, and
-- handles Temple/Plaza teleports. Ownership is stored on the plot as the
-- attribute "OwnerUserId" (0 = free). TempleService builds the temple on it
-- and uses OwnerUserId to stop anyone changing another player's temple.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local PlotService = {}

local plotsFolder = nil
local plotByPlayer = {} -- [Player] = plot Model

local function setSign(plot, text)
	local sign = plot:FindFirstChild("Sign")
	local label = sign and sign:FindFirstChild("Label")
	local textLabel = label and label:FindFirstChild("Text")
	if textLabel then
		textLabel.Text = text
	end
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
			-- The temple itself is built from saved data by TempleService.SetupPlayer.
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
	local pads = plot:FindFirstChild("Pads")
	if pads then
		pads:ClearAllChildren()
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
