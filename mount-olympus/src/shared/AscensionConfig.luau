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
		Description = "Three brutal waves, then a champion at full strength. (Placeholder enemies until Phase 7.)",
		Available = true,
		Color = Color3.fromRGB(180, 55, 45),
		Waves = {
			{ Bandit = 4, Skeleton = 2 },
			{ Bandit = 5, Skeleton = 4 },
			{ Boss = "TrainingChampion", Skeleton = 3 },
		},
		WaveHealth = { 3, 3.5, 4 },
		WaveDamage = { 2, 2.2, 2.5 },
		WaveSpeed = { 1.2, 1.25, 1.3 },
		BossHealth = 2, -- the champion has double health here
	},
	[4] = { Id = "Minotaur", Name = "Defeat the Minotaur", Description = "The Minotaur arrives in Phase 7.", Available = false },
	[5] = { Id = "DivineTrial", Name = "Complete your god's Divine Trial", Description = "Divine Trials arrive in Phase 7.", Available = false },
	[6] = { Id = "Cerberus", Name = "Defeat Cerberus", Description = "Cerberus arrives in Phase 7.", Available = false },
	[7] = { Id = "OlympianGauntlet", Name = "Complete the Olympian Gauntlet", Description = "The Gauntlet arrives in Phase 7.", Available = false },
	[8] = { Id = "TitanKing", Name = "Defeat the Titan King", Description = "The Titan King arrives in Phase 7.", Available = false },
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
