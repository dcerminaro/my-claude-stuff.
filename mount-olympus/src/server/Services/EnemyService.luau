-- EnemyService (ModuleScript)
-- Location: ServerScriptService > Services > EnemyService
--
-- Server-controlled enemies:
--   * Spawns enemies from CombatConfig.Enemies (placeholder characters).
--   * Simple AI: idle -> chase the nearest player -> wind up (weapon glows
--     red, red ring on the ground, weapon raised) -> strike -> cooldown.
--     Gives up and heals if pulled too far from its spawn.
--   * Hits knock enemies back and stagger them briefly. Training dummies
--     wobble (drawn on each player's device, so it costs the server nothing).
--   * Health bar over its head, damage numbers, death effect.
--   * Rewards XP + Gold ONCE per kill to every player who damaged it.
--
--   * Bosses (CombatConfig `Boss = true`): special attacks with big red
--     warnings (Slam: a circle; Charge: a line), an enraged second phase, and
--     no knockback or stagger.
--
-- Used by later systems:
--   EnemyService.Spawn(enemyType, cframe, options) -> model
--       options = { HealthMultiplier, DamageMultiplier, SpeedMultiplier, RewardMultiplier,
--                   AggroRange, LeashRange, Attributes = { name = value },
--                   OnDeath = function(model), OnPhase2 = function(model) }
--   EnemyService.Remove(model) -- removes an enemy silently (no rewards)
--   EnemyService.DamageEnemy(model, amount, player) -> true/false
--   EnemyService.GetEnemiesInRange(position, range) -> { record, ... }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))

local EnemyService = {}

local DataService = nil
local ProgressionService = nil
local CombatService = nil
local fxRemote = nil

local enemies = {} -- [Model] = record
local templates = {} -- [enemyType] = finished body, built once and cloned (cloning is instant)
local getPlayers = function()
	return Players:GetPlayers()
end
local folder = nil

local THINK_INTERVAL = 0.15
local HEAL_DELAY = 4 -- an enemy only heals after this many seconds without being hit
local REWARD_WINDOW = 60 -- damage older than this (seconds) doesn't earn a share of the reward

-- Roblox's own default R15 walk animation (free for every game). Attack
-- poses are our own (SwordPoses), played on each device.
local WALK_ANIMATION = "rbxassetid://507777826"
local KNOCKBACK_SPEED = 8 -- small, so hits don't push enemies out of sword reach
local STAGGER_TIME = 0.3

--------------------------------------------------------------------------
-- Building an enemy character
--------------------------------------------------------------------------
local function buildFallbackRig(look)
	-- Used only if Roblox can't create a normal character.
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = model
	local torso = Instance.new("Part")
	torso.Name = "UpperTorso"
	torso.Size = Vector3.new(2 * look.Width, 2, 1)
	torso.Color = look.Shirt
	torso.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Color = look.Skin
	head.Parent = model
	for _, pair in { { torso, CFrame.new() }, { head, CFrame.new(0, 1.6, 0) } } do
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = pair[1]
		weld.C0 = pair[2]
		weld.Parent = root
		pair[1].CFrame = root.CFrame * pair[2]
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function buildRig(look)
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = look.Skin
		description.LeftArmColor = look.Skin
		description.RightArmColor = look.Skin
		description.TorsoColor = look.Shirt
		description.LeftLegColor = look.Pants
		description.RightLegColor = look.Pants
		description.WidthScale = look.Width
		description.DepthScale = look.Width
		description.HeightScale = look.Height or 1
		description.HeadScale = look.Height or 1
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		return model
	end
	warn("[EnemyService] Using fallback enemy body: " .. tostring(model))
	return buildFallbackRig(look)
end

local function addWeapon(model, color, length)
	local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("UpperTorso")
	if not hand or not color then
		return
	end
	length = length or 3.6
	local blade = Instance.new("Part")
	blade.Name = "Weapon"
	blade.Size = Vector3.new(0.25 * length / 3.6, 0.4 * length / 3.6, length)
	blade.Material = Enum.Material.Metal
	blade.Color = color
	blade.CanCollide = false
	blade.Massless = true
	blade.CFrame = hand.CFrame * CFrame.new(0, -0.2, -length / 2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = blade
	weld.Parent = blade
	blade.Parent = model
end

-- Wooden training dummy: crossed feet, post, straw body with a target,
-- arms, and a sack head. Everything is anchored; the root sits 3 studs up.
local function buildDummy()
	local model = Instance.new("Model")
	local WOOD = Color3.fromRGB(120, 85, 55)
	local STRAW = Color3.fromRGB(222, 196, 130)
	local ROPE = Color3.fromRGB(140, 100, 60)
	local SACK = Color3.fromRGB(196, 168, 120)
	local origin = CFrame.new(0, 3, 0) -- root position; ground is 3 below
	local function part(name, size, offset, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = origin * offset
		for key, value in props or {} do
			p[key] = value
		end
		p.Parent = model
		return p
	end
	local function vcyl(name, height, diameter, y, color, material)
		-- vertical cylinder whose centre is `y` studs above the ground
		return part(name, Vector3.new(height, diameter, diameter), CFrame.new(0, y - 3, 0) * CFrame.Angles(0, 0, math.rad(90)), {
			Shape = Enum.PartType.Cylinder, Color = color, Material = material or Enum.Material.Wood,
		})
	end

	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(), { Transparency = 1, CanCollide = false })
	part("FootA", Vector3.new(4, 0.4, 0.7), CFrame.new(0, -2.8, 0), { Color = WOOD, Material = Enum.Material.Wood })
	part("FootB", Vector3.new(0.7, 0.4, 4), CFrame.new(0, -2.8, 0), { Color = WOOD, Material = Enum.Material.Wood })
	vcyl("Post", 5.6, 0.6, 3.2, WOOD)
	vcyl("Body", 2.8, 2.1, 3.4, STRAW, Enum.Material.Fabric)
	vcyl("RopeLow", 0.25, 2.2, 2.3, ROPE, Enum.Material.Fabric)
	vcyl("RopeHigh", 0.25, 2.2, 4.5, ROPE, Enum.Material.Fabric)
	-- Target on the front (local -Z faces the player)
	for i, ring in { { 1.5, Color3.fromRGB(200, 40, 35) }, { 1.0, Color3.fromRGB(245, 240, 230) }, { 0.45, Color3.fromRGB(200, 40, 35) } } do
		part("Target" .. i, Vector3.new(0.08, ring[1], ring[1]), CFrame.new(0, 0.4, -1.05 - i * 0.03) * CFrame.Angles(0, math.rad(90), 0), {
			Shape = Enum.PartType.Cylinder, Color = ring[2], Material = Enum.Material.SmoothPlastic,
		})
	end
	part("Arms", Vector3.new(4.6, 0.4, 0.4), CFrame.new(0, 1.3, 0), { Color = WOOD, Material = Enum.Material.Wood })
	for i, x in { -2.4, 2.4 } do
		part("Hand" .. i, Vector3.new(0.8, 0.8, 0.8), CFrame.new(x, 1.3, 0), { Shape = Enum.PartType.Ball, Color = STRAW, Material = Enum.Material.Fabric })
	end
	part("Head", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 2.85, 0), { Shape = Enum.PartType.Ball, Color = SACK, Material = Enum.Material.Fabric })
	for i, x in { -0.3, 0.3 } do
		part("Eye" .. i, Vector3.new(0.22, 0.22, 0.1), CFrame.new(x, 3.0, -0.76), { Color = Color3.fromRGB(40, 30, 25) })
	end
	part("Mouth", Vector3.new(0.6, 0.08, 0.1), CFrame.new(0, 2.6, -0.76), { Color = Color3.fromRGB(40, 30, 25) })
	part("Knot", Vector3.new(0.5, 0.35, 0.5), CFrame.new(0, 3.75, 0), { Color = ROPE, Material = Enum.Material.Fabric })

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

-- A finished enemy body for this type (the first one is built, the rest are copies).
local function makeBody(enemyType, cfg)
	if cfg.Builder == "Dummy" then
		return buildDummy()
	end
	if templates[enemyType] == nil then
		templates[enemyType] = false -- "being built": other spawns wait for it
		local template = buildRig(cfg.Appearance)
		addWeapon(template, cfg.Appearance.Weapon, cfg.Appearance.WeaponLength)
		templates[enemyType] = template
	end
	while templates[enemyType] == false do
		task.wait()
	end
	return templates[enemyType]:Clone()
end

local function addHealthBar(record)
	local head = record.Model:FindFirstChild("Head")
	if not head then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EnemyBar"
	billboard.Size = UDim2.fromOffset(120, 34)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.MaxDistance = 90
	billboard.AlwaysOnTop = true

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 16)
	name.BackgroundTransparency = 1
	name.Text = record.Config.DisplayName
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Parent = billboard

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 20)
	back.Size = UDim2.new(1, 0, 0, 10)
	back.BackgroundColor3 = Color3.fromRGB(40, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = billboard

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(210, 60, 50)
	fill.BorderSizePixel = 0
	fill.Parent = back

	billboard.Parent = head
	record.Humanoid.HealthChanged:Connect(function(health)
		fill.Size = UDim2.fromScale(math.clamp(health / record.Humanoid.MaxHealth, 0, 1), 1)
	end)
end

local function loadAnimation(humanoid, id)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local ok, track = pcall(function()
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		return animator:LoadAnimation(animation)
	end)
	return if ok then track else nil
end

--------------------------------------------------------------------------
-- AI helpers
--------------------------------------------------------------------------
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function face(record, position)
	local root = record.Root
	local look = flat(position - root.Position)
	if look.Magnitude > 0.1 and not root.Anchored then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
	end
end

local function aliveCharacterRoot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function findTarget(record)
	-- Whoever hit it recently is chased first (even from a little further away).
	local attacker = record.LastAttacker
	if attacker and attacker.Parent and os.clock() - record.LastDamagedAt < HEAL_DELAY then
		local root = aliveCharacterRoot(attacker)
		if root and (root.Position - record.Home).Magnitude <= record.LeashRange then
			return attacker, (root.Position - record.Root.Position).Magnitude
		end
	end
	local best, bestDistance = nil, math.huge
	for _, player in getPlayers() do
		local root = aliveCharacterRoot(player)
		if root then
			local distance = (root.Position - record.Root.Position).Magnitude
			local range = if record.Target == player then record.AggroRange * 1.5 else record.AggroRange
			local fromHome = (root.Position - record.Home).Magnitude
			if distance <= range and fromHome <= record.LeashRange and distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best, bestDistance
end

local function clearTelegraph(record)
	if record.Telegraph then
		for _, item in record.Telegraph do
			item:Destroy()
		end
		record.Telegraph = nil
	end
	local weapon = record.Model:FindFirstChild("Weapon")
	if weapon and record.WeaponLook then
		weapon.Material = record.WeaponLook.Material
		weapon.Color = record.WeaponLook.Color
	end
end

local function startAttack(record, target)
	local cfg = record.Config
	record.State = "Windup"
	record.Humanoid:MoveTo(record.Root.Position)
	local targetRoot = aliveCharacterRoot(target)
	if targetRoot then
		face(record, targetRoot.Position)
	end

	-- Telegraph: the weapon glows red, a red ring shows the danger zone, and
	-- every player's screen shows the enemy raising its weapon.
	local weapon = record.Model:FindFirstChild("Weapon")
	if weapon then
		record.WeaponLook = record.WeaponLook or { Material = weapon.Material, Color = weapon.Color }
		weapon.Material = Enum.Material.Neon
		weapon.Color = Color3.fromRGB(255, 50, 40)
	end
	fxRemote:FireAllClients("EnemyAttack", record.Root.Position, record.Model, cfg.Windup)

	local groundY = record.Root.Position.Y - record.Root.Size.Y / 2 - record.Humanoid.HipHeight + 0.1
	local ring = Instance.new("Part")
	ring.Name = "AttackWarning"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 50, 40)
	ring.Transparency = 0.6
	local diameter = (cfg.AttackRange + 1.5) * 2
	ring.Size = Vector3.new(0.2, diameter, diameter)
	ring.CFrame = CFrame.new(record.Root.Position.X, groundY, record.Root.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder
	record.Telegraph = { ring }

	task.delay(cfg.Windup, function()
		clearTelegraph(record)
		if record.Dead or not record.Model.Parent then
			return
		end
		local root = record.Root
		for _, player in getPlayers() do
			local playerRoot = aliveCharacterRoot(player)
			if playerRoot then
				local offset = flat(playerRoot.Position - root.Position)
				local inRange = offset.Magnitude <= cfg.AttackRange + 1.5
				local inFront = offset.Magnitude < 1 or root.CFrame.LookVector:Dot(offset.Unit) > 0.1
				if inRange and inFront then
					CombatService.DamagePlayer(player, cfg.Damage * record.DamageMultiplier, root.Position)
				end
			end
		end
		record.NextAttackAt = os.clock() + cfg.AttackCooldown * record.CooldownMultiplier
		record.State = "Chase"
	end)
end

--------------------------------------------------------------------------
-- Boss special attacks
--------------------------------------------------------------------------
local WARNING_RED = Color3.fromRGB(255, 50, 40)

local function warningPart(props)
	local part = Instance.new("Part")
	part.Name = "AttackWarning"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = WARNING_RED
	part.Transparency = 0.55
	for key, value in props do
		part[key] = value
	end
	part.Parent = folder
	return part
end

local function groundUnder(record)
	return record.Root.Position.Y - record.Root.Size.Y / 2 - record.Humanoid.HipHeight + 0.1
end

local function glowWeapon(record)
	local weapon = record.Model:FindFirstChild("Weapon")
	if weapon then
		record.WeaponLook = record.WeaponLook or { Material = weapon.Material, Color = weapon.Color }
		weapon.Material = Enum.Material.Neon
		weapon.Color = WARNING_RED
	end
end

local function startSpecial(record, target, attack)
	record.State = "Windup"
	record.AttackReadyAt[attack.Name] = os.clock() + attack.Windup + attack.Cooldown * record.CooldownMultiplier
	record.Humanoid:MoveTo(record.Root.Position)
	local targetRoot = aliveCharacterRoot(target)
	if targetRoot then
		face(record, targetRoot.Position)
	end
	glowWeapon(record)
	fxRemote:FireAllClients("EnemyAttack", record.Root.Position, record.Model, attack.Windup)
	local root = record.Root
	local ground = groundUnder(record)
	local origin = Vector3.new(root.Position.X, ground, root.Position.Z)
	local look = flat(root.CFrame.LookVector).Unit
	local damage = attack.Damage * record.DamageMultiplier

	if attack.Kind == "Slam" then
		-- A big red circle around the boss; everyone inside when it lands is hit.
		local d = attack.Radius * 2
		local ring = warningPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, d, d),
			CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90)),
		})
		record.Telegraph = { ring }
		task.delay(attack.Windup, function()
			clearTelegraph(record)
			if record.Dead or not record.Model.Parent then
				return
			end
			for _, player in getPlayers() do
				local playerRoot = aliveCharacterRoot(player)
				if playerRoot and flat(playerRoot.Position - origin).Magnitude <= attack.Radius then
					CombatService.DamagePlayer(player, damage, origin)
				end
			end
			fxRemote:FireAllClients("Shockwave", root.Position, WARNING_RED, attack.Radius)
			record.State = "Chase"
		end)
	elseif attack.Kind == "Charge" then
		-- A red lane in front; the boss rushes down it, hitting everyone inside.
		local lane = warningPart({
			Size = Vector3.new(attack.Width, 0.2, attack.Length),
			CFrame = CFrame.lookAt(origin + look * (attack.Length / 2), origin + look * attack.Length),
		})
		record.Telegraph = { lane }
		task.delay(attack.Windup, function()
			clearTelegraph(record)
			if record.Dead or not record.Model.Parent then
				return
			end
			local finish = origin + look * attack.Length
			for _, player in getPlayers() do
				local playerRoot = aliveCharacterRoot(player)
				if playerRoot then
					local offset = flat(playerRoot.Position - origin)
					local along = offset:Dot(look)
					local side = (offset - look * along).Magnitude
					if along >= -1 and along <= attack.Length + 1 and side <= attack.Width / 2 + 1 then
						CombatService.DamagePlayer(player, damage, origin)
					end
				end
			end
			-- The rush itself
			local attachment = Instance.new("Attachment")
			attachment.Parent = root
			local push = Instance.new("LinearVelocity")
			push.Attachment0 = attachment
			push.RelativeTo = Enum.ActuatorRelativeTo.World
			push.VectorVelocity = look * (attack.Length / 0.4)
			push.MaxForce = 200000
			push.Parent = root
			Debris:AddItem(push, 0.4)
			Debris:AddItem(attachment, 0.4)
			fxRemote:FireAllClients("DashTrail", root.Position, WARNING_RED, finish + Vector3.new(0, root.Position.Y - origin.Y, 0))
			task.delay(0.45, function()
				record.State = "Chase"
			end)
		end)
	end
end

-- A special attack that is ready and fits the distance, or nil.
local function pickSpecial(record, distance, now)
	local attacks = record.Config.Attacks
	if not attacks then
		return nil
	end
	for _, attack in attacks do
		if now >= (record.AttackReadyAt[attack.Name] or 0) and distance <= attack.Range and distance >= (attack.MinRange or 0) then
			return attack
		end
	end
	return nil
end

local function think(record, now)
	if record.Dead then
		return
	end
	local cfg = record.Config
	local humanoid = record.Humanoid

	if cfg.Passive then
		if now - record.LastDamagedAt > cfg.RegenDelay and humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = humanoid.MaxHealth
		end
		return
	end
	if record.State == "Windup" or now < record.StaggerUntil then
		return
	end

	local target, distance = findTarget(record)
	record.Target = target
	local fromHome = (record.Root.Position - record.Home).Magnitude

	if not target or fromHome > record.LeashRange then
		-- Go home, and heal up once nobody has hit it for a while.
		if fromHome > 3 then
			humanoid:MoveTo(record.Home)
		elseif humanoid.Health < humanoid.MaxHealth and now - record.LastDamagedAt > HEAL_DELAY then
			humanoid.Health = humanoid.MaxHealth
		end
		return
	end

	local targetRoot = aliveCharacterRoot(target)
	local special = pickSpecial(record, distance, now)
	if special then
		startSpecial(record, target, special)
	elseif distance > cfg.AttackRange then
		humanoid:MoveTo(targetRoot.Position)
	elseif now >= record.NextAttackAt then
		startAttack(record, target)
	else
		-- Waiting to attack again: keep facing the target. A tiny step turns it
		-- smoothly; up close (where a step would walk into you) it only turns
		-- when it's facing well away.
		local toward = flat(targetRoot.Position - record.Root.Position)
		if toward.Magnitude > 3.5 then
			humanoid:MoveTo(record.Root.Position + toward.Unit * 0.5)
		elseif toward.Magnitude > 0.5 then
			humanoid:MoveTo(record.Root.Position)
			if record.Root.CFrame.LookVector:Dot(toward.Unit) < 0.8 then
				face(record, targetRoot.Position)
			end
		end
	end
end

--------------------------------------------------------------------------
-- Death and rewards
--------------------------------------------------------------------------
local function die(record)
	if record.Dead then
		return
	end
	record.Dead = true
	enemies[record.Model] = nil
	clearTelegraph(record)

	local cfg = record.Config
	local position = record.Root.Position
	local now = os.clock()
	local xp = math.floor(cfg.XP * record.RewardMultiplier)
	local gold = math.floor(cfg.Gold * record.RewardMultiplier)

	-- Every player who helped gets the reward once.
	for player, info in record.Contributors do
		if player.Parent and info.Damage > 0 and now - info.Last <= REWARD_WINDOW then
			local data = DataService.GetData(player)
			if data then
				data.Stats.EnemiesDefeated += 1
				if xp > 0 then
					ProgressionService.AddXP(player, xp, "Combat")
				end
				if gold > 0 then
					ProgressionService.AddCurrency(player, "Gold", gold, "Combat")
				end
				if xp > 0 or gold > 0 then
					fxRemote:FireClient(player, "Reward", position, ("+%d XP  +%d Gold"):format(xp, gold))
				end
			end
		end
	end

	-- Roblox's classic death: the joints break and the body falls apart.
	-- Make every piece land on the ground and tumble, then fade away.
	fxRemote:FireAllClients("Death", position)
	for _, item in record.Model:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanCollide = true
			item.Massless = false
		elseif item:IsA("BillboardGui") then
			item.Enabled = false
		end
	end
	task.delay(2, function()
		for _, item in record.Model:GetDescendants() do
			if item:IsA("BasePart") then
				TweenService:Create(item, TweenInfo.new(1), { Transparency = 1 }):Play()
			end
		end
	end)
	Debris:AddItem(record.Model, 3.2)

	if record.OnDeath then
		task.spawn(record.OnDeath, record.Model)
	end
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------
function EnemyService.Init(dataService, progressionService, combatService, fxRemoteEvent)
	DataService = dataService
	ProgressionService = progressionService
	CombatService = combatService
	fxRemote = fxRemoteEvent

	folder = Workspace:FindFirstChild("Enemies")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Enemies"
		folder.Parent = Workspace
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < THINK_INTERVAL then
			return
		end
		elapsed = 0
		local now = os.clock()
		for _, record in enemies do
			think(record, now)
		end
	end)
end

function EnemyService.Spawn(enemyType, cframe, options)
	local cfg = CombatConfig.Enemies[enemyType]
	if not cfg then
		warn("[EnemyService] Unknown enemy type: " .. tostring(enemyType))
		return nil
	end
	options = options or {}

	local model = makeBody(enemyType, cfg)
	model.Name = enemyType
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.CollisionGroup = CombatService.ENEMY_GROUP
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local healthMultiplier = options.HealthMultiplier or 1
	humanoid.MaxHealth = math.floor(cfg.MaxHealth * healthMultiplier)
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = cfg.WalkSpeed * (options.SpeedMultiplier or 1)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = true

	model:PivotTo(cframe + Vector3.new(0, 3, 0))
	if cfg.Passive then
		root.Anchored = true
	end
	if cfg.Builder == "Dummy" then
		model:SetAttribute("Dummy", true) -- clients wobble it when hit
	end
	model:SetAttribute("IsEnemy", true)
	if cfg.Boss then
		model:SetAttribute("IsBoss", true)
		model:SetAttribute("DisplayName", cfg.DisplayName)
	end
	for key, value in options.Attributes or {} do
		model:SetAttribute(key, value)
	end
	model.Parent = folder
	if not root.Anchored then
		pcall(function()
			root:SetNetworkOwner(nil) -- the server moves enemies; players can't
		end)
	end

	local record = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Type = enemyType,
		Config = cfg,
		Home = cframe.Position,
		State = "Idle",
		Target = nil,
		NextAttackAt = 0,
		LastDamagedAt = 0,
		LastAttacker = nil,
		Contributors = {}, -- [Player] = { Damage, Last }
		Dead = false,
		DamageMultiplier = options.DamageMultiplier or 1,
		RewardMultiplier = options.RewardMultiplier or 1,
		OnDeath = options.OnDeath,
		OnPhase2 = options.OnPhase2,
		StaggerUntil = 0,
		AggroRange = options.AggroRange or cfg.AggroRange or 0,
		LeashRange = options.LeashRange or cfg.LeashRange or 0,
		AttackReadyAt = {},
		CooldownMultiplier = 1,
		Phase2 = false,
	}
	-- Special attacks start on a short delay so a boss doesn't open with one.
	for _, attack in cfg.Attacks or {} do
		record.AttackReadyAt[attack.Name] = os.clock() + 3
	end
	addHealthBar(record)

	local walkTrack = if cfg.Passive then nil else loadAnimation(humanoid, WALK_ANIMATION)
	if walkTrack then
		humanoid.Running:Connect(function(speed)
			if speed > 0.5 and not walkTrack.IsPlaying then
				walkTrack:Play()
			elseif speed <= 0.5 and walkTrack.IsPlaying then
				walkTrack:Stop()
			end
		end)
	end

	humanoid.Died:Connect(function()
		die(record)
	end)
	enemies[model] = record
	return model
end

-- Damages an enemy on behalf of a player. Returns true if it was hit.
-- options.Knockback = push speed (studs/s) instead of the default.
function EnemyService.DamageEnemy(model, amount, player, options)
	local record = enemies[model]
	if not record or record.Dead or record.Humanoid.Health <= 0 then
		return false
	end
	amount = math.max(1, math.floor(amount))
	local now = os.clock()
	record.LastDamagedAt = now
	if player then
		record.LastAttacker = player
		local info = record.Contributors[player] or { Damage = 0, Last = 0 }
		info.Damage += amount
		info.Last = now
		record.Contributors[player] = info
	end
	local head = model:FindFirstChild("Head") or record.Root
	fxRemote:FireAllClients("Damage", head.Position + Vector3.new(0, 1.5, 0), amount, "Enemy")

	if record.Config.Immortal then
		-- Training dummies never die: a "knockout" pops them straight back up.
		if record.Humanoid.Health - amount <= 0 then
			record.Humanoid.Health = record.Humanoid.MaxHealth
			fxRemote:FireAllClients("Damage", head.Position + Vector3.new(0, 3, 0), 0, "KnockedOut")
			fxRemote:FireAllClients("Death", record.Root.Position)
		else
			record.Humanoid.Health -= amount
		end
		return true
	end

	record.Humanoid:TakeDamage(amount)
	if record.Humanoid.Health <= 0 then
		die(record)
		return true
	end

	-- Boss second phase.
	local phase2 = record.Config.Phase2
	if phase2 and not record.Phase2 and record.Humanoid.Health <= record.Humanoid.MaxHealth * phase2.At then
		record.Phase2 = true
		record.CooldownMultiplier = phase2.CooldownMultiplier or 1
		record.Humanoid.WalkSpeed *= phase2.SpeedMultiplier or 1
		model:SetAttribute("Enraged", true)
		if record.OnPhase2 then
			task.spawn(record.OnPhase2, model)
		end
	end
	if record.Config.Boss then
		return true -- bosses aren't knocked back or staggered
	end

	-- Knock it back a little and interrupt its walking (not a wind-up already started).
	local attackerRoot = player and aliveCharacterRoot(player)
	if attackerRoot and not record.Root.Anchored then
		local away = flat(record.Root.Position - attackerRoot.Position)
		if away.Magnitude > 0.1 then
			-- A short push that the enemy's own walking can't cancel.
			local attachment = Instance.new("Attachment")
			attachment.Parent = record.Root
			local push = Instance.new("LinearVelocity")
			push.Attachment0 = attachment
			push.RelativeTo = Enum.ActuatorRelativeTo.World
			push.VectorVelocity = away.Unit * (options and options.Knockback or KNOCKBACK_SPEED)
			push.MaxForce = 40000
			push.Parent = record.Root
			Debris:AddItem(push, 0.12)
			Debris:AddItem(attachment, 0.12)
		end
		record.Humanoid:MoveTo(record.Root.Position)
		record.StaggerUntil = now + STAGGER_TIME
	end
	return true
end

-- Removes an enemy without rewards (e.g. when an arena run ends).
function EnemyService.Remove(model)
	local record = enemies[model]
	if record then
		record.Dead = true
		enemies[model] = nil
		clearTelegraph(record)
	end
	if model then
		model:Destroy()
	end
end

-- Living enemies whose root is within `range` of `position`.
function EnemyService.GetEnemiesInRange(position, range)
	local found = {}
	for _, record in enemies do
		if not record.Dead and (record.Root.Position - position).Magnitude <= range then
			table.insert(found, record)
		end
	end
	return found
end

function EnemyService.GetEnemyCount()
	local count = 0
	for _ in enemies do
		count += 1
	end
	return count
end

-- Test helper: lets the cloud test supply pretend players.
function EnemyService._SetPlayerProvider(provider)
	getPlayers = provider
end

-- Spawns the Practice Field enemies; each one respawns after it dies.
function EnemyService.SpawnPracticeField()
	local field = CombatConfig.PracticeField
	for _, entry in field.Spawns do
		local cfg = CombatConfig.Enemies[entry.Enemy]
		local position = field.Center + entry.Offset
		local cframe = CFrame.lookAt(position, position + Vector3.new(0, 0, 1)) -- face the entrance
		local function spawnOne()
			EnemyService.Spawn(entry.Enemy, cframe, {
				OnDeath = function()
					task.wait(cfg.RespawnTime)
					spawnOne()
				end,
			})
		end
		task.spawn(spawnOne) -- all at once, not one after another
	end
end

return EnemyService
