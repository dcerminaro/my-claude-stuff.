-- ProgressionService (ModuleScript)
-- Location: ServerScriptService > Services > ProgressionService
--
-- The ONLY place that changes XP, levels, ranks and currencies.
-- Server-only: clients can never call these functions directly.
-- Later systems (combat, arenas, temple, quests) will call:
--   ProgressionService.AddXP(player, amount, source)
--   ProgressionService.AddCurrency(player, "Gold", amount, source)
--   ProgressionService.SpendCurrency(player, "Gold", amount) -> true/false
--   ProgressionService.AdvanceRank(player, trialId) -> true/false, message
--
-- Values are shown to the client through Player Attributes (Level, XP,
-- Gold, ...). Attributes set by the server replicate to the client, and a
-- client changing its own copy does NOT affect the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Progression = require(Shared:WaitForChild("Progression"))

local ProgressionService = {}

local DataService = nil
local notifyRemote = nil
local bonusProvider = nil -- function(player) -> { AttackPercent, HealthPercent, SpeedPercent }

local BASE_WALK_SPEED = 16

local VALID_CURRENCY = {}
for _, name in GameConfig.Currencies do
	VALID_CURRENCY[name] = true
end

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------

-- Accepts only positive whole finite numbers.
local function sanitizeAmount(amount)
	if type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount == -math.huge then
		return nil
	end
	amount = math.floor(amount)
	if amount <= 0 then
		return nil
	end
	return amount
end

local function notify(player, kind, value)
	if notifyRemote and player.Parent then
		notifyRemote:FireClient(player, kind, value)
	end
end

-- Converts stored XP into level-ups, respecting the rank cap.
local function processLevels(data)
	local cap = Progression.GetLevelCap(data.RankIndex)
	while data.Level < cap do
		local need = Progression.XPToNextLevel(data.Level)
		if need <= 0 or data.XP < need then
			break
		end
		data.XP -= need
		data.Level += 1
	end
	if data.Level >= cap then
		local need = Progression.XPToNextLevel(data.Level)
		-- At the cap the bar stays full; extra XP is not banked.
		data.XP = if need > 0 then math.min(data.XP, need) else 0
	end
end

local function getBonuses(player)
	local bonuses = if bonusProvider then bonusProvider(player) else nil
	return bonuses or {}
end

local function applyCharacterStats(player, character, healFully)
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	local data = DataService.GetData(player)
	if not humanoid or not data then
		return
	end
	local bonuses = getBonuses(player)
	local maxHealth = math.floor(Progression.GetMaxHealth(data.Level) * (1 + (bonuses.HealthPercent or 0) / 100))
	humanoid.MaxHealth = maxHealth
	humanoid.WalkSpeed = BASE_WALK_SPEED * (1 + (bonuses.SpeedPercent or 0) / 100)
	if healFully then
		humanoid.Health = maxHealth
	end
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------
function ProgressionService.Init(dataService, notifyRemoteEvent)
	DataService = dataService
	notifyRemote = notifyRemoteEvent
end

-- Phase 3: GodService supplies blessing bonuses (attack / health / speed %).
function ProgressionService.SetBonusProvider(provider)
	bonusProvider = provider
end

-- Pushes saved values to attributes + leaderboard so the client can display them.
function ProgressionService.Refresh(player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local rank = Progression.GetRank(data.RankIndex)
	local cap = Progression.GetLevelCap(data.RankIndex)

	player:SetAttribute("Level", data.Level)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("XPToNext", Progression.XPToNextLevel(data.Level))
	player:SetAttribute("RankIndex", data.RankIndex)
	player:SetAttribute("RankName", rank.Name)
	player:SetAttribute("LevelCap", cap)
	player:SetAttribute("TrialReady", data.Level >= cap and data.RankIndex < #GameConfig.Ranks)
	local attackBonus = getBonuses(player).AttackPercent or 0
	player:SetAttribute("BaseAttack", math.floor(Progression.GetBaseAttack(data.Level) * (1 + attackBonus / 100)))
	for _, name in GameConfig.Currencies do
		player:SetAttribute(name, data.Currencies[name] or 0)
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Level.Value = data.Level
		leaderstats.Rank.Value = rank.Name
		leaderstats.Gold.Value = data.Currencies.Gold or 0
	end
end

-- Call once after data has loaded.
function ProgressionService.SetupPlayer(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = leaderstats

	local rank = Instance.new("StringValue")
	rank.Name = "Rank"
	rank.Parent = leaderstats

	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Parent = leaderstats

	leaderstats.Parent = player

	ProgressionService.Refresh(player)

	player.CharacterAdded:Connect(function(character)
		applyCharacterStats(player, character, true)
	end)
	if player.Character then
		task.spawn(applyCharacterStats, player, player.Character, true)
	end
end

-- Refresh everything, including the character's health (used after a data reset).
function ProgressionService.RefreshAll(player)
	ProgressionService.Refresh(player)
	task.spawn(applyCharacterStats, player, player.Character, true)
end

function ProgressionService.AddXP(player, amount, source)
	local data = DataService.GetData(player)
	amount = sanitizeAmount(amount)
	if not data or not amount then
		return false
	end

	local oldLevel = data.Level
	data.XP += amount
	processLevels(data)
	ProgressionService.Refresh(player)

	if data.Level > oldLevel then
		task.spawn(applyCharacterStats, player, player.Character, true)
		notify(player, "LevelUp", data.Level)

		local cap = Progression.GetLevelCap(data.RankIndex)
		if data.Level >= cap and data.RankIndex < #GameConfig.Ranks then
			local nextRank = Progression.GetRank(data.RankIndex + 1)
			notify(player, "Message", ("Level cap reached! Complete your trial to become a %s."):format(nextRank.Name))
		end
	end
	return true
end

function ProgressionService.AddCurrency(player, currency, amount, source)
	local data = DataService.GetData(player)
	amount = sanitizeAmount(amount)
	if not data or not amount or not VALID_CURRENCY[currency] then
		return false
	end
	data.Currencies[currency] = (data.Currencies[currency] or 0) + amount
	ProgressionService.Refresh(player)
	return true
end

function ProgressionService.CanAfford(player, currency, amount)
	local data = DataService.GetData(player)
	amount = sanitizeAmount(amount)
	if not data or not amount or not VALID_CURRENCY[currency] then
		return false
	end
	return (data.Currencies[currency] or 0) >= amount
end

-- Check and subtract happen with no yield in between, so two purchases
-- arriving at once cannot both spend the same Gold.
function ProgressionService.SpendCurrency(player, currency, amount)
	if not ProgressionService.CanAfford(player, currency, amount) then
		return false
	end
	local data = DataService.GetData(player)
	data.Currencies[currency] -= math.floor(amount)
	ProgressionService.Refresh(player)
	return true
end

-- Phase 6 will call this when a trial is won. Requires the level cap to be reached.
function ProgressionService.AdvanceRank(player, trialId)
	local data = DataService.GetData(player)
	if not data then
		return false, "Data not loaded."
	end
	if data.RankIndex >= #GameConfig.Ranks then
		return false, "You are already an Elder God."
	end
	local cap = Progression.GetLevelCap(data.RankIndex)
	if data.Level < cap then
		return false, ("Reach level %d before attempting this trial."):format(cap)
	end

	data.RankIndex += 1
	local newRank = Progression.GetRank(data.RankIndex)
	if newRank.Trial ~= "" then
		data.CompletedTrials[newRank.Trial] = true
	end

	local oldLevel = data.Level
	processLevels(data) -- a full XP bar turns into the next level now the cap is lifted
	ProgressionService.Refresh(player)
	notify(player, "RankUp", newRank.Name)
	if data.Level > oldLevel then
		task.spawn(applyCharacterStats, player, player.Character, true)
	end
	return true, "You are now a " .. newRank.Name .. "!"
end

return ProgressionService
