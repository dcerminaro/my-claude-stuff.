-- AscensionConfig (ModuleScript)
-- Location: ReplicatedStorage > Shared > AscensionConfig
--
-- Phase 6: ascension trials, rank looks (outfit + physique + aura).
-- Ranks themselves (names, level ranges) are in GameConfig.Ranks.
-- To rank up: reach the top level of your rank, then win the trial for the
-- NEXT rank. Trials are short solo arena runs (see ArenaService.StartTrial).
-- All numbers are PLACEHOLDERS, balanced in Phase 8.

local AscensionConfig = {}

-- Trial for reaching rank N (index = rank number, 2 = Warrior ... 8 = Elder God).
-- Ids match GameConfig.Ranks[N].Trial.
AscensionConfig.Trials = {
	[2] = {
		Id = "TrainingChampion",
		Name = "Defeat the Training Champion",
		Description = "Face the Training Champion alone.",
		Available = true,
		Color = Color3.fromRGB(205, 150, 60),
		Waves = { { Boss = "TrainingChampion" } },
	},
	[3] = {
		Id = "SpartanArena",
		Name = "Complete the Spartan Arena trial",
		Description = "Survive the Spartan phalanx, then defeat the Spartan Warlord.",
		Available = true,
		Color = Color3.fromRGB(180, 55, 45),
		Theme = { Floor = Color3.fromRGB(170, 140, 100), Wall = Color3.fromRGB(150, 110, 75), Fire = Color3.fromRGB(255, 120, 40) },
		Waves = {
			{ SpartanSoldier = 4, WarHound = 2 },
			{ SpartanSoldier = 5, WarHound = 3 },
			{ Boss = "SpartanWarlord", SpartanSoldier = 2 },
		},
		WaveHealth = { 1.2, 1.4, 1.5 },
		WaveDamage = { 1.1, 1.2, 1.3 },
	},
	[4] = {
		Id = "Minotaur",
		Name = "Defeat the Minotaur",
		Description = "Face the Minotaur alone in its labyrinth.",
		Available = true,
		Color = Color3.fromRGB(150, 120, 90),
		Theme = { Floor = Color3.fromRGB(120, 115, 105), Wall = Color3.fromRGB(95, 90, 82), Fire = Color3.fromRGB(255, 160, 60) },
		Radius = 50,
		Waves = { { Boss = "Minotaur" } },
	},
	[5] = {
		Id = "DivineTrial",
		Name = "Complete your god's Divine Trial",
		Description = "Prove yourself to your god: two waves of cursed foes, then your god's own Avatar.",
		Available = true,
		Divine = true, -- the boss is named "Avatar of <your god>"
		Color = Color3.fromRGB(255, 220, 120),
		Theme = { Floor = Color3.fromRGB(235, 230, 215), Wall = Color3.fromRGB(212, 175, 55), Fire = Color3.fromRGB(255, 240, 180) },
		Radius = 50,
		Waves = {
			{ CursedWarrior = 3, Gorgon = 2 },
			{ UndeadSoldier = 3, HellHound = 2 },
			{ Boss = "DivineAvatar" },
		},
		WaveHealth = { 0.8, 0.8, 1 },
		WaveDamage = { 0.8, 0.8, 1 },
	},
	[6] = {
		Id = "Cerberus",
		Name = "Defeat Cerberus",
		Description = "Slay the three-headed guardian of the Underworld.",
		Available = true,
		Color = Color3.fromRGB(150, 80, 230),
		Theme = { Floor = Color3.fromRGB(50, 40, 55), Wall = Color3.fromRGB(35, 28, 40), Fire = Color3.fromRGB(160, 80, 255) },
		Radius = 55,
		Waves = { { Boss = "Cerberus" } },
	},
	[7] = {
		Id = "OlympianGauntlet",
		Name = "Complete the Olympian Gauntlet",
		Description = "Three legends in a row: the Minotaur, Medusa and Cerberus.",
		Available = true,
		Color = Color3.fromRGB(200, 150, 20),
		Theme = { Floor = Color3.fromRGB(235, 230, 215), Wall = Color3.fromRGB(200, 170, 90), Fire = Color3.fromRGB(255, 220, 120) },
		Radius = 55,
		Waves = { { Boss = "Minotaur" }, { Boss = "Medusa" }, { Boss = "Cerberus" } },
		BossHealth = 1.2,
	},
	[8] = {
		Id = "TitanKing",
		Name = "Defeat the Titan King",
		Description = "The final trial: overthrow the Titan King.",
		Available = true,
		Color = Color3.fromRGB(230, 120, 20),
		Theme = { Floor = Color3.fromRGB(200, 185, 150), Wall = Color3.fromRGB(170, 150, 110), Fire = Color3.fromRGB(255, 200, 80) },
		Radius = 65,
		Waves = { { Boss = "TitanKing" } },
	},
}

-- Body size per rank, multiplying the player's own avatar proportions.
-- Wider/deeper grows faster than height: a bigger, more powerful build.
AscensionConfig.Physique = {}
for rank = 1, 8 do
	AscensionConfig.Physique[rank] = {
		Height = 1 + 0.03 * (rank - 1),
		Width = 1 + 0.05 * (rank - 1),
		Depth = 1 + 0.04 * (rank - 1),
		Head = 1 + 0.01 * (rank - 1),
	}
end

-- Shown in the Ascension Chamber.
AscensionConfig.Perks = {
	[1] = "Your journey begins.",
	[2] = "Leather shoulder pads, bracers and belt · a stronger build",
	[3] = "Bronze chest plate and greaves",
	[4] = "A hero's red cape",
	[5] = "Steel armour, a glowing chest gem and a divine aura",
	[6] = "Golden armour, a laurel wreath and a cape in your god's colour",
	[7] = "Wings of light",
	[8] = "A halo and a blazing aura",
}

-- Aura particles per second from Demigod upwards.
AscensionConfig.AuraRate = { [5] = 4, [6] = 6, [7] = 9, [8] = 14 }

return AscensionConfig
