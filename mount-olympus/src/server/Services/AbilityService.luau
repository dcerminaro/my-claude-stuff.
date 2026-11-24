-- AbilityService (ModuleScript)
-- Location: ServerScriptService > Services > AbilityService
--
-- God abilities (Phase 4B), all decided on the server:
--   * The client only says "use slot Q/E/R/Form" (or that it dashed).
--   * The server finds the active god's blessing for that slot, checks the
--     blessing is unlocked, the cooldown, and that the player is alive and
--     not blocking, then works out targets and damage itself.
--   * Abilities of gods you don't currently worship can't be used.
--   * Cooldowns are published as player attributes "Cooldown_<slot>"
--     (the server time when the slot is ready again) for the buttons.
--   * Buffs (Forms, Berserker Rage) add attack %, speed % and/or damage
--     reduction for a few seconds.
-- Visuals are drawn on every device from CombatFX events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbilityConfig = require(Shared:WaitForChild("AbilityConfig"))
local GodConfig = require(Shared:WaitForChild("GodConfig"))

local AbilityService = {}

local DataService = nil
local ProgressionService = nil
local TempleService = nil
local EnemyService = nil
local GodService = nil
local fxRemote = nil

local state = {} -- [Player] = { ReadyAt = { [slot] = os.clock() }, Buffs = { [abilityId] = { Until, ... } } }

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function getParts(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return character, humanoid, root
	end
	return nil
end

local function godColor(player)
	local data = DataService.GetData(player)
	return GodConfig.GetColors(data and data.SelectedGod or "").Primary
end

-- The active god's blessing for a slot, and its level (0 = locked).
local function blessingForSlot(data, slot)
	local god = GodConfig.Gods[data.SelectedGod]
	if not god then
		return nil, 0
	end
	for _, blessing in god.Blessings do
		if blessing.Ability == slot then
			local tree = data.Blessings[god.Id]
			local level = if type(tree) == "table" then tonumber(tree[blessing.Id]) or 0 else 0
			return blessing, level
		end
	end
	return nil, 0
end

local function activeBuffs(player)
	local st = state[player]
	local mods = { AttackPercent = 0, SpeedPercent = 0, DamageTaken = 1 }
	if not st then
		return mods
	end
	local now = os.clock()
	for id, buff in st.Buffs do
		if now < buff.Until then
			mods.AttackPercent += buff.AttackPercent
			mods.SpeedPercent += buff.SpeedPercent
			mods.DamageTaken *= buff.DamageTaken
		else
			st.Buffs[id] = nil
		end
	end
	return mods
end

-- Damage one point of "ability damage" is worth for this player.
local function baseDamage(player)
	local baseAttack = player:GetAttribute("BaseAttack") or 10
	local combatBonus = TempleService.GetEffect(player, "CombatBonusPercent") / 100
	local buff = activeBuffs(player).AttackPercent / 100
	return baseAttack * (1 + combatBonus) * (1 + buff)
end

local function hit(player, record, amount, knockback)
	if EnemyService.DamageEnemy(record.Model, amount, player, { Knockback = knockback }) then
		fxRemote:FireAllClients("Hit", record.Root.Position, record.Model, nil)
		return true
	end
	return false
end

-- Enemies in range, those in front first, then by distance.
local function enemiesNear(root, range)
	local look = flat(root.CFrame.LookVector).Unit
	local list = {}
	for _, record in EnemyService.GetEnemiesInRange(root.Position, range) do
		local offset = flat(record.Root.Position - root.Position)
		local inFront = offset.Magnitude < 1 or look:Dot(offset.Unit) > 0.3
		table.insert(list, { Record = record, Distance = offset.Magnitude, InFront = inFront })
	end
	table.sort(list, function(a, b)
		if a.InFront ~= b.InFront then
			return a.InFront
		end
		return a.Distance < b.Distance
	end)
	return list
end

local function distanceToSegment(point, a, b)
	local ab = flat(b - a)
	local ap = flat(point - a)
	local length = ab.Magnitude
	if length < 0.01 then
		return ap.Magnitude
	end
	local t = math.clamp(ap:Dot(ab) / (length * length), 0, 1)
	return (ap - ab * t).Magnitude
end

-- Lets other players' screens play the same move.
local function broadcastMove(player, moveName)
	if not moveName then
		return
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			fxRemote:FireClient(other, "Swing", player, moveName)
		end
	end
end

--------------------------------------------------------------------------
-- What each kind of ability does
--------------------------------------------------------------------------
local Kinds = {}

-- A bolt from the sky on the best target, damaging everything around it.
function Kinds.Strike(player, root, cfg, level, color)
	local best = enemiesNear(root, cfg.Range)[1]
	local point = if best then best.Record.Root.Position else root.Position + flat(root.CFrame.LookVector).Unit * 12
	local damage = baseDamage(player) * AbilityConfig.DamageMultiplier(cfg.Id, level)
	for _, record in EnemyService.GetEnemiesInRange(point, cfg.Radius) do
		hit(player, record, damage)
	end
	fxRemote:FireAllClients("Lightning", point, color, cfg.Radius)
end

-- Jumps from enemy to enemy, weaker each time.
function Kinds.Chain(player, root, cfg, level, color)
	local first = enemiesNear(root, cfg.Range)[1]
	local points = { root.Position + Vector3.new(0, 2, 0) }
	if first then
		local damage = baseDamage(player) * AbilityConfig.DamageMultiplier(cfg.Id, level)
		local current = first.Record
		local done = {}
		local jumps = cfg.Jumps + (cfg.JumpsPerLevel or 0) * (level - 1)
		for _ = 0, jumps do
			done[current] = true
			hit(player, current, damage)
			table.insert(points, current.Root.Position)
			damage *= cfg.Falloff
			local nextRecord, nextDistance = nil, math.huge
			for _, record in EnemyService.GetEnemiesInRange(current.Root.Position, cfg.JumpRange) do
				local d = (record.Root.Position - current.Root.Position).Magnitude
				if not done[record] and d < nextDistance then
					nextRecord, nextDistance = record, d
				end
			end
			if not nextRecord then
				break
			end
			current = nextRecord
		end
	else
		table.insert(points, root.Position + flat(root.CFrame.LookVector).Unit * 14 + Vector3.new(0, 2, 0))
	end
	fxRemote:FireAllClients("Chain", root.Position, color, points)
end

-- Several lightning pulses around the player.
function Kinds.Storm(player, _root, cfg, level, color)
	for pulse = 1, cfg.Pulses do
		task.delay((pulse - 1) * cfg.Interval + 0.3, function()
			local _, _, root = getParts(player)
			if not root then
				return
			end
			local damage = baseDamage(player) * AbilityConfig.DamageMultiplier(cfg.Id, level)
			local struck = 0
			for _, record in EnemyService.GetEnemiesInRange(root.Position, cfg.Radius) do
				if hit(player, record, damage) and struck < 6 then
					struck += 1
					fxRemote:FireAllClients("Lightning", record.Root.Position, color, 3)
				end
			end
			fxRemote:FireAllClients("Shockwave", root.Position, color, cfg.Radius)
		end)
	end
end

-- A wide swing in front with knockback.
function Kinds.Cleave(player, root, cfg, level, color)
	local damage = baseDamage(player) * AbilityConfig.DamageMultiplier(cfg.Id, level)
	local look = flat(root.CFrame.LookVector).Unit
	for _, record in EnemyService.GetEnemiesInRange(root.Position, cfg.Range + 3) do
		local offset = flat(record.Root.Position - root.Position)
		if offset.Magnitude <= cfg.Range + 1.5 and (offset.Magnitude < 1.5 or look:Dot(offset.Unit) >= cfg.ArcDot) then
			hit(player, record, damage, cfg.Knockback)
		end
	end
	fxRemote:FireAllClients("Cleave", root.Position, color, root.CFrame.LookVector, cfg.Range)
end

-- Jump-slam: damage around the player when the sword hits the ground.
function Kinds.Slam(player, _root, cfg, level, color)
	task.delay(cfg.Delay, function()
		local _, _, root = getParts(player)
		if not root then
			return
		end
		local damage = baseDamage(player) * AbilityConfig.DamageMultiplier(cfg.Id, level)
		for _, record in EnemyService.GetEnemiesInRange(root.Position, cfg.Radius) do
			hit(player, record, damage, cfg.Knockback)
		end
		fxRemote:FireAllClients("Shockwave", root.Position, color, cfg.Radius)
	end)
end

-- A timed power-up with an aura.
function Kinds.Buff(player, _root, cfg, level, color)
	local st = state[player]
	st.Buffs[cfg.Id] = {
		Until = os.clock() + cfg.Duration,
		AttackPercent = (cfg.AttackPercent or 0) + (cfg.AttackPerLevel or 0) * (level - 1),
		SpeedPercent = cfg.SpeedPercent or 0,
		DamageTaken = cfg.DamageTaken or 1,
	}
	ProgressionService.RefreshStats(player) -- applies the speed bonus now
	task.delay(cfg.Duration + 0.05, function()
		if state[player] then
			activeBuffs(player) -- clears it
			ProgressionService.RefreshStats(player)
		end
	end)
	fxRemote:FireAllClients("Aura", Vector3.zero, color, player, cfg.Duration)
end

-- Upgraded dash: damages enemies along the dash path.
function Kinds.DashHit(player, root, cfg, level, color, direction)
	local start = root.Position
	local finish = start + direction * cfg.Distance
	local damage = baseDamage(player) * AbilityConfig.DamageMultiplier(cfg.Id, level)
	for _, record in EnemyService.GetEnemiesInRange(start, cfg.Distance + cfg.Width) do
		if distanceToSegment(record.Root.Position, start, finish) <= cfg.Width / 2 + record.Root.Size.X / 2 then
			hit(player, record, damage, cfg.Knockback)
		end
	end
	fxRemote:FireAllClients("DashTrail", start, color, finish)
end

--------------------------------------------------------------------------
-- Using abilities
--------------------------------------------------------------------------
local function setCooldown(player, slot, seconds)
	local st = state[player]
	st.ReadyAt[slot] = os.clock() + seconds
	player:SetAttribute("Cooldown_" .. slot, Workspace:GetServerTimeNow() + seconds)
end

-- Returns true if the ability was used.
function AbilityService.UseAbility(player, slot, direction)
	local st = state[player]
	local data = DataService.GetData(player)
	local _, _, root = getParts(player)
	if not st or not data or not root or player:GetAttribute("Blocking") == true then
		return false
	end
	local blessing, level = blessingForSlot(data, slot)
	if not blessing or level < 1 then
		return false -- locked, or this god has no ability here
	end
	local cfg = AbilityConfig.Abilities[blessing.Id]
	if not cfg or not Kinds[cfg.Kind] then
		return false
	end
	if os.clock() < (st.ReadyAt[slot] or 0) - 0.1 then
		return false -- still cooling down (small allowance for network timing)
	end
	setCooldown(player, slot, cfg.Cooldown)

	broadcastMove(player, cfg.Move)
	Kinds[cfg.Kind](player, root, cfg, level, godColor(player), direction)
	return true
end

-- Called by CombatService after a dash: runs the god's dash ability if unlocked and ready.
function AbilityService.OnDash(player, direction)
	if typeof(direction) ~= "Vector3" or direction ~= direction then
		return
	end
	direction = flat(direction)
	if direction.Magnitude < 0.1 then
		return
	end
	AbilityService.UseAbility(player, "Dash", direction.Unit)
end

-- { AttackPercent, SpeedPercent, DamageTaken } from active buffs.
function AbilityService.GetModifiers(player)
	return activeBuffs(player)
end

function AbilityService.Init(dataService, progressionService, templeService, enemyService, godService, fxRemoteEvent, abilityRemote)
	DataService = dataService
	ProgressionService = progressionService
	TempleService = templeService
	EnemyService = enemyService
	GodService = godService
	fxRemote = fxRemoteEvent

	-- Speed from buffs joins the blessing bonuses that ProgressionService applies.
	ProgressionService.SetBonusProvider(function(player)
		local bonuses = GodService.GetBonuses(player)
		bonuses.SpeedPercent += activeBuffs(player).SpeedPercent
		return bonuses
	end)

	if abilityRemote then
		abilityRemote.OnServerEvent:Connect(function(player, slot)
			if slot == "Q" or slot == "E" or slot == "R" or slot == "Form" then
				AbilityService.UseAbility(player, slot)
			end
		end)
	end
end

function AbilityService.SetupPlayer(player)
	state[player] = { ReadyAt = {}, Buffs = {} }
	for _, slot in { "Q", "E", "R", "Form", "Dash" } do
		player:SetAttribute("Cooldown_" .. slot, 0)
	end
end

function AbilityService.ReleasePlayer(player)
	state[player] = nil
end

return AbilityService
