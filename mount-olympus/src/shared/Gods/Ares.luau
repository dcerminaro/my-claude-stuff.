-- Ares (ModuleScript)
-- Location: ReplicatedStorage > Shared > Gods > Ares
-- See Zeus for what each field means.

return {
	Id = "Ares",
	DisplayName = "Ares",
	Title = "God of War",
	Specialty = "Melee combat and aggressive damage.",
	Available = true,

	Colors = {
		Primary = Color3.fromRGB(215, 60, 45),
		Accent = Color3.fromRGB(175, 105, 50),  -- bronze
		Glow = Color3.fromRGB(235, 70, 40),
		Fire = Color3.fromRGB(255, 90, 40),
	},

	Blessings = {
		{ Id = "WarSlash", Name = "War Slash", Tier = 1, Ability = "Q",
			Description = "A brutal sweeping strike.", Passive = { Stat = "AttackPercent", PerLevel = 3 } },
		{ Id = "BattleCharge", Name = "Battle Charge", Tier = 2, Ability = "Dash",
			Description = "Charge into enemies, knocking them back.", Passive = { Stat = "HealthPercent", PerLevel = 5 } },
		{ Id = "BerserkerRage", Name = "Berserker Rage", Tier = 3, Ability = "E",
			Description = "Hit harder and faster for a while.", Passive = { Stat = "AttackPercent", PerLevel = 4 } },
		{ Id = "GodOfWar", Name = "God of War", Tier = 4, Ability = "R",
			Description = "Unleash the fury of war (ultimate).", Passive = { Stat = "HealthPercent", PerLevel = 8 } },
		{ Id = "DivineWarlordForm", Name = "Divine Warlord Form", Tier = 5, Ability = "Form",
			Description = "Become an unstoppable warlord for a short time.", Passive = { Stat = "AttackPercent", PerLevel = 6 } },
	},
}
