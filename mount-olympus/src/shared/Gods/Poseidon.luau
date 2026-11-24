-- Poseidon (ModuleScript)
-- Location: ReplicatedStorage > Shared > Gods > Poseidon
-- See Zeus for what each field means. Phase 7A: playable.

return {
	Id = "Poseidon",
	DisplayName = "Poseidon",
	Title = "God of the Sea",
	Specialty = "Water damage and crowd control.",
	Available = true,

	Colors = {
		Primary = Color3.fromRGB(40, 170, 210),
		Accent = Color3.fromRGB(60, 160, 190),
		Glow = Color3.fromRGB(60, 220, 230),
		Fire = Color3.fromRGB(80, 200, 255),
	},

	Blessings = {
		{ Id = "WaterBlast", Name = "Water Blast", Tier = 1, Ability = "Q",
			Description = "A blast of water that pierces a line of enemies.", Passive = { Stat = "AttackPercent", PerLevel = 3 } },
		{ Id = "TidalDash", Name = "Tidal Dash", Tier = 2, Ability = "Dash",
			Description = "Ride a wave forward, sweeping enemies aside.", Passive = { Stat = "HealthPercent", PerLevel = 4 } },
		{ Id = "Whirlpool", Name = "Whirlpool", Tier = 3, Ability = "E",
			Description = "Drag enemies into a whirlpool and slow them.", Passive = { Stat = "AttackPercent", PerLevel = 4 } },
		{ Id = "DivineTsunami", Name = "Divine Tsunami", Tier = 4, Ability = "R",
			Description = "A huge wave crashes forward (ultimate).", Passive = { Stat = "HealthPercent", PerLevel = 6 } },
		{ Id = "OceanicAscension", Name = "Oceanic Ascension", Tier = 5, Ability = "Form",
			Description = "Become the tide: take less damage and heal.", Passive = { Stat = "AttackPercent", PerLevel = 5 } },
	},
}
