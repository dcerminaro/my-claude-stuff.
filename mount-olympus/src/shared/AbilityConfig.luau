-- AbilityConfig (ModuleScript)
-- Location: ReplicatedStorage > Shared > AbilityConfig
--
-- Numbers for the god abilities (Phase 4B). Each ability belongs to the
-- blessing with the same Id (see Shared > Gods), and its slot comes from
-- that blessing's `Ability` field (Q, Dash, E, R or Form).
-- Damage = BaseAttack (level + blessings) x (1 + Training Grounds bonus)
--          x (1 + active buffs) x (Damage + PerLevel x (blessing level - 1)).
-- All numbers are PLACEHOLDERS, balanced in Phase 8.

local AbilityConfig = {}

-- Keyboard and controller keys for each slot (touch screens get buttons).
AbilityConfig.Keys = {
	Q = { Enum.KeyCode.Q, Enum.KeyCode.ButtonL1 },
	E = { Enum.KeyCode.E, Enum.KeyCode.ButtonR1 },
	R = { Enum.KeyCode.R, Enum.KeyCode.ButtonY },
	Form = { Enum.KeyCode.T, Enum.KeyCode.DPadUp },
}
AbilityConfig.SlotOrder = { "Q", "E", "R", "Form" }
AbilityConfig.KeyLabels = { Q = "Q", E = "E", R = "R", Form = "T" }

AbilityConfig.Abilities = {
	------------------------------------------------------------------ Zeus
	LightningStrike = {
		Kind = "Strike", Move = "Cast", Cooldown = 6,
		Damage = 2.2, PerLevel = 0.4,
		Range = 28,  -- how far away it can target an enemy
		Radius = 6,  -- splash around the strike
	},
	ThunderDash = {
		Kind = "DashHit", Cooldown = 4,
		Damage = 1.2, PerLevel = 0.3,
		Width = 6, Distance = 11, Knockback = 8,
	},
	ChainLightning = {
		Kind = "Chain", Move = "Lunge", Cooldown = 9,
		Damage = 1.6, PerLevel = 0.3,
		Range = 22, JumpRange = 14, Jumps = 3, JumpsPerLevel = 1,
		Falloff = 0.85, -- each jump does 85% of the previous one
	},
	WrathOfOlympus = {
		Kind = "Storm", Move = "Cast", Cooldown = 30,
		Damage = 1.1, PerLevel = 0.25,
		Radius = 20, Pulses = 5, Interval = 0.5,
	},
	AscendedThunderForm = {
		Kind = "Buff", Move = "Cast", Cooldown = 60, Duration = 12,
		AttackPercent = 40, AttackPerLevel = 10, SpeedPercent = 25,
	},

	------------------------------------------------------------------ Ares
	WarSlash = {
		Kind = "Cleave", Move = "Cleave", Cooldown = 5,
		Damage = 2.4, PerLevel = 0.4,
		Range = 11, ArcDot = -0.2, -- about 200 degrees in front
		Knockback = 16,
	},
	BattleCharge = {
		Kind = "DashHit", Cooldown = 4,
		Damage = 1.4, PerLevel = 0.3,
		Width = 6, Distance = 11, Knockback = 22,
	},
	BerserkerRage = {
		Kind = "Buff", Move = "Cast", Cooldown = 18, Duration = 8,
		AttackPercent = 35, AttackPerLevel = 10, SpeedPercent = 15,
	},
	GodOfWar = {
		Kind = "Slam", Move = "Slam", Cooldown = 25,
		Damage = 3.5, PerLevel = 0.6,
		Radius = 14, Delay = 0.5, -- lands when the sword hits the ground
		Knockback = 28,
	},
	DivineWarlordForm = {
		Kind = "Buff", Move = "Cast", Cooldown = 60, Duration = 12,
		AttackPercent = 30, AttackPerLevel = 10, DamageTaken = 0.7, -- take 30% less damage
	},

	------------------------------------------------------------------ Poseidon (Phase 7A)
	WaterBlast = {
		Kind = "Line", Move = "Lunge", Cooldown = 6,
		Damage = 2.0, PerLevel = 0.35,
		Range = 26, Width = 4, Pierce = 3, Knockback = 14,
	},
	TidalDash = {
		Kind = "DashHit", Cooldown = 4,
		Damage = 1.2, PerLevel = 0.3,
		Width = 7, Distance = 11, Knockback = 24,
	},
	Whirlpool = {
		Kind = "Pull", Move = "Cast", Cooldown = 12,
		Damage = 0.6, PerLevel = 0.15, -- per tick
		Offset = 10, Radius = 11, Ticks = 5, Interval = 0.5,
		Slow = 0.5, SlowTime = 3, -- enemies walk at 50% for 3 s
	},
	DivineTsunami = {
		Kind = "Cone", Move = "Cleave", Cooldown = 28,
		Damage = 3.2, PerLevel = 0.5,
		Range = 22, ArcDot = 0.35, Knockback = 35,
	},
	OceanicAscension = {
		Kind = "Buff", Move = "Cast", Cooldown = 60, Duration = 12,
		AttackPercent = 15, AttackPerLevel = 5, DamageTaken = 0.7, RegenPercent = 2,
	},

	------------------------------------------------------------------ Hades (Phase 7A)
	ShadowStrike = {
		Kind = "Strike", Move = "Lunge", Cooldown = 6,
		Damage = 2.0, PerLevel = 0.35,
		Range = 20, Radius = 4, LifeSteal = 0.3, -- heals 30% of the damage dealt
	},
	SoulDrain = {
		Kind = "DashHit", Cooldown = 4,
		Damage = 1.1, PerLevel = 0.3,
		Width = 6, Distance = 11, Knockback = 8, LifeSteal = 0.5,
	},
	SummonUndead = {
		Kind = "Summon", Move = "Cast", Cooldown = 20,
		Damage = 0.6, PerLevel = 0.15, -- per spirit, per second
		Count = 2, CountPerLevel = 0.5, Duration = 15, Interval = 1, Range = 16,
	},
	ArmyOfTheDead = {
		Kind = "Storm", Move = "Slam", Cooldown = 30,
		Damage = 0.9, PerLevel = 0.2,
		Radius = 18, Pulses = 6, Interval = 0.5, LifeSteal = 0.25,
	},
	UnderworldAscension = {
		Kind = "Buff", Move = "Cast", Cooldown = 60, Duration = 12,
		AttackPercent = 30, AttackPerLevel = 10, LifeSteal = 0.2,
	},

	------------------------------------------------------------------ Athena (Phase 7A)
	SpearStrike = {
		Kind = "Line", Move = "Lunge", Cooldown = 5,
		Damage = 2.6, PerLevel = 0.45,
		Range = 16, Width = 3, Pierce = 2, Knockback = 10,
	},
	DivineShield = {
		Kind = "DashHit", Cooldown = 5,
		Damage = 0.8, PerLevel = 0.2,
		Width = 6, Distance = 11, Knockback = 14,
		ShieldTime = 3, ShieldDamageTaken = 0.5, -- take 50% damage for 3 s
	},
	Counterattack = {
		Kind = "Counter", Move = "Cast", Cooldown = 10,
		Duration = 2.5, Damage = 2.5, PerLevel = 0.5, -- each parried hit strikes back for this x attack
	},
	AegisOfOlympus = {
		Kind = "Aegis", Move = "Slam", Cooldown = 30,
		Damage = 2.0, PerLevel = 0.4,
		Radius = 14, Duration = 6, DamageTaken = 0.4, Knockback = 30,
	},
	DivineGuardianForm = {
		Kind = "Buff", Move = "Cast", Cooldown = 60, Duration = 12,
		AttackPercent = 25, AttackPerLevel = 5, DamageTaken = 0.6,
	},

	------------------------------------------------------------------ Apollo (Phase 7A)
	SolarArrow = {
		Kind = "Line", Move = "Lunge", Cooldown = 5,
		Damage = 2.0, PerLevel = 0.35,
		Range = 40, Width = 3, Pierce = 3, Knockback = 6,
	},
	RadiantDash = {
		Kind = "DashHit", Cooldown = 4,
		Damage = 1.0, PerLevel = 0.25,
		Width = 6, Distance = 11, Knockback = 8, HealPercent = 8, -- heals 8% of max health
	},
	HealingLight = {
		Kind = "Heal", Move = "Cast", Cooldown = 15,
		Radius = 20, HealPercent = 25, HealPerLevel = 5,
	},
	SolarJudgment = {
		Kind = "Storm", Move = "Cast", Cooldown = 30,
		Damage = 1.2, PerLevel = 0.25,
		Radius = 24, Pulses = 6, Interval = 0.4, Straight = true, -- straight sunbeams
	},
	SunGodForm = {
		Kind = "Buff", Move = "Cast", Cooldown = 60, Duration = 12,
		AttackPercent = 25, AttackPerLevel = 5, SpeedPercent = 20, RegenPercent = 2,
	},
}

for id, ability in AbilityConfig.Abilities do
	ability.Id = id
end

function AbilityConfig.DamageMultiplier(abilityId, level)
	local a = AbilityConfig.Abilities[abilityId]
	if not a or not a.Damage then
		return 0
	end
	return a.Damage + (a.PerLevel or 0) * (math.max(level, 1) - 1)
end

return AbilityConfig
