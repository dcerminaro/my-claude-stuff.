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

local GameEvents = require(script.Parent:WaitForChild("GameEvents"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
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
	local mods = { AttackPercent = 0, SpeedPercent = 0, DamageTaken = 1, LifeSteal = 0, RegenPercent = 0 }
	if not st then
		return mods
	end
	local now = os.clock()
	for id, buff in st.Buffs do
		if now < buff.Until then
			mods.AttackPercent += buff.AttackPercent
			mods.SpeedPercent += buff.SpeedPercent
			mods.DamageTaken *= buff.DamageTaken
			mods.LifeSteal += buff.LifeSteal or 0
			mods.RegenPercent += buff.RegenPercent or 0
		else
			st.Buffs[id] = nil
		end
	end
	return mods
end

-- Damage one point of "ability damage" is worth for this player.
local powerProvider = nil -- Phase 7C: function(player) -> equipped weapon power multiplier

local function baseDamage(player)
	local baseAttack = player:GetAttribute("BaseAttack") or 10
	local combatBonus = TempleService.GetEffect(player, "CombatBonusPercent") / 100
	local buff = activeBuffs(player).AttackPercent / 100
	local power = if powerProvider then powerProvider(player) else 1
	return baseAttack * power * (1 + combatBonus) * (1 + buff)
end

-- Everyone in the server, always including the caster.
local function everyone(player)
	local list = Players:GetPlayers()
	if not table.find(list, player) then
		table.insert(list, player)
	end
	return list
end

local function healPlayer(player, amount)
	local _, humanoid, root = getParts(player)
	if humanoid and amount >= 1 and humanoid.Health < humanoid.MaxHealth then
		local before = humanoid.Health
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
		local healed = math.floor(humanoid.Health - before)
		if healed >= 1 then
			fxRemote:FireAllClients("Damage", root.Position + Vector3.new(0, 3, 0), healed, "Heal")
		end
	end
end

-- Damages an enemy; `cfg.LifeSteal` (and life-steal buffs) heal the player.
local function hit(player, record, amount, knockback, cfg)
	if EnemyService.DamageEnemy(record.Model, amount, player, { Knockback = knockback }) then
		fxRemote:FireAllClients("Hit", record.Root.Position, record.Model, nil)
		local lifeSteal = (cfg and cfg.LifeSteal or 0) + activeBuffs(player).LifeSteal
		if lifeSteal > 0 then
			healPlayer(player, amount * lifeSteal)
		end
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
		hit(player, record, damage, nil, cfg)
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
				if hit(player, record, damage, nil, cfg) and struck < 6 then
					struck += 1
					fxRemote:FireAllClients("Lightning", record.Root.Position, color, 3, cfg.Straight == true)
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
		LifeSteal = cfg.LifeSteal or 0,
		RegenPercent = cfg.RegenPercent or 0,
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
			hit(player, record, damage, cfg.Knockback, cfg)
		end
	end
	fxRemote:FireAllClients("DashTrail", start, color, finish)
	if cfg.HealPercent then
		local _, humanoid = getParts(player)
		if humanoid then
			healPlayer(player, humanoid.MaxHealth * cfg.HealPercent / 100)
		end
	end
	if cfg.ShieldTime then
		state[player].Buffs[cfg.Id] = {
			Until = os.clock() + cfg.ShieldTime,
			AttackPercent = 0, SpeedPercent = 0, DamageTaken = cfg.ShieldDamageTaken or 0.5,
		}
		fxRemote:FireAllClients("Aura", Vector3.zero, color, player, cfg.ShieldTime)
	end
end

-- A piercing line (water blast, spear, arrow): hits the first few enemies in front.
function Kinds.Line(player, root, cfg, level, color)
	local look = flat(root.CFrame.LookVector).Unit
	local start = root.Position
	local finish = start + look * cfg.Range
	local damage = baseDamage(player) * AbilityConfig.DamageMultiplier(cfg.Id, level)
	local inLine = {}
	for _, record in EnemyService.GetEnemiesInRange(start, cfg.Range + 3) do
		local offset = flat(record.Root.Position - start)
		local along = offset:Dot(look)
		if along >= -1 and along <= cfg.Range + 1 and distanceToSegment(record.Root.Position, start, finish) <= cfg.Width / 2 + record.Root.Size.X / 2 then
			table.insert(inLine, { Record = record, Along = along })
		end
	end
	table.sort(inLine, function(a, b)
		return a.Along < b.Along
	end)
	for i = 1, math.min(#inLine, cfg.Pierce or 1) do
		hit(player, inLine[i].Record, damage, cfg.Knockback, cfg)
	end
	fxRemote:FireAllClients("Beam", start + Vector3.new(0, 1, 0), color, finish + Vector3.new(0, 1, 0), cfg.Width)
end

-- A whirlpool in front: pulls enemies in, slows them, and damages them over time.
function Kinds.Pull(player, root, cfg, level, color)
	local center = root.Position + flat(root.CFrame.LookVector).Unit * cfg.Offset
	for _, record in EnemyService.GetEnemiesInRange(center, cfg.Radius) do
		local toward = flat(center - record.Root.Position)
		if toward.Magnitude > 1 then
			EnemyService.Push(record.Model, toward.Unit * 14, 0.5)
		end
		EnemyService.Slow(record.Model, cfg.Slow, cfg.SlowTime)
	end
	for tick = 1, cfg.Ticks do
		task.delay((tick - 1) * cfg.Interval + 0.2, function()
			local damage = baseDamage(player) * AbilityConfig.DamageMultiplier(cfg.Id, level)
			for _, record in EnemyService.GetEnemiesInRange(center, cfg.Radius) do
				hit(player, record, damage, 0, cfg)
			end
		end)
	end
	fxRemote:FireAllClients("Vortex", center, color, cfg.Radius, cfg.Ticks * cfg.Interval + 0.3)
end

-- A wave crashing forward in a cone.
function Kinds.Cone(player, root, cfg, level, color)
	local damage = baseDamage(player) * AbilityConfig.DamageMultiplier(cfg.Id, level)
	local look = flat(root.CFrame.LookVector).Unit
	for _, record in EnemyService.GetEnemiesInRange(root.Position, cfg.Range + 3) do
		local offset = flat(record.Root.Position - root.Position)
		if offset.Magnitude <= cfg.Range + 1.5 and (offset.Magnitude < 1.5 or look:Dot(offset.Unit) >= cfg.ArcDot) then
			hit(player, record, damage, cfg.Knockback, cfg)
		end
	end
	fxRemote:FireAllClients("Wave", root.Position, color, root.CFrame.LookVector, cfg.Range)
end

-- Spectral spirits circle the player and attack nearby enemies.
function Kinds.Summon(player, root, cfg, level, color)
	local character = root.Parent
	local count = math.floor(cfg.Count + (cfg.CountPerLevel or 0) * (level - 1))
	local spirits = {}
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local orb = Instance.new("Part")
		orb.Name = "Spirit"
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(1.3, 1.3, 1.3)
		orb.Material = Enum.Material.Neon
		orb.Color = color
		orb.Transparency = 0.2
		orb.CanCollide = false
		orb.CanQuery = false
		orb.CanTouch = false
		orb.Massless = true
		orb.CFrame = root.CFrame * CFrame.new(math.cos(angle) * 3, 2.5, math.sin(angle) * 3)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = orb
		weld.Parent = orb
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 8
		light.Parent = orb
		orb.Parent = character
		table.insert(spirits, orb)
	end
	local ticks = math.floor(cfg.Duration / cfg.Interval)
	for tick = 1, ticks do
		task.delay(tick * cfg.Interval, function()
			local damage = baseDamage(player) * AbilityConfig.DamageMultiplier(cfg.Id, level)
			for _, orb in spirits do
				if orb.Parent then
					local best, bestDistance = nil, math.huge
					for _, record in EnemyService.GetEnemiesInRange(orb.Position, cfg.Range) do
						local d = (record.Root.Position - orb.Position).Magnitude
						if d < bestDistance then
							best, bestDistance = record, d
						end
					end
					if best and hit(player, best, damage, 0, cfg) then
						fxRemote:FireAllClients("Chain", orb.Position, color, { orb.Position, best.Root.Position })
					end
				end
			end
		end)
	end
	task.delay(cfg.Duration + 0.1, function()
		for _, orb in spirits do
			orb:Destroy()
		end
	end)
end

-- Parry: for a moment, hits against you are blocked and struck back.
function Kinds.Counter(player, _root, cfg, level, color)
	state[player].Counter = {
		Until = os.clock() + cfg.Duration,
		Multiplier = AbilityConfig.DamageMultiplier(cfg.Id, level),
		Color = color,
	}
	fxRemote:FireAllClients("Aura", Vector3.zero, color, player, cfg.Duration)
end

-- A great shield: you and nearby allies take less damage; enemies are blasted away.
function Kinds.Aegis(player, root, cfg, level, color)
	task.delay(0.5, function()
		local _, _, liveRoot = getParts(player)
		local center = if liveRoot then liveRoot.Position else root.Position
		local damage = baseDamage(player) * AbilityConfig.DamageMultiplier(cfg.Id, level)
		for _, record in EnemyService.GetEnemiesInRange(center, cfg.Radius) do
			hit(player, record, damage, cfg.Knockback, cfg)
		end
		for _, ally in everyone(player) do
			local _, _, allyRoot = getParts(ally)
			if allyRoot and state[ally] and (allyRoot.Position - center).Magnitude <= cfg.Radius then
				state[ally].Buffs["Aegis"] = {
					Until = os.clock() + cfg.Duration,
					AttackPercent = 0, SpeedPercent = 0, DamageTaken = cfg.DamageTaken,
				}
				fxRemote:FireAllClients("Aura", Vector3.zero, color, ally, cfg.Duration)
			end
		end
		fxRemote:FireAllClients("Dome", center, color, cfg.Radius, cfg.Duration)
		fxRemote:FireAllClients("Shockwave", center, color, cfg.Radius)
	end)
end

-- Heals you and nearby allies.
function Kinds.Heal(player, root, cfg, level, color)
	local percent = cfg.HealPercent + (cfg.HealPerLevel or 0) * (level - 1)
	for _, ally in everyone(player) do
		local _, humanoid, allyRoot = getParts(ally)
		if humanoid and (allyRoot.Position - root.Position).Magnitude <= cfg.Radius then
			healPlayer(ally, humanoid.MaxHealth * percent / 100)
		end
	end
	fxRemote:FireAllClients("HealBurst", root.Position, color, cfg.Radius)
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
	GameEvents.Fire("UseAbility", player, data.SelectedGod)
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

-- Athena's Counterattack: called by CombatService when an enemy hits the
-- player. Returns true if the hit was parried (and strikes back).
function AbilityService.TryCounter(player, attackerModel)
	local st = state[player]
	local counter = st and st.Counter
	if not counter or os.clock() > counter.Until then
		return false
	end
	if typeof(attackerModel) == "Instance" then
		local root = attackerModel:FindFirstChild("HumanoidRootPart")
		local damage = baseDamage(player) * counter.Multiplier
		if EnemyService.DamageEnemy(attackerModel, damage, player, { Knockback = 20 }) and root then
			fxRemote:FireAllClients("Hit", root.Position, attackerModel, nil)
			fxRemote:FireAllClients("Lightning", root.Position, counter.Color, 3, true)
		end
	end
	return true
end

-- { AttackPercent, SpeedPercent, DamageTaken, LifeSteal, RegenPercent } from active buffs.
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

	-- Healing-over-time buffs (Oceanic Ascension, Sun God Form).
	task.spawn(function()
		while true do
			task.wait(1)
			for player in state do
				local regen = activeBuffs(player).RegenPercent
				if regen > 0 then
					local _, humanoid = getParts(player)
					if humanoid then
						healPlayer(player, humanoid.MaxHealth * regen / 100)
					end
				end
			end
		end
	end)

	if abilityRemote then
		abilityRemote.OnServerEvent:Connect(function(player, slot, aim)
			if slot == "Q" or slot == "E" or slot == "R" or slot == "Form" then
				CombatService.ApplyAim(player, aim) -- face the aim dot (fighting areas only)
				AbilityService.UseAbility(player, slot)
			end
		end)
	end
end

function AbilityService.SetPowerProvider(provider)
	powerProvider = provider
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
