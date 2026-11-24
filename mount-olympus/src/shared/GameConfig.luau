-- GameConfig (ModuleScript)
-- Location: ReplicatedStorage > Shared > GameConfig
--
-- Central settings for Mount Olympus: Rise of the Gods.
-- Both the server and the client read this file.
-- Players CAN read anything in ReplicatedStorage, so never put secrets here.
-- Changing a number here is how you balance the game; you should not need
-- to edit the other scripts to tweak values.

local GameConfig = {}

--------------------------------------------------------------------------
-- DATA SAVING
--------------------------------------------------------------------------
GameConfig.Data = {
	StoreName = "MountOlympus_PlayerData", -- changing this starts everyone fresh
	SchemaVersion = 1,         -- bump when the data layout changes (see DataService migrations)
	AutosaveInterval = 120,    -- seconds between automatic saves
	SessionLockTimeout = 600,  -- a lock older than this (seconds) is treated as left behind by a crashed server
	MaxLoadAttempts = 6,
	LoadRetryDelay = 5,        -- seconds between load attempts
	MaxSaveAttempts = 3,
}

--------------------------------------------------------------------------
-- LEVELS AND STATS
--------------------------------------------------------------------------
GameConfig.Progression = {
	MaxLevel = 200,

	-- XP needed to go from level L to L+1 = floor(BaseXP * L ^ XPExponent)
	-- Placeholder curve; tuned during Phase 8 balancing.
	BaseXP = 100,
	XPExponent = 1.5,

	-- If true, a player stops levelling at the top of their rank's range
	-- (e.g. Mortal stops at 10) until they complete the ascension trial.
	LevelCappedByRank = true,

	BaseHealth = 100,
	HealthPerLevel = 10,
	BaseAttack = 10,
	AttackPerLevel = 2,
}

--------------------------------------------------------------------------
-- ASCENSION RANKS
-- Trial = the trial that must be completed to REACH this rank.
--------------------------------------------------------------------------
GameConfig.Ranks = {
	{ Name = "Mortal",     MinLevel = 1,   MaxLevel = 10,  Trial = "",                 Color = Color3.fromRGB(120, 112, 100) },
	{ Name = "Warrior",    MinLevel = 11,  MaxLevel = 25,  Trial = "TrainingChampion", Color = Color3.fromRGB(165, 105, 55) },
	{ Name = "Champion",   MinLevel = 26,  MaxLevel = 45,  Trial = "SpartanArena",     Color = Color3.fromRGB(180, 55, 45) },
	{ Name = "Hero",       MinLevel = 46,  MaxLevel = 70,  Trial = "Minotaur",         Color = Color3.fromRGB(50, 110, 190) },
	{ Name = "Demigod",    MinLevel = 71,  MaxLevel = 100, Trial = "DivineTrial",      Color = Color3.fromRGB(125, 70, 195) },
	{ Name = "Lesser God", MinLevel = 101, MaxLevel = 140, Trial = "Cerberus",         Color = Color3.fromRGB(30, 150, 140) },
	{ Name = "Olympian",   MinLevel = 141, MaxLevel = 180, Trial = "OlympianGauntlet", Color = Color3.fromRGB(200, 150, 20) },
	{ Name = "Elder God",  MinLevel = 181, MaxLevel = 200, Trial = "TitanKing",        Color = Color3.fromRGB(230, 120, 20) },
}

--------------------------------------------------------------------------
-- CURRENCIES
--------------------------------------------------------------------------
GameConfig.Currencies = { "Gold", "DivineFavor", "Ambrosia" }

GameConfig.CurrencyInfo = {
	Gold        = { DisplayName = "Gold",   Color = Color3.fromRGB(212, 175, 55) },
	DivineFavor = { DisplayName = "Favor",  Color = Color3.fromRGB(110, 170, 255) },
	Ambrosia    = { DisplayName = "Ambrosia", Color = Color3.fromRGB(230, 110, 170) },
}

GameConfig.StartingCurrencies = {
	Gold = 100,
	DivineFavor = 0,
	Ambrosia = 0,
}

--------------------------------------------------------------------------
-- TEMPLE PLOTS
-- Count must be >= the server's Max Players (Game Settings > Places).
--------------------------------------------------------------------------
GameConfig.Plots = {
	Count = 8,
	Columns = 4,
	Size = Vector3.new(80, 1, 80),
	Spacing = 100,
	Origin = Vector3.new(-150, 0.5, 200), -- centre of Plot1
}

--------------------------------------------------------------------------
-- MISC
--------------------------------------------------------------------------
GameConfig.Teleport = {
	Cooldown = 3, -- seconds between teleport requests
}

-- Shown small in the corner so you can tell which update a server is running.
-- Bump this with every publish.
GameConfig.BuildLabel = "v35"

GameConfig.Debug = {
	-- Chat commands like "!xp 500". They ONLY work inside Roblox Studio,
	-- never in the live game, even if this is left true.
	ChatCommandsInStudio = true,

	-- Lets ONLY the game's owner use the same chat commands in the live
	-- game (e.g. testing on an iPad without Studio). Nobody else can.
	-- !!! Set this to false before releasing the game to the public. !!!
	ChatCommandsForOwnerInLiveGame = true,

	-- Devices send a small performance/error report to the server, saved in
	-- the "OlympusDiagnostics" DataStore so problems can be investigated.
	-- Set to false before release if no longer needed.
	Diagnostics = true,
}

return GameConfig
