-- ChallengeService (ModuleScript)
-- Location: ServerScriptService > Services > ChallengeService
--
-- Phase 7E: the Titan Gate (west of the plaza, beside the Arena Gate) and
-- Olympian Challenges: harder boss rematches and the Olympian Gauntlet
-- (settings in Shared/ChallengeConfig). A challenge runs as a solo arena run
-- through ArenaService.StartTrial, with stronger bosses and bigger rewards.
-- Clears and best times are saved in data.Challenges and sent to the client
-- as attribute "ChallengesJson".

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChallengeConfig = require(Shared:WaitForChild("ChallengeConfig"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local GameEvents = require(script.Parent:WaitForChild("GameEvents"))

local ChallengeService = {}

local DataService = nil
local ArenaService = nil
local notifyRemote = nil

local function message(player, text)
	if notifyRemote and player.Parent then
		notifyRemote:FireClient(player, "Message", text)
	end
end

local function records(data)
	if type(data.Challenges) ~= "table" then
		data.Challenges = {}
	end
	return data.Challenges
end

local function push(player, data)
	player:SetAttribute("ChallengesJson", HttpService:JSONEncode(records(data)))
end

-- Builds the run description handed to ArenaService.
local function buildRun(challenge, difficulty, firstClear)
	local waveHealth, waveDamage, waveSpeed = {}, {}, {}
	for i = 1, #challenge.Waves do
		waveHealth[i] = difficulty.AddHealth
		waveDamage[i] = difficulty.AddDamage
		waveSpeed[i] = difficulty.Speed
	end
	local rewards = {}
	for currency, amount in challenge.Rewards do
		rewards[currency] = math.floor(amount * difficulty.Reward)
	end
	if firstClear then
		rewards.Ambrosia = (rewards.Ambrosia or 0) + difficulty.FirstClearAmbrosia
	end
	return {
		Id = challenge.Id,
		ArenaId = "Challenge_" .. challenge.Id,
		Name = challenge.Name,
		DisplayName = ("%s (%s)"):format(challenge.Name, difficulty.Name),
		Color = difficulty.Color,
		Waves = challenge.Waves,
		WaveHealth = waveHealth,
		WaveDamage = waveDamage,
		WaveSpeed = waveSpeed,
		BossHealth = difficulty.BossHealth,
		BossDamage = difficulty.BossDamage,
		BossSpeed = difficulty.Speed,
		Theme = challenge.Theme,
		Radius = challenge.Radius,
		Rewards = rewards,
	}
end

function ChallengeService.Start(player, challengeId, difficultyId)
	local data = DataService.GetData(player)
	local challenge = ChallengeConfig.ById[challengeId]
	local difficulty = ChallengeConfig.Difficulties[difficultyId]
	if not data or not challenge or not difficulty then
		return false
	end
	if ArenaService.IsInRun(player) then
		message(player, "You're already in a fight.")
		return false
	end
	local reason = ChallengeConfig.LockReason(challenge, difficultyId, data.RankIndex)
	if reason then
		message(player, ("%s: %s."):format(challenge.Name, reason))
		return false
	end
	local key = ChallengeConfig.Key(challengeId, difficultyId)
	local firstClear = records(data)[key] == nil
	local run = buildRun(challenge, difficulty, firstClear)
	local ok = ArenaService.StartTrial(player, run, function(finishedRun)
		local current = DataService.GetData(player)
		if not current then
			return
		end
		local seconds = math.floor(os.clock() - finishedRun.StartedAt)
		local record = records(current)[key] or { Clears = 0, Best = 0 }
		record.Clears += 1
		local newBest = record.Best == 0 or seconds < record.Best
		if newBest then
			record.Best = seconds
		end
		records(current)[key] = record
		push(player, current)
		GameEvents.Fire("WinChallenge", player, challengeId)
		if firstClear then
			message(player, ("First %s clear of %s! +%d bonus Ambrosia."):format(difficulty.Name, challenge.Name, difficulty.FirstClearAmbrosia))
		elseif newBest then
			message(player, ("New best time: %d:%02d!"):format(seconds // 60, seconds % 60))
		end
	end)
	return ok
end

function ChallengeService.BuildGate()
	local hub = Workspace:WaitForChild("Hub")
	local marker = hub:FindFirstChild("Titan Gate")
	if marker then
		marker:Destroy() -- the old placeholder pad
	end
	if hub:FindFirstChild("TitanGate") then
		return
	end
	local gate = Instance.new("Model")
	gate.Name = "TitanGate"
	local MP = WorldBuilder.MakePart
	local base = Vector3.new(-44, 1, 35)
	local stone = Color3.fromRGB(70, 60, 85)
	local purple = Color3.fromRGB(150, 70, 200)
	-- Two huge dark pillars, a heavy lintel, and a purple portal.
	for _, z in { -6, 6 } do
		MP(gate, {
			Name = "Pillar", Size = Vector3.new(4, 20, 4), Position = base + Vector3.new(0, 10, z),
			Material = Enum.Material.Slate, Color = stone,
		})
		MP(gate, {
			Name = "PillarCap", Size = Vector3.new(5.5, 1.5, 5.5), Position = base + Vector3.new(0, 20.5, z),
			Material = Enum.Material.Slate, Color = stone,
		})
		MP(gate, {
			Name = "Rune", Size = Vector3.new(0.3, 12, 1), Position = base + Vector3.new(2.1, 10, z),
			Material = Enum.Material.Neon, Color = purple, CanCollide = false,
		})
	end
	MP(gate, { Name = "Lintel", Size = Vector3.new(5, 3, 17), Position = base + Vector3.new(0, 22.5, 0), Material = Enum.Material.Slate, Color = stone })
	local portal = MP(gate, {
		Name = "Portal", Size = Vector3.new(0.4, 19, 8), Position = base + Vector3.new(0, 10.5, 0),
		Material = Enum.Material.Neon, Color = purple, Transparency = 0.3, CanCollide = false,
	})
	WorldBuilder.AddLabel(portal, "Titan Gate", Color3.fromRGB(200, 140, 255), 13)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Titan Gate (Olympian Challenges)"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal
	prompt.Triggered:Connect(function(player)
		notifyRemote:FireClient(player, "OpenTitanGate")
	end)
	gate.Parent = hub
end

function ChallengeService.Init(dataService, arenaService, notifyRemoteEvent, challengeRemote)
	DataService = dataService
	ArenaService = arenaService
	notifyRemote = notifyRemoteEvent
	if challengeRemote then
		local last = {}
		challengeRemote.OnServerEvent:Connect(function(player, action, challengeId, difficultyId)
			local t = os.clock()
			if last[player] and t - last[player] < 0.5 then
				return
			end
			last[player] = t
			if action == "Start" and type(challengeId) == "string" and type(difficultyId) == "string" then
				ChallengeService.Start(player, challengeId, difficultyId)
			end
		end)
	end
end

function ChallengeService.SetupPlayer(player)
	local data = DataService.GetData(player)
	if data then
		push(player, data)
	end
end

return ChallengeService
