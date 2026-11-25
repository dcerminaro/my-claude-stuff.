-- TempleConfig (ModuleScript)
-- Location: ReplicatedStorage > Shared > TempleConfig
--
-- Everything about the Temple Tycoon that you might want to tweak:
-- building names, costs, effects, requirements and where they sit on the plot.
-- Both the server (to decide purchases) and the client (to show the upgrade
-- menu) read this file. All numbers are PLACEHOLDERS, balanced in Phase 8.
--
-- To add a new building later: add an entry to Buildings, add its id to
-- BuildingOrder, and add a model function in TempleModels.

local TempleConfig = {}

TempleConfig.MaxBuildingLevel = 6     -- level 6 ("Divine") needs the Divine Citadel (Phase 7E)
TempleConfig.IncomeInterval = 5      -- seconds between passive income payments
TempleConfig.UpgradeCooldown = 0.5   -- seconds between purchase requests per player

--------------------------------------------------------------------------
-- TEMPLE TIERS
-- Tier = 1 + Temple Core level. Core has 6 levels -> tiers 1-7.
-- Tier 7 (Divine Citadel, Phase 7E) needs character level 100 and Elder God.
--------------------------------------------------------------------------
TempleConfig.Tiers = {
	{ Name = "Ruined Shrine" },
	{ Name = "Sacred Sanctuary" },
	{ Name = "Temple of Devotion" },
	{ Name = "Blessed Temple" },
	{ Name = "Grand Pantheon" },
	{ Name = "Celestial Palace" },
	{ Name = "Divine Citadel" },
}

-- Order shown in the upgrade menu.
TempleConfig.BuildingOrder = {
	"GoldTreasury",
	"MainAltar",
	"DivineFountain",
	"TrainingGrounds",
	"StatueHall",
	"TempleCore",
}

--------------------------------------------------------------------------
-- BUILDINGS
-- Slot = centre of the building, relative to the plot centre (X, Z).
-- Pad  = centre of its glowing purchase pad, relative to the plot centre.
-- Costs[n] = Gold to reach level n.
-- Effect / EffectValues[n] = what the building gives at level n.
-- Players arrive at the front of the plot (negative Z).
--------------------------------------------------------------------------
TempleConfig.Buildings = {
	GoldTreasury = {
		DisplayName = "Gold Treasury",
		Description = "Earns Gold automatically while you play.",
		Slot = Vector3.new(-28, 0, -16),
		Pad = Vector3.new(-28, 0, -30),
		Costs = { 100, 600, 3000, 15000, 75000, 400000 },
		Effect = "GoldPerMinute",
		EffectLabel = "Gold per minute",
		EffectValues = { 30, 75, 180, 420, 900, 2000 },
	},
	MainAltar = {
		DisplayName = "Main Altar",
		Description = "Earns Divine Favor. Unlocks higher blessing tiers (Phase 3).",
		Slot = Vector3.new(0, 0, -20),
		Pad = Vector3.new(-9, 0, -30),
		Costs = { 250, 1500, 7500, 35000, 150000, 750000 },
		Effect = "FavorPerMinute",
		EffectLabel = "Favor per minute",
		EffectValues = { 5, 12, 25, 50, 100, 200 },
	},
	DivineFountain = {
		DisplayName = "Divine Fountain",
		Description = "Improves health and energy regeneration (used from Phase 4).",
		Slot = Vector3.new(28, 0, -16),
		Pad = Vector3.new(28, 0, -30),
		Costs = { 300, 2000, 10000, 45000, 180000, 900000 },
		Effect = "RegenBonusPercent",
		EffectLabel = "Regeneration bonus %",
		EffectValues = { 10, 20, 35, 50, 75, 100 },
	},
	TrainingGrounds = {
		DisplayName = "Training Grounds",
		Description = "Boosts combat and equipment progression (used from Phase 4).",
		Slot = Vector3.new(-28, 0, 20),
		Pad = Vector3.new(-28, 0, 5),
		Costs = { 400, 2500, 12000, 50000, 200000, 1000000 },
		Effect = "CombatBonusPercent",
		EffectLabel = "Combat bonus %",
		EffectValues = { 2, 4, 7, 10, 15, 20 },
	},
	StatueHall = {
		DisplayName = "Statue Hall",
		Description = "Displays statues and improves worship rewards (used from Phase 3).",
		Slot = Vector3.new(28, 0, 20),
		Pad = Vector3.new(28, 0, 5),
		Costs = { 500, 3000, 15000, 60000, 250000, 1250000 },
		Effect = "WorshipBonusPercent",
		EffectLabel = "Worship bonus %",
		EffectValues = { 5, 10, 20, 30, 50, 75 },
	},
	TempleCore = {
		DisplayName = "Temple Core",
		Description = "Raises your temple tier, changes its look, and unlocks stronger buildings.",
		Slot = Vector3.new(0, 0, 12), -- the main temple itself
		Pad = Vector3.new(9, 0, -30),
		Costs = { 1000, 8000, 40000, 160000, 600000, 3000000 },
		RequiredLevel = { 5, 10, 25, 45, 70, 100 }, -- character level needed for each Core level
		RequiredRank = { [6] = 8 }, -- Core level 6 (Divine Citadel) also needs Elder God
		IsCore = true,
	},
}

--------------------------------------------------------------------------
-- Shared rules (used by both the server and the menu)
--------------------------------------------------------------------------
function TempleConfig.TierFromCoreLevel(coreLevel)
	return math.clamp(1 + (tonumber(coreLevel) or 0), 1, #TempleConfig.Tiers)
end

function TempleConfig.GetTierName(tier)
	local info = TempleConfig.Tiers[tier]
	return if info then info.Name else "?"
end

-- Value of a building's effect at a level (0 if not built).
function TempleConfig.GetEffectValue(buildingId, level)
	local building = TempleConfig.Buildings[buildingId]
	if not building or not building.EffectValues or level <= 0 then
		return 0
	end
	return building.EffectValues[math.min(level, #building.EffectValues)] or 0
end

-- What the next upgrade of a building needs.
-- Returns a table: { Maxed = bool, NextLevel = n, Cost = gold, Blocked = "reason" or nil }
-- Temple tier needed for each building level (level 6 needs the Divine Citadel).
TempleConfig.BuildingTierNeeded = { 1, 2, 3, 4, 5, 7 }

local RANK_NAMES = { "Mortal", "Warrior", "Champion", "Hero", "Demigod", "Lesser God", "Olympian", "Elder God" }

function TempleConfig.GetUpgradeInfo(buildingId, currentLevel, templeTier, playerLevel, rankIndex)
	local building = TempleConfig.Buildings[buildingId]
	if not building then
		return nil
	end
	if currentLevel >= TempleConfig.MaxBuildingLevel then
		return { Maxed = true }
	end

	local nextLevel = currentLevel + 1
	local blocked = nil
	if building.IsCore then
		local required = building.RequiredLevel[nextLevel]
		local rankNeeded = building.RequiredRank and building.RequiredRank[nextLevel]
		if playerLevel < required then
			blocked = ("Reach character level %d"):format(required)
		elseif rankNeeded and (rankIndex or 1) < rankNeeded then
			blocked = ("Ascend to %s"):format(RANK_NAMES[rankNeeded])
		end
	else
		local tierNeeded = TempleConfig.BuildingTierNeeded[nextLevel] or nextLevel
		if templeTier < tierNeeded then
			blocked = ("Needs temple tier %d (%s)"):format(tierNeeded, TempleConfig.GetTierName(tierNeeded))
		end
	end

	return {
		Maxed = false,
		NextLevel = nextLevel,
		Cost = building.Costs[nextLevel],
		Blocked = blocked,
	}
end

--------------------------------------------------------------------------
-- TEMPLE PRESTIGE (Phase 7E)
-- After the Divine Citadel with every building at level 6, keep improving
-- the temple: 10 Prestige levels. Nothing resets. Each level adds
-- IncomeBonusPercent to temple Gold and Favor income and new decorations.
--------------------------------------------------------------------------
TempleConfig.Prestige = {
	MaxLevel = 10,
	IncomeBonusPercent = 5, -- per Prestige level
	BaseGold = 2000000,   -- Prestige 1 costs 2M Gold; each level x1.4 (Prestige 10: ~41M)
	GoldGrowth = 1.4,
	BaseAmbrosia = 5,     -- Prestige 1 costs 5 Ambrosia; +3 per level
	AmbrosiaPerLevel = 3,
	-- New look at each level (shown in the menu).
	Looks = {
		[1] = "Golden banners on the citadel",
		[2] = "A ring of glowing pillars around the citadel",
		[3] = "A divine halo above the dome",
		[4] = "Prestige stars on the citadel",
		[5] = "A beam of light into the sky",
		[6] = "Two more floating sky islands",
		[7] = "Flames of the gods on every tower",
		[8] = "A second, larger halo",
		[9] = "Golden statues of you at the gates",
		[10] = "Radiant Citadel: everything glows",
	},
}

-- What the next Prestige level needs.
-- Returns { Maxed, NextLevel, Gold, Ambrosia, Blocked }.
function TempleConfig.GetPrestigeInfo(prestige, templeTier, buildings)
	local p = TempleConfig.Prestige
	prestige = tonumber(prestige) or 0
	if prestige >= p.MaxLevel then
		return { Maxed = true }
	end
	local nextLevel = prestige + 1
	local blocked = nil
	if templeTier < #TempleConfig.Tiers then
		blocked = "Build the Divine Citadel first"
	else
		for _, id in TempleConfig.BuildingOrder do
			if (tonumber(buildings[id]) or 0) < TempleConfig.MaxBuildingLevel then
				blocked = ("Raise every building to level %d first"):format(TempleConfig.MaxBuildingLevel)
				break
			end
		end
	end
	return {
		Maxed = false,
		NextLevel = nextLevel,
		Gold = math.floor(p.BaseGold * p.GoldGrowth ^ prestige / 1000) * 1000,
		Ambrosia = p.BaseAmbrosia + p.AmbrosiaPerLevel * prestige,
		Blocked = blocked,
	}
end

function TempleConfig.PrestigeMultiplier(prestige)
	return 1 + (tonumber(prestige) or 0) * TempleConfig.Prestige.IncomeBonusPercent / 100
end

return TempleConfig
