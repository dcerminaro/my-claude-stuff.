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
