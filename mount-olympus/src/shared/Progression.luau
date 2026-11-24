-- Progression (ModuleScript)
-- Location: ReplicatedStorage > Shared > Progression
--
-- Pure formulas shared by server and client (no data is changed here).
-- The server uses these to apply progression; the client uses them for display.

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))

local P = GameConfig.Progression
local Progression = {}

-- XP required to go from `level` to `level + 1`. Returns 0 at max level.
function Progression.XPToNextLevel(level)
	if level >= P.MaxLevel then
		return 0
	end
	return math.floor(P.BaseXP * level ^ P.XPExponent)
end

function Progression.GetRank(rankIndex)
	local index = math.clamp(math.floor(tonumber(rankIndex) or 1), 1, #GameConfig.Ranks)
	return GameConfig.Ranks[index]
end

-- Highest level a player can reach at their current rank.
function Progression.GetLevelCap(rankIndex)
	if not P.LevelCappedByRank then
		return P.MaxLevel
	end
	return math.min(Progression.GetRank(rankIndex).MaxLevel, P.MaxLevel)
end

function Progression.GetMaxHealth(level)
	return P.BaseHealth + P.HealthPerLevel * (level - 1)
end

function Progression.GetBaseAttack(level)
	return P.BaseAttack + P.AttackPerLevel * (level - 1)
end

-- 950 -> "950", 1500 -> "1.5K", 2000000 -> "2M"
local SUFFIXES = { "", "K", "M", "B", "T", "Qa" }
function Progression.FormatNumber(n)
	n = math.floor(tonumber(n) or 0)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local value = n
	local i = 1
	while math.abs(value) >= 1000 and i < #SUFFIXES do
		value /= 1000
		i += 1
	end
	local text = string.format("%.1f%s", value, SUFFIXES[i])
	return (string.gsub(text, "%.0(%a)", "%1"))
end

return Progression
