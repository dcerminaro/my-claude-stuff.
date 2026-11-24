-- Apollo (ModuleScript)
-- Location: ReplicatedStorage > Shared > Gods > Apollo
-- See Zeus for what each field means. Phase 7A: playable.

return {
	Id = "Apollo",
	DisplayName = "Apollo",
	Title = "God of the Sun",
	Specialty = "Ranged damage and healing.",
	Available = true,

	Colors = {
		Primary = Color3.fromRGB(245, 190, 40),
		Accent = Color3.fromRGB(240, 190, 40),
		Glow = Color3.fromRGB(255, 220, 90),
		Fire = Color3.fromRGB(255, 200, 80),
	},

	Blessings = {
		{ Id = "SolarArrow", Name = "Solar Arrow", Tier = 1, Ability = "Q",
			Description = "A long-range arrow of sunlight that pierces enemies.", Passive = { Stat = "AttackPercent", PerLevel = 3 } },
		{ Id = "RadiantDash", Name = "Radiant Dash", Tier = 2, Ability = "Dash",
			Description = "Dash as light, healing yourself.", Passive = { Stat = "SpeedPercent", PerLevel = 4 } },
		{ Id = "HealingLight", Name = "Healing Light", Tier = 3, Ability = "E",
			Description = "Heal yourself and nearby allies.", Passive = { Stat = "HealthPercent", PerLevel = 5 } },
		{ Id = "SolarJudgment", Name = "Solar Judgment", Tier = 4, Ability = "R",
			Description = "Sunbeams strike the enemies around you (ultimate).", Passive = { Stat = "AttackPercent", PerLevel = 6 } },
		{ Id = "SunGodForm", Name = "Sun God Form", Tier = 5, Ability = "Form",
			Description = "Shine like the sun: attack, speed and healing.", Passive = { Stat = "SpeedPercent", PerLevel = 5 } },
	},
}
