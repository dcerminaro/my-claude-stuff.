-- Athena (ModuleScript)
-- Location: ReplicatedStorage > Shared > Gods > Athena
-- See Zeus for what each field means. Phase 7A: playable.

return {
	Id = "Athena",
	DisplayName = "Athena",
	Title = "Goddess of Wisdom",
	Specialty = "Defense, precision, and counterattacks.",
	Available = true,

	Colors = {
		Primary = Color3.fromRGB(190, 195, 215),
		Accent = Color3.fromRGB(200, 200, 210),
		Glow = Color3.fromRGB(255, 240, 200),
		Fire = Color3.fromRGB(255, 240, 200),
	},

	Blessings = {
		{ Id = "SpearStrike", Name = "Spear Strike", Tier = 1, Ability = "Q",
			Description = "A long, precise spear thrust.", Passive = { Stat = "AttackPercent", PerLevel = 3 } },
		{ Id = "DivineShield", Name = "Divine Shield", Tier = 2, Ability = "Dash",
			Description = "Dash behind your shield and take less damage.", Passive = { Stat = "HealthPercent", PerLevel = 5 } },
		{ Id = "Counterattack", Name = "Counterattack", Tier = 3, Ability = "E",
			Description = "Parry the next attacks and strike back hard.", Passive = { Stat = "AttackPercent", PerLevel = 4 } },
		{ Id = "AegisOfOlympus", Name = "Aegis of Olympus", Tier = 4, Ability = "R",
			Description = "A great shield protects you and your allies and blasts enemies away (ultimate).", Passive = { Stat = "HealthPercent", PerLevel = 8 } },
		{ Id = "DivineGuardianForm", Name = "Divine Guardian Form", Tier = 5, Ability = "Form",
			Description = "Become an unbreakable guardian.", Passive = { Stat = "AttackPercent", PerLevel = 5 } },
	},
}
