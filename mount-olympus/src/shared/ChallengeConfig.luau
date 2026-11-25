-- ChallengeConfig (ModuleScript)
-- Location: ReplicatedStorage > Shared > ChallengeConfig
--
-- Phase 7E: Olympian Challenges at the Titan Gate. Harder rematches of every
-- arena boss, plus the Olympian Gauntlet (all six bosses in a row).
--   Heroic: open once you could enter that boss's arena (its RequiredRank).
--   Mythic and the Gauntlet: Elder God only (the true endgame).
-- Two waves per rematch: the arena's elite wave, then the boss with helpers.
-- Rewards = the arena's rewards x difficulty, plus a one-time first-clear
-- Ambrosia bonus. All numbers are PLACEHOLDERS, balanced in Phase 8.

local ArenaConfig = require(script.Parent:WaitForChild("ArenaConfig"))
local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local ChallengeConfig = {}

local RANK_NAMES = { "Mortal", "Warrior", "Champion", "Hero", "Demigod", "Lesser God", "Olympian", "Elder God" }

ChallengeConfig.ElderGodRank = 8

ChallengeConfig.DifficultyOrder = { "Heroic", "Mythic" }
ChallengeConfig.Difficulties = {
	Heroic = {
		Name = "Heroic", Color = Color3.fromRGB(200, 120, 40),
		BossHealth = 2.5, BossDamage = 1.6,   -- the boss
		AddHealth = 2.2, AddDamage = 1.6,     -- everything else
		Speed = 1.25, Reward = 3, FirstClearAmbrosia = 3,
	},
	Mythic = {
		Name = "Mythic", Color = Color3.fromRGB(170, 60, 210),
		BossHealth = 5, BossDamage = 2.4,
		AddHealth = 4, AddDamage = 2.2,
		Speed = 1.4, Reward = 7, FirstClearAmbrosia = 8,
		RequiredRank = 8,
	},
}

ChallengeConfig.Challenges = {}
ChallengeConfig.ById = {}

local function add(challenge)
	table.insert(ChallengeConfig.Challenges, challenge)
	ChallengeConfig.ById[challenge.Id] = challenge
end

for _, arena in ArenaConfig.Arenas do
	local bossWave = arena.Waves[#arena.Waves]
	local boss = bossWave.Boss
	local bossCfg = boss and CombatConfig.Enemies[boss]
	if arena.Available and bossCfg then
		add({
			Id = "Rematch_" .. boss,
			Name = bossCfg.DisplayName .. " Rematch",
			Description = "Elite " .. arena.DisplayName .. " forces, then a far stronger " .. bossCfg.DisplayName .. ".",
			Boss = boss,
			RequiredRank = arena.RequiredRank or 1,
			Arena = arena,
			Waves = { arena.Waves[#arena.Waves - 1], bossWave },
			Rewards = arena.Rewards,
			Theme = arena.Theme,
			Radius = arena.Radius,
			Color = arena.Color,
		})
	end
end

local colosseum = ArenaConfig.ById and ArenaConfig.ById.TitansColosseum
add({
	Id = "OlympianGauntlet",
	Name = "The Olympian Gauntlet",
	Description = "All six bosses, one after another, with no healing breaks beyond the short pauses. Only for Elder Gods.",
	Boss = "TitanKing",
	RequiredRank = 8,
	MythicOnlyRank = true,
	Waves = {
		{ Boss = "TrainingChampion" },
		{ Boss = "SpartanWarlord" },
		{ Boss = "Minotaur" },
		{ Boss = "Medusa" },
		{ Boss = "Cerberus" },
		{ Boss = "TitanKing" },
	},
	Rewards = { XP = 60000, Gold = 50000, DivineFavor = 300, Ambrosia = 4 },
	Theme = colosseum and colosseum.Theme,
	Radius = colosseum and colosseum.Radius,
	Color = Color3.fromRGB(230, 190, 60),
})

-- Why a player can't start this challenge at this difficulty (nil = they can).
function ChallengeConfig.LockReason(challenge, difficultyId, rankIndex)
	local difficulty = ChallengeConfig.Difficulties[difficultyId]
	if not challenge or not difficulty then
		return "Unknown challenge."
	end
	local needed = math.max(challenge.RequiredRank or 1, difficulty.RequiredRank or 1)
	if rankIndex < needed then
		return if needed >= ChallengeConfig.ElderGodRank then "Elder God only" else ("Ascend to %s"):format(RANK_NAMES[needed] or "?")
	end
	return nil
end

-- The clear record key, e.g. "Rematch_Medusa:Mythic".
function ChallengeConfig.Key(challengeId, difficultyId)
	return challengeId .. ":" .. difficultyId
end

return ChallengeConfig
