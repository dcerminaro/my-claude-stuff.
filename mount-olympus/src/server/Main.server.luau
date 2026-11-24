-- Main (Script)
-- Location: ServerScriptService > Main
--
-- Starts every server system in the right order and handles players
-- joining and leaving. This is the only server Script; everything else
-- is a ModuleScript in ServerScriptService > Services.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Services = ServerScriptService:WaitForChild("Services")
local WorldBuilder = require(Services:WaitForChild("WorldBuilder"))
local DataService = require(Services:WaitForChild("DataService"))
local ProgressionService = require(Services:WaitForChild("ProgressionService"))
local PlotService = require(Services:WaitForChild("PlotService"))

--------------------------------------------------------------------------
-- 1. Remotes (created by the server so they always exist)
--------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local notifyRemote = Instance.new("RemoteEvent") -- server -> client pop-up messages
notifyRemote.Name = "Notify"
notifyRemote.Parent = remotes

local teleportRemote = Instance.new("RemoteEvent") -- client -> server "take me to my temple / plaza"
teleportRemote.Name = "RequestTeleport"
teleportRemote.Parent = remotes

remotes.Parent = ReplicatedStorage

--------------------------------------------------------------------------
-- 2. Start systems
--------------------------------------------------------------------------
WorldBuilder.Build()
DataService.Init()
ProgressionService.Init(DataService, notifyRemote)
PlotService.Init()

--------------------------------------------------------------------------
-- 3. Studio-only debug chat commands
--------------------------------------------------------------------------
local DEBUG_ENABLED = RunService:IsStudio() and GameConfig.Debug.ChatCommandsInStudio

local function runDebugCommand(player, message)
	local args = string.split(message, " ")
	local command = string.lower(args[1] or "")
	local number = tonumber(args[2])

	local function reply(text)
		notifyRemote:FireClient(player, "Message", text)
		print("[Debug] " .. player.Name .. ": " .. text)
	end

	if command == "!xp" and number then
		ProgressionService.AddXP(player, number, "Debug")
		reply("Added " .. number .. " XP")
	elseif command == "!gold" and number then
		ProgressionService.AddCurrency(player, "Gold", number, "Debug")
		reply("Added " .. number .. " Gold")
	elseif command == "!favor" and number then
		ProgressionService.AddCurrency(player, "DivineFavor", number, "Debug")
		reply("Added " .. number .. " Divine Favor")
	elseif command == "!ambrosia" and number then
		ProgressionService.AddCurrency(player, "Ambrosia", number, "Debug")
		reply("Added " .. number .. " Ambrosia")
	elseif command == "!spend" and number then
		local ok = ProgressionService.SpendCurrency(player, "Gold", number)
		reply(if ok then "Spent " .. number .. " Gold" else "Not enough Gold (purchase refused)")
	elseif command == "!rank" then
		local _, text = ProgressionService.AdvanceRank(player, "Debug")
		reply(text)
	elseif command == "!save" then
		reply(if DataService.SaveNow(player) then "Saved" else "Save failed (see Output)")
	elseif command == "!data" then
		local data = DataService.GetData(player)
		print("[Debug] Data for " .. player.Name .. ":\n" .. (if data then HttpService:JSONEncode(data) else "not loaded"))
		reply("Printed your data to the Output window")
	elseif command == "!reset" then
		if DataService.ResetData(player) then
			ProgressionService.RefreshAll(player)
			reply("Progress reset to defaults")
		end
	else
		reply("Commands: !xp N, !gold N, !favor N, !ambrosia N, !spend N, !rank, !save, !data, !reset")
	end
end

--------------------------------------------------------------------------
-- 4. Player lifecycle
--------------------------------------------------------------------------
local function onPlayerAdded(player)
	if DEBUG_ENABLED then
		player.Chatted:Connect(function(message)
			if string.sub(message, 1, 1) == "!" then
				runDebugCommand(player, message)
			end
		end)
	end

	local data = DataService.LoadPlayer(player) -- yields; nil = failed/kicked/left
	if not data then
		return
	end

	local plot = PlotService.AssignPlot(player)
	if not plot then
		player:Kick("This server has no free temple plots. Please join another server.")
		return
	end

	ProgressionService.SetupPlayer(player)
	player:SetAttribute("DataLoaded", true)
	print(("[Main] %s ready: Level %d, %d Gold, %s"):format(player.Name, data.Level, data.Currencies.Gold, plot.Name))
end

local lastTeleport = {}

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player) -- players who joined before this script ran
end

Players.PlayerRemoving:Connect(function(player)
	lastTeleport[player] = nil
	PlotService.ReleasePlot(player)
	DataService.ReleasePlayer(player) -- yields while saving
end)

--------------------------------------------------------------------------
-- 5. Teleport requests (validated: never trust what the client sends)
--------------------------------------------------------------------------
teleportRemote.OnServerEvent:Connect(function(player, destination)
	if destination ~= "Temple" and destination ~= "Plaza" then
		return
	end
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end
	local now = os.clock()
	if lastTeleport[player] and now - lastTeleport[player] < GameConfig.Teleport.Cooldown then
		return
	end
	lastTeleport[player] = now
	PlotService.TeleportPlayer(player, destination)
end)
