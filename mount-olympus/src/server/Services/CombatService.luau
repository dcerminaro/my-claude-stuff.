-- CombatService (ModuleScript)
-- Location: ServerScriptService > Services > CombatService
--
-- The player side of combat, all checked on the server:
--   * Basic attack: the client only says "I swung". The server checks the
--     cooldown, finds enemies in front of the player, and works out damage
--     (BaseAttack incl. blessings, x Training Grounds bonus).
--   * Block: less damage taken, slower movement, can't attack.
--   * Dash: the client moves itself; the server grants a short moment where
--     you can't be hit (with its own cooldown, so it can't be spammed).
--   * Damage to players (from enemies), damage numbers.
--   * Health regeneration (replaces Roblox's default), boosted by the
--     Divine Fountain.
--   * Gives every player a placeholder sword welded into their hand that
--     glows in their god's colour and leaves a light trail when swung.
--     Real weapons come in Phase 7. The swing animations themselves are
--     played on each device by SwordAnimator.
--
-- Other systems call: CombatService.DamagePlayer(player, amount, sourcePosition)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local GodConfig = require(Shared:WaitForChild("GodConfig"))
local SwordBuilder = require(Shared:WaitForChild("SwordBuilder"))
local SwordPoses = require(Shared:WaitForChild("SwordPoses"))

local CombatService = {}

local TempleService = nil
local EnemyService = nil
local fxRemote = nil

local CFG = CombatConfig.Player
local state = {} -- [Player] = { NextAttackAt, NextDashAt, InvulnerableUntil, Blocking, SavedWalkSpeed, Shield, LastDamagedAt }
local random = Random.new()

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------
local function getParts(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return character, humanoid, root
	end
	return nil
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function setBlocking(player, on)
	local st = state[player]
	if not st or st.Blocking == on then
		return
	end
	local _, humanoid, root = getParts(player)
	st.Blocking = on
	player:SetAttribute("Blocking", on)

	if on then
		if humanoid then
			st.SavedWalkSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = humanoid.WalkSpeed * CFG.Block.WalkSpeedMultiplier
		end
		if root then
			-- A see-through shield bubble everyone can see.
			local shield = Instance.new("Part")
			shield.Name = "BlockShield"
			shield.Shape = Enum.PartType.Ball
			shield.Size = Vector3.new(7, 7, 7)
			shield.Material = Enum.Material.ForceField
			shield.Color = Color3.fromRGB(120, 190, 255)
			shield.CanCollide = false
			shield.CanQuery = false
			shield.CanTouch = false
			shield.Massless = true
			shield.CFrame = root.CFrame
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = shield
			weld.Parent = shield
			shield.Parent = root.Parent
			st.Shield = shield
		end
	else
		if humanoid and st.SavedWalkSpeed then
			humanoid.WalkSpeed = st.SavedWalkSpeed
		end
		st.SavedWalkSpeed = nil
		if st.Shield then
			st.Shield:Destroy()
			st.Shield = nil
		end
	end
end

--------------------------------------------------------------------------
-- Placeholder sword (welded into the right hand; see SwordBuilder)
--------------------------------------------------------------------------
local function swordColor(player)
	return GodConfig.GetColors(player:GetAttribute("SelectedGod") or "").Primary
end

local function giveSword(player, character)
	if character.Parent and character:FindFirstChildOfClass("Humanoid") then
		SwordBuilder.Attach(character, swordColor(player))
	end
end

local function flashTrail(player)
	local trail = SwordBuilder.GetTrail(player.Character)
	if trail then
		trail.Enabled = true
		task.delay(0.3, function()
			trail.Enabled = false
		end)
	end
end

--------------------------------------------------------------------------
-- Requests from the client
--------------------------------------------------------------------------
-- combo = which swing of the combo the client played (1-3), only used so
-- other players see the same animation.
function CombatService.BasicAttack(player, combo)
	local st = state[player]
	local _, _, root = getParts(player)
	if not st or not root or st.Blocking then
		return 0
	end
	local now = os.clock()
	if now < st.NextAttackAt then
		return 0
	end
	local attack = CFG.BasicAttack
	st.NextAttackAt = now + attack.Cooldown * 0.9 -- small tolerance for network timing
	flashTrail(player)

	-- Let everyone else's screen play the same swing.
	local moveName = SwordPoses.ComboOrder[if type(combo) == "number" then math.clamp(math.floor(combo), 1, 3) else 1]
	for _, other in Players:GetPlayers() do
		if other ~= player then
			fxRemote:FireClient(other, "Swing", player, moveName)
		end
	end

	local baseAttack = player:GetAttribute("BaseAttack") or 10
	local combatBonus = TempleService.GetEffect(player, "CombatBonusPercent") / 100
	local look = flat(root.CFrame.LookVector).Unit

	-- Enemies in front of the player, closest first.
	local candidates = {}
	for _, record in EnemyService.GetEnemiesInRange(root.Position, attack.Range + 4) do
		local offset = flat(record.Root.Position - root.Position)
		local reach = attack.Range + record.Root.Size.X / 2
		if offset.Magnitude <= reach and (offset.Magnitude < 1.5 or look:Dot(offset.Unit) >= attack.ArcDot) then
			table.insert(candidates, { Record = record, Distance = offset.Magnitude })
		end
	end
	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)

	local hits = 0
	for i = 1, math.min(#candidates, attack.MaxTargets) do
		local record = candidates[i].Record
		local spread = 1 + random:NextNumber(-attack.RandomSpread, attack.RandomSpread)
		local damage = baseAttack * attack.DamageMultiplier * (1 + combatBonus) * spread
		if EnemyService.DamageEnemy(record.Model, damage, player) then
			hits += 1
			fxRemote:FireAllClients("Hit", record.Root.Position, record.Model, player)
		end
	end
	return hits
end

function CombatService.Dash(player)
	local st = state[player]
	if not st or not getParts(player) then
		return false
	end
	local now = os.clock()
	if now < st.NextDashAt then
		return false
	end
	st.NextDashAt = now + CFG.Dash.Cooldown * 0.9
	st.InvulnerableUntil = now + CFG.Dash.InvulnerableTime
	return true
end

--------------------------------------------------------------------------
-- Damage to players
--------------------------------------------------------------------------
function CombatService.DamagePlayer(player, amount, _sourcePosition)
	local st = state[player]
	local _, humanoid, root = getParts(player)
	if not st or not humanoid then
		return 0
	end
	local now = os.clock()
	if now < st.InvulnerableUntil then
		fxRemote:FireAllClients("Damage", root.Position + Vector3.new(0, 3, 0), 0, "Dodged")
		return 0
	end
	local style = "Player"
	if st.Blocking then
		amount *= CFG.Block.DamageTaken
		style = "Blocked"
	end
	amount = math.max(1, math.floor(amount))
	st.LastDamagedAt = now
	humanoid:TakeDamage(amount)
	fxRemote:FireAllClients("Damage", root.Position + Vector3.new(0, 3, 0), amount, style)
	return amount
end

--------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------
function CombatService.Init(templeService, enemyService, fxRemoteEvent, remotes)
	TempleService = templeService
	EnemyService = enemyService
	fxRemote = fxRemoteEvent
	Players.RespawnTime = CFG.RespawnTime

	if remotes then
		remotes.Attack.OnServerEvent:Connect(function(player, combo)
			CombatService.BasicAttack(player, combo)
		end)
		remotes.Block.OnServerEvent:Connect(function(player, on)
			if type(on) == "boolean" then
				setBlocking(player, on)
			end
		end)
		remotes.Dash.OnServerEvent:Connect(function(player)
			CombatService.Dash(player)
		end)
	end

	-- Health regeneration, once per second. Also makes sure everyone is
	-- still holding their sword (avatar loading can replace the hand).
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, st in state do
				local character = getParts(player)
				if character then
					giveSword(player, character)
				end
				local _, humanoid = getParts(player)
				if humanoid and humanoid.Health < humanoid.MaxHealth and now - st.LastDamagedAt >= CFG.Regen.DelayAfterDamage then
					local bonus = 1 + TempleService.GetEffect(player, "RegenBonusPercent") / 100
					local heal = humanoid.MaxHealth * CFG.Regen.PercentPerSecond / 100 * bonus
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal)
				end
			end
		end
	end)
end

function CombatService.SetupPlayer(player)
	state[player] = {
		NextAttackAt = 0,
		NextDashAt = 0,
		InvulnerableUntil = 0,
		Blocking = false,
		SavedWalkSpeed = nil,
		Shield = nil,
		LastDamagedAt = 0,
	}
	player:SetAttribute("Blocking", false)
	player:GetAttributeChangedSignal("SelectedGod"):Connect(function()
		local sword = player.Character and player.Character:FindFirstChild(SwordBuilder.Name)
		if sword then
			SwordBuilder.SetColor(sword, swordColor(player))
		end
	end)
	if player.Character then
		task.spawn(giveSword, player, player.Character)
	end
	-- Fires once the avatar's own body parts and clothes have been applied.
	if typeof(player) == "Instance" then
		player.CharacterAppearanceLoaded:Connect(function(character)
			giveSword(player, character)
		end)
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			character:WaitForChild("Humanoid", 10)
			giveSword(player, character)
		end)
		local st = state[player]
		if st then
			st.Blocking = false
			st.SavedWalkSpeed = nil
			st.Shield = nil
			st.InvulnerableUntil = 0
			player:SetAttribute("Blocking", false)
		end
	end)
end

function CombatService.ReleasePlayer(player)
	state[player] = nil
end

-- Test helper: lets the cloud test act as a player.
function CombatService._GetState(player)
	return state[player]
end

return CombatService
