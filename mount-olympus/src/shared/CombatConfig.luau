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
		Windup = 0.45,
		AttackCooldown = 1.0,
		AggroRange = 22,
		LeashRange = 55,
		XP = 25,
		Gold = 10,
		RespawnTime = 6,
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
		Windup = 0.4,
		AttackCooldown = 1.1,
		AggroRange = 22,
		LeashRange = 55,
		XP = 35,
		Gold = 14,
		RespawnTime = 7,
		Appearance = {
			Skin = Color3.fromRGB(235, 230, 215),
			Shirt = Color3.fromRGB(225, 220, 205),
			Pants = Color3.fromRGB(215, 210, 195),
			Width = 0.7,
			Weapon = Color3.fromRGB(110, 100, 90),
		},
	},
	-- Phase 5 boss of the Mortal Training Pit.
	TrainingChampion = {
		DisplayName = "Training Champion",
		Boss = true,           -- big health bar, no knockback or stagger
		MaxHealth = 2500,
		Damage = 22,           -- basic sword swing
		WalkSpeed = 13,
		AttackRange = 6,
		Windup = 0.4,
		AttackCooldown = 0.9,
		AggroRange = 90,
		LeashRange = 200,
		XP = 150,
		Gold = 80,
		RespawnTime = 0,
		Appearance = {
			Skin = Color3.fromRGB(204, 160, 120),
			Shirt = Color3.fromRGB(200, 160, 60),  -- gold armour
			Pants = Color3.fromRGB(150, 95, 45),   -- bronze
			Width = 1.3,
			Height = 1.35,
			Weapon = Color3.fromRGB(230, 200, 120),
			WeaponLength = 5,
		},
		-- Special attacks, each with a clear red warning on the ground.
		-- Range = how close the target must be to start it.
		Attacks = {
			{ Name = "Slam", Kind = "Slam", Windup = 0.9, Cooldown = 6, Range = 10, Radius = 13, Damage = 35 },
			{ Name = "Charge", Kind = "Charge", Windup = 0.75, Cooldown = 7, Range = 30, MinRange = 9, Length = 26, Width = 6, Damage = 30 },
		},
		-- Below half health: faster attacks, faster walking, calls for help once.
		Phase2 = {
			At = 0.5,
			CooldownMultiplier = 0.65,
			SpeedMultiplier = 1.2,
			Summon = { Bandit = 2 },
			Message = "The Training Champion is enraged!",
		},
	},
	------------------------------------------------------------------
	-- Phase 7B: arena 2-6 enemies and bosses.
	-- Appearance.Extras: Helmet, Shield, Horns, Snakes, Eye, Crown (parts on
	-- the body). Appearance.Scale: grows the whole model (giants).
	-- Builder = "Beast": a four-legged animal (Size, Heads, Fire).
	-- Special attack kinds: Slam (circle), Charge (lane), Cone (fan in front,
	-- can slow you), Meteors (several circles around players).
	------------------------------------------------------------------
	SpartanSoldier = {
		DisplayName = "Spartan Soldier", MaxHealth = 160, Damage = 20, WalkSpeed = 13,
		AttackRange = 5.5, Windup = 0.45, AttackCooldown = 1.0, AggroRange = 30, LeashRange = 60,
		XP = 120, Gold = 60, RespawnTime = 0,
		Appearance = { Skin = Color3.fromRGB(204, 160, 120), Shirt = Color3.fromRGB(170, 40, 35), Pants = Color3.fromRGB(150, 100, 50),
			Width = 1.1, Weapon = Color3.fromRGB(180, 180, 185), WeaponLength = 4.4, Extras = { "Helmet", "Shield" }, ExtraColor = Color3.fromRGB(176, 112, 56) },
	},
	WarHound = {
		DisplayName = "War Hound", Builder = "Beast", MaxHealth = 90, Damage = 14, WalkSpeed = 20,
		AttackRange = 5, Windup = 0.35, AttackCooldown = 0.9, AggroRange = 35, LeashRange = 60,
		XP = 90, Gold = 40, RespawnTime = 0,
		Appearance = { Body = Color3.fromRGB(110, 80, 55), Accent = Color3.fromRGB(70, 50, 35), Eye = Color3.fromRGB(255, 200, 80), Size = 0.8, Heads = 1 },
	},
	SpartanWarlord = {
		DisplayName = "Spartan Warlord", Boss = true, MaxHealth = 7000, Damage = 40, WalkSpeed = 14,
		AttackRange = 7, Windup = 0.45, AttackCooldown = 0.9, AggroRange = 90, LeashRange = 200,
		XP = 900, Gold = 500, RespawnTime = 0,
		Appearance = { Skin = Color3.fromRGB(204, 160, 120), Shirt = Color3.fromRGB(150, 25, 25), Pants = Color3.fromRGB(176, 112, 56),
			Width = 1.4, Height = 1.5, Weapon = Color3.fromRGB(230, 200, 120), WeaponLength = 6, Extras = { "Helmet", "Shield" }, ExtraColor = Color3.fromRGB(212, 175, 55) },
		Attacks = {
			{ Name = "Slam", Kind = "Slam", Windup = 0.9, Cooldown = 6, Range = 11, Radius = 14, Damage = 55 },
			{ Name = "Charge", Kind = "Charge", Windup = 0.75, Cooldown = 7, Range = 32, MinRange = 9, Length = 30, Width = 7, Damage = 50 },
		},
		Phase2 = { At = 0.5, CooldownMultiplier = 0.65, SpeedMultiplier = 1.2, Summon = { SpartanSoldier = 2 }, Message = "The Spartan Warlord calls his phalanx!" },
	},

	LabyrinthGuardian = {
		DisplayName = "Labyrinth Guardian", MaxHealth = 450, Damage = 34, WalkSpeed = 12,
		AttackRange = 6.5, Windup = 0.5, AttackCooldown = 1.1, AggroRange = 30, LeashRange = 60,
		XP = 400, Gold = 180, RespawnTime = 0,
		Appearance = { Skin = Color3.fromRGB(150, 145, 135), Shirt = Color3.fromRGB(120, 115, 105), Pants = Color3.fromRGB(100, 95, 88),
			Width = 1.3, Height = 1.25, Weapon = Color3.fromRGB(90, 90, 95), WeaponLength = 5, Extras = { "Helmet" }, ExtraColor = Color3.fromRGB(110, 105, 98) },
	},
	MinotaurBrute = {
		DisplayName = "Minotaur Brute", MaxHealth = 380, Damage = 38, WalkSpeed = 15,
		AttackRange = 6.5, Windup = 0.45, AttackCooldown = 1.0, AggroRange = 32, LeashRange = 60,
		XP = 420, Gold = 200, RespawnTime = 0,
		Appearance = { Skin = Color3.fromRGB(105, 70, 45), Shirt = Color3.fromRGB(90, 60, 40), Pants = Color3.fromRGB(70, 50, 35),
			Width = 1.35, Height = 1.2, Weapon = Color3.fromRGB(120, 110, 100), WeaponLength = 4.5, Extras = { "Horns" }, ExtraColor = Color3.fromRGB(235, 225, 200) },
	},
	Minotaur = {
		DisplayName = "The Minotaur", Boss = true, MaxHealth = 15000, Damage = 70, WalkSpeed = 15,
		AttackRange = 9, Windup = 0.5, AttackCooldown = 1.0, AggroRange = 120, LeashRange = 250,
		XP = 3000, Gold = 1500, RespawnTime = 0,
		Appearance = { Skin = Color3.fromRGB(95, 60, 38), Shirt = Color3.fromRGB(80, 52, 34), Pants = Color3.fromRGB(60, 42, 30),
			Width = 1.3, Scale = 2.0, Weapon = Color3.fromRGB(150, 140, 130), WeaponLength = 5, Extras = { "Horns" }, ExtraColor = Color3.fromRGB(240, 230, 205) },
		Attacks = {
			{ Name = "Charge", Kind = "Charge", Windup = 0.9, Cooldown = 6, Range = 45, MinRange = 10, Length = 42, Width = 10, Damage = 95 },
			{ Name = "Slam", Kind = "Slam", Windup = 0.9, Cooldown = 7, Range = 14, Radius = 18, Damage = 85 },
		},
		Phase2 = { At = 0.5, CooldownMultiplier = 0.6, SpeedMultiplier = 1.3, Summon = { MinotaurBrute = 2 }, Message = "The Minotaur roars with rage!" },
	},

	CursedWarrior = {
		DisplayName = "Cursed Warrior", MaxHealth = 750, Damage = 50, WalkSpeed = 14,
		AttackRange = 6, Windup = 0.45, AttackCooldown = 1.0, AggroRange = 32, LeashRange = 60,
		XP = 1100, Gold = 450, RespawnTime = 0,
		Appearance = { Skin = Color3.fromRGB(120, 140, 110), Shirt = Color3.fromRGB(50, 70, 55), Pants = Color3.fromRGB(40, 45, 40),
			Width = 1.15, Weapon = Color3.fromRGB(120, 255, 150), WeaponLength = 4.5, Extras = { "Helmet" }, ExtraColor = Color3.fromRGB(60, 80, 65) },
	},
	Gorgon = {
		DisplayName = "Gorgon", MaxHealth = 600, Damage = 44, WalkSpeed = 13,
		AttackRange = 5.5, Windup = 0.45, AttackCooldown = 1.1, AggroRange = 34, LeashRange = 60,
		XP = 1200, Gold = 480, RespawnTime = 0,
		Appearance = { Skin = Color3.fromRGB(120, 170, 110), Shirt = Color3.fromRGB(70, 110, 70), Pants = Color3.fromRGB(60, 90, 60),
			Width = 0.95, Weapon = Color3.fromRGB(200, 200, 160), WeaponLength = 3.6, Extras = { "Snakes" }, ExtraColor = Color3.fromRGB(70, 160, 60) },
		Attacks = {
			{ Name = "Gaze", Kind = "Cone", Windup = 0.7, Cooldown = 6, Range = 20, MinRange = 4, Arc = 30, Damage = 35, Slow = 0.6, SlowTime = 2 },
		},
	},
	Medusa = {
		DisplayName = "Medusa", Boss = true, MaxHealth = 26000, Damage = 80, WalkSpeed = 13,
		AttackRange = 8, Windup = 0.45, AttackCooldown = 1.0, AggroRange = 120, LeashRange = 250,
		XP = 7000, Gold = 3500, RespawnTime = 0,
		Appearance = { Skin = Color3.fromRGB(110, 165, 105), Shirt = Color3.fromRGB(60, 100, 60), Pants = Color3.fromRGB(50, 85, 50),
			Width = 1.1, Scale = 1.8, Weapon = Color3.fromRGB(220, 220, 170), WeaponLength = 4.5, Extras = { "Snakes", "Crown" }, ExtraColor = Color3.fromRGB(80, 180, 60) },
		Attacks = {
			{ Name = "Gaze", Kind = "Cone", Windup = 0.9, Cooldown = 7, Range = 32, MinRange = 5, Arc = 35, Damage = 90, Slow = 0.4, SlowTime = 3 },
			{ Name = "TailSweep", Kind = "Slam", Windup = 0.8, Cooldown = 6, Range = 12, Radius = 16, Damage = 85 },
		},
		Phase2 = { At = 0.5, CooldownMultiplier = 0.6, SpeedMultiplier = 1.2, Summon = { Gorgon = 2 }, Message = "Medusa's sisters answer her call!" },
	},

	UndeadSoldier = {
		DisplayName = "Undead Soldier", MaxHealth = 1200, Damage = 70, WalkSpeed = 14,
		AttackRange = 6, Windup = 0.45, AttackCooldown = 1.0, AggroRange = 32, LeashRange = 60,
		XP = 2800, Gold = 1000, RespawnTime = 0,
		Appearance = { Skin = Color3.fromRGB(200, 195, 180), Shirt = Color3.fromRGB(60, 50, 70), Pants = Color3.fromRGB(45, 40, 55),
			Width = 0.85, Weapon = Color3.fromRGB(160, 90, 255), WeaponLength = 4.5, Extras = { "Helmet" }, ExtraColor = Color3.fromRGB(55, 50, 65) },
	},
	HellHound = {
		DisplayName = "Hellhound", Builder = "Beast", MaxHealth = 900, Damage = 65, WalkSpeed = 22,
		AttackRange = 5.5, Windup = 0.35, AttackCooldown = 0.9, AggroRange = 38, LeashRange = 60,
		XP = 2600, Gold = 950, RespawnTime = 0,
		Appearance = { Body = Color3.fromRGB(45, 30, 30), Accent = Color3.fromRGB(120, 30, 20), Eye = Color3.fromRGB(255, 120, 30), Size = 1.0, Heads = 1, Fire = true },
	},
	Cerberus = {
		DisplayName = "Cerberus", Boss = true, Builder = "Beast", MaxHealth = 45000, Damage = 100, WalkSpeed = 17,
		AttackRange = 11, Windup = 0.45, AttackCooldown = 1.0, AggroRange = 120, LeashRange = 250,
		XP = 16000, Gold = 7000, RespawnTime = 0,
		Appearance = { Body = Color3.fromRGB(40, 28, 28), Accent = Color3.fromRGB(110, 25, 20), Eye = Color3.fromRGB(255, 90, 20), Size = 2.6, Heads = 3, Fire = true },
		Attacks = {
			{ Name = "FireBreath", Kind = "Cone", Windup = 0.8, Cooldown = 6, Range = 28, MinRange = 4, Arc = 40, Damage = 115 },
			{ Name = "Pounce", Kind = "Slam", Windup = 0.8, Cooldown = 7, Range = 16, Radius = 18, Damage = 120 },
			{ Name = "Charge", Kind = "Charge", Windup = 0.8, Cooldown = 8, Range = 45, MinRange = 14, Length = 38, Width = 12, Damage = 105 },
		},
		Phase2 = { At = 0.5, CooldownMultiplier = 0.6, SpeedMultiplier = 1.25, Summon = { HellHound = 3 }, Message = "Cerberus howls for the hounds of the Underworld!" },
	},

	TitanWarrior = {
		DisplayName = "Titan Warrior", MaxHealth = 1900, Damage = 100, WalkSpeed = 13,
		AttackRange = 8, Windup = 0.5, AttackCooldown = 1.1, AggroRange = 34, LeashRange = 70,
		XP = 6000, Gold = 2200, RespawnTime = 0,
		Appearance = { Skin = Color3.fromRGB(170, 140, 120), Shirt = Color3.fromRGB(90, 90, 110), Pants = Color3.fromRGB(70, 70, 85),
			Width = 1.2, Scale = 1.5, Weapon = Color3.fromRGB(200, 200, 210), WeaponLength = 5, Extras = { "Helmet" }, ExtraColor = Color3.fromRGB(120, 120, 140) },
	},
	Cyclops = {
		DisplayName = "Cyclops", MaxHealth = 2300, Damage = 115, WalkSpeed = 12,
		AttackRange = 8.5, Windup = 0.55, AttackCooldown = 1.2, AggroRange = 34, LeashRange = 70,
		XP = 6800, Gold = 2500, RespawnTime = 0,
		Appearance = { Skin = Color3.fromRGB(150, 165, 130), Shirt = Color3.fromRGB(110, 90, 60), Pants = Color3.fromRGB(90, 70, 50),
			Width = 1.4, Scale = 1.6, Weapon = Color3.fromRGB(110, 85, 60), WeaponLength = 4.5, Extras = { "Eye" }, ExtraColor = Color3.fromRGB(255, 255, 255) },
	},
	TitanKing = {
		DisplayName = "The Titan King", Boss = true, MaxHealth = 90000, Damage = 150, WalkSpeed = 14,
		AttackRange = 15, Windup = 0.55, AttackCooldown = 1.1, AggroRange = 150, LeashRange = 300,
		XP = 40000, Gold = 15000, RespawnTime = 0,
		Appearance = { Skin = Color3.fromRGB(180, 150, 120), Shirt = Color3.fromRGB(70, 60, 90), Pants = Color3.fromRGB(55, 45, 70),
			Width = 1.3, Scale = 3.0, Weapon = Color3.fromRGB(255, 170, 60), WeaponLength = 5.5, Extras = { "Crown" }, ExtraColor = Color3.fromRGB(212, 175, 55) },
		Attacks = {
			{ Name = "Meteors", Kind = "Meteors", Windup = 1.2, Cooldown = 8, Range = 70, Count = 6, Radius = 8, Damage = 150 },
			{ Name = "Slam", Kind = "Slam", Windup = 0.9, Cooldown = 7, Range = 20, Radius = 24, Damage = 180 },
			{ Name = "Charge", Kind = "Charge", Windup = 0.9, Cooldown = 9, Range = 60, MinRange = 18, Length = 50, Width = 14, Damage = 160 },
		},
		Phase2 = { At = 0.5, CooldownMultiplier = 0.6, SpeedMultiplier = 1.2, Summon = { TitanWarrior = 2 }, Message = "The Titan King summons his titans!" },
	},

	-- Demigod trial boss: shown as "Avatar of <your god>".
	DivineAvatar = {
		DisplayName = "Divine Avatar", Boss = true, MaxHealth = 30000, Damage = 85, WalkSpeed = 16,
		AttackRange = 8, Windup = 0.45, AttackCooldown = 0.9, AggroRange = 120, LeashRange = 250,
		XP = 0, Gold = 0, RespawnTime = 0,
		Appearance = { Skin = Color3.fromRGB(255, 240, 200), Shirt = Color3.fromRGB(240, 230, 210), Pants = Color3.fromRGB(212, 175, 55),
			Width = 1.2, Scale = 1.7, Weapon = Color3.fromRGB(255, 240, 160), WeaponLength = 5, Extras = { "Crown" }, ExtraColor = Color3.fromRGB(255, 220, 90) },
		Attacks = {
			{ Name = "Judgment", Kind = "Meteors", Windup = 1.1, Cooldown = 8, Range = 60, Count = 4, Radius = 7, Damage = 100 },
			{ Name = "Slam", Kind = "Slam", Windup = 0.8, Cooldown = 6, Range = 12, Radius = 16, Damage = 95 },
		},
		Phase2 = { At = 0.5, CooldownMultiplier = 0.6, SpeedMultiplier = 1.2, Message = "The Avatar blazes with divine power!" },
	},
	TrainingDummy = {
		DisplayName = "Training Dummy",
		MaxHealth = 500,
		Damage = 0,
		WalkSpeed = 0,
		Passive = true,   -- never moves or attacks
		Immortal = true,  -- when "knocked out" it pops straight back up instead of dying
		Builder = "Dummy", -- a wooden training dummy instead of a character
		RegenDelay = 3,   -- heals fully after 3 seconds without being hit
		XP = 0,
		Gold = 0,
		RespawnTime = 0,
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
