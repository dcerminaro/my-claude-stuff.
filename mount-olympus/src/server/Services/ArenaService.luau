-- ArenaService (ModuleScript)
-- Location: ServerScriptService > Services > ArenaService
--
-- PvE arenas (Phase 5), all run by the server:
--   * The Arena Gate in Olympus Plaza opens the arena menu.
--   * Solo runs, or a party queue (up to 4) for one arena.
--   * Each run gets its own copy of the arena, built far from the hub.
--   * 5 waves (the last with a boss); enemies scale with party size.
--   * Players who die or leave are out; the run fails if nobody is left.
--   * Victory pays the arena's completion rewards; a failed run pays a part.
--   * Rewards are paid once per run; everyone is sent back to the plaza.
-- Run progress is published as player attributes for the HUD:
--   ArenaRunId, ArenaName, ArenaState, ArenaWave, ArenaWaves,
--   ArenaEnemiesLeft, ArenaTimerEnd (server time).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaConfig = require(Shared:WaitForChild("ArenaConfig"))
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local WorldBuilder = require(ServerScriptService:WaitForChild("Services"):WaitForChild("WorldBuilder"))

local ArenaService = {}

local DataService = nil
local ProgressionService = nil
local PlotService = nil
local EnemyService = nil
local notifyRemote = nil
local arenaEvent = nil

local runs = {}      -- [runId] = run
local playerRun = {} -- [Player] = run
local queues = {}    -- [arenaId] = { Player, ... }
local slotUsed = {}  -- [slot] = true
local nextRunId = 0
local dropHandler = nil -- Phase 7C: function(player, bossTypes) -> { weapon names won }
local arenasFolder = nil

local ATTRIBUTES = { "ArenaRunId", "ArenaName", "ArenaState", "ArenaWave", "ArenaWaves", "ArenaEnemiesLeft", "ArenaTimerEnd" }

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------
local function message(player, text)
	if notifyRemote and player.Parent then
		notifyRemote:FireClient(player, "Message", text)
	end
end

local function aliveRoot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil
end

local function playerLevel(player)
	local data = DataService.GetData(player)
	return if data then data.Level else 0
end

local function now()
	return Workspace:GetServerTimeNow()
end

local function publish(run)
	for player in run.Players do
		if player.Parent then
			player:SetAttribute("ArenaRunId", run.Id)
			player:SetAttribute("ArenaName", run.Arena.DisplayName)
			player:SetAttribute("ArenaState", run.State)
			player:SetAttribute("ArenaWave", run.Wave)
			player:SetAttribute("ArenaWaves", #run.Arena.Waves)
			player:SetAttribute("ArenaEnemiesLeft", run.Remaining)
			player:SetAttribute("ArenaTimerEnd", run.TimerEnd or 0)
		end
	end
end

local function clearAttributes(player)
	for _, name in ATTRIBUTES do
		player:SetAttribute(name, nil)
	end
end

local function sendQueue(arenaId)
	local queue = queues[arenaId] or {}
	local names = {}
	for _, player in queue do
		table.insert(names, player.DisplayName)
	end
	for _, player in queue do
		arenaEvent:FireClient(player, "Queue", arenaId, names)
	end
end

local function leaveQueue(player)
	for arenaId, queue in queues do
		local index = table.find(queue, player)
		if index then
			table.remove(queue, index)
			sendQueue(arenaId)
			if player.Parent then
				arenaEvent:FireClient(player, "Queue", nil, {})
			end
		end
	end
end

--------------------------------------------------------------------------
-- Building an arena copy (placeholder geometry)
--------------------------------------------------------------------------
local function buildArena(center, arena)
	local model = Instance.new("Model")
	model.Name = "Arena_" .. arena.Id
	local MP = WorldBuilder.MakePart
	local R = arena.Radius or ArenaConfig.Radius
	local theme = arena.Theme or {}
	local stone = theme.Wall or Color3.fromRGB(176, 160, 130)

	MP(model, {
		Name = "Floor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, R * 2 + 6, R * 2 + 6),
		CFrame = CFrame.new(center - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Sandstone,
		Color = theme.Floor or Color3.fromRGB(196, 170, 125),
	})
	MP(model, {
		Name = "Centre",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 14, 14),
		CFrame = CFrame.new(center + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Slate,
		Color = arena.Color or stone,
	})
	-- Ring wall of blocks and columns (keeps everyone inside)
	local segments = 24
	for i = 0, segments - 1 do
		local angle = (i / segments) * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle) * (R + 1.5), 0, math.sin(angle) * (R + 1.5))
		MP(model, {
			Name = "Wall",
			Size = Vector3.new(2 * math.pi * (R + 1.5) / segments + 0.5, 10, 3),
			CFrame = CFrame.lookAt(pos + Vector3.new(0, 5, 0), center + Vector3.new(0, 5, 0)),
			Material = Enum.Material.Slate,
			Color = stone,
		})
		if i % 3 == 0 then
			MP(model, {
				Name = "Column",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(16, 3.5, 3.5),
				CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			})
			local fire = Instance.new("Fire")
			fire.Size = 6
			if theme.Fire then
				fire.Color = theme.Fire
				fire.SecondaryColor = Color3.new(1, 1, 1)
			end
			fire.Heat = 10
			fire.Parent = MP(model, {
				Name = "Torch",
				Size = Vector3.new(1.6, 0.6, 1.6),
				Position = pos + Vector3.new(0, 16.3, 0),
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(212, 175, 55),
			})
		end
	end
	local sign = MP(model, { Name = "Sign", Size = Vector3.new(1, 1, 1), Position = center + Vector3.new(0, 20, 0), Transparency = 1, CanCollide = false })
	WorldBuilder.AddLabel(sign, arena.DisplayName, arena.Color or Color3.new(1, 1, 1), 0)
	model.Parent = arenasFolder
	return model
end

--------------------------------------------------------------------------
-- Running a run
--------------------------------------------------------------------------
local finish -- forward declaration

local function spawnPoint(run, index, count)
	local angle = math.rad(-150 + 300 * ((index - 0.5) / math.max(count, 1))) - math.pi / 2
	local r = (run.Arena.Radius or ArenaConfig.Radius) - 8
	return run.Center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
end

local function onEnemyGone(run, model)
	if not run.Enemies[model] then
		return
	end
	run.Enemies[model] = nil
	run.Remaining -= 1
	publish(run)
	if run.Remaining > 0 or run.Finished or run.State ~= "Fighting" then
		return
	end
	run.Cleared = run.Wave
	if run.Wave >= #run.Arena.Waves then
		finish(run, true)
		return
	end
	run.State = "Intermission"
	run.TimerEnd = now() + ArenaConfig.IntermissionTime
	publish(run)
	task.delay(ArenaConfig.IntermissionTime, function()
		if not run.Finished then
			ArenaService._StartWave(run, run.Wave + 1)
		end
	end)
end

local function spawnEnemy(run, enemyType, position, isBoss)
	local partyExtra = run.PartySize - 1
	local party = ArenaConfig.Party
	local healthMultiplier = 1 + partyExtra * (if isBoss then party.BossHealthPerExtraPlayer else party.HealthPerExtraPlayer)
	if isBoss then
		healthMultiplier *= run.Arena.BossHealth or 1 -- e.g. a tougher boss in a trial
	end
	-- Waves get harder: normal enemies get more health and damage each wave.
	local damageMultiplier = 1
	local speedMultiplier = 1
	if not isBoss then
		local wave = math.max(run.Wave, 1)
		healthMultiplier *= (run.Arena.WaveHealth and run.Arena.WaveHealth[wave]) or 1
		damageMultiplier = (run.Arena.WaveDamage and run.Arena.WaveDamage[wave]) or 1
		speedMultiplier = (run.Arena.WaveSpeed and run.Arena.WaveSpeed[wave]) or 1
	end
	local cframe = CFrame.lookAt(position, Vector3.new(run.Center.X, position.Y, run.Center.Z))
	local model
	model = EnemyService.Spawn(enemyType, cframe, {
		HealthMultiplier = healthMultiplier,
		DamageMultiplier = damageMultiplier,
		SpeedMultiplier = speedMultiplier,
		AggroRange = (run.Arena.Radius or ArenaConfig.Radius) * 3, -- arena enemies always find you
		LeashRange = (run.Arena.Radius or ArenaConfig.Radius) * 3,
		Attributes = { RunId = run.Id, DisplayName = if isBoss then run.Arena.BossDisplayName else nil },
		OnDeath = function(deadModel)
			onEnemyGone(run, deadModel)
		end,
		OnPhase2 = function(bossModel)
			local cfg = CombatConfig.Enemies[enemyType]
			local phase2 = cfg.Phase2
			for player in run.Alive do
				message(player, phase2.Message or "The boss is enraged!")
			end
			local root = bossModel:FindFirstChild("HumanoidRootPart")
			local i = 0
			for addType, count in phase2.Summon or {} do
				for _ = 1, count do
					i += 1
					local base = if root then root.Position - Vector3.new(0, 3, 0) else run.Center
					local offset = Vector3.new(math.cos(i * 2.1) * 8, 0, math.sin(i * 2.1) * 8)
					spawnEnemy(run, addType, base + offset, false)
				end
			end
			publish(run) -- show the summoned enemies in "Enemies left"
		end,
	})
	if model then
		run.Enemies[model] = true
		run.Remaining += 1
		if isBoss then
			run.BossTypes[enemyType] = true
		end
	end
	return model
end

function ArenaService._StartWave(run, index)
	run.Wave = index
	run.State = "Fighting"
	run.TimerEnd = 0
	local wave = run.Arena.Waves[index]
	local extra = (run.PartySize - 1) * ArenaConfig.Party.CountPerExtraPlayer

	-- Work out the list first, so the remaining count is right from the start.
	local list = {}
	if wave.Boss then
		table.insert(list, { wave.Boss, true })
	end
	for enemyType, count in wave do
		if enemyType ~= "Boss" then
			for _ = 1, math.floor(count * (1 + extra) + 0.5) do
				table.insert(list, { enemyType, false })
			end
		end
	end
	for i, entry in list do
		local position = if entry[2] then run.Center + Vector3.new(0, 0, -(run.Arena.Radius or ArenaConfig.Radius) + 16) else spawnPoint(run, i, #list)
		spawnEnemy(run, entry[1], position, entry[2])
	end
	publish(run)
	for player in run.Alive do
		message(player, if wave.Boss then "Final wave: the boss appears!" else ("Wave %d of %d"):format(index, #run.Arena.Waves))
	end
end

local function returnHome(player)
	if player.Parent then
		PlotService.TeleportPlayer(player, "Plaza")
		clearAttributes(player)
	end
	playerRun[player] = nil
end

local function cleanup(run)
	for model in run.Enemies do
		EnemyService.Remove(model)
	end
	run.Enemies = {}
	if run.Model then
		run.Model:Destroy()
	end
	for _, connection in run.Connections do
		connection:Disconnect()
	end
	slotUsed[run.Slot] = nil
	runs[run.Id] = nil
end

finish = function(run, victory)
	if run.Finished then
		return
	end
	run.Finished = true
	run.State = if victory then "Victory" else "Failed"
	run.TimerEnd = now() + ArenaConfig.ReturnDelay

	-- Remaining enemies vanish (no rewards for them).
	for model in run.Enemies do
		EnemyService.Remove(model)
	end
	run.Enemies = {}
	run.Remaining = 0
	publish(run)
	if victory and run.OnVictory then
		task.spawn(run.OnVictory, run) -- e.g. an ascension trial ranks the player up
	end

	local rewards = run.Arena.Rewards or {}
	local multiplier = if victory then 1 else ArenaConfig.FailRewardMultiplier * (run.Cleared / #run.Arena.Waves)
	local elapsed = math.floor(os.clock() - run.StartedAt)
	for player in run.Players do
		if player.Parent and DataService.GetData(player) then
			local paid = {}
			for currency, amount in rewards do
				local value = math.floor(amount * multiplier)
				if currency == "Ambrosia" and not victory then
					value = 0 -- Ambrosia only for winning
				end
				if value > 0 then
					if currency == "XP" then
						ProgressionService.AddXP(player, value, "Arena")
					else
						ProgressionService.AddCurrency(player, currency, value, "Arena")
					end
					paid[currency] = value
				end
			end
			local weapons = if victory and dropHandler then dropHandler(player, run.BossTypes) else {}
			arenaEvent:FireClient(player, "Result", {
				Weapons = weapons,
				Victory = victory,
				Arena = run.Arena.DisplayName,
				WavesCleared = run.Cleared,
				Waves = #run.Arena.Waves,
				Seconds = elapsed,
				Rewards = paid,
			})
		end
	end

	task.delay(ArenaConfig.ReturnDelay, function()
		for player in run.Players do
			if playerRun[player] == run then
				returnHome(player)
			end
		end
		cleanup(run)
	end)
end

-- A player stops taking part (died, left the arena or the game).
local function playerOut(run, player)
	if not run.Alive[player] then
		return
	end
	run.Alive[player] = nil
	if not run.Finished and next(run.Alive) == nil then
		finish(run, false)
	end
end

-- `arena` is an ArenaConfig entry, or a trial built by StartTrial.
local function startRun(arena, members, onVictory)
	if not arena or not arena.Available then
		return false, "That arena isn't open yet."
	end
	local slot = nil
	for i = 1, ArenaConfig.MaxRuns do
		if not slotUsed[i] then
			slot = i
			break
		end
	end
	if not slot then
		return false, "All arenas are busy. Try again in a minute."
	end
	local ready = {}
	for _, player in members do
		if player.Parent and not playerRun[player] and aliveRoot(player) and playerLevel(player) >= arena.MinLevel then
			table.insert(ready, player)
		end
	end
	if #ready == 0 then
		return false, ("You need level %d and to be alive to enter."):format(arena.MinLevel)
	end

	slotUsed[slot] = true
	nextRunId += 1
	local center = ArenaConfig.Origin + Vector3.new((slot - 1) * ArenaConfig.SlotSpacing, 0, 0)
	local run = {
		Id = nextRunId,
		Arena = arena,
		Slot = slot,
		Center = center,
		Players = {},
		Alive = {},
		PartySize = #ready,
		Wave = 0,
		Cleared = 0,
		Remaining = 0,
		Enemies = {},
		State = "Countdown",
		TimerEnd = now() + ArenaConfig.CountdownTime,
		Finished = false,
		StartedAt = os.clock(),
		Connections = {},
		OnVictory = onVictory,
		BossTypes = {},
	}
	runs[run.Id] = run
	run.Model = buildArena(center, arena)

	for i, player in ready do
		leaveQueue(player)
		run.Players[player] = true
		run.Alive[player] = true
		playerRun[player] = run
		local pos = center + Vector3.new((i - (#ready + 1) / 2) * 5, 3, (arena.Radius or ArenaConfig.Radius) - 10)
		player.Character:PivotTo(CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)))
		local _, humanoid = aliveRoot(player)
		if humanoid then
			table.insert(run.Connections, humanoid.Died:Connect(function()
				playerOut(run, player)
			end))
		end
	end
	publish(run)
	task.delay(ArenaConfig.CountdownTime, function()
		if not run.Finished then
			ArenaService._StartWave(run, 1)
		end
	end)
	return true, run
end

--------------------------------------------------------------------------
-- Requests
--------------------------------------------------------------------------
function ArenaService.StartSolo(player, arenaId)
	if playerRun[player] then
		return false
	end
	local ok, result = startRun(ArenaConfig.ById[arenaId], { player })
	if not ok then
		message(player, result)
	end
	return ok, result
end

-- Phase 6: a solo ascension trial. `trial` is an AscensionConfig.Trials entry;
-- onVictory(run) is called once if the player wins.
function ArenaService.StartTrial(player, trial, onVictory)
	if playerRun[player] then
		return false
	end
	local arena = {
		Id = "Trial_" .. trial.Id,
		DisplayName = "Trial: " .. trial.Name,
		Available = true,
		MinLevel = 0,
		Color = trial.Color,
		Waves = trial.Waves,
		WaveHealth = trial.WaveHealth,
		WaveDamage = trial.WaveDamage,
		WaveSpeed = trial.WaveSpeed,
		BossHealth = trial.BossHealth,
		BossDisplayName = trial.BossDisplayName,
		Theme = trial.Theme,
		Radius = trial.Radius,
		Rewards = {},
	}
	leaveQueue(player)
	local ok, result = startRun(arena, { player }, onVictory)
	if not ok then
		message(player, result)
	end
	return ok, result
end

function ArenaService.JoinQueue(player, arenaId)
	local arena = ArenaConfig.ById[arenaId]
	if not arena or playerRun[player] then
		return false
	end
	local data = DataService.GetData(player)
	local reason = ArenaConfig.LockReason(arena, playerLevel(player), data and data.RankIndex or 1)
	if reason then
		message(player, reason .. " to enter " .. arena.DisplayName .. ".")
		return false
	end
	leaveQueue(player)
	queues[arenaId] = queues[arenaId] or {}
	if #queues[arenaId] >= ArenaConfig.Party.MaxPlayers then
		message(player, "That party is full.")
		return false
	end
	table.insert(queues[arenaId], player)
	sendQueue(arenaId)
	return true
end

function ArenaService.StartParty(player)
	for arenaId, queue in queues do
		if table.find(queue, player) then
			local members = table.clone(queue)
			local ok, result = startRun(ArenaConfig.ById[arenaId], members)
			if not ok then
				message(player, result)
			end
			return ok, result
		end
	end
	return false
end

-- Leaving: during a run you're out; after it you just go home early.
function ArenaService.Leave(player)
	local run = playerRun[player]
	if not run then
		return false
	end
	playerOut(run, player)
	returnHome(player)
	return true
end

function ArenaService.SetDropHandler(handler)
	dropHandler = handler
end

function ArenaService.IsInRun(player)
	return playerRun[player] ~= nil
end

--------------------------------------------------------------------------
-- Arena Gate in Olympus Plaza
--------------------------------------------------------------------------
function ArenaService.BuildGate()
	local hub = Workspace:WaitForChild("Hub")
	local marker = hub:FindFirstChild("Arena Gate")
	if marker then
		marker:Destroy() -- the old "coming in Phase 5" marker
	end
	if hub:FindFirstChild("ArenaGate") then
		return
	end
	local gate = Instance.new("Model")
	gate.Name = "ArenaGate"
	local MP = WorldBuilder.MakePart
	local base = Vector3.new(-44, 1, 0)
	local bronze = Color3.fromRGB(150, 95, 45)
	for _, z in { -5, 5 } do
		MP(gate, {
			Name = "Pillar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(14, 2.4, 2.4),
			CFrame = CFrame.new(base + Vector3.new(0, 7, z)) * CFrame.Angles(0, 0, math.rad(90)),
		})
	end
	MP(gate, { Name = "Lintel", Size = Vector3.new(3, 2, 13), Position = base + Vector3.new(0, 15, 0), Material = Enum.Material.Metal, Color = bronze })
	local portal = MP(gate, {
		Name = "Portal",
		Size = Vector3.new(0.4, 13, 8),
		Position = base + Vector3.new(0, 7.5, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(230, 90, 50),
		Transparency = 0.35,
		CanCollide = false,
	})
	WorldBuilder.AddLabel(portal, "Arena Gate", Color3.fromRGB(255, 140, 90), 9)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Arena Gate"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal
	prompt.Triggered:Connect(function(player)
		notifyRemote:FireClient(player, "OpenArenaMenu")
	end)
	gate.Parent = hub
end

--------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------
function ArenaService.Init(dataService, progressionService, plotService, enemyService, notifyRemoteEvent, arenaActionRemote, arenaEventRemote)
	DataService = dataService
	ProgressionService = progressionService
	PlotService = plotService
	EnemyService = enemyService
	notifyRemote = notifyRemoteEvent
	arenaEvent = arenaEventRemote

	arenasFolder = Workspace:FindFirstChild("Arenas") or Instance.new("Folder")
	arenasFolder.Name = "Arenas"
	arenasFolder.Parent = Workspace

	if arenaActionRemote then
		local last = {}
		arenaActionRemote.OnServerEvent:Connect(function(player, action, arg)
			local t = os.clock()
			if last[player] and t - last[player] < 0.5 then
				return
			end
			last[player] = t
			if action == "StartSolo" and type(arg) == "string" then
				ArenaService.StartSolo(player, arg)
			elseif action == "JoinQueue" and type(arg) == "string" then
				ArenaService.JoinQueue(player, arg)
			elseif action == "LeaveQueue" then
				leaveQueue(player)
			elseif action == "StartParty" then
				ArenaService.StartParty(player)
			elseif action == "Leave" then
				ArenaService.Leave(player)
			end
		end)
	end
end

function ArenaService.ReleasePlayer(player)
	leaveQueue(player)
	local run = playerRun[player]
	if run then
		playerOut(run, player)
		run.Players[player] = nil
		playerRun[player] = nil
	end
end

-- Test helpers
function ArenaService._GetRun(player)
	return playerRun[player]
end
function ArenaService._PlayerOut(player)
	local run = playerRun[player]
	if run then
		playerOut(run, player)
	end
end

return ArenaService
