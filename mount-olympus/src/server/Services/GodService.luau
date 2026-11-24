-- GodService (ModuleScript)
-- Location: ServerScriptService > Services > GodService
--
-- Everything about gods, on the server:
--   * First god choice (the intro screen), Zeus and Ares playable for now.
--   * Blessings: unlocked and upgraded with Divine Favor, gated by Main Altar
--     level, loyalty with the god, and ascension rank (rules in GodConfig).
--   * Passive blessing bonuses (attack / health / speed) for the ACTIVE god only.
--   * Worship at your god's statue: Divine Favor + loyalty (cooldown saved).
--   * Changing god: start at the Shrine of Change, then pray there.
--     Levels, currencies, temple, and every god's blessings/loyalty are kept.
--   * Builds the Hall of the Gods in Olympus Plaza.
--   * Tells TempleService which colours to paint the temple.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GodConfig = require(Shared:WaitForChild("GodConfig"))
local WorldBuilder = require(ServerScriptService:WaitForChild("Services"):WaitForChild("WorldBuilder"))

local GodService = {}

local DataService = nil
local ProgressionService = nil
local TempleService = nil
local notifyRemote = nil

local MAX_LEVEL = GodConfig.MaxBlessingLevel
local HALL_CENTER = Vector3.new(-42, 1, -35) -- on the plaza floor (top at Y = 1)
local lastAction = {} -- [Player] = os.clock() of last menu request

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------
local function notify(player, kind, value)
	if notifyRemote and player.Parent then
		notifyRemote:FireClient(player, kind, value)
	end
end

local function message(player, text)
	notify(player, "Message", text)
end

local function blessingLevel(data, godId, blessingId)
	local tree = data.Blessings[godId]
	return if type(tree) == "table" then tonumber(tree[blessingId]) or 0 else 0
end

local function loyalty(data, godId)
	return tonumber(data.GodLoyalty[godId]) or 0
end

-- Tier 1 level 1 is free whenever you start worshipping a god.
local function grantFirstBlessing(data, godId)
	local god = GodConfig.Gods[godId]
	data.Blessings[godId] = data.Blessings[godId] or {}
	for _, blessing in god.Blessings do
		if blessing.Tier == 1 and blessingLevel(data, godId, blessing.Id) < 1 then
			data.Blessings[godId][blessing.Id] = 1
		end
	end
end

local function sanitize(data)
	if type(data.SelectedGod) ~= "string" or (data.SelectedGod ~= "" and not GodConfig.IsPlayable(data.SelectedGod)) then
		data.SelectedGod = ""
	end
	for godId, tree in data.Blessings do
		if type(tree) == "table" then
			for id, level in tree do
				tree[id] = math.clamp(math.floor(tonumber(level) or 0), 0, MAX_LEVEL)
			end
		else
			data.Blessings[godId] = nil
		end
	end
	for godId, value in data.GodLoyalty do
		data.GodLoyalty[godId] = math.max(0, math.floor(tonumber(value) or 0))
	end
	local change = data.GodChange
	if change.Target ~= "" and (not GodConfig.IsPlayable(change.Target) or change.Target == data.SelectedGod) then
		change.Target, change.Prayers = "", 0
	end
end

-- Publishes god values so the menus can show them.
local function pushAttributes(player, data)
	local godId = data.SelectedGod
	player:SetAttribute("SelectedGod", godId)
	player:SetAttribute("Loyalty", if godId ~= "" then loyalty(data, godId) else 0)
	for blessingId, entry in GodConfig.BlessingsById do
		player:SetAttribute("Blessing_" .. blessingId, blessingLevel(data, entry.God, blessingId))
	end
	player:SetAttribute("GodChangeTarget", data.GodChange.Target)
	player:SetAttribute("GodChangePrayers", data.GodChange.Prayers)
	player:SetAttribute("NextPrayerAt", data.GodChange.NextPrayerAt)
	player:SetAttribute("NextWorshipAt", data.NextWorshipAt)

	local bonuses = GodService.GetBonuses(player)
	player:SetAttribute("BonusAttackPercent", bonuses.AttackPercent)
	player:SetAttribute("BonusHealthPercent", bonuses.HealthPercent)
	player:SetAttribute("BonusSpeedPercent", bonuses.SpeedPercent)
end

-- After anything that changes bonuses or colours.
local function refreshAll(player, data, rebuildTemple)
	pushAttributes(player, data)
	ProgressionService.RefreshAll(player) -- re-applies health, speed and attack
	if rebuildTemple then
		TempleService.Rebuild(player) -- new god colours
	end
end

--------------------------------------------------------------------------
-- Hall of the Gods (placeholder build in Olympus Plaza)
--------------------------------------------------------------------------
local function addPrompt(part, actionText, objectText, onTriggered)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(onTriggered)
	return prompt
end

function GodService.BuildHall()
	local hub = Workspace:WaitForChild("Hub")
	if hub:FindFirstChild("HallOfTheGods") then
		return
	end
	local hall = Instance.new("Model")
	hall.Name = "HallOfTheGods"
	local c = HALL_CENTER
	local MP = WorldBuilder.MakePart

	MP(hall, { Name = "Floor", Size = Vector3.new(18, 0.6, 26), Position = c + Vector3.new(0, 0.3, 0), Color = Color3.fromRGB(245, 240, 228) })
	local titlePart = MP(hall, { Name = "Title", Size = Vector3.new(1, 1, 1), Position = c + Vector3.new(0, 1, 0), Transparency = 1, CanCollide = false })
	WorldBuilder.AddLabel(titlePart, "Hall of the Gods", Color3.fromRGB(255, 220, 120), 16)

	-- One statue per god along the back (west) side, facing the plaza.
	for i, godId in GodConfig.Order do
		local god = GodConfig.Gods[godId]
		local z = c.Z - 11 + (i - 1) * 4.4
		local x = c.X - 6
		MP(hall, { Name = godId .. "Pedestal", Size = Vector3.new(3, 2, 3), Position = Vector3.new(x, c.Y + 1.6, z) })
		local figure = MP(hall, {
			Name = godId .. "Statue",
			Size = Vector3.new(1.8, 6, 1.8),
			Position = Vector3.new(x, c.Y + 5.6, z),
			Material = if god.Available then Enum.Material.Neon else Enum.Material.Marble,
			Color = if god.Available then god.Colors.Primary else Color3.fromRGB(190, 185, 178),
		})
		WorldBuilder.AddLabel(figure, god.DisplayName .. "\n" .. (if god.Available then god.Title else "Coming in Phase 7"), god.Colors.Primary, 5)
		if god.Available then
			local light = Instance.new("PointLight")
			light.Color = god.Colors.Primary
			light.Range = 10
			light.Parent = figure
			addPrompt(figure, "Worship", god.DisplayName, function(player)
				GodService.Worship(player, godId)
			end)
		end
	end

	-- Altar that opens the god menu
	local altar = MP(hall, { Name = "GodAltar", Size = Vector3.new(4, 3, 3), Position = c + Vector3.new(3, 2.1, -4), Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal })
	WorldBuilder.AddLabel(altar, "Your God & Blessings", Color3.new(1, 1, 1), 4)
	addPrompt(altar, "Open", "Gods & Blessings", function(player)
		notify(player, "OpenGodMenu", "Blessings")
	end)

	-- Shrine of Change
	local shrine = MP(hall, {
		Name = "ShrineOfChange",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(7, 2.4, 2.4),
		CFrame = CFrame.new(c + Vector3.new(3, 4.1, 6)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(160, 100, 230),
	})
	WorldBuilder.AddLabel(shrine, "Shrine of Change", Color3.fromRGB(200, 160, 255), 5)
	addPrompt(shrine, "Pray", "Shrine of Change", function(player)
		GodService.Pray(player)
	end)

	hall.Parent = hub
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------
function GodService.Init(dataService, progressionService, templeService, notifyRemoteEvent, godRemote)
	DataService = dataService
	ProgressionService = progressionService
	TempleService = templeService
	notifyRemote = notifyRemoteEvent

	ProgressionService.SetBonusProvider(GodService.GetBonuses)
	TempleService.SetColorProvider(GodService.GetColors)

	-- Requests from the god menus: ("Choose", godId), ("UpgradeBlessing", blessingId),
	-- ("StartChange", godId), ("CancelChange"). Never trust the client.
	if godRemote then
		godRemote.OnServerEvent:Connect(function(player, action, arg)
			local now = os.clock()
			if lastAction[player] and now - lastAction[player] < 0.3 then
				return
			end
			lastAction[player] = now
			if action == "Choose" and type(arg) == "string" then
				GodService.ChooseFirstGod(player, arg)
			elseif action == "UpgradeBlessing" and type(arg) == "string" then
				GodService.UpgradeBlessing(player, arg)
			elseif action == "StartChange" and type(arg) == "string" then
				GodService.StartGodChange(player, arg)
			elseif action == "CancelChange" then
				GodService.CancelGodChange(player)
			end
		end)
	end
end

-- Call after data has loaded (before TempleService.SetupPlayer).
function GodService.SetupPlayer(player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	sanitize(data)
	pushAttributes(player, data)
end

-- Re-publish everything (used after the !reset debug command).
function GodService.Refresh(player)
	local data = DataService.GetData(player)
	if data then
		sanitize(data)
		refreshAll(player, data, false)
	end
end

function GodService.ReleasePlayer(player)
	lastAction[player] = nil
end

-- Sum of passive bonuses from the ACTIVE god's blessings.
function GodService.GetBonuses(player)
	local bonuses = { AttackPercent = 0, HealthPercent = 0, SpeedPercent = 0 }
	local data = DataService.GetData(player)
	local god = data and GodConfig.Gods[data.SelectedGod]
	if not god then
		return bonuses
	end
	for _, blessing in god.Blessings do
		local level = blessingLevel(data, god.Id, blessing.Id)
		local stat = blessing.Passive and blessing.Passive.Stat
		if level > 0 and bonuses[stat] then
			bonuses[stat] += level * blessing.Passive.PerLevel
		end
	end
	return bonuses
end

function GodService.GetColors(player)
	local data = DataService.GetData(player)
	return GodConfig.GetColors(data and data.SelectedGod or "")
end

function GodService.ChooseFirstGod(player, godId)
	local data = DataService.GetData(player)
	if not data or data.SelectedGod ~= "" then
		return false -- already chosen: changing goes through the Shrine of Change
	end
	if not GodConfig.IsPlayable(godId) then
		message(player, "That god is not available yet.")
		return false
	end
	data.SelectedGod = godId
	grantFirstBlessing(data, godId)
	refreshAll(player, data, true)
	local god = GodConfig.Gods[godId]
	message(player, ("You now worship %s, %s!"):format(god.DisplayName, god.Title))
	return true
end

function GodService.UpgradeBlessing(player, blessingId)
	local data = DataService.GetData(player)
	local entry = GodConfig.BlessingsById[blessingId]
	if not data or not entry then
		return false
	end
	if entry.God ~= data.SelectedGod then
		message(player, "You can only upgrade blessings of the god you worship.")
		return false
	end

	local level = blessingLevel(data, entry.God, blessingId)
	local altarLevel = tonumber(data.Temple.Buildings.MainAltar) or 0
	local info = GodConfig.GetBlessingUpgradeInfo(blessingId, level, altarLevel, loyalty(data, entry.God), data.RankIndex)
	if info.Maxed then
		message(player, entry.Blessing.Name .. " is already at max level.")
		return false
	end
	if info.Blocked then
		message(player, info.Blocked .. " to upgrade " .. entry.Blessing.Name .. ".")
		return false
	end
	if info.Cost > 0 and not ProgressionService.SpendCurrency(player, "DivineFavor", info.Cost) then
		message(player, ("You need %d more Divine Favor."):format(info.Cost - (data.Currencies.DivineFavor or 0)))
		return false
	end

	data.Blessings[entry.God] = data.Blessings[entry.God] or {}
	data.Blessings[entry.God][blessingId] = info.NextLevel
	refreshAll(player, data, false)
	message(player, ("%s reached level %d!"):format(entry.Blessing.Name, info.NextLevel))
	return true
end

function GodService.Worship(player, godId)
	local data = DataService.GetData(player)
	if not data then
		return false
	end
	if data.SelectedGod == "" then
		notify(player, "OpenGodMenu", "Choose")
		return false
	end
	if godId ~= data.SelectedGod then
		message(player, ("You worship %s. Visit the Shrine of Change to switch gods."):format(GodConfig.Gods[data.SelectedGod].DisplayName))
		return false
	end
	local now = os.time()
	if now < data.NextWorshipAt then
		message(player, ("You can worship again in %d seconds."):format(data.NextWorshipAt - now))
		return false
	end

	local multiplier = 1 + TempleService.GetEffect(player, "WorshipBonusPercent") / 100
	local favor = math.floor(GodConfig.Worship.Favor * multiplier)
	local gainedLoyalty = math.floor(GodConfig.Worship.Loyalty * multiplier)
	data.NextWorshipAt = now + GodConfig.Worship.Cooldown
	data.GodLoyalty[godId] = loyalty(data, godId) + gainedLoyalty
	ProgressionService.AddCurrency(player, "DivineFavor", favor, "Worship")
	pushAttributes(player, data)
	message(player, ("%s is pleased: +%d Favor, +%d Loyalty"):format(GodConfig.Gods[godId].DisplayName, favor, gainedLoyalty))
	return true
end

function GodService.StartGodChange(player, godId)
	local data = DataService.GetData(player)
	if not data or data.SelectedGod == "" then
		return false
	end
	if not GodConfig.IsPlayable(godId) or godId == data.SelectedGod then
		message(player, "You can't switch to that god.")
		return false
	end
	data.GodChange.Target = godId
	data.GodChange.Prayers = 0
	pushAttributes(player, data)
	message(player, ("Pray %d times at the Shrine of Change to follow %s."):format(GodConfig.GodChange.PrayersNeeded, GodConfig.Gods[godId].DisplayName))
	return true
end

function GodService.CancelGodChange(player)
	local data = DataService.GetData(player)
	if not data or data.GodChange.Target == "" then
		return false
	end
	data.GodChange.Target = ""
	data.GodChange.Prayers = 0
	pushAttributes(player, data)
	message(player, "God change cancelled.")
	return true
end

function GodService.Pray(player)
	local data = DataService.GetData(player)
	if not data then
		return false
	end
	local change = data.GodChange
	if data.SelectedGod == "" then
		notify(player, "OpenGodMenu", "Choose")
		return false
	end
	if change.Target == "" then
		notify(player, "OpenGodMenu", "Change") -- shows the "choose a new god" options
		return false
	end
	local now = os.time()
	if now < change.NextPrayerAt then
		message(player, ("You can pray again in %d seconds."):format(change.NextPrayerAt - now))
		return false
	end

	change.Prayers += 1
	change.NextPrayerAt = now + GodConfig.GodChange.PrayerCooldown
	local target = GodConfig.Gods[change.Target]

	if change.Prayers < GodConfig.GodChange.PrayersNeeded then
		pushAttributes(player, data)
		message(player, ("Prayer to %s: %d / %d"):format(target.DisplayName, change.Prayers, GodConfig.GodChange.PrayersNeeded))
		return true
	end

	-- Quest complete: switch god. Everything else is kept.
	data.SelectedGod = change.Target
	change.Target, change.Prayers = "", 0
	grantFirstBlessing(data, data.SelectedGod)
	refreshAll(player, data, true)
	message(player, ("You now worship %s, %s!"):format(target.DisplayName, target.Title))
	return true
end

-- Studio / owner test command: every blessing of the current god to max level.
function GodService.DebugMaxBlessings(player)
	local data = DataService.GetData(player)
	local god = data and GodConfig.Gods[data.SelectedGod]
	if not god then
		return false
	end
	data.Blessings[god.Id] = data.Blessings[god.Id] or {}
	for _, blessing in god.Blessings do
		data.Blessings[god.Id][blessing.Id] = MAX_LEVEL
	end
	refreshAll(player, data, false)
	return true
end

-- Studio / owner test command: add loyalty to the current god.
function GodService.AddLoyalty(player, amount)
	local data = DataService.GetData(player)
	amount = math.floor(tonumber(amount) or 0)
	if not data or data.SelectedGod == "" or amount <= 0 then
		return false
	end
	data.GodLoyalty[data.SelectedGod] = loyalty(data, data.SelectedGod) + amount
	pushAttributes(player, data)
	return true
end

return GodService
