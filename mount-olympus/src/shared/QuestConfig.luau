-- QuestConfig (ModuleScript)
-- Location: ReplicatedStorage > Shared > QuestConfig
--
-- Phase 7D: quests. Quests are grouped in CHAINS: only the first unfinished
-- quest of each chain is active, and claiming it unlocks the next one.
-- Daily quests: 3 picked from the Daily pool each day (UTC), reset at midnight.
--
-- Objective types (counted by the server as things happen):
--   KillEnemy / KillBoss (Target = enemy type or "Any"), WinArena (Target =
--   arena id or "Any"), UpgradeBuilding (building id or "Any"), Worship
--   (god or "Any"), UpgradeBlessing, UseAbility (god or "Any"), CraftWeapon,
--   UpgradeWeapon, EarnGold (amount).
-- State objectives (checked from your save): ChooseGod, ReachLevel,
--   ReachRank, TempleTier.
-- Rewards: XP, Gold, DivineFavor, Ambrosia. Daily rewards grow with level.
-- All numbers are PLACEHOLDERS, balanced in Phase 8.

local QuestConfig = {}

local function q(id, name, description, objective, rewards, requires)
	return { Id = id, Name = name, Description = description, Objective = objective, Rewards = rewards, Requires = requires }
end

QuestConfig.Chains = {
	-- The main journey (story + ascension)
	{
		Id = "Main", Name = "The Path to Godhood", Category = "Story",
		Quests = {
			q("M01", "Arrival at Olympus", "Choose a god to worship in the Hall of the Gods.", { Type = "ChooseGod", Count = 1 }, { Gold = 100 }),
			q("M02", "A Humble Shrine", "Build the Gold Treasury at your temple.", { Type = "BuildingLevel", Target = "GoldTreasury", Count = 1 }, { Gold = 150, XP = 50 }),
			q("M03", "First Blood", "Defeat 5 enemies (the Practice Field is behind the plaza).", { Type = "KillEnemy", Target = "Any", Count = 5 }, { XP = 100, Gold = 100 }),
			q("M04", "Into the Pit", "Win the Mortal Training Pit at the Arena Gate.", { Type = "WinArena", Target = "MortalTrainingPit", Count = 1 }, { XP = 300, Gold = 250, DivineFavor = 20 }),
			q("M05", "Mortal No More", "Ascend to Warrior at the Ascension Chamber.", { Type = "ReachRank", Count = 2 }, { Gold = 500, Ambrosia = 1 }),
			q("M06", "Spartan Glory", "Win the Spartan Battleground.", { Type = "WinArena", Target = "SpartanBattleground", Count = 1 }, { XP = 1500, Gold = 1500, Ambrosia = 1 }),
			q("M07", "Champion of Olympus", "Ascend to Champion.", { Type = "ReachRank", Count = 3 }, { Gold = 3000, Ambrosia = 2 }),
			q("M08", "Into the Labyrinth", "Win the Labyrinth of Crete.", { Type = "WinArena", Target = "LabyrinthOfCrete", Count = 1 }, { XP = 6000, Gold = 6000, Ambrosia = 2 }),
			q("M09", "A Hero's Name", "Ascend to Hero.", { Type = "ReachRank", Count = 4 }, { Gold = 10000, Ambrosia = 3 }),
			q("M10", "Lifting the Curse", "Win the Cursed Temple.", { Type = "WinArena", Target = "CursedTemple", Count = 1 }, { XP = 20000, Gold = 20000, Ambrosia = 3 }),
			q("M11", "Divine Blood", "Ascend to Demigod.", { Type = "ReachRank", Count = 5 }, { Gold = 30000, Ambrosia = 5 }),
			q("M12", "Gates of the Dead", "Win the Gates of the Underworld.", { Type = "WinArena", Target = "GatesOfTheUnderworld", Count = 1 }, { XP = 60000, Gold = 50000, Ambrosia = 5 }),
			q("M13", "Among the Gods", "Ascend to Lesser God.", { Type = "ReachRank", Count = 6 }, { Gold = 80000, Ambrosia = 8 }),
			q("M14", "The Fall of Titans", "Win Titan's Colosseum.", { Type = "WinArena", Target = "TitansColosseum", Count = 1 }, { XP = 150000, Gold = 120000, Ambrosia = 10 }),
			q("M15", "Seat on Olympus", "Ascend to Olympian.", { Type = "ReachRank", Count = 7 }, { Gold = 200000, Ambrosia = 15 }),
			q("M16", "Elder God", "Ascend to Elder God.", { Type = "ReachRank", Count = 8 }, { Gold = 500000, Ambrosia = 30 }),
		},
	},
	{
		Id = "Combat", Name = "Warpath", Category = "Combat",
		Quests = {
			q("C1", "Blooded", "Defeat 25 enemies.", { Type = "KillEnemy", Target = "Any", Count = 25 }, { XP = 200, Gold = 200 }),
			q("C2", "Veteran", "Defeat 100 enemies.", { Type = "KillEnemy", Target = "Any", Count = 100 }, { XP = 2000, Gold = 1500 }),
			q("C3", "Slayer", "Defeat 500 enemies.", { Type = "KillEnemy", Target = "Any", Count = 500 }, { XP = 20000, Gold = 10000, Ambrosia = 2 }),
			q("C4", "Legend of War", "Defeat 2,000 enemies.", { Type = "KillEnemy", Target = "Any", Count = 2000 }, { XP = 100000, Gold = 60000, Ambrosia = 6 }),
		},
	},
	{
		Id = "Bosses", Name = "Monster Hunter", Category = "Boss",
		Quests = {
			q("B1", "The Champion Falls", "Defeat the Training Champion.", { Type = "KillBoss", Target = "TrainingChampion", Count = 1 }, { Gold = 400, Ambrosia = 1 }),
			q("B2", "Warlord of Sparta", "Defeat the Spartan Warlord.", { Type = "KillBoss", Target = "SpartanWarlord", Count = 1 }, { Gold = 2500, Ambrosia = 1 }),
			q("B3", "The Bull of Crete", "Defeat the Minotaur.", { Type = "KillBoss", Target = "Minotaur", Count = 1 }, { Gold = 8000, Ambrosia = 2 }),
			q("B4", "Stone Gaze", "Defeat Medusa.", { Type = "KillBoss", Target = "Medusa", Count = 1 }, { Gold = 20000, Ambrosia = 3 }),
			q("B5", "Hound of Hades", "Defeat Cerberus.", { Type = "KillBoss", Target = "Cerberus", Count = 1 }, { Gold = 50000, Ambrosia = 5 }),
			q("B6", "Kingslayer", "Defeat the Titan King.", { Type = "KillBoss", Target = "TitanKing", Count = 1 }, { Gold = 120000, Ambrosia = 10 }),
		},
	},
	{
		Id = "Temple", Name = "House of the Gods", Category = "Temple",
		Quests = {
			q("T1", "Builder", "Reach 5 total building levels at your temple.", { Type = "TotalBuildingLevels", Count = 5 }, { Gold = 500, DivineFavor = 10 }),
			q("T2", "Sacred Sanctuary", "Raise your temple to tier 2 with the Temple Core.", { Type = "TempleTier", Count = 2 }, { Gold = 1500, DivineFavor = 20 }),
			q("T3", "Temple of Devotion", "Raise your temple to tier 3.", { Type = "TempleTier", Count = 3 }, { Gold = 8000, DivineFavor = 50, Ambrosia = 1 }),
			q("T4", "Master Builder", "Reach 15 total building levels at your temple.", { Type = "TotalBuildingLevels", Count = 15 }, { Gold = 20000, DivineFavor = 80 }),
			q("T5", "Blessed Temple", "Raise your temple to tier 4.", { Type = "TempleTier", Count = 4 }, { Gold = 40000, DivineFavor = 150, Ambrosia = 2 }),
			q("T6", "Grand Pantheon", "Raise your temple to tier 5.", { Type = "TempleTier", Count = 5 }, { Gold = 150000, DivineFavor = 300, Ambrosia = 4 }),
			q("T7", "Celestial Palace", "Raise your temple to tier 6.", { Type = "TempleTier", Count = 6 }, { Gold = 500000, DivineFavor = 600, Ambrosia = 8 }),
		},
	},
	{
		Id = "Worship", Name = "Devotion", Category = "Worship",
		Quests = {
			q("W1", "First Prayer", "Worship your god 5 times in the Hall of the Gods.", { Type = "Worship", Target = "Any", Count = 5 }, { DivineFavor = 30, Gold = 100 }),
			q("W2", "Blessed", "Upgrade a blessing in the Hall of the Gods.", { Type = "BlessingLevels", Count = 1 }, { DivineFavor = 40 }),
			q("W3", "Faithful", "Worship 25 times.", { Type = "Worship", Target = "Any", Count = 25 }, { DivineFavor = 150, Gold = 1000 }),
			q("W4", "Chosen", "Reach 5 total blessing levels.", { Type = "BlessingLevels", Count = 5 }, { DivineFavor = 300, Ambrosia = 1 }),
			q("W5", "Devoted for Life", "Worship 100 times.", { Type = "Worship", Target = "Any", Count = 100 }, { DivineFavor = 800, Ambrosia = 3 }),
		},
	},
	{
		Id = "Forge", Name = "Smith of the Gods", Category = "Forge",
		Quests = {
			q("F1", "Fresh Steel", "Own 2 weapons (craft one at the Divine Forge).", { Type = "OwnWeapons", Count = 2 }, { Gold = 300 }),
			q("F2", "Sharpened", "Upgrade weapons 5 times.", { Type = "UpgradeWeapon", Target = "Any", Count = 5 }, { Gold = 3000 }),
			q("F3", "Armory", "Own 5 weapons (craft them or win them from bosses).", { Type = "OwnWeapons", Count = 5 }, { Gold = 15000, Ambrosia = 2 }),
			q("F4", "Master Smith", "Upgrade weapons 25 times.", { Type = "UpgradeWeapon", Target = "Any", Count = 25 }, { Gold = 80000, Ambrosia = 5 }),
		},
	},
}

-- God quests: one small chain per god, only while you worship that god.
local GOD_IDS = { "Zeus", "Poseidon", "Hades", "Ares", "Athena", "Apollo" }
for _, god in GOD_IDS do
	table.insert(QuestConfig.Chains, {
		Id = "God_" .. god, Name = "Divine Tasks of " .. god, Category = "God", God = god,
		Quests = {
			q("G_" .. god .. "_1", "Devotion to " .. god, "Worship " .. god .. " 10 times.", { Type = "Worship", Target = god, Count = 10 }, { DivineFavor = 100, Gold = 500 }),
			q("G_" .. god .. "_2", "Power of " .. god, "Use " .. god .. "'s abilities 30 times.", { Type = "UseAbility", Target = god, Count = 30 }, { DivineFavor = 250, Gold = 2000, Ambrosia = 1 }),
			q("G_" .. god .. "_3", "Champion of " .. god, "Use " .. god .. "'s abilities 200 times.", { Type = "UseAbility", Target = god, Count = 200 }, { DivineFavor = 1000, Gold = 20000, Ambrosia = 4 }),
		},
	})
end

-- Daily pool: 3 are picked each day. Rewards are multiplied by (1 + level / 20).
QuestConfig.DailyCount = 3
QuestConfig.Daily = {
	q("D_Kill", "Daily: Cull the Monsters", "Defeat 30 enemies.", { Type = "KillEnemy", Target = "Any", Count = 30 }, { XP = 300, Gold = 300 }),
	q("D_Arena", "Daily: Arena Victory", "Win any arena.", { Type = "WinArena", Target = "Any", Count = 1 }, { XP = 500, Gold = 400, Ambrosia = 1 }),
	q("D_Worship", "Daily: Prayers", "Worship 5 times.", { Type = "Worship", Target = "Any", Count = 5 }, { DivineFavor = 60, Gold = 150 }),
	q("D_Build", "Daily: Builder", "Make a temple upgrade.", { Type = "UpgradeBuilding", Target = "Any", Count = 1 }, { Gold = 400, DivineFavor = 20 }),
	q("D_Ability", "Daily: Divine Power", "Use god abilities 20 times.", { Type = "UseAbility", Target = "Any", Count = 20 }, { XP = 300, DivineFavor = 40 }),
	q("D_Gold", "Daily: Treasury", "Earn 5,000 Gold.", { Type = "EarnGold", Count = 5000 }, { XP = 250, DivineFavor = 30 }),
	q("D_Boss", "Daily: Giant Slayer", "Defeat any boss.", { Type = "KillBoss", Target = "Any", Count = 1 }, { XP = 600, Gold = 500, Ambrosia = 1 }),
	q("D_Forge", "Daily: At the Anvil", "Upgrade a weapon.", { Type = "UpgradeWeapon", Target = "Any", Count = 1 }, { Gold = 500 }),
}

-- Lookups
QuestConfig.ById = {}
for _, chain in QuestConfig.Chains do
	for index, quest in chain.Quests do
		quest.Chain = chain
		quest.Index = index
		quest.Category = chain.Category
		QuestConfig.ById[quest.Id] = quest
	end
end
for _, quest in QuestConfig.Daily do
	quest.Category = "Daily"
	quest.IsDaily = true
	QuestConfig.ById[quest.Id] = quest
end

-- Objectives that are checked from the save instead of counted.
QuestConfig.StateObjectives = {
	ChooseGod = true, ReachLevel = true, ReachRank = true, TempleTier = true,
	BuildingLevel = true, TotalBuildingLevels = true, BlessingLevels = true, OwnWeapons = true,
}

return QuestConfig
