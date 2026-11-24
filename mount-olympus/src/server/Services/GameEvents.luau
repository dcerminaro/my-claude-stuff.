-- GameEvents (ModuleScript)
-- Location: ServerScriptService > Services > GameEvents
--
-- A tiny message board for "something happened" (Phase 7D). Systems report
-- events here, and anything that cares (quests) listens, so systems don't
-- need to know about each other.
--   GameEvents.Fire(eventName, player, target, amount)
--   GameEvents.Connect(function(eventName, player, target, amount) ... end)
-- Events: KillEnemy, KillBoss (target = enemy type), WinArena (arena id),
-- UpgradeBuilding (building id), Worship (god id), UpgradeBlessing
-- (blessing id), UseAbility (god id), CraftWeapon, UpgradeWeapon (weapon id),
-- EarnGold (amount).

local GameEvents = {}

local listeners = {}

function GameEvents.Connect(listener)
	table.insert(listeners, listener)
end

function GameEvents.Fire(eventName, player, target, amount)
	for _, listener in listeners do
		task.spawn(listener, eventName, player, target, amount or 1)
	end
end

return GameEvents
