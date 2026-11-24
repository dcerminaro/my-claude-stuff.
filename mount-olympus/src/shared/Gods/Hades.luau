-- Hades (ModuleScript)
-- Location: ReplicatedStorage > Shared > Gods > Hades
-- See Zeus for what each field means. Phase 7A: playable.

return {
	Id = "Hades",
	DisplayName = "Hades",
	Title = "God of the Underworld",
	Specialty = "Shadow damage, life stealing, and summoning.",
	Available = true,

	Colors = {
		Primary = Color3.fromRGB(150, 80, 230),
		Accent = Color3.fromRGB(90, 60, 120),
		Glow = Color3.fromRGB(160, 80, 255),
		Fire = Color3.fromRGB(150, 60, 255),
	},

	Blessings = {
		{ Id = "ShadowStrike", Name = "Shadow Strike", Tier = 1, Ability = "Q",
			Description = "Strike from the shadows and steal life.", Passive = { Stat = "AttackPercent", PerLevel = 3 } },
		{ Id = "SoulDrain", Name = "Soul Drain", Tier = 2, Ability = "Dash",
			Description = "Pass through enemies, draining their souls.", Passive = { Stat = "HealthPercent", PerLevel = 5 } },
		{ Id = "SummonUndead", Name = "Summon Undead", Tier = 3, Ability = "E",
			Description = "Spectral skulls fight beside you.", Passive = { Stat = "AttackPercent", PerLevel = 4 } },
		{ Id = "ArmyOfTheDead", Name = "Army of the Dead", Tier = 4, Ability = "R",
			Description = "The dead rise around you, draining everything nearby (ultimate).", Passive = { Stat = "AttackPercent", PerLevel = 5 } },
		{ Id = "UnderworldAscension", Name = "Underworld Ascension", Tier = 5, Ability = "Form",
			Description = "Become death itself: more attack and life steal.", Passive = { Stat = "HealthPercent", PerLevel = 7 } },
	},
}
