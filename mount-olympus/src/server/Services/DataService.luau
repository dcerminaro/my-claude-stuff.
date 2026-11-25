-- DataService (ModuleScript)
-- Location: ServerScriptService > Services > DataService
--
-- Loads and saves each player's progress with DataStoreService.
-- Safety features:
--   * Session locking: only one server can own a player's data at a time,
--     so fast server-hopping cannot duplicate or roll back progress.
--   * Never overwrites saved data with defaults. If loading fails, the
--     player is kicked and NOTHING is written.
--   * Retries on load and save.
--   * Schema versioning + migrations for future updates.
--   * Autosave, save on leave, and save on server shutdown (BindToClose).
--
-- Other scripts must only change data through the table returned by
-- DataService.GetData(player). It returns nil if data is not safely loaded.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DATA = GameConfig.Data

local DataService = {}

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATA.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] Could not open the DataStore: " .. tostring(result))
		warn("[DataService] In Studio: publish the place, then Game Settings > Security > Enable Studio Access to API Services.")
	end
end

local profiles = {} -- [Player] = { Key = string, Data = table, Writing = bool, Released = bool }
local pendingReleases = 0
local shuttingDown = false

--------------------------------------------------------------------------
-- Default data
--------------------------------------------------------------------------
local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- The full save layout. Later phases fill in the empty sections.
local function makeDefaultData()
	return {
		SchemaVersion = DATA.SchemaVersion,

		Level = 1,
		XP = 0,
		RankIndex = 1, -- 1 = Mortal (see GameConfig.Ranks)

		Currencies = deepCopy(GameConfig.StartingCurrencies),

		SelectedGod = "",     -- Phase 3
		GodLoyalty = {},      -- Phase 3: [GodName] = number
		Blessings = {},       -- Phase 3: [GodName] = { [BlessingId] = level }
		NextWorshipAt = 0,    -- Phase 3: os.time() when worship is ready again
		GodChange = {         -- Phase 3: Shrine of Change quest in progress
			Target = "",      -- god being switched to ("" = none)
			Prayers = 0,
			NextPrayerAt = 0,
		},

		Temple = {            -- Phase 2
			Tier = 1,
			Buildings = {},   -- [BuildingId] = level
			Prestige = 0,     -- Phase 7E: Temple Prestige level (0-10)
		},

		Inventory = {         -- Phase 7
			Items = {},
			EquippedWeapon = "",
		},

		Quests = {            -- Phase 7
			Active = {},
			Completed = {},
			LastDailyReset = 0,
			Daily = { Day = 0, Ids = {}, Progress = {}, Claimed = {} }, -- Phase 7D
		},

		CompletedTrials = {}, -- [TrialId] = true
		Challenges = {},      -- Phase 7E: ["<challenge>:<difficulty>"] = { Clears, Best (seconds) }

		Stats = {
			JoinCount = 0,
			EnemiesDefeated = 0,
		},

		Settings = {
			MusicVolume = 0.5,
			SfxVolume = 0.8,
		},
	}
end

-- Adds any missing fields (e.g. after an update) without touching existing values.
local function reconcile(target, template)
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
end

--------------------------------------------------------------------------
-- Schema migrations
-- When you change the data layout: add a step here, then increase
-- GameConfig.Data.SchemaVersion by 1.
--------------------------------------------------------------------------
local Migrations = {
	-- Example for the future:
	-- [1] = function(data) -- turns a version 1 save into version 2
	--     data.Temple.Prestige = 0
	-- end,
}

local function migrate(data)
	local version = tonumber(data.SchemaVersion) or 0
	while version < DATA.SchemaVersion do
		local step = Migrations[version]
		if step then
			step(data)
		end
		version += 1
	end
	data.SchemaVersion = DATA.SchemaVersion
end

--------------------------------------------------------------------------
-- Low-level DataStore calls
-- Stored format: { Data = <player data>, SessionLock = { JobId, Time } | nil }
--------------------------------------------------------------------------
local function keyFor(player)
	return "Player_" .. player.UserId
end

local function lockedByAnotherServer(lock)
	return type(lock) == "table"
		and lock.JobId ~= game.JobId
		and (os.time() - (tonumber(lock.Time) or 0)) < DATA.SessionLockTimeout
end

-- Returns status ("OK", "Locked", "TooNew", "Corrupt", "Error") and data/error.
local function tryLoad(key)
	local status, loaded = "Error", nil

	local ok, err = pcall(function()
		store:UpdateAsync(key, function(stored)
			status, loaded = "Error", nil

			if stored ~= nil and type(stored) ~= "table" then
				status = "Corrupt"
				return nil -- cancel: do not write anything
			end
			stored = stored or {}

			if lockedByAnotherServer(stored.SessionLock) then
				status = "Locked"
				return nil
			end

			if type(stored.Data) == "table" and (tonumber(stored.Data.SchemaVersion) or 0) > DATA.SchemaVersion then
				status = "TooNew" -- saved by a newer version of the game; this server must not touch it
				return nil
			end

			if type(stored.Data) ~= "table" then
				stored.Data = makeDefaultData() -- genuinely new player (no save exists)
			end

			stored.SessionLock = { JobId = game.JobId, Time = os.time() }
			status, loaded = "OK", stored.Data
			return stored
		end)
	end)

	if not ok then
		return "Error", tostring(err)
	end
	return status, loaded
end

local function writeProfile(profile, release)
	for attempt = 1, DATA.MaxSaveAttempts do
		local lockLost = false
		local ok, err = pcall(function()
			store:UpdateAsync(profile.Key, function(stored)
				lockLost = false
				if type(stored) ~= "table" then
					stored = {}
				end
				if type(stored.SessionLock) == "table" and stored.SessionLock.JobId ~= game.JobId then
					lockLost = true -- another server owns this data now; never overwrite it
					return nil
				end
				stored.Data = profile.Data
				if release then
					stored.SessionLock = nil
				else
					stored.SessionLock = { JobId = game.JobId, Time = os.time() }
				end
				return stored
			end)
		end)

		if ok then
			if lockLost then
				warn("[DataService] Did not save " .. profile.Key .. ": another server owns this data.")
				return false
			end
			print("[DataService] Saved " .. profile.Key .. (if release then " (released)" else ""))
			return true
		end

		warn(("[DataService] Save attempt %d for %s failed: %s"):format(attempt, profile.Key, tostring(err)))
		if attempt < DATA.MaxSaveAttempts then
			task.wait(attempt * 2)
		end
	end
	return false
end

-- Only one write per player at a time.
local function save(profile, release)
	while profile.Writing do
		task.wait(0.1)
	end
	profile.Writing = true
	local ok = writeProfile(profile, release)
	profile.Writing = false
	return ok
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------

-- Yields. Returns the player's data table, or nil (player is kicked or left).
function DataService.LoadPlayer(player)
	if not store then
		player:Kick("Saving is unavailable right now, so your progress was not loaded. Please rejoin later.")
		return nil
	end

	local key = keyFor(player)

	for attempt = 1, DATA.MaxLoadAttempts do
		if not player.Parent or shuttingDown then
			return nil
		end

		local status, result = tryLoad(key)

		if status == "OK" then
			migrate(result)
			reconcile(result, makeDefaultData())
			result.Stats.JoinCount += 1

			profiles[player] = { Key = key, Data = result, Writing = false, Released = false }
			print(("[DataService] Loaded %s (Level %d)"):format(key, result.Level))

			if not player.Parent then
				-- They left while we were loading: hand the data straight back.
				DataService.ReleasePlayer(player)
				return nil
			end
			return result

		elseif status == "TooNew" then
			player:Kick("A newer version of Mount Olympus saved your progress. Please rejoin to get an updated server.")
			return nil

		elseif status == "Corrupt" then
			warn("[DataService] Save for " .. key .. " is not in the expected format. Not loading or overwriting it.")
			player:Kick("There is a problem with your save file. It has not been changed. Please contact the developer.")
			return nil
		end

		warn(("[DataService] Load attempt %d/%d for %s: %s %s"):format(
			attempt, DATA.MaxLoadAttempts, key, status, if result then tostring(result) else ""))
		task.wait(DATA.LoadRetryDelay)
	end

	player:Kick("We couldn't load your progress safely, so nothing was changed. Please rejoin in a minute.")
	return nil
end

-- Returns the live data table, or nil if not loaded / already released.
function DataService.GetData(player)
	local profile = profiles[player]
	if profile and not profile.Released then
		return profile.Data
	end
	return nil
end

function DataService.IsLoaded(player)
	return DataService.GetData(player) ~= nil
end

-- Yields. Saves immediately (keeps the session lock).
function DataService.SaveNow(player)
	local profile = profiles[player]
	if not profile or profile.Released then
		return false
	end
	return save(profile, false)
end

-- Yields. Final save + unlock. Call when the player leaves.
function DataService.ReleasePlayer(player)
	local profile = profiles[player]
	if not profile or profile.Released then
		return
	end
	profile.Released = true
	pendingReleases += 1
	save(profile, true)
	pendingReleases -= 1
	if profiles[player] == profile then
		profiles[player] = nil
	end
end

-- Studio testing only: wipe this player's progress back to defaults.
function DataService.ResetData(player)
	local profile = profiles[player]
	if not profile or profile.Released then
		return false
	end
	profile.Data = makeDefaultData()
	return true
end

function DataService.Init()
	-- Autosave loop
	task.spawn(function()
		while true do
			task.wait(DATA.AutosaveInterval)
			for _, profile in profiles do
				if not profile.Released and not profile.Writing then
					task.spawn(save, profile, false)
				end
			end
		end
	end)

	-- Server shutting down: save everyone before Roblox closes the server (max ~30s).
	game:BindToClose(function()
		shuttingDown = true
		for player in profiles do
			task.spawn(DataService.ReleasePlayer, player)
		end
		local started = os.clock()
		while pendingReleases > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
end

return DataService
