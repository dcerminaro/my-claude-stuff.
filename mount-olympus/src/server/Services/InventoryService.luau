-- InventoryService (ModuleScript)
-- Location: ServerScriptService > Services > InventoryService
--
-- Phase 7C: weapons, all decided on the server.
--   * Saved in data.Inventory.Items = { { Uid, Id, Level }, ... } and
--     data.Inventory.EquippedWeapon = Uid. Uids are made here (never by the
--     client) and each weapon Id can only be owned once, so items can't be
--     duplicated. A duplicate drop is salvaged into Gold instead.
--   * Everyone owns the Bronze Sword.
--   * Equip anywhere; craft and upgrade at the Divine Forge (distance checked).
--   * Boss drops are rolled when an arena or trial with that boss is won.
-- The client sees: attribute "WeaponsJson" (owned weapons) and
-- "EquippedWeaponId", "EquippedWeaponLevel", "WeaponType", "WeaponCooldown",
-- "WeaponRange" (for the attack buttons and the forge screen).

local GameEvents = require(script.Parent:WaitForChild("GameEvents"))
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))
local WorldBuilder = require(ServerScriptService:WaitForChild("Services"):WaitForChild("WorldBuilder"))

local InventoryService = {}

local DataService = nil
local ProgressionService = nil
local notifyRemote = nil
local weaponChanged = nil -- callback(player) so CombatService can swap the model in hand

local FORGE_POSITION = Vector3.new(42, 1, -36)

local function message(player, text)
	if notifyRemote and player.Parent then
		notifyRemote:FireClient(player, "Message", text)
	end
end

local function findItem(data, key, value)
	for _, item in data.Inventory.Items do
		if item[key] == value then
			return item
		end
	end
	return nil
end

local function newItem(weaponId)
	return { Uid = HttpService:GenerateGUID(false), Id = weaponId, Level = 0 }
end

-- Keeps saved inventories valid: known weapons only, one of each, levels in range.
local function sanitize(data)
	local inventory = data.Inventory
	if type(inventory.Items) ~= "table" then
		inventory.Items = {}
	end
	local seen = {}
	local clean = {}
	for _, item in inventory.Items do
		local weapon = type(item) == "table" and WeaponConfig.Weapons[item.Id]
		if weapon and not seen[item.Id] and type(item.Uid) == "string" then
			seen[item.Id] = true
			local maxLevel = WeaponConfig.Rarities[weapon.Rarity].MaxLevel
			item.Level = math.clamp(math.floor(tonumber(item.Level) or 0), 0, maxLevel)
			table.insert(clean, item)
		end
	end
	inventory.Items = clean
	if not seen[WeaponConfig.StarterWeapon] then
		table.insert(inventory.Items, 1, newItem(WeaponConfig.StarterWeapon))
	end
	if not findItem(data, "Uid", inventory.EquippedWeapon) then
		inventory.EquippedWeapon = findItem(data, "Id", WeaponConfig.StarterWeapon).Uid
	end
end

local function push(player, data)
	local list = {}
	for _, item in data.Inventory.Items do
		table.insert(list, { Uid = item.Uid, Id = item.Id, Level = item.Level })
	end
	player:SetAttribute("WeaponsJson", HttpService:JSONEncode(list))
	local equipped = findItem(data, "Uid", data.Inventory.EquippedWeapon)
	local weapon = WeaponConfig.Weapons[equipped.Id]
	local kind = WeaponConfig.Types[weapon.Type]
	player:SetAttribute("EquippedWeaponId", equipped.Id)
	player:SetAttribute("EquippedWeaponUid", equipped.Uid)
	player:SetAttribute("EquippedWeaponLevel", equipped.Level)
	player:SetAttribute("WeaponType", weapon.Type)
	player:SetAttribute("WeaponCooldown", kind.Cooldown * weapon.Speed)
	player:SetAttribute("WeaponRange", kind.Range)
end

local function nearForge(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - FORGE_POSITION).Magnitude <= WeaponConfig.ForgeRange
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------

-- Everything combat needs about the equipped weapon.
function InventoryService.GetEquipped(player)
	local data = DataService.GetData(player)
	local item = data and findItem(data, "Uid", data.Inventory.EquippedWeapon)
	local weapon = item and WeaponConfig.Weapons[item.Id] or WeaponConfig.Weapons[WeaponConfig.StarterWeapon]
	local level = item and item.Level or 0
	local kind = WeaponConfig.Types[weapon.Type]
	local special = weapon.Special or {}
	return {
		Weapon = weapon,
		Level = level,
		Power = WeaponConfig.Power(weapon.Id, level),
		Type = weapon.Type,
		Range = kind.Range,
		ArcDot = kind.ArcDot,
		Width = kind.Width,
		Ranged = kind.Ranged == true,
		Cooldown = kind.Cooldown * weapon.Speed,
		MaxTargets = kind.MaxTargets + (special.ExtraTargets or 0) + (special.Pierce or 0),
		CritChance = special.CritChance or 0,
		LifeSteal = special.LifeSteal or 0,
		Combo = kind.Combo,
	}
end

-- Adds a weapon (or salvages a duplicate into Gold). Returns "New" or "Salvaged".
function InventoryService.GiveWeapon(player, weaponId)
	local data = DataService.GetData(player)
	local weapon = WeaponConfig.Weapons[weaponId]
	if not data or not weapon then
		return nil
	end
	if findItem(data, "Id", weaponId) then
		local gold = WeaponConfig.Rarities[weapon.Rarity].Salvage
		ProgressionService.AddCurrency(player, "Gold", gold, "Salvage")
		message(player, ("You already own the %s: salvaged for %d Gold."):format(weapon.Name, gold))
		return "Salvaged"
	end
	table.insert(data.Inventory.Items, newItem(weaponId))
	push(player, data)
	message(player, ("New weapon: %s (%s)!"):format(weapon.Name, WeaponConfig.Rarities[weapon.Rarity].Name))
	return "New"
end

function InventoryService.Equip(player, uid)
	local data = DataService.GetData(player)
	local item = data and type(uid) == "string" and findItem(data, "Uid", uid)
	if not item then
		return false
	end
	data.Inventory.EquippedWeapon = uid
	push(player, data)
	if weaponChanged then
		weaponChanged(player)
	end
	message(player, "Equipped " .. WeaponConfig.Weapons[item.Id].Name .. ".")
	return true
end

function InventoryService.Craft(player, weaponId)
	local data = DataService.GetData(player)
	local weapon = WeaponConfig.Weapons[weaponId]
	if not data or not weapon or not weapon.Cost then
		return false
	end
	if not nearForge(player) then
		message(player, "Crafting happens at the Divine Forge.")
		return false
	end
	if findItem(data, "Id", weaponId) then
		message(player, "You already own the " .. weapon.Name .. ".")
		return false
	end
	local gold, ambrosia = weapon.Cost.Gold or 0, weapon.Cost.Ambrosia or 0
	if (data.Currencies.Gold or 0) < gold or (data.Currencies.Ambrosia or 0) < ambrosia then
		message(player, ("You need %d Gold%s."):format(gold, if ambrosia > 0 then (" and %d Ambrosia"):format(ambrosia) else ""))
		return false
	end
	-- Both checked above with no yield in between, then both spent.
	if gold > 0 then
		ProgressionService.SpendCurrency(player, "Gold", gold)
	end
	if ambrosia > 0 then
		ProgressionService.SpendCurrency(player, "Ambrosia", ambrosia)
	end
	local crafted = InventoryService.GiveWeapon(player, weaponId) == "New"
	if crafted then
		GameEvents.Fire("CraftWeapon", player, weaponId)
	end
	return crafted
end

function InventoryService.Upgrade(player, uid)
	local data = DataService.GetData(player)
	local item = data and type(uid) == "string" and findItem(data, "Uid", uid)
	if not item then
		return false
	end
	if not nearForge(player) then
		message(player, "Upgrades happen at the Divine Forge.")
		return false
	end
	local weapon = WeaponConfig.Weapons[item.Id]
	local training = tonumber(data.Temple.Buildings.TrainingGrounds) or 0
	local gold, ambrosia = WeaponConfig.UpgradeCost(item.Id, item.Level, training)
	if not gold then
		message(player, weapon.Name .. " is fully upgraded.")
		return false
	end
	if (data.Currencies.Gold or 0) < gold or (data.Currencies.Ambrosia or 0) < ambrosia then
		message(player, ("Upgrading needs %d Gold%s."):format(gold, if ambrosia > 0 then (" and %d Ambrosia"):format(ambrosia) else ""))
		return false
	end
	ProgressionService.SpendCurrency(player, "Gold", gold)
	if ambrosia > 0 then
		ProgressionService.SpendCurrency(player, "Ambrosia", ambrosia)
	end
	item.Level += 1
	push(player, data)
	message(player, ("%s upgraded to +%d!"):format(weapon.Name, item.Level))
	GameEvents.Fire("UpgradeWeapon", player, item.Id)
	return true
end

-- Rolls the weapon drops for bosses beaten in a won arena/trial. Returns the names won.
function InventoryService.RollBossDrops(player, bossTypes)
	local won = {}
	for bossType in bossTypes do
		for id, weapon in WeaponConfig.Weapons do
			if weapon.Drop and weapon.Drop.Boss == bossType and math.random() < weapon.Drop.Chance then
				local result = InventoryService.GiveWeapon(player, id)
				if result then
					table.insert(won, weapon.Name .. (if result == "Salvaged" then " (salvaged)" else ""))
				end
			end
		end
	end
	return won
end

--------------------------------------------------------------------------
-- The Divine Forge (placeholder build in Olympus Plaza)
--------------------------------------------------------------------------
function InventoryService.BuildForge()
	local hub = Workspace:WaitForChild("Hub")
	local marker = hub:FindFirstChild("Divine Forge")
	if marker then
		marker:Destroy() -- the old "coming in Phase 7" marker
	end
	if hub:FindFirstChild("DivineForge") then
		return
	end
	local forge = Instance.new("Model")
	forge.Name = "DivineForge"
	local MP = WorldBuilder.MakePart
	local c = FORGE_POSITION
	MP(forge, { Name = "Floor", Size = Vector3.new(16, 0.6, 14), Position = c + Vector3.new(0, 0.3, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(90, 80, 75) })
	-- Furnace
	MP(forge, { Name = "Furnace", Size = Vector3.new(6, 6, 4), Position = c + Vector3.new(0, 3.6, 4), Material = Enum.Material.Brick, Color = Color3.fromRGB(120, 60, 45) })
	local mouth = MP(forge, { Name = "FurnaceFire", Size = Vector3.new(3, 2, 0.4), Position = c + Vector3.new(0, 2.6, 1.9), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 120, 30) })
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 12
	fire.Parent = mouth
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Range = 18
	light.Brightness = 2
	light.Parent = mouth
	MP(forge, { Name = "Chimney", Size = Vector3.new(2, 8, 2), Position = c + Vector3.new(0, 10.6, 5), Material = Enum.Material.Brick, Color = Color3.fromRGB(110, 55, 42) })
	-- Anvil
	MP(forge, { Name = "AnvilBase", Size = Vector3.new(1.6, 1.6, 1.4), Position = c + Vector3.new(0, 1.4, -2) , Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 60, 65) })
	local anvil = MP(forge, { Name = "Anvil", Size = Vector3.new(3.4, 0.9, 1.6), Position = c + Vector3.new(0, 2.6, -2), Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 70, 78) })
	WorldBuilder.AddLabel(anvil, "Divine Forge", Color3.fromRGB(255, 160, 60), 5)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Forge"
	prompt.ObjectText = "Divine Forge"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = anvil
	prompt.Triggered:Connect(function(player)
		notifyRemote:FireClient(player, "OpenWeapons", "Forge")
	end)
	forge.Parent = hub
end

--------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------
function InventoryService.Init(dataService, progressionService, notifyRemoteEvent, weaponRemote)
	DataService = dataService
	ProgressionService = progressionService
	notifyRemote = notifyRemoteEvent

	if weaponRemote then
		local last = {}
		weaponRemote.OnServerEvent:Connect(function(player, action, arg)
			local t = os.clock()
			if last[player] and t - last[player] < 0.4 then
				return
			end
			last[player] = t
			if type(arg) ~= "string" then
				return
			end
			if action == "Equip" then
				InventoryService.Equip(player, arg)
			elseif action == "Craft" then
				InventoryService.Craft(player, arg)
			elseif action == "Upgrade" then
				InventoryService.Upgrade(player, arg)
			end
		end)
	end
end

-- CombatService registers this to swap the weapon model when you equip.
function InventoryService.SetWeaponChangedHandler(handler)
	weaponChanged = handler
end

function InventoryService.SetupPlayer(player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	sanitize(data)
	push(player, data)
end

-- Test helper
function InventoryService._ForgePosition()
	return FORGE_POSITION
end

return InventoryService
