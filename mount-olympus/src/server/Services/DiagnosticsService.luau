-- DiagnosticsService (ModuleScript)
-- Location: ServerScriptService > Services > DiagnosticsService
--
-- Receives the small reports devices send (see the Diagnostics LocalScript),
-- adds server numbers (server frame rate, network use, memory, enemy count)
-- and saves the latest 40 per player in the "OlympusDiagnostics" DataStore.
-- They can be read later with a Luau Execution task. Debug use only.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local DiagnosticsService = {}

local KEEP = 40
local FLUSH_EVERY = 15
local MAX_REPORT_CHARS = 6000

local queue = {} -- [userId] = { entries }
local lastReport = {}
local serverFps = 0

-- Server-side notes about a player (e.g. an error applying their rank looks).
function DiagnosticsService.Note(player, text)
	local list = queue[player.UserId] or {}
	table.insert(list, { Time = os.time(), PlaceVersion = game.PlaceVersion, ServerNote = string.sub(tostring(text), 1, 1000) })
	queue[player.UserId] = list
end

function DiagnosticsService.Init(remote)
	local store = DataStoreService:GetDataStore("OlympusDiagnostics")

	-- Server frame rate (Heartbeats per second).
	local beats, since = 0, os.clock()
	RunService.Heartbeat:Connect(function()
		beats += 1
		local now = os.clock()
		if now - since >= 5 then
			serverFps = math.floor(beats / (now - since) * 10) / 10
			beats, since = 0, now
		end
	end)

	remote.OnServerEvent:Connect(function(player, report)
		local now = os.clock()
		if type(report) ~= "table" or (lastReport[player] and now - lastReport[player] < 5) then
			return
		end
		lastReport[player] = now
		local ok, json = pcall(HttpService.JSONEncode, HttpService, report)
		if not ok then
			return
		end
		local enemies = Workspace:FindFirstChild("Enemies")
		local entry = {
			Time = os.time(),
			PlaceVersion = game.PlaceVersion,
			Server = {
				Fps = serverFps,
				Players = #Players:GetPlayers(),
				MemoryMb = math.floor(Stats:GetTotalMemoryUsageMb()),
				ReceiveKbps = math.floor(Stats.DataReceiveKbps),
				SendKbps = math.floor(Stats.DataSendKbps),
				EnemyModels = if enemies then #enemies:GetChildren() else 0,
			},
			Client = string.sub(json, 1, MAX_REPORT_CHARS),
		}
		local list = queue[player.UserId] or {}
		table.insert(list, entry)
		queue[player.UserId] = list
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastReport[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(FLUSH_EVERY)
			for userId, entries in queue do
				queue[userId] = nil
				pcall(function()
					store:UpdateAsync("Player_" .. userId, function(old)
						local list = if type(old) == "table" then old else {}
						for _, e in entries do
							table.insert(list, e)
						end
						while #list > KEEP do
							table.remove(list, 1)
						end
						return list
					end)
				end)
			end
		end
	end)
end

return DiagnosticsService
