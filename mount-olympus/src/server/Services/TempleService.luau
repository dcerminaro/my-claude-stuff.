-- TempleService (ModuleScript)
-- Location: ServerScriptService > Services > TempleService
--
-- The Temple Tycoon, all on the server:
--   * Builds each player's temple and buildings from their SAVED data
--     (data.Temple) when they join, on whichever plot they get.
--   * Glowing purchase pads (with a hold-to-buy prompt) on the owner's plot.
--     Only the plot's owner can buy; checked against the plot's OwnerUserId.
--   * Validates every purchase (level, temple tier, character level, Gold).
--   * Plays the construction animation and saves the new level.
--   * Pays passive income (Gold Treasury -> Gold, Main Altar -> Divine Favor)
--     only while the player is in the game.
--
-- Other systems can read temple bonuses with:
--   TempleService.GetEffect(player, "CombatBonusPercent")  -> number

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TempleConfig = require(Shared:WaitForChild("TempleConfig"))
local Progression = require(Shared:WaitForChild("Progression"))

local Services = ServerScriptService:WaitForChild("Services")
local TempleModels = require(Services:WaitForChild("TempleModels"))
local WorldBuilder = require(Services:WaitForChild("WorldBuilder"))

local TempleService = {}

local DataService = nil
local ProgressionService = nil
local PlotService = nil
local notifyRemote = nil

local MAX_LEVEL = TempleConfig.MaxBuildingLevel
local PAD_READY = Color3.fromRGB(120, 230, 120)
local PAD_TOO_EXPENSIVE = Color3.fromRGB(230, 120, 80)
local PAD_LOCKED = Color3.fromRGB(150, 150, 160)
local PAD_MAXED = Color3.fromRGB(212, 175, 55)

-- [Player] = { Plot, Pads = { [id] = { Part, Label, Prompt } }, Income = { Gold, DivineFavor }, LastRequest, Connections }
local state = {}

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------
local function notify(player, text)
	if notifyRemote and player.Parent then
		notifyRemote:FireClient(player, "Message", text)
	end
end

local function getLevel(data, buildingId)
	return tonumber(data.Temple.Buildings[buildingId]) or 0
end

-- Makes sure saved temple data is valid (whole numbers, 0-5) and the tier matches the Core.
local function sanitizeTemple(data)
	local buildings = data.Temple.Buildings
	for id in TempleConfig.Buildings do
		local level = math.clamp(math.floor(tonumber(buildings[id]) or 0), 0, MAX_LEVEL)
		buildings[id] = if level > 0 then level else nil
	end
	data.Temple.Tier = TempleConfig.TierFromCoreLevel(buildings.TempleCore)
end

local function slotCFrame(plot, offset)
	local base = plot:FindFirstChild("Base")
	local top = base.Position.Y + base.Size.Y / 2
	return CFrame.new(base.Position.X + offset.X, top, base.Position.Z + offset.Z)
end

-- Publishes temple values so the upgrade menu can show them.
local function pushAttributes(player, data)
	player:SetAttribute("TempleTier", data.Temple.Tier)
	player:SetAttribute("TempleTierName", TempleConfig.GetTierName(data.Temple.Tier))
	for id in TempleConfig.Buildings do
		player:SetAttribute("Temple_" .. id, getLevel(data, id))
	end
	player:SetAttribute("GoldPerMinute", TempleConfig.GetEffectValue("GoldTreasury", getLevel(data, "GoldTreasury")))
	player:SetAttribute("FavorPerMinute", TempleConfig.GetEffectValue("MainAltar", getLevel(data, "MainAltar")))
end

--------------------------------------------------------------------------
-- Building the models on the plot
--------------------------------------------------------------------------
local function placeTemple(player, data, animate)
	local st = state[player]
	local buildings = st.Plot:FindFirstChild("Buildings")
	local old = buildings:FindFirstChild("Temple")
	if old then
		old:Destroy()
	end
	local model = TempleModels.Temple(data.Temple.Tier, slotCFrame(st.Plot, TempleConfig.Buildings.TempleCore.Slot))
	if animate then
		TempleModels.AnimateIn(model, 1.8)
	end
	model.Parent = buildings
end

local function placeBuilding(player, data, buildingId, animate)
	local st = state[player]
	local buildings = st.Plot:FindFirstChild("Buildings")
	local old = buildings:FindFirstChild(buildingId)
	if old then
		old:Destroy()
	end
	local model = TempleModels.Building(buildingId, getLevel(data, buildingId), slotCFrame(st.Plot, TempleConfig.Buildings[buildingId].Slot))
	if not model then
		return
	end
	if animate then
		TempleModels.AnimateIn(model)
	end
	model.Parent = buildings
end

local function placeEverything(player, data)
	local buildings = state[player].Plot:FindFirstChild("Buildings")
	buildings:ClearAllChildren()
	placeTemple(player, data, false)
	for id, info in TempleConfig.Buildings do
		if not info.IsCore then
			placeBuilding(player, data, id, false)
		end
	end
end

--------------------------------------------------------------------------
-- Purchase pads
--------------------------------------------------------------------------
local function refreshPads(player)
	local st = state[player]
	local data = DataService.GetData(player)
	if not st or not data then
		return
	end
	local gold = data.Currencies.Gold or 0

	for id, pad in st.Pads do
		local info = TempleConfig.Buildings[id]
		local level = getLevel(data, id)
		local upgrade = TempleConfig.GetUpgradeInfo(id, level, data.Temple.Tier, data.Level)
		local name = info.DisplayName

		if upgrade.Maxed then
			pad.Label.Text = name .. "\nMAX LEVEL"
			pad.Part.Color = PAD_MAXED
			pad.Prompt.Enabled = false
		elseif upgrade.Blocked then
			pad.Label.Text = ("%s  Lv %d\nLocked: %s"):format(name, level, upgrade.Blocked)
			pad.Part.Color = PAD_LOCKED
			pad.Prompt.Enabled = true
			pad.Prompt.ActionText = "Locked"
			pad.Prompt.ObjectText = name
		else
			local costText = Progression.FormatNumber(upgrade.Cost) .. " Gold"
			if level == 0 then
				pad.Label.Text = ("Build %s\n%s"):format(name, costText)
			else
				pad.Label.Text = ("%s  Lv %d -> %d\n%s"):format(name, level, upgrade.NextLevel, costText)
			end
			pad.Part.Color = if gold >= upgrade.Cost then PAD_READY else PAD_TOO_EXPENSIVE
			pad.Prompt.Enabled = true
			pad.Prompt.ActionText = if level == 0 then "Build" else "Upgrade"
			pad.Prompt.ObjectText = name .. " (" .. costText .. ")"
		end
	end
end

local function createPads(player)
	local st = state[player]
	local plot = st.Plot
	local padsFolder = plot:FindFirstChild("Pads")
	if not padsFolder then
		padsFolder = Instance.new("Folder")
		padsFolder.Name = "Pads"
		padsFolder.Parent = plot
	end
	padsFolder:ClearAllChildren()

	for id, info in TempleConfig.Buildings do
		local part = WorldBuilder.MakePart(padsFolder, {
			Name = "Pad_" .. id,
			Size = Vector3.new(6, 0.4, 6),
			CFrame = slotCFrame(plot, info.Pad) * CFrame.new(0, 0.2, 0),
			Material = Enum.Material.Neon,
			Color = PAD_LOCKED,
			Transparency = 0.15,
		})
		local label = WorldBuilder.AddLabel(part, info.DisplayName, Color3.new(1, 1, 1), 4)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Build"
		prompt.ObjectText = info.DisplayName
		prompt.HoldDuration = 0.4 -- a short hold stops accidental purchases
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.Parent = part

		prompt.Triggered:Connect(function(who)
			-- Ownership check: only this plot's owner may change it.
			if plot:GetAttribute("OwnerUserId") ~= who.UserId then
				notify(who, "This is not your temple.")
				return
			end
			TempleService.RequestUpgrade(who, id)
		end)

		st.Pads[id] = { Part = part, Label = label, Prompt = prompt }
	end
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------
function TempleService.Init(dataService, progressionService, plotService, notifyRemoteEvent, upgradeRemote)
	DataService = dataService
	ProgressionService = progressionService
	PlotService = plotService
	notifyRemote = notifyRemoteEvent

	-- Upgrade requests from the menu. Never trust the client: check everything.
	if upgradeRemote then
		upgradeRemote.OnServerEvent:Connect(function(player, buildingId)
			if type(buildingId) ~= "string" or not TempleConfig.Buildings[buildingId] then
				return
			end
			TempleService.RequestUpgrade(player, buildingId)
		end)
	end

	-- Passive income loop
	task.spawn(function()
		local interval = TempleConfig.IncomeInterval
		while true do
			task.wait(interval)
			TempleService.PayIncome(interval)
		end
	end)
end

-- Call after the player's data has loaded and they have a plot.
function TempleService.SetupPlayer(player, plot)
	local data = DataService.GetData(player)
	if not data or not plot then
		return
	end
	sanitizeTemple(data)

	state[player] = {
		Plot = plot,
		Pads = {},
		Income = { Gold = 0, DivineFavor = 0 },
		LastRequest = 0,
		Connections = {},
	}

	placeEverything(player, data)
	createPads(player)
	pushAttributes(player, data)
	refreshPads(player)

	-- Keep pad colours/labels in sync when Gold or level changes from anywhere.
	local st = state[player]
	for _, attribute in { "Gold", "Level" } do
		table.insert(st.Connections, player:GetAttributeChangedSignal(attribute):Connect(function()
			refreshPads(player)
		end))
	end
end

-- Call when the player leaves (before PlotService.ReleasePlot).
function TempleService.ReleasePlayer(player)
	local st = state[player]
	if not st then
		return
	end
	state[player] = nil
	for _, connection in st.Connections do
		connection:Disconnect()
	end
	local pads = st.Plot:FindFirstChild("Pads")
	if pads then
		pads:ClearAllChildren()
	end
end

-- Rebuilds the plot from saved data (used after the !reset debug command).
function TempleService.Rebuild(player)
	local data = DataService.GetData(player)
	if not data or not state[player] then
		return
	end
	sanitizeTemple(data)
	placeEverything(player, data)
	pushAttributes(player, data)
	refreshPads(player)
end

-- Validates and performs one upgrade. Returns true if it happened.
function TempleService.RequestUpgrade(player, buildingId)
	local st = state[player]
	local data = DataService.GetData(player)
	local info = TempleConfig.Buildings[buildingId]
	if not st or not data or not info then
		return false
	end
	if PlotService.GetPlot(player) ~= st.Plot or st.Plot:GetAttribute("OwnerUserId") ~= player.UserId then
		return false
	end

	local now = os.clock()
	if now - st.LastRequest < TempleConfig.UpgradeCooldown then
		return false
	end
	st.LastRequest = now

	local level = getLevel(data, buildingId)
	local upgrade = TempleConfig.GetUpgradeInfo(buildingId, level, data.Temple.Tier, data.Level)
	if upgrade.Maxed then
		notify(player, info.DisplayName .. " is already at max level.")
		return false
	end
	if upgrade.Blocked then
		notify(player, upgrade.Blocked .. " to upgrade the " .. info.DisplayName .. ".")
		return false
	end

	-- SpendCurrency checks and subtracts without yielding, so double-clicks can't double-spend.
	if not ProgressionService.SpendCurrency(player, "Gold", upgrade.Cost) then
		local missing = upgrade.Cost - (data.Currencies.Gold or 0)
		notify(player, ("You need %s more Gold."):format(Progression.FormatNumber(missing)))
		return false
	end

	data.Temple.Buildings[buildingId] = upgrade.NextLevel

	if info.IsCore then
		data.Temple.Tier = TempleConfig.TierFromCoreLevel(upgrade.NextLevel)
		placeTemple(player, data, true)
		notify(player, ("Your temple is now a %s!"):format(TempleConfig.GetTierName(data.Temple.Tier)))
	else
		placeBuilding(player, data, buildingId, true)
		notify(player, ("%s reached level %d!"):format(info.DisplayName, upgrade.NextLevel))
	end

	pushAttributes(player, data)
	refreshPads(player)
	return true
end

-- Total of one effect across all buildings, e.g. "CombatBonusPercent".
function TempleService.GetEffect(player, effect)
	local data = DataService.GetData(player)
	if not data then
		return 0
	end
	local total = 0
	for id, info in TempleConfig.Buildings do
		if info.Effect == effect then
			total += TempleConfig.GetEffectValue(id, getLevel(data, id))
		end
	end
	return total
end

-- Pays `seconds` worth of income to everyone in the game. Fractions carry over.
function TempleService.PayIncome(seconds)
	for player, st in state do
		local data = DataService.GetData(player)
		if data and player.Parent then
			local rates = {
				Gold = TempleService.GetEffect(player, "GoldPerMinute"),
				DivineFavor = TempleService.GetEffect(player, "FavorPerMinute"),
			}
			for currency, perMinute in rates do
				if perMinute > 0 then
					st.Income[currency] += perMinute * seconds / 60
					local whole = math.floor(st.Income[currency])
					if whole > 0 then
						st.Income[currency] -= whole
						ProgressionService.AddCurrency(player, currency, whole, "Temple")
					end
				end
			end
		end
	end
end

return TempleService
