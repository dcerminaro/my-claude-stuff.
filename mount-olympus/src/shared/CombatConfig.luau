-- CombatConfig (ModuleScript)
-- Location: ReplicatedStorage > Shared > CombatConfig
--
-- Tunable combat numbers for players and enemies. Server and client read it.
-- All numbers are PLACEHOLDERS, balanced in Phase 8.
-- To add an enemy: add an entry to Enemies. Arenas (Phase 5) spawn enemies by
-- these names through EnemyService.Spawn.

local CombatConfig = {}

--------------------------------------------------------------------------
-- PLAYER
--------------------------------------------------------------------------
CombatConfig.Player = {
	RespawnTime = 4, -- seconds after dying

	-- Damage = BaseAttack (level + blessings) x DamageMultiplier x (1 + Training Grounds bonus)
	BasicAttack = {
		DamageMultiplier = 1,
		Range = 7.5,        -- studs in front of you
		ArcDot = 0.2,       -- how wide the swing is (0 = 180 degrees, 0.7 = narrow)
		Cooldown = 0.45,    -- seconds between swings
		MaxTargets = 3,
		RandomSpread = 0.1, -- +/- 10% damage variation
	},

	Block = {
		DamageTaken = 0.3,          -- you take 30% damage while blocking
		WalkSpeedMultiplier = 0.5,  -- and move at half speed
	},

	Dash = {
		Cooldown = 2,
		Speed = 60,             -- studs per second during the dash
		Duration = 0.18,        -- seconds
		InvulnerableTime = 0.3, -- you can't be hit right after dashing
	},

	-- Replaces Roblox's default regeneration. The Divine Fountain bonus multiplies it.
	Regen = {
		DelayAfterDamage = 5, -- seconds without taking damage before regen starts
		PercentPerSecond = 1, -- % of max health per second
	},
}

--------------------------------------------------------------------------
-- ENEMIES
-- Windup = the warning time (the enemy glows red) before an attack lands.
-- AggroRange = how close you must be before it chases you.
-- LeashRange = how far from its spawn it will follow you before giving up.
--------------------------------------------------------------------------
CombatConfig.Enemies = {
	Bandit = {
		DisplayName = "Bandit",
		MaxHealth = 60,
		Damage = 8,
		WalkSpeed = 12,
		AttackRange = 5,
		Windup = 0.7,
		AttackCooldown = 1.6,
		AggroRange = 22,
		LeashRange = 55,
		XP = 25,
		Gold = 10,
		RespawnTime = 10,
		Appearance = {
			Skin = Color3.fromRGB(204, 160, 120),
			Shirt = Color3.fromRGB(120, 60, 40),
			Pants = Color3.fromRGB(70, 55, 40),
			Width = 1,
			Weapon = Color3.fromRGB(150, 150, 155),
		},
	},
	Skeleton = {
		DisplayName = "Skeleton",
		MaxHealth = 45,
		Damage = 10,
		WalkSpeed = 14,
		AttackRange = 5,
		Windup = 0.6,
		AttackCooldown = 1.8,
		AggroRange = 22,
		LeashRange = 55,
		XP = 35,
		Gold = 14,
		RespawnTime = 12,
		Appearance = {
			Skin = Color3.fromRGB(235, 230, 215),
			Shirt = Color3.fromRGB(225, 220, 205),
			Pants = Color3.fromRGB(215, 210, 195),
			Width = 0.7,
			Weapon = Color3.fromRGB(110, 100, 90),
		},
	},
	TrainingDummy = {
		DisplayName = "Training Dummy",
		MaxHealth = 500,
		Damage = 0,
		WalkSpeed = 0,
		Passive = true,   -- never moves or attacks
		RegenDelay = 3,   -- heals fully after 3 seconds without being hit
		XP = 0,
		Gold = 0,
		RespawnTime = 3,
		Appearance = {
			Skin = Color3.fromRGB(214, 190, 140),
			Shirt = Color3.fromRGB(160, 120, 80),
			Pants = Color3.fromRGB(120, 85, 55),
			Width = 1.1,
		},
	},
}

--------------------------------------------------------------------------
-- PRACTICE FIELD (behind the plaza spawn) — a place to fight before arenas
-- exist. Offsets are relative to Center (Y = floor top).
--------------------------------------------------------------------------
CombatConfig.PracticeField = {
	Center = Vector3.new(0, 1, -125),
	Size = Vector3.new(90, 1, 70),
	Spawns = {
		{ Enemy = "TrainingDummy", Offset = Vector3.new(-20, 0, 18) },
		{ Enemy = "TrainingDummy", Offset = Vector3.new(0, 0, 18) },
		{ Enemy = "TrainingDummy", Offset = Vector3.new(20, 0, 18) },
		{ Enemy = "Bandit", Offset = Vector3.new(-22, 0, 2) },
		{ Enemy = "Bandit", Offset = Vector3.new(0, 0, -6) },
		{ Enemy = "Bandit", Offset = Vector3.new(22, 0, 2) },
		{ Enemy = "Skeleton", Offset = Vector3.new(-14, 0, -24) },
		{ Enemy = "Skeleton", Offset = Vector3.new(14, 0, -24) },
	},
}

return CombatConfig
