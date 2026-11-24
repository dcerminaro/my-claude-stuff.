-- Zeus (ModuleScript)
-- Location: ReplicatedStorage > Shared > Gods > Zeus
--
-- One god = one config module. Blessing tiers 1-5 follow the shared rules
-- in GodConfig (costs, Altar level, Loyalty and rank requirements).
-- Ability = which control the blessing's ability will use (Phase 4).
-- Passive = a permanent stat bonus per blessing level, active NOW while
-- Zeus is your god: AttackPercent, HealthPercent or SpeedPercent.

return {
	Id = "Zeus",
	DisplayName = "Zeus",
	Title = "God of Thunder",
	Specialty = "Lightning and burst damage.",
	Available = true,

	Colors = {
		Primary = Color3.fromRGB(90, 170, 255),  -- menus and badges
		Accent = Color3.fromRGB(212, 175, 55),   -- metal trim on your temple
		Glow = Color3.fromRGB(90, 170, 255),     -- glowing parts on your temple
		Fire = Color3.fromRGB(120, 180, 255),    -- temple flames
	},

	Blessings = {
		{ Id = "LightningStrike", Name = "Lightning Strike", Tier = 1, Ability = "Q",
			Description = "Call down a bolt of lightning.", Passive = { Stat = "AttackPercent", PerLevel = 3 } },
		{ Id = "ThunderDash", Name = "Thunder Dash", Tier = 2, Ability = "Dash",
			Description = "Dash forward as a streak of thunder.", Passive = { Stat = "SpeedPercent", PerLevel = 4 } },
		{ Id = "ChainLightning", Name = "Chain Lightning", Tier = 3, Ability = "E",
			Description = "Lightning that leaps between enemies.", Passive = { Stat = "AttackPercent", PerLevel = 4 } },
		{ Id = "WrathOfOlympus", Name = "Wrath of Olympus", Tier = 4, Ability = "R",
			Description = "A storm of lightning around you (ultimate).", Passive = { Stat = "AttackPercent", PerLevel = 6 } },
		{ Id = "AscendedThunderForm", Name = "Ascended Thunder Form", Tier = 5, Ability = "Form",
			Description = "Become living lightning for a short time.", Passive = { Stat = "SpeedPercent", PerLevel = 5 } },
	},
}
