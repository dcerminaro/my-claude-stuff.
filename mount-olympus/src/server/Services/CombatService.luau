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
--   * Gives every player a placeholder sword (held as a Tool, so Roblox's
--     sword-holding pose is used) that glows in their god's colour and
--     leaves a light trail when swung. Real weapons come in Phase 7.
--
-- Other systems call: CombatService.DamagePlayer(player, amount, sourcePosition)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local GodConfig = require(Shared:WaitForChild("GodConfig"))

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
-- Placeholder sword
--------------------------------------------------------------------------
local SWORD_NAME = "DivineSword"

local function swordColor(player)
	return GodConfig.GetColors(player:GetAttribute("SelectedGod") or "").Primary
end

local function colorSword(player, tool)
	local color = swordColor(player)
	local handle = tool:FindFirstChild("Handle")
	local glow = handle and handle:FindFirstChild("Glow")
	local trail = handle and handle:FindFirstChild("SwingTrail")
	if glow then
		glow.Color = color
	end
	if trail then
		trail.Color = ColorSequence.new(color)
	end
end

local function weldTo(handle, part, offset)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	part.Parent = handle
	return part
end

local function giveSword(player, character)
	if character:FindFirstChild(SWORD_NAME) then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = SWORD_NAME
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	tool.RequiresHandle = true
	-- Same grip as Roblox's classic sword: the blade points up and forward.
	tool.Grip = CFrame.new(0, 0, -1.7, 0, 0, 1, 1, 0, 0, 0, 1, 0)

	-- The handle is the blade (it runs along Z; the hand holds the -Z end).
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.22, 0.5, 4.2)
	handle.Material = Enum.Material.Metal
	handle.Color = Color3.fromRGB(205, 210, 220)
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Size = Vector3.new(0.26, 0.14, 3.0)
	glow.Material = Enum.Material.Neon
	weldTo(handle, glow, CFrame.new(0, 0, 0.5))

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(0.32, 1.6, 0.32)
	guard.Material = Enum.Material.Metal
	guard.Color = Color3.fromRGB(212, 175, 55)
	weldTo(handle, guard, CFrame.new(0, 0, -1.15))

	local grip = Instance.new("Part")
	grip.Name = "GripWrap"
	grip.Size = Vector3.new(0.3, 0.6, 0.95)
	grip.Material = Enum.Material.Fabric
	grip.Color = Color3.fromRGB(110, 70, 40)
	weldTo(handle, grip, CFrame.new(0, 0, -1.75))

	local pommel = Instance.new("Part")
	pommel.Name = "Pommel"
	pommel.Shape = Enum.PartType.Ball
	pommel.Size = Vector3.new(0.45, 0.45, 0.45)
	pommel.Material = Enum.Material.Metal
	pommel.Color = Color3.fromRGB(212, 175, 55)
	weldTo(handle, pommel, CFrame.new(0, 0, -2.3))

	-- Light trail between the guard and the tip while swinging.
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailBase"
	a0.Position = Vector3.new(0, 0, -1.0)
	a0.Parent = handle
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailTip"
	a1.Position = Vector3.new(0, 0, 2.1)
	a1.Parent = handle
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.2
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Enabled = false
	trail.Parent = handle

	colorSword(player, tool)
	tool.Parent = character -- equipped straight away
end

local function flashTrail(player)
	local character = player.Character
	local tool = character and character:FindFirstChild(SWORD_NAME)
	local trail = tool and tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("SwingTrail")
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
function CombatService.BasicAttack(player)
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
			fxRemote:FireAllClients("Hit", record.Root.Position)
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
		remotes.Attack.OnServerEvent:Connect(function(player)
			CombatService.BasicAttack(player)
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

	-- Health regeneration, once per second.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, st in state do
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
		local tool = player.Character and player.Character:FindFirstChild(SWORD_NAME)
		if tool then
			colorSword(player, tool)
		end
	end)
	if player.Character then
		task.spawn(giveSword, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			character:WaitForChild("Humanoid", 10)
			if character.Parent then
				giveSword(player, character)
			end
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
