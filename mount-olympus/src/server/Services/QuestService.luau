-- QuestService (ModuleScript)
-- Location: ServerScriptService > Services > QuestService
--
-- Phase 7D: quests, all tracked on the server.
--   * Chains (QuestConfig.Chains): the first unfinished quest of each chain
--     whose requirements are met is active; claiming it unlocks the next.
--   * Daily quests: 3 per day from QuestConfig.Daily, reset at midnight UTC.
--   * Progress comes from GameEvents (kills, wins, upgrades...) or, for
--     state objectives (god chosen, rank, temple tier, buildings, blessings,
--     weapons owned), from the save, so things done before still count.
--   * Rewards are paid once, when the player presses Claim.
-- Saved in data.Quests: Active = { [questId] = progress }, Completed =
-- { [questId] = true }, Daily = { Day, Ids, Progress, Claimed }.
-- The client gets attribute "QuestsJson" (the active quests).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared:WaitForChild("QuestConfig"))

local QuestService = {}

local DataService = nil
local ProgressionService = nil
local notifyRemote = nil
local announced = {} -- [Player] = { [questId] = true } "ready to claim" messages already sent

local function message(player, text)
	if notifyRemote and player.Parent then
		notifyRemote:FireClient(player, "Message", text)
	end
end

local function today()
	return math.floor(os.time() / 86400)
end

-- Picks today's daily quests (the same for a player all day).
local function refreshDaily(player, data)
	local quests = data.Quests
	if type(quests.Daily) ~= "table" then
		quests.Daily = {}
	end
	local daily = quests.Daily
	local day = today()
	if daily.Day == day and type(daily.Ids) == "table" then
		return false
	end
	local pool = {}
	for _, quest in QuestConfig.Daily do
		table.insert(pool, quest.Id)
	end
	local rng = Random.new(day * 7919 + math.abs(player.UserId) % 100000)
	local ids = {}
	for _ = 1, math.min(QuestConfig.DailyCount, #pool) do
		table.insert(ids, table.remove(pool, rng:NextInteger(1, #pool)))
	end
	quests.Daily = { Day = day, Ids = ids, Progress = {}, Claimed = {} }
	if announced[player] then
		for _, quest in QuestConfig.Daily do
			announced[player][quest.Id] = nil -- a new day: dailies can be announced again
		end
	end
	return true
end

local function requirementsMet(data, chain)
	return chain.God == nil or chain.God == data.SelectedGod
end

-- The quests currently active for this player (chain heads + today's dailies).
local function activeQuests(data)
	local list = {}
	for _, chain in QuestConfig.Chains do
		if requirementsMet(data, chain) then
			for _, quest in chain.Quests do
				if not data.Quests.Completed[quest.Id] then
					table.insert(list, quest)
					break
				end
			end
		end
	end
	local daily = data.Quests.Daily
	if type(daily) == "table" and type(daily.Ids) == "table" then
		for _, id in daily.Ids do
			local quest = QuestConfig.ById[id]
			if quest and not daily.Claimed[id] then
				table.insert(list, quest)
			end
		end
	end
	return list
end

local function isActive(data, questId)
	for _, quest in activeQuests(data) do
		if quest.Id == questId then
			return quest
		end
	end
	return nil
end

-- Current progress (capped at the objective count).
local function progressOf(data, quest)
	local objective = quest.Objective
	local value
	if objective.Type == "ChooseGod" then
		value = if data.SelectedGod ~= "" then 1 else 0
	elseif objective.Type == "ReachLevel" then
		value = data.Level
	elseif objective.Type == "ReachRank" then
		value = data.RankIndex
	elseif objective.Type == "TempleTier" then
		value = data.Temple.Tier
	elseif objective.Type == "TemplePrestige" then
		value = tonumber(data.Temple.Prestige) or 0
	elseif objective.Type == "BuildingLevel" then
		value = tonumber(data.Temple.Buildings[objective.Target]) or 0
	elseif objective.Type == "TotalBuildingLevels" then
		value = 0
		for _, level in data.Temple.Buildings do
			value += tonumber(level) or 0
		end
	elseif objective.Type == "BlessingLevels" then
		value = 0
		for _, blessings in data.Blessings do
			for _, level in blessings do
				value += tonumber(level) or 0
			end
		end
	elseif objective.Type == "OwnWeapons" then
		value = #data.Inventory.Items
	elseif quest.IsDaily then
		value = data.Quests.Daily.Progress[quest.Id] or 0
	else
		value = data.Quests.Active[quest.Id] or 0
	end
	return math.min(value, objective.Count)
end

local function rewardsFor(data, quest)
	if not quest.IsDaily then
		return quest.Rewards
	end
	local scale = 1 + data.Level / 20
	local scaled = {}
	for currency, amount in quest.Rewards do
		scaled[currency] = if currency == "Ambrosia" then amount else math.floor(amount * scale)
	end
	return scaled
end

local function push(player, data)
	local list = {}
	for _, quest in activeQuests(data) do
		local progress = progressOf(data, quest)
		local ready = progress >= quest.Objective.Count
		table.insert(list, {
			Id = quest.Id,
			Name = quest.Name,
			Description = quest.Description,
			Category = quest.Category,
			Progress = progress,
			Count = quest.Objective.Count,
			Rewards = rewardsFor(data, quest),
			Ready = ready,
			Daily = quest.IsDaily == true,
		})
		announced[player] = announced[player] or {}
		if ready and not announced[player][quest.Id] then
			announced[player][quest.Id] = true
			message(player, ("Quest complete: %s! Claim it in your Quests."):format(quest.Name))
		end
	end
	player:SetAttribute("QuestsJson", HttpService:JSONEncode(list))
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------

-- Counts an event towards every matching active quest.
function QuestService.Record(player, eventType, target, amount)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	refreshDaily(player, data)
	local changed = false
	for _, quest in activeQuests(data) do
		local objective = quest.Objective
		if objective.Type == eventType and (objective.Target == nil or objective.Target == "Any" or objective.Target == target) then
			local store = if quest.IsDaily then data.Quests.Daily.Progress else data.Quests.Active
			local before = store[quest.Id] or 0
			if before < objective.Count then
				store[quest.Id] = math.min(objective.Count, before + (amount or 1))
				changed = true
			end
		end
	end
	if changed or eventType == "UpgradeBuilding" or eventType == "TemplePrestige" or eventType == "UpgradeBlessing" or eventType == "CraftWeapon" then
		push(player, data) -- state quests (building levels, weapons owned...) may have moved too
	end
end

-- Pays a finished quest once. Returns true if paid.
function QuestService.Claim(player, questId)
	local data = DataService.GetData(player)
	if not data or type(questId) ~= "string" then
		return false
	end
	refreshDaily(player, data)
	local quest = isActive(data, questId)
	if not quest or progressOf(data, quest) < quest.Objective.Count then
		return false
	end
	-- Mark first (no yield before this), so a double click can't pay twice.
	if quest.IsDaily then
		data.Quests.Daily.Claimed[questId] = true
	else
		data.Quests.Completed[questId] = true
		data.Quests.Active[questId] = nil
	end
	local paid = {}
	for currency, amount in rewardsFor(data, quest) do
		if currency == "XP" then
			ProgressionService.AddXP(player, amount, "Quest")
		else
			ProgressionService.AddCurrency(player, currency, amount, "Quest")
		end
		table.insert(paid, ("+%d %s"):format(amount, if currency == "DivineFavor" then "Favor" else currency))
	end
	push(player, data)
	message(player, ("%s: %s"):format(quest.Name, table.concat(paid, "  ")))
	return true
end

-- Re-publishes quests (e.g. after state changes like a rank-up).
function QuestService.Refresh(player)
	local data = DataService.GetData(player)
	if data then
		refreshDaily(player, data)
		push(player, data)
	end
end

function QuestService.Init(dataService, progressionService, gameEvents, notifyRemoteEvent, questRemote)
	DataService = dataService
	ProgressionService = progressionService
	notifyRemote = notifyRemoteEvent

	gameEvents.Connect(function(eventType, player, target, amount)
		QuestService.Record(player, eventType, target, amount)
	end)

	if questRemote then
		local last = {}
		questRemote.OnServerEvent:Connect(function(player, action, questId)
			local t = os.clock()
			if last[player] and t - last[player] < 0.3 then
				return
			end
			last[player] = t
			if action == "Claim" then
				QuestService.Claim(player, questId)
			end
		end)
	end

	-- Every 10 s: new day's dailies, and state quests (rank, tier, god) update.
	task.spawn(function()
		while true do
			task.wait(10)
			for _, player in Players:GetPlayers() do
				QuestService.Refresh(player)
			end
		end
	end)
end

function QuestService.SetupPlayer(player)
	announced[player] = {}
	QuestService.Refresh(player)
end

function QuestService.ReleasePlayer(player)
	announced[player] = nil
end

return QuestService
