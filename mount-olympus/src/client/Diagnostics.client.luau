-- Diagnostics (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > Diagnostics
--
-- Sends a small report to the server so problems on real devices can be
-- investigated: frame rate, ping, script errors, and what the sword
-- animation system is doing. Turn off with GameConfig.Debug.Diagnostics.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
if not GameConfig.Debug.Diagnostics then
	return
end
local SwordAnimator = require(Shared:WaitForChild("SwordAnimator"))
local reportRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClientReport")

local player = Players.LocalPlayer
local errors = {}
local errorCount = 0

ScriptContext.Error:Connect(function(message, trace, source)
	errorCount += 1
	if #errors < 15 then
		table.insert(errors, {
			Message = string.sub(tostring(message), 1, 300),
			Trace = string.sub(tostring(trace), 1, 300),
			Script = if source then source:GetFullName() else "?",
		})
	end
end)

local frames = 0
local slowFrames = 0
RunService.RenderStepped:Connect(function(dt)
	frames += 1
	if dt > 1 / 30 then
		slowFrames += 1
	end
end)

local function round(n)
	return math.floor(n * 10 + 0.5) / 10
end

local function snapshot(elapsed)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	local enemies = Workspace:FindFirstChild("Enemies")
	local ok, anim = pcall(SwordAnimator.GetDebugInfo)
	return {
		Build = GameConfig.BuildLabel,
		Fps = round(frames / elapsed),
		SlowFramePercent = round(100 * slowFrames / math.max(frames, 1)),
		PingMs = math.floor(player:GetNetworkPing() * 1000),
		MemoryMb = math.floor(Stats:GetTotalMemoryUsageMb()),
		Touch = UserInputService.TouchEnabled,
		Screen = if camera then ("%dx%d"):format(camera.ViewportSize.X, camera.ViewportSize.Y) else "?",
		Position = if root then ("%d,%d,%d"):format(root.Position.X, root.Position.Y, root.Position.Z) else "none",
		HasSword = character ~= nil and character:FindFirstChild("DivineSword") ~= nil,
		EnemyModels = if enemies then #enemies:GetChildren() else 0,
		Parts = #Workspace:GetDescendants(),
		Animator = if ok then anim else { Error = tostring(anim) },
		ErrorCount = errorCount,
		Errors = errors,
	}
end

task.spawn(function()
	while player:GetAttribute("DataLoaded") ~= true do
		task.wait(1)
	end
	local started = os.clock()
	local last = os.clock()
	while true do
		-- Every 10 s for the first 5 minutes, then once a minute.
		task.wait(if os.clock() - started < 300 then 10 else 60)
		local now = os.clock()
		local report = snapshot(now - last)
		last = now
		frames, slowFrames = 0, 0
		errors = {}
		reportRemote:FireServer(report)
	end
end)
