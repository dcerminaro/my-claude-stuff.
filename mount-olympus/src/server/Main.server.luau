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
local AbilityService = require(Services:WaitForChild("AbilityService"))
local ArenaService = require(Services:WaitForChild("ArenaService"))
local AscensionService = require(Services:WaitForChild("AscensionService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))
local GameEvents = require(Services:WaitForChild("GameEvents"))
local QuestService = require(Services:WaitForChild("QuestService"))
local ChallengeService = require(Services:WaitForChild("ChallengeService"))
local MasteryService = require(Services:WaitForChild("MasteryService"))

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
local abilityRemote = newRemote("UseAbility") -- client -> server "use my Q / E / R / Form ability"
local arenaActionRemote = newRemote("ArenaAction") -- client -> server arena menu requests
local arenaEventRemote = newRemote("ArenaEvent") -- server -> client party queue and results
local ascensionRemote = newRemote("AscensionAction") -- client -> server "start my ascension trial"
local weaponRemote = newRemote("WeaponAction") -- client -> server equip / craft / upgrade a weapon
local questRemote = newRemote("QuestAction") -- client -> server "claim this quest"
local challengeRemote = newRemote("ChallengeAction") -- client -> server "start this Titan Gate challenge"
local incarnationRemote = newRemote("IncarnationAction") -- client -> server "transform now"

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
AbilityService.Init(DataService, ProgressionService, TempleService, EnemyService, GodService, fxRemote, abilityRemote)
CombatService.SetModifierProvider(AbilityService.GetModifiers)
CombatService.SetDashHandler(AbilityService.OnDash)
CombatService.SetCounterHandler(AbilityService.TryCounter)
ArenaService.Init(DataService, ProgressionService, PlotService, EnemyService, notifyRemote, arenaActionRemote, arenaEventRemote)
ArenaService.BuildGate()
ChallengeService.Init(DataService, ArenaService, notifyRemote, challengeRemote)
ChallengeService.BuildGate()
MasteryService.Init(DataService, ProgressionService, AbilityService, GameEvents, notifyRemote, fxRemote, incarnationRemote)
AscensionService.Init(DataService, ProgressionService, ArenaService, notifyRemote, fxRemote, ascensionRemote, if GameConfig.Debug.Diagnostics then DiagnosticsService else nil)
AscensionService.BuildChamber()
InventoryService.Init(DataService, ProgressionService, notifyRemote, weaponRemote)
InventoryService.BuildForge()
QuestService.Init(DataService, ProgressionService, GameEvents, notifyRemote, questRemote)
CombatService.SetWeaponProvider(InventoryService.GetEquipped)
AbilityService.SetPowerProvider(function(player)
	return InventoryService.GetEquipped(player).Power
end)
InventoryService.SetWeaponChangedHandler(CombatService.RefreshWeapon)
ArenaService.SetDropHandler(InventoryService.RollBossDrops)
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
	elseif command == "!blessall" then
		reply(if GodService.DebugMaxBlessings(player) then "All blessings of your god are now max level" else "Choose a god first")
	elseif command == "!loyalty" and number then
		reply(if GodService.AddLoyalty(player, number) then "Added " .. number .. " loyalty" else "Choose a god first")
	elseif command == "!rank" then
		local ok, text = ProgressionService.AdvanceRank(player, "Debug")
		if ok then
			AscensionService.OnRankUp(player)
		end
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
			task.spawn(AscensionService.ApplyLooks, player)
			reply("Progress reset to defaults")
		end
	else
		reply("Commands: !xp N, !gold N, !favor N, !ambrosia N, !loyalty N, !blessall, !spend N, !rank, !save, !data, !reset")
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
	InventoryService.SetupPlayer(player) -- before combat, so the right weapon is in hand
	CombatService.SetupPlayer(player)
	AbilityService.SetupPlayer(player)
	AscensionService.SetupPlayer(player)
	QuestService.SetupPlayer(player)
	ChallengeService.SetupPlayer(player)
	MasteryService.SetupPlayer(player)
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
	AbilityService.ReleasePlayer(player)
	ArenaService.ReleasePlayer(player)
	AscensionService.ReleasePlayer(player)
	QuestService.ReleasePlayer(player)
	MasteryService.ReleasePlayer(player)
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
	if ArenaService.IsInRun(player) then
		ArenaService.Leave(player) -- travelling away from an arena counts as leaving it
	end
	PlotService.TeleportPlayer(player, destination)
end)
