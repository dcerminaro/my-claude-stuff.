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
local MessagingService = game:GetService("MessagingService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Services = ServerScriptService:WaitForChild("Services")
local WorldBuilder = require(Services:WaitForChild("WorldBuilder"))
local DataService = require(Services:WaitForChild("DataService"))
local ProgressionService = require(Services:WaitForChild("ProgressionService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local TempleService = require(Services:WaitForChild("TempleService"))
local GodService = require(Services:WaitForChild("GodService"))
local EnemyService = require(Services:WaitForChild("EnemyService"))
local CombatService = require(Services:WaitForChild("CombatService"))
local DiagnosticsService = require(Services:WaitForChild("DiagnosticsService"))

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

local upgradeRemote = Instance.new("RemoteEvent") -- client -> server "upgrade this temple building"
upgradeRemote.Name = "RequestUpgrade"
upgradeRemote.Parent = remotes

local godRemote = Instance.new("RemoteEvent") -- client -> server god menu requests (choose, blessings, change)
godRemote.Name = "GodAction"
godRemote.Parent = remotes

local function newRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end
local combatRemotes = {
	Attack = newRemote("CombatAttack"), -- client -> server "I swung"
	Block = newRemote("CombatBlock"),   -- client -> server block on/off
	Dash = newRemote("CombatDash"),     -- client -> server "I dashed"
}
local fxRemote = newRemote("CombatFX") -- server -> clients damage numbers and effects
local reportRemote = newRemote("ClientReport") -- client -> server diagnostics report

remotes.Parent = ReplicatedStorage

--------------------------------------------------------------------------
-- 2. Start systems
--------------------------------------------------------------------------
WorldBuilder.Build()
DataService.Init()
ProgressionService.Init(DataService, notifyRemote)
PlotService.Init()
TempleService.Init(DataService, ProgressionService, PlotService, notifyRemote, upgradeRemote)
GodService.Init(DataService, ProgressionService, TempleService, notifyRemote, godRemote)
GodService.BuildHall()
CombatService.Init(TempleService, EnemyService, fxRemote, combatRemotes)
EnemyService.Init(DataService, ProgressionService, CombatService, fxRemote)
EnemyService.SpawnPracticeField()
if GameConfig.Debug.Diagnostics then
	DiagnosticsService.Init(reportRemote)
end

--------------------------------------------------------------------------
-- 3. Debug chat commands
-- Allowed in Studio, and in the live game for the game's owner only
-- (see GameConfig.Debug).
--------------------------------------------------------------------------
local function isGameOwner(player)
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	-- Group-owned game: only the group owner (rank 255).
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank == 255
end

local function canUseDebugCommands(player)
	if RunService:IsStudio() then
		return GameConfig.Debug.ChatCommandsInStudio
	end
	return GameConfig.Debug.ChatCommandsForOwnerInLiveGame and isGameOwner(player)
end

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
	elseif command == "!loyalty" and number then
		reply(if GodService.AddLoyalty(player, number) then "Added " .. number .. " loyalty" else "Choose a god first")
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
			GodService.Refresh(player)
			TempleService.Rebuild(player)
			reply("Progress reset to defaults")
		end
	else
		reply("Commands: !xp N, !gold N, !favor N, !ambrosia N, !loyalty N, !spend N, !rank, !save, !data, !reset")
	end
end

--------------------------------------------------------------------------
-- 4. Player lifecycle
--------------------------------------------------------------------------
local function onPlayerAdded(player)
	if canUseDebugCommands(player) then
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
	GodService.SetupPlayer(player)
	TempleService.SetupPlayer(player, plot)
	CombatService.SetupPlayer(player)
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
	TempleService.ReleasePlayer(player)
	GodService.ReleasePlayer(player)
	CombatService.ReleasePlayer(player)
	PlotService.ReleasePlot(player)
	DataService.ReleasePlayer(player) -- yields while saving
end)

--------------------------------------------------------------------------
-- 4b. Update restarts: when a new version is published, a message on the
-- "OlympusUpdate" topic (sent with Open Cloud) asks every OLD server to send
-- its players back in, so nobody stays on an outdated version.
--------------------------------------------------------------------------
if not RunService:IsStudio() then
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync("OlympusUpdate", function(message)
				local newVersion = tonumber(message.Data)
				if newVersion and newVersion > game.PlaceVersion then
					for _, player in Players:GetPlayers() do
						player:Kick("Mount Olympus was just updated! Please rejoin to play the new version.")
					end
				end
			end)
		end)
		if not ok then
			warn("[Main] Could not listen for updates: " .. tostring(err))
		end
	end)
end

--------------------------------------------------------------------------
-- 5. Teleport requests (validated: never trust what the client sends)
--------------------------------------------------------------------------
teleportRemote.OnServerEvent:Connect(function(player, destination)
	if destination ~= "Temple" and destination ~= "Plaza" and destination ~= "Practice" then
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
