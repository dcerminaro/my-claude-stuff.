-- WeaponConfig (ModuleScript)
-- Location: ReplicatedStorage > Shared > WeaponConfig
--
-- Phase 7C: weapons, rarities, the Divine Forge and boss drops.
-- Damage = a multiplier on your attack power (Bronze Sword = 1.0), raised by
-- +6% per upgrade level. It applies to basic attacks AND god abilities.
-- Speed = attack cooldown multiplier (lower = faster).
-- Special: CritChance (0-1, double damage), LifeSteal (0-1), Pierce (extra
-- enemies hit), ExtraTargets.
-- Look: Blade / Handle / Glow colours and Length for the model in your hand.
-- All numbers are PLACEHOLDERS, balanced in Phase 8.

local WeaponConfig = {}

WeaponConfig.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(175, 175, 175), MaxLevel = 5, UpgradeGold = 200, UpgradeAmbrosia = 0, Salvage = 100 },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 200, 90), MaxLevel = 6, UpgradeGold = 600, UpgradeAmbrosia = 0, Salvage = 400 },
	{ Name = "Rare", Color = Color3.fromRGB(70, 140, 255), MaxLevel = 8, UpgradeGold = 2000, UpgradeAmbrosia = 0, Salvage = 1500 },
	{ Name = "Epic", Color = Color3.fromRGB(175, 80, 240), MaxLevel = 10, UpgradeGold = 8000, UpgradeAmbrosia = 1, Salvage = 6000 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 160, 40), MaxLevel = 12, UpgradeGold = 30000, UpgradeAmbrosia = 2, Salvage = 25000 },
	{ Name = "Divine", Color = Color3.fromRGB(255, 225, 110), MaxLevel = 15, UpgradeGold = 100000, UpgradeAmbrosia = 3, Salvage = 80000 },
}

-- How each weapon type attacks. Combo = the three swing animations (SwordPoses).
WeaponConfig.Types = {
	Sword = { Range = 7.5, ArcDot = 0.2, MaxTargets = 3, Cooldown = 0.45, Combo = { "Slash1", "Slash2", "Lunge" } },
	Axe = { Range = 7.5, ArcDot = 0.0, MaxTargets = 4, Cooldown = 0.6, Combo = { "Slash1", "Cleave", "Slash2" } },
	Spear = { Range = 10.5, ArcDot = 0.6, MaxTargets = 2, Cooldown = 0.55, Combo = { "Lunge", "Slash1", "Lunge" } },
	Trident = { Range = 9, ArcDot = 0.35, MaxTargets = 4, Cooldown = 0.55, Combo = { "Lunge", "Slash2", "Lunge" } },
	Bow = { Range = 32, Width = 3, MaxTargets = 1, Cooldown = 0.6, Ranged = true, Combo = { "Lunge", "Lunge", "Lunge" } },
}

WeaponConfig.StarterWeapon = "BronzeSword"

-- Cost = Gold (+ Ambrosia) to craft at the Divine Forge; nil = not craftable.
-- Drop = { Boss = enemy type, Chance = 0-1 } when you win that boss's arena or trial.
WeaponConfig.Weapons = {
	BronzeSword = { Name = "Bronze Sword", Type = "Sword", Rarity = 1, Damage = 1.0, Speed = 1.0,
		Look = { Blade = Color3.fromRGB(205, 140, 75), Glow = nil, Length = 3.0 } },
	WoodenSpear = { Name = "Wooden Spear", Type = "Spear", Rarity = 1, Damage = 1.05, Speed = 1.0, Cost = { Gold = 300 },
		Look = { Blade = Color3.fromRGB(170, 170, 175), Handle = Color3.fromRGB(120, 85, 55), Length = 5.5 } },
	HuntingBow = { Name = "Hunting Bow", Type = "Bow", Rarity = 1, Damage = 0.95, Speed = 1.0, Cost = { Gold = 400 },
		Look = { Blade = Color3.fromRGB(120, 85, 55), Length = 4 } },

	IronSword = { Name = "Iron Sword", Type = "Sword", Rarity = 2, Damage = 1.2, Speed = 1.0, Cost = { Gold = 2000 },
		Look = { Blade = Color3.fromRGB(190, 195, 205), Length = 3.2 } },
	HopliteSpear = { Name = "Hoplite Spear", Type = "Spear", Rarity = 2, Damage = 1.25, Speed = 1.0, Cost = { Gold = 2500 },
		Look = { Blade = Color3.fromRGB(205, 140, 75), Handle = Color3.fromRGB(110, 75, 45), Length = 6 } },
	FishermansTrident = { Name = "Fisherman's Trident", Type = "Trident", Rarity = 2, Damage = 1.2, Speed = 1.0, Cost = { Gold = 2500 },
		Look = { Blade = Color3.fromRGB(180, 190, 200), Handle = Color3.fromRGB(110, 80, 50), Length = 5.5 } },

	ChampionsBlade = { Name = "Champion's Blade", Type = "Sword", Rarity = 3, Damage = 1.45, Speed = 0.95, Special = { CritChance = 0.1 },
		Cost = { Gold = 8000, Ambrosia = 1 }, Drop = { Boss = "TrainingChampion", Chance = 0.3 },
		Look = { Blade = Color3.fromRGB(230, 205, 120), Glow = Color3.fromRGB(255, 220, 120), Length = 3.4 } },
	SilverLongbow = { Name = "Silver Longbow", Type = "Bow", Rarity = 3, Damage = 1.4, Speed = 0.95, Special = { Pierce = 1 },
		Cost = { Gold = 12000, Ambrosia = 2 },
		Look = { Blade = Color3.fromRGB(210, 215, 225), Glow = Color3.fromRGB(180, 220, 255), Length = 4.6 } },
	SpartanBlade = { Name = "Spartan Blade", Type = "Sword", Rarity = 3, Damage = 1.55, Speed = 0.9, Special = { CritChance = 0.15 },
		Drop = { Boss = "SpartanWarlord", Chance = 0.3 },
		Look = { Blade = Color3.fromRGB(200, 60, 45), Glow = Color3.fromRGB(255, 90, 60), Length = 3.2 } },

	MinotaursLabrys = { Name = "Minotaur's Labrys", Type = "Axe", Rarity = 4, Damage = 1.9, Speed = 1.1, Special = { ExtraTargets = 2 },
		Drop = { Boss = "Minotaur", Chance = 0.25 },
		Look = { Blade = Color3.fromRGB(150, 140, 130), Handle = Color3.fromRGB(95, 60, 38), Glow = Color3.fromRGB(255, 160, 80), Length = 4.2 } },
	GorgonSpear = { Name = "Gorgon Spear", Type = "Spear", Rarity = 4, Damage = 1.8, Speed = 0.95, Special = { LifeSteal = 0.05 },
		Drop = { Boss = "Medusa", Chance = 0.25 },
		Look = { Blade = Color3.fromRGB(110, 200, 100), Handle = Color3.fromRGB(60, 90, 60), Glow = Color3.fromRGB(120, 255, 130), Length = 6.5 } },
	TridentOfTheDeep = { Name = "Trident of the Deep", Type = "Trident", Rarity = 4, Damage = 1.75, Speed = 0.95, Special = { ExtraTargets = 1 },
		Cost = { Gold = 60000, Ambrosia = 6 },
		Look = { Blade = Color3.fromRGB(60, 200, 220), Handle = Color3.fromRGB(40, 90, 120), Glow = Color3.fromRGB(80, 230, 255), Length = 6 } },

	HellfireBlade = { Name = "Hellfire Blade", Type = "Sword", Rarity = 5, Damage = 2.2, Speed = 0.9, Special = { CritChance = 0.2 },
		Drop = { Boss = "Cerberus", Chance = 0.2 },
		Look = { Blade = Color3.fromRGB(60, 30, 30), Glow = Color3.fromRGB(255, 100, 30), Length = 3.6 } },
	SunlightBow = { Name = "Sunlight Bow", Type = "Bow", Rarity = 5, Damage = 2.1, Speed = 0.9, Special = { Pierce = 3 },
		Cost = { Gold = 250000, Ambrosia = 15 },
		Look = { Blade = Color3.fromRGB(245, 200, 80), Glow = Color3.fromRGB(255, 220, 90), Length = 5 } },
	AegisSpear = { Name = "Aegis Spear", Type = "Spear", Rarity = 5, Damage = 2.15, Speed = 0.9, Special = { LifeSteal = 0.08 },
		Cost = { Gold = 250000, Ambrosia = 15 },
		Look = { Blade = Color3.fromRGB(230, 230, 240), Handle = Color3.fromRGB(212, 175, 55), Glow = Color3.fromRGB(255, 240, 200), Length = 7 } },

	ThunderboltBlade = { Name = "Thunderbolt Blade", Type = "Sword", Rarity = 6, Damage = 2.8, Speed = 0.85, Special = { CritChance = 0.25, LifeSteal = 0.05 },
		Drop = { Boss = "TitanKing", Chance = 0.15 },
		Look = { Blade = Color3.fromRGB(240, 240, 255), Glow = Color3.fromRGB(110, 190, 255), Length = 3.8 } },
	TridentOfPoseidon = { Name = "Trident of Poseidon", Type = "Trident", Rarity = 6, Damage = 2.7, Speed = 0.85, Special = { ExtraTargets = 2, LifeSteal = 0.04 },
		Cost = { Gold = 1000000, Ambrosia = 50 },
		Look = { Blade = Color3.fromRGB(255, 225, 110), Handle = Color3.fromRGB(40, 150, 200), Glow = Color3.fromRGB(80, 230, 255), Length = 7 } },
	BowOfApollo = { Name = "Bow of Apollo", Type = "Bow", Rarity = 6, Damage = 2.6, Speed = 0.85, Special = { Pierce = 5, CritChance = 0.15 },
		Cost = { Gold = 1000000, Ambrosia = 50 },
		Look = { Blade = Color3.fromRGB(255, 225, 110), Glow = Color3.fromRGB(255, 240, 160), Length = 5.4 } },
}

for id, weapon in WeaponConfig.Weapons do
	weapon.Id = id
end

-- Display order (forge list): by rarity, then name.
WeaponConfig.Order = {}
for id in WeaponConfig.Weapons do
	table.insert(WeaponConfig.Order, id)
end
table.sort(WeaponConfig.Order, function(a, b)
	local wa, wb = WeaponConfig.Weapons[a], WeaponConfig.Weapons[b]
	if wa.Rarity ~= wb.Rarity then
		return wa.Rarity < wb.Rarity
	end
	return wa.Name < wb.Name
end)

WeaponConfig.DamagePerLevel = 0.06      -- +6% per upgrade level
WeaponConfig.UpgradeDiscountPerTrainingLevel = 0.04 -- Training Grounds: -4% upgrade cost per level
WeaponConfig.ForgeRange = 22            -- crafting/upgrading needs you at the Divine Forge

-- Attack power multiplier of a weapon at a level.
function WeaponConfig.Power(weaponId, level)
	local w = WeaponConfig.Weapons[weaponId]
	return (if w then w.Damage else 1) * (1 + WeaponConfig.DamagePerLevel * (level or 0))
end

-- Cost of the next upgrade: gold, ambrosia (nil if maxed).
function WeaponConfig.UpgradeCost(weaponId, level, trainingLevel)
	local w = WeaponConfig.Weapons[weaponId]
	local rarity = w and WeaponConfig.Rarities[w.Rarity]
	if not rarity or level >= rarity.MaxLevel then
		return nil
	end
	local discount = 1 - WeaponConfig.UpgradeDiscountPerTrainingLevel * (trainingLevel or 0)
	local gold = math.floor(rarity.UpgradeGold * (level + 1) ^ 1.5 * discount)
	local ambrosia = rarity.UpgradeAmbrosia * (if level >= 3 then 2 else 1)
	return gold, ambrosia
end

return WeaponConfig
