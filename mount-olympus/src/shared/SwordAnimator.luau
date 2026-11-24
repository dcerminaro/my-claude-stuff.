-- SwordAnimator (ModuleScript, used by the client only)
-- Location: ReplicatedStorage > Shared > SwordAnimator
--
-- Plays our own sword animations (SwordPoses) by setting the R15 joints
-- every frame, right after Roblox's normal animations (walk, jump...).
-- It runs on every player's device for every nearby sword-holder: you,
-- other players (when the server tells us they swung) and enemies.
--   * Holding a weapon: the ready stance (right arm only, legs still walk).
--   * Blocking (player attribute "Blocking"): the guard pose.
--   * Attacks: SwordAnimator.Play(model, "Slash1" | "Slash2" | "Lunge")
--   * Enemy attacks: SwordAnimator.PlayKeys(model, SwordPoses.EnemyAttack(windup))

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Poses = require(script.Parent:WaitForChild("SwordPoses"))

local SwordAnimator = {}

local JOINT_PARTS = {
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	Waist = "UpperTorso",
}
local MAX_DISTANCE = 150 -- don't bother animating far-away characters
local BLEND_SPEED = 18   -- how fast the stance changes (hold <-> block)

local active = setmetatable({}, { __mode = "k" })  -- [Model] = { Keys, Start, Duration, Joints }
local current = setmetatable({}, { __mode = "k" }) -- [Model] = { [joint] = CFrame currently applied }
local motorCache = setmetatable({}, { __mode = "k" })

local function toCFrame(e)
	return CFrame.Angles(math.rad(e[1]), math.rad(e[2]), math.rad(e[3]))
end

local function getMotor(model, joint)
	local cache = motorCache[model]
	if not cache then
		cache = {}
		motorCache[model] = cache
	end
	local motor = cache[joint]
	if motor and motor.Parent then
		return motor
	end
	local part = model:FindFirstChild(JOINT_PARTS[joint])
	motor = part and part:FindFirstChild(joint)
	if motor and motor:IsA("Motor6D") then
		cache[joint] = motor
		return motor
	end
	return nil
end

local function jointsIn(keys)
	local set = {}
	for _, key in keys do
		for joint in key[2] do
			set[joint] = true
		end
	end
	return set
end

local function smooth(alpha)
	return alpha * alpha * (3 - 2 * alpha)
end

-- Pose at time t within a list of keyframes: { [joint] = CFrame }
local function sample(move, t)
	local keys = move.Keys
	local i = 1
	while i < #keys and keys[i + 1][1] < t do
		i += 1
	end
	local a, b = keys[i], keys[math.min(i + 1, #keys)]
	local span = b[1] - a[1]
	local alpha = if span > 0 then smooth(math.clamp((t - a[1]) / span, 0, 1)) else 1
	local pose = {}
	for joint in move.Joints do
		local from = a[2][joint] or { 0, 0, 0 }
		local to = b[2][joint] or { 0, 0, 0 }
		pose[joint] = toCFrame(from):Lerp(toCFrame(to), alpha)
	end
	return pose
end

local function stance(pose)
	local result = {}
	for joint, e in pose do
		result[joint] = toCFrame(e)
	end
	return result
end
local HOLD = stance(Poses.Hold)
local BLOCK = stance(Poses.Block)

local function apply(model, target, dt, instant)
	local cur = current[model]
	if not cur then
		cur = {}
		current[model] = cur
	end
	local alpha = if instant then 1 else math.min(1, dt * BLEND_SPEED)
	-- Joints we drove last frame but not now: blend back to neutral, then let go.
	for joint, cf in cur do
		if not target[joint] then
			local motor = getMotor(model, joint)
			local blended = cf:Lerp(CFrame.new(), alpha)
			if motor then
				motor.Transform = blended
			end
			cur[joint] = if alpha >= 1 then nil else blended
		end
	end
	for joint, cf in target do
		local motor = getMotor(model, joint)
		if motor then
			local blended = if cur[joint] then cur[joint]:Lerp(cf, alpha) else cf
			motor.Transform = blended
			cur[joint] = blended
		end
	end
end

local function holdsWeapon(model)
	return model:FindFirstChild("DivineSword") ~= nil or model:FindFirstChild("Weapon") ~= nil
end

local function step(dt)
	local camera = Workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()

	local function update(model, blocking)
		local root = model:FindFirstChild("HumanoidRootPart")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 or not holdsWeapon(model) then
			return
		end
		if (root.Position - camPos).Magnitude > MAX_DISTANCE then
			return
		end
		local move = active[model]
		if move then
			local t = now - move.Start
			if t < move.Duration then
				apply(model, sample(move, t), dt, true)
				return
			end
			active[model] = nil
		end
		apply(model, if blocking then BLOCK else HOLD, dt, false)
	end

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			update(character, player:GetAttribute("Blocking") == true)
		end
	end
	local enemies = Workspace:FindFirstChild("Enemies")
	if enemies then
		for _, model in enemies:GetChildren() do
			update(model, false)
		end
	end
end

-- Plays a keyframe list on a character or enemy.
function SwordAnimator.PlayKeys(model, keys)
	if not model or #keys < 2 then
		return
	end
	active[model] = {
		Keys = keys,
		Start = os.clock(),
		Duration = keys[#keys][1],
		Joints = jointsIn(keys),
	}
end

-- Plays one of the named moves in SwordPoses.Moves.
function SwordAnimator.Play(model, moveName)
	local keys = Poses.Moves[moveName]
	if keys then
		SwordAnimator.PlayKeys(model, keys)
	end
end

-- Runs each frame right after Roblox's own animations, so our poses win.
RunService.PreSimulation:Connect(step)

return SwordAnimator
