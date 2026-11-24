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
		-- Completion rewards (on top of what each enemy drops).
		Rewards = { XP = 250, Gold = 200, DivineFavor = 15, Ambrosia = 1 },
	},
	{ Id = "SpartanBattleground", DisplayName = "Spartan Battleground", Description = "Armored soldiers and beasts.", MinLevel = 16, MaxLevel = 35, Available = false },
	{ Id = "LabyrinthOfCrete", DisplayName = "Labyrinth of Crete", Description = "Minotaurs and guardians.", MinLevel = 36, MaxLevel = 60, Available = false },
	{ Id = "CursedTemple", DisplayName = "Cursed Temple", Description = "Gorgons and cursed warriors.", MinLevel = 61, MaxLevel = 90, Available = false },
	{ Id = "GatesOfTheUnderworld", DisplayName = "Gates of the Underworld", Description = "Undead and underworld monsters.", MinLevel = 91, MaxLevel = 135, Available = false },
	{ Id = "TitansColosseum", DisplayName = "Titan's Colosseum", Description = "Titan warriors and divine monsters.", MinLevel = 136, MaxLevel = 200, Available = false },
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

-- Why an arena can't be entered, or nil if it can.
function ArenaConfig.LockReason(arena, level)
	if not arena.Available then
		return "Coming in Phase 7"
	end
	if level < arena.MinLevel then
		return ("Reach level %d"):format(arena.MinLevel)
	end
	return nil
end

return ArenaConfig
