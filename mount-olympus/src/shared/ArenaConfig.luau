-- ArenaConfig (ModuleScript)
-- Location: ReplicatedStorage > Shared > ArenaConfig
--
-- The PvE arenas (Phase 5). Each arena: 5 waves, the last with a boss.
-- Waves list enemy types (from CombatConfig.Enemies) and how many; "Boss"
-- names the boss. Add an arena by adding an entry and setting Available.
-- All numbers are PLACEHOLDERS, balanced in Phase 8.

local ArenaConfig = {}

ArenaConfig.Arenas = {
	{
		Id = "MortalTrainingPit",
		DisplayName = "Mortal Training Pit",
		Description = "Bandits and skeletons. Defeat the Training Champion!",
		MinLevel = 1,
		MaxLevel = 15,
		Available = true,
		Color = Color3.fromRGB(205, 120, 60),
		Waves = {
			{ Bandit = 2 },
			{ Bandit = 3, Skeleton = 1 },
			{ Bandit = 2, Skeleton = 3 },
			{ Bandit = 4, Skeleton = 3 },
			{ Boss = "TrainingChampion", Bandit = 2 },
		},
		-- Each wave is harder than the last (wave 1 is a warm-up).
		-- Multiplies normal enemies' health and damage; the boss is not scaled.
		WaveHealth = { 0.7, 0.9, 1.15, 1.4, 1.7 },
		WaveDamage = { 0.6, 0.8, 1.0, 1.2, 1.4 },
		WaveSpeed = { 0.9, 1.0, 1.1, 1.2, 1.3 }, -- walking speed
		-- Completion rewards (on top of what each enemy drops).
		Rewards = { XP = 250, Gold = 200, DivineFavor = 15, Ambrosia = 1 },
	},
	-- RequiredRank (Phase 6): the ascension rank needed to enter (2 = Warrior ...).
	-- Theme (Phase 7B): floor, wall and torch-fire colours. Radius: arena size.
	{
		Id = "SpartanBattleground", DisplayName = "Spartan Battleground", Description = "Spartan soldiers and war hounds. Defeat the Spartan Warlord!",
		MinLevel = 16, MaxLevel = 35, RequiredRank = 2, Available = true, Color = Color3.fromRGB(190, 60, 45),
		Theme = { Floor = Color3.fromRGB(170, 140, 100), Wall = Color3.fromRGB(150, 110, 75), Fire = Color3.fromRGB(255, 120, 40) },
		Waves = {
			{ SpartanSoldier = 3 },
			{ SpartanSoldier = 3, WarHound = 2 },
			{ SpartanSoldier = 4, WarHound = 3 },
			{ SpartanSoldier = 5, WarHound = 4 },
			{ Boss = "SpartanWarlord", SpartanSoldier = 2 },
		},
		WaveHealth = { 0.7, 0.9, 1.15, 1.4, 1.7 },
		WaveDamage = { 0.6, 0.8, 1.0, 1.2, 1.4 },
		WaveSpeed = { 0.9, 1.0, 1.1, 1.2, 1.3 },
		Rewards = { XP = 1500, Gold = 1200, DivineFavor = 60, Ambrosia = 2 },
	},
	{
		Id = "LabyrinthOfCrete", DisplayName = "Labyrinth of Crete", Description = "Stone guardians and minotaur brutes. Defeat the Minotaur!",
		MinLevel = 36, MaxLevel = 60, RequiredRank = 3, Available = true, Color = Color3.fromRGB(150, 120, 90),
		Theme = { Floor = Color3.fromRGB(120, 115, 105), Wall = Color3.fromRGB(95, 90, 82), Fire = Color3.fromRGB(255, 160, 60) },
		Radius = 50,
		Waves = {
			{ LabyrinthGuardian = 3 },
			{ LabyrinthGuardian = 2, MinotaurBrute = 2 },
			{ LabyrinthGuardian = 3, MinotaurBrute = 3 },
			{ LabyrinthGuardian = 4, MinotaurBrute = 4 },
			{ Boss = "Minotaur", MinotaurBrute = 2 },
		},
		WaveHealth = { 0.7, 0.9, 1.15, 1.4, 1.7 },
		WaveDamage = { 0.6, 0.8, 1.0, 1.2, 1.4 },
		WaveSpeed = { 0.9, 1.0, 1.1, 1.2, 1.3 },
		Rewards = { XP = 6000, Gold = 5000, DivineFavor = 150, Ambrosia = 3 },
	},
	{
		Id = "CursedTemple", DisplayName = "Cursed Temple", Description = "Cursed warriors and gorgons. Defeat Medusa!",
		MinLevel = 61, MaxLevel = 90, RequiredRank = 4, Available = true, Color = Color3.fromRGB(80, 170, 90),
		Theme = { Floor = Color3.fromRGB(80, 95, 80), Wall = Color3.fromRGB(55, 70, 58), Fire = Color3.fromRGB(110, 255, 120) },
		Radius = 50,
		Waves = {
			{ CursedWarrior = 3 },
			{ CursedWarrior = 2, Gorgon = 2 },
			{ CursedWarrior = 3, Gorgon = 3 },
			{ CursedWarrior = 4, Gorgon = 4 },
			{ Boss = "Medusa", Gorgon = 2 },
		},
		WaveHealth = { 0.7, 0.9, 1.15, 1.4, 1.7 },
		WaveDamage = { 0.6, 0.8, 1.0, 1.2, 1.4 },
		WaveSpeed = { 0.9, 1.0, 1.1, 1.2, 1.3 },
		Rewards = { XP = 20000, Gold = 15000, DivineFavor = 400, Ambrosia = 5 },
	},
	{
		Id = "GatesOfTheUnderworld", DisplayName = "Gates of the Underworld", Description = "Undead soldiers and hellhounds. Defeat Cerberus!",
		MinLevel = 91, MaxLevel = 135, RequiredRank = 5, Available = true, Color = Color3.fromRGB(150, 80, 230),
		Theme = { Floor = Color3.fromRGB(50, 40, 55), Wall = Color3.fromRGB(35, 28, 40), Fire = Color3.fromRGB(160, 80, 255) },
		Radius = 55,
		Waves = {
			{ UndeadSoldier = 3 },
			{ UndeadSoldier = 3, HellHound = 2 },
			{ UndeadSoldier = 3, HellHound = 3 },
			{ UndeadSoldier = 4, HellHound = 4 },
			{ Boss = "Cerberus", HellHound = 2 },
		},
		WaveHealth = { 0.7, 0.9, 1.15, 1.4, 1.7 },
		WaveDamage = { 0.6, 0.8, 1.0, 1.2, 1.4 },
		WaveSpeed = { 0.9, 1.0, 1.1, 1.2, 1.3 },
		Rewards = { XP = 60000, Gold = 40000, DivineFavor = 900, Ambrosia = 8 },
	},
	{
		Id = "TitansColosseum", DisplayName = "Titan's Colosseum", Description = "Titan warriors and cyclopes. Defeat the Titan King!",
		MinLevel = 136, MaxLevel = 200, RequiredRank = 6, Available = true, Color = Color3.fromRGB(230, 170, 60),
		Theme = { Floor = Color3.fromRGB(200, 185, 150), Wall = Color3.fromRGB(170, 150, 110), Fire = Color3.fromRGB(255, 200, 80) },
		Radius = 65,
		Waves = {
			{ TitanWarrior = 2 },
			{ TitanWarrior = 2, Cyclops = 1 },
			{ TitanWarrior = 3, Cyclops = 2 },
			{ TitanWarrior = 3, Cyclops = 3 },
			{ Boss = "TitanKing", TitanWarrior = 2 },
		},
		WaveHealth = { 0.7, 0.9, 1.15, 1.4, 1.7 },
		WaveDamage = { 0.6, 0.8, 1.0, 1.2, 1.4 },
		WaveSpeed = { 0.9, 1.0, 1.1, 1.2, 1.3 },
		Rewards = { XP = 150000, Gold = 100000, DivineFavor = 2000, Ambrosia = 15 },
	},
}

ArenaConfig.ById = {}
for _, arena in ArenaConfig.Arenas do
	ArenaConfig.ById[arena.Id] = arena
end

-- Bigger parties: tougher and more numerous enemies.
ArenaConfig.Party = {
	MaxPlayers = 4,
	HealthPerExtraPlayer = 0.5,     -- +50% enemy health per extra player
	CountPerExtraPlayer = 0.25,     -- +25% enemies per extra player (rounded)
	BossHealthPerExtraPlayer = 0.6, -- +60% boss health per extra player
}

ArenaConfig.CountdownTime = 3      -- seconds before wave 1
ArenaConfig.IntermissionTime = 4   -- seconds between waves
ArenaConfig.ReturnDelay = 12       -- seconds on the results screen before going home
ArenaConfig.FailRewardMultiplier = 0.3 -- a failed run pays 30% x (waves cleared / 5)
ArenaConfig.MaxRuns = 4            -- arenas that can run at the same time on one server

-- Where arena copies are built (far from the hub), one slot per running arena.
ArenaConfig.Origin = Vector3.new(0, 1, 1500)
ArenaConfig.SlotSpacing = 400
ArenaConfig.Radius = 45

local RANK_NAMES = { "Mortal", "Warrior", "Champion", "Hero", "Demigod", "Lesser God", "Olympian", "Elder God" }

-- Why an arena can't be entered, or nil if it can.
function ArenaConfig.LockReason(arena, level, rankIndex)
	if not arena.Available then
		return "Coming in Phase 7"
	end
	if level < arena.MinLevel then
		return ("Reach level %d"):format(arena.MinLevel)
	end
	if arena.RequiredRank and (rankIndex or 1) < arena.RequiredRank then
		return ("Ascend to %s"):format(RANK_NAMES[arena.RequiredRank])
	end
	return nil
end

return ArenaConfig
