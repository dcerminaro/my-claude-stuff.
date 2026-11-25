-- MasteryConfig (ModuleScript)
-- Location: ReplicatedStorage > Shared > MasteryConfig
--
-- Phase 7E part 3: Divine Mastery and Divine Incarnations.
--
-- DIVINE MASTERY: every god has its own mastery level (1-50). Mastery XP is
-- earned for the god you currently worship by fighting and worshipping.
-- Each level gives a small, capped bonus and some levels unlock cosmetics.
--
-- DIVINE INCARNATION (Elder God only): fill Divine Energy by hitting and
-- defeating enemies, then transform into your god's divine form for a short
-- time: an opening blast, glowing form and strong temporary buffs.
-- All numbers are PLACEHOLDERS, balanced in Phase 8.

local MasteryConfig = {}

MasteryConfig.MaxLevel = 50

-- Mastery XP needed to go from `level` to `level + 1`.
function MasteryConfig.XPForLevel(level)
	return math.floor(100 * level ^ 1.8)
end

-- Where mastery XP comes from.
MasteryConfig.Sources = {
	KillXPShare = 0.1,      -- a tenth of the enemy's normal XP (dummies give 0)
	ArenaXPShare = 0.1,     -- a tenth of the arena's XP reward for a win
	ChallengeWin = 1500,
	Worship = 20,
	UseAbility = 2,
}

-- Small, capped bonuses (per level; level 50 = +10% attack, +10% health).
MasteryConfig.AttackPercentPerLevel = 0.2
MasteryConfig.HealthPercentPerLevel = 0.2

-- Cosmetics unlocked at mastery levels (for the god you worship).
MasteryConfig.Unlocks = {
	{ Level = 5, Id = "Sparks", Name = "Divine Sparks", Description = "Sparks of your god's colour drift around you." },
	{ Level = 10, Id = "Title1", Name = "Title: Adept", Description = "\"<God> Adept\" above your head." },
	{ Level = 15, Id = "Trail", Name = "Divine Trail", Description = "A glowing trail follows your steps." },
	{ Level = 25, Id = "Title2", Name = "Title: Master", Description = "\"Master of <God>\" above your head." },
	{ Level = 30, Id = "Glow", Name = "Inner Light", Description = "You shine with your god's light." },
	{ Level = 40, Id = "Title3", Name = "Title: Grandmaster", Description = "\"Grandmaster of <God>\" above your head." },
	{ Level = 50, Id = "Crown", Name = "Crown of Light", Description = "A floating crown of light and the title \"Chosen of <God>\"." },
}

function MasteryConfig.Title(godName, level)
	if level >= 50 then
		return "Chosen of " .. godName
	elseif level >= 40 then
		return "Grandmaster of " .. godName
	elseif level >= 25 then
		return "Master of " .. godName
	elseif level >= 10 then
		return godName .. " Adept"
	end
	return nil
end

--------------------------------------------------------------------------
-- DIVINE INCARNATION
--------------------------------------------------------------------------
MasteryConfig.Incarnation = {
	RequiredRank = 8,        -- Elder God
	EnergyMax = 100,
	EnergyPerHit = 1,        -- each time you damage an enemy
	EnergyPerKill = 3,
	EnergyPerBossKill = 25,
	BaseDuration = 18,       -- seconds
	DurationPerMastery = 0.2, -- + seconds per mastery level (level 50: 28 s)
	BlastRadius = 24,        -- opening blast
	BlastDamage = 8,         -- x your ability damage
	HealPercent = 30,        -- heals you when you transform
	Key = Enum.KeyCode.T,    -- keyboard key (phones/tablets get a button)
}

-- Each god's form. Buff numbers work like ability buffs:
-- AttackPercent, SpeedPercent, DamageTaken (0.6 = take 40% less),
-- RegenPercent (% of max health per second), LifeSteal (share of damage).
MasteryConfig.Forms = {
	Zeus = { Name = "Avatar of the Storm", AttackPercent = 60, SpeedPercent = 25, DamageTaken = 0.7 },
	Poseidon = { Name = "Lord of the Deep", AttackPercent = 40, SpeedPercent = 20, DamageTaken = 0.6, RegenPercent = 3 },
	Hades = { Name = "King of the Dead", AttackPercent = 45, SpeedPercent = 20, DamageTaken = 0.65, LifeSteal = 0.15 },
	Ares = { Name = "Avatar of War", AttackPercent = 75, SpeedPercent = 25, DamageTaken = 0.75 },
	Athena = { Name = "Aegis Incarnate", AttackPercent = 35, SpeedPercent = 20, DamageTaken = 0.45 },
	Apollo = { Name = "The Radiant Sun", AttackPercent = 45, SpeedPercent = 40, DamageTaken = 0.7, RegenPercent = 2 },
}
MasteryConfig.DefaultForm = { Name = "Divine Form", AttackPercent = 40, SpeedPercent = 20, DamageTaken = 0.7 }

return MasteryConfig
