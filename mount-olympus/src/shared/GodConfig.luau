-- GodConfig (ModuleScript)
-- Location: ReplicatedStorage > Shared > GodConfig
--
-- Loads every god module from ReplicatedStorage > Shared > Gods and holds the
-- rules shared by all gods: blessing tiers, Divine Favor costs, requirements,
-- worship and god-changing. Both server and client read this.
-- To add a god: create a module in the Gods folder, add its Id to Order.
-- All numbers are PLACEHOLDERS, balanced in Phase 8.

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))
local GodsFolder = script.Parent:WaitForChild("Gods")

local GodConfig = {}

-- Display order in the menus.
GodConfig.Order = { "Zeus", "Poseidon", "Hades", "Ares", "Athena", "Apollo" }

GodConfig.Gods = {}
for _, id in GodConfig.Order do
	GodConfig.Gods[id] = require(GodsFolder:WaitForChild(id))
end

-- [BlessingId] = { God = godId, Blessing = blessing table }
GodConfig.BlessingsById = {}
for godId, god in GodConfig.Gods do
	for _, blessing in god.Blessings do
		GodConfig.BlessingsById[blessing.Id] = { God = godId, Blessing = blessing }
	end
end

--------------------------------------------------------------------------
-- Blessing tiers (same rules for every god)
-- AltarLevel = Main Altar level needed, Loyalty = loyalty with that god,
-- RankIndex  = ascension rank needed (1 Mortal, 2 Warrior, 3 Champion, 4 Hero),
-- Costs[n]   = Divine Favor to reach blessing level n.
-- Tier 1 level 1 is given free when you start worshipping a god.
--------------------------------------------------------------------------
GodConfig.MaxBlessingLevel = 3

GodConfig.Tiers = {
	{ AltarLevel = 0, Loyalty = 0,   RankIndex = 1, Costs = { 0, 40, 120 } },
	{ AltarLevel = 1, Loyalty = 25,  RankIndex = 1, Costs = { 60, 150, 400 } },
	{ AltarLevel = 2, Loyalty = 100, RankIndex = 2, Costs = { 200, 500, 1200 } },
	{ AltarLevel = 3, Loyalty = 300, RankIndex = 3, Costs = { 600, 1500, 3500 } },
	{ AltarLevel = 4, Loyalty = 800, RankIndex = 4, Costs = { 1500, 4000, 10000 } },
}

-- Worship at your god's statue in the Hall of the Gods.
-- Rewards are increased by the Statue Hall's worship bonus.
GodConfig.Worship = {
	Cooldown = 30, -- seconds
	Favor = 10,
	Loyalty = 10,
}

-- Changing god: start at the Shrine of Change, then pray there this many times.
-- Levels, currencies, temple and every god's blessings and loyalty are kept.
GodConfig.GodChange = {
	PrayersNeeded = 3,
	PrayerCooldown = 20, -- seconds between prayers
}

-- Temple colours before a god is chosen.
GodConfig.DefaultColors = {
	Primary = Color3.fromRGB(212, 175, 55),
	Accent = Color3.fromRGB(212, 175, 55),
	Glow = Color3.fromRGB(110, 170, 255),
}

--------------------------------------------------------------------------
-- Shared rules
--------------------------------------------------------------------------
function GodConfig.IsPlayable(godId)
	local god = GodConfig.Gods[godId]
	return god ~= nil and god.Available == true
end

function GodConfig.GetColors(godId)
	local god = GodConfig.Gods[godId]
	return if god then god.Colors else GodConfig.DefaultColors
end

-- What the next level of a blessing needs.
-- Returns { Maxed = bool, NextLevel = n, Cost = favor, Blocked = "reason" or nil }
function GodConfig.GetBlessingUpgradeInfo(blessingId, currentLevel, altarLevel, loyalty, rankIndex)
	local entry = GodConfig.BlessingsById[blessingId]
	if not entry then
		return nil
	end
	if currentLevel >= GodConfig.MaxBlessingLevel then
		return { Maxed = true }
	end
	local tier = GodConfig.Tiers[entry.Blessing.Tier]
	local nextLevel = currentLevel + 1

	local blocked = nil
	if altarLevel < tier.AltarLevel then
		blocked = ("Needs Main Altar level %d"):format(tier.AltarLevel)
	elseif loyalty < tier.Loyalty then
		blocked = ("Needs %d loyalty"):format(tier.Loyalty)
	elseif rankIndex < tier.RankIndex then
		blocked = ("Needs rank %s"):format(GameConfig.Ranks[tier.RankIndex].Name)
	end

	return {
		Maxed = false,
		NextLevel = nextLevel,
		Cost = tier.Costs[nextLevel],
		Blocked = blocked,
	}
end

return GodConfig
