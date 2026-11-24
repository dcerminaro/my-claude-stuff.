-- AscensionService (ModuleScript)
-- Location: ServerScriptService > Services > AscensionService
--
-- Phase 6, ascension:
--   * Builds the Ascension Chamber in Olympus Plaza (8 rank pillars + altar).
--   * Trials: at the top level of your rank you can start the trial for the
--     next rank (a solo arena run). Winning it calls
--     ProgressionService.AdvanceRank, which raises the rank and the level cap.
--   * Rank looks: each rank makes the character bigger and broader (applied
--     to the player's OWN avatar proportions) and adds outfit pieces and,
--     from Demigod up, an aura (see RankOutfits / AscensionConfig).
--   * Ranking up plays a pillar-of-light effect for everyone nearby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local GodConfig = require(Shared:WaitForChild("GodConfig"))
local Progression = require(Shared:WaitForChild("Progression"))
local AscensionConfig = require(Shared:WaitForChild("AscensionConfig"))
local RankOutfits = require(Shared:WaitForChild("RankOutfits"))
local WorldBuilder = require(ServerScriptService:WaitForChild("Services"):WaitForChild("WorldBuilder"))

local AscensionService = {}

local DataService = nil
local DiagnosticsService = nil
local ProgressionService = nil
local ArenaService = nil
local notifyRemote = nil
local fxRemote = nil

local originalScales = {} -- [Player] = the avatar's own body scales
local applyToken = {}     -- [Player] = number, so only the newest ApplyLooks finishes

local CHAMBER_CENTER = Vector3.new(44, 1, 0)

local function message(player, text)
	if notifyRemote and player.Parent then
		notifyRemote:FireClient(player, "Message", text)
	end
end

local function note(player, text)
	if DiagnosticsService then
		DiagnosticsService.Note(player, text)
	end
end

local function godColor(data)
	return GodConfig.GetColors(data and data.SelectedGod or "").Primary
end

--------------------------------------------------------------------------
-- Rank looks
--------------------------------------------------------------------------
local function applyPhysique(player, character, rank)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local ok, description = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if not ok or not description then
		note(player, "GetAppliedDescription failed: " .. tostring(description))
		return
	end
	local base = originalScales[player]
	if not base then
		base = {
			Height = description.HeightScale,
			Width = description.WidthScale,
			Depth = description.DepthScale,
			Head = description.HeadScale,
		}
		originalScales[player] = base
	end
	local scale = AscensionConfig.Physique[rank] or AscensionConfig.Physique[1]
	local target = {
		HeightScale = base.Height * scale.Height,
		WidthScale = base.Width * scale.Width,
		DepthScale = base.Depth * scale.Depth,
		HeadScale = base.Head * scale.Head,
	}
	local changed = false
	for property, value in target do
		if math.abs(description[property] - value) > 0.001 then
			description[property] = value
			changed = true
		end
	end
	if changed then
		local applied, err = pcall(function()
			humanoid:ApplyDescription(description)
		end)
		if not applied then
			note(player, "ApplyDescription failed: " .. tostring(err))
		end
	end
end

-- Size + outfit + aura for the player's current rank.
function AscensionService.ApplyLooks(player)
	local data = DataService.GetData(player)
	local character = player.Character
	if not data or not character or not character.Parent then
		return
	end
	applyToken[player] = (applyToken[player] or 0) + 1
	local token = applyToken[player]
	applyPhysique(player, character, data.RankIndex)
	if applyToken[player] ~= token or player.Character ~= character then
		return -- a newer call (or a new character) took over
	end
	RankOutfits.Apply(character, data.RankIndex, godColor(data))
	character:SetAttribute("LooksRank", data.RankIndex)
end


-- Just the outfit colours (e.g. after changing god).
local function refreshOutfit(player)
	local data = DataService.GetData(player)
	if data and player.Character then
		RankOutfits.Apply(player.Character, data.RankIndex, godColor(data))
	end
end

function AscensionService.OnRankUp(player)
	local data = DataService.GetData(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		fxRemote:FireAllClients("Ascend", root.Position, godColor(data), player)
	end
	task.spawn(AscensionService.ApplyLooks, player)
end

--------------------------------------------------------------------------
-- Trials
--------------------------------------------------------------------------
-- The next trial and whether it can be started now. Returns trial, reason.
function AscensionService.NextTrial(player)
	local data = DataService.GetData(player)
	if not data then
		return nil, "Your data isn't loaded."
	end
	if data.RankIndex >= #GameConfig.Ranks then
		return nil, "You are already an Elder God."
	end
	local trial = AscensionConfig.Trials[data.RankIndex + 1]
	local cap = Progression.GetLevelCap(data.RankIndex)
	if data.Level < cap then
		return trial, ("Reach level %d first (you are level %d)."):format(cap, data.Level)
	end
	if not trial.Available then
		return trial, trial.Description
	end
	return trial, nil
end

function AscensionService.StartTrial(player)
	local trial, reason = AscensionService.NextTrial(player)
	if reason then
		message(player, reason)
		return false
	end
	local ok = ArenaService.StartTrial(player, trial, function(run)
		if not run.Players[player] or not player.Parent then
			return
		end
		local advanced, text = ProgressionService.AdvanceRank(player, trial.Id)
		if advanced then
			AscensionService.OnRankUp(player)
			message(player, text)
		end
	end)
	return ok
end

--------------------------------------------------------------------------
-- Ascension Chamber (placeholder build in Olympus Plaza)
--------------------------------------------------------------------------
function AscensionService.BuildChamber()
	local hub = Workspace:WaitForChild("Hub")
	local marker = hub:FindFirstChild("Ascension Chamber")
	if marker then
		marker:Destroy() -- the old "coming in Phase 6" marker
	end
	if hub:FindFirstChild("AscensionChamber") then
		return
	end
	local chamber = Instance.new("Model")
	chamber.Name = "AscensionChamber"
	local MP = WorldBuilder.MakePart
	local c = CHAMBER_CENTER

	MP(chamber, {
		Name = "Dais",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 22, 22),
		CFrame = CFrame.new(c + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(240, 236, 226),
	})
	-- One pillar per rank; its top glows on YOUR screen once you reach that rank.
	for i, rank in GameConfig.Ranks do
		local angle = math.rad(-90 + (i - 1) * 45)
		local pos = c + Vector3.new(math.cos(angle) * 9, 0.8, math.sin(angle) * 9)
		local height = 3 + i * 0.6
		MP(chamber, {
			Name = "Pillar" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 1.6, 1.6),
			CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		})
		local top = MP(chamber, {
			Name = "RankGlow" .. i,
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = CFrame.new(pos + Vector3.new(0, height + 0.9, 0)) * CFrame.Angles(0, math.rad(45), 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(150, 150, 160),
		})
		top:SetAttribute("RankIndex", i)
		WorldBuilder.AddLabel(top, rank.Name, rank.Color, 2)
	end
	local altar = MP(chamber, {
		Name = "Altar",
		Size = Vector3.new(4, 3, 4),
		Position = c + Vector3.new(0, 2.3, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(212, 175, 55),
	})
	WorldBuilder.AddLabel(altar, "Ascension Chamber", Color3.fromRGB(120, 200, 255), 6)
	MP(chamber, {
		Name = "Beam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(40, 1.2, 1.2),
		CFrame = CFrame.new(c + Vector3.new(0, 23.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 236, 170),
		Transparency = 0.6,
		CanCollide = false,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ascend"
	prompt.ObjectText = "Ascension Chamber"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = altar
	prompt.Triggered:Connect(function(player)
		notifyRemote:FireClient(player, "OpenAscension")
	end)
	chamber.Parent = hub
end

--------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------
function AscensionService.Init(dataService, progressionService, arenaService, notifyRemoteEvent, fxRemoteEvent, ascensionRemote, diagnosticsService)
	DataService = dataService
	DiagnosticsService = diagnosticsService

	-- Safety net: every 2 s, make sure everyone shows their rank looks
	-- (avatar loading can replace body parts after we applied them).
	task.spawn(function()
		local failures = {}
		while true do
			task.wait(2)
			for player in originalScales do
				if player.Parent == nil then
					originalScales[player] = nil
				end
			end
			for _, player in game:GetService("Players"):GetPlayers() do
				local data = DataService.GetData(player)
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if data and humanoid and humanoid.Health > 0 then
					local missingOutfit = data.RankIndex >= 2 and not character:FindFirstChild(RankOutfits.Name)
					if character:GetAttribute("LooksRank") ~= data.RankIndex or missingOutfit then
						local ok, err = pcall(AscensionService.ApplyLooks, player)
						if not ok then
							failures[player] = (failures[player] or 0) + 1
							if failures[player] <= 3 then
								note(player, "ApplyLooks error: " .. tostring(err))
							end
						end
					end
				end
			end
		end
	end)
	ProgressionService = progressionService
	ArenaService = arenaService
	notifyRemote = notifyRemoteEvent
	fxRemote = fxRemoteEvent

	if ascensionRemote then
		local last = {}
		ascensionRemote.OnServerEvent:Connect(function(player, action)
			local t = os.clock()
			if last[player] and t - last[player] < 1 then
				return
			end
			last[player] = t
			if action == "StartTrial" then
				AscensionService.StartTrial(player)
			end
		end)
	end
end

function AscensionService.SetupPlayer(player)
	-- Looks are applied once the avatar has fully loaded (body parts arrive late).
	if typeof(player) == "Instance" then
		player.CharacterAppearanceLoaded:Connect(function()
			AscensionService.ApplyLooks(player)
		end)
		if player.Character and player:HasAppearanceLoaded() then
			task.spawn(AscensionService.ApplyLooks, player)
		end
	elseif player.Character then
		task.spawn(AscensionService.ApplyLooks, player)
	end
	player:GetAttributeChangedSignal("SelectedGod"):Connect(function()
		refreshOutfit(player)
	end)
end

function AscensionService.ReleasePlayer(player)
	originalScales[player] = nil
	applyToken[player] = nil
end

return AscensionService
