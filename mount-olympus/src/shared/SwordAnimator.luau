-- SwordAnimator (ModuleScript, used by the client only)
-- Location: ReplicatedStorage > Shared > SwordAnimator
--
-- Plays our own sword animations (SwordPoses) on R15 joints every frame.
-- Roblox's Animator owns each joint's Transform (walk, idle...), so writing
-- there loses the race. Instead we move the joint's own offset, which the
-- Animator never touches, and cancel the Animator's current Transform on the
-- joints we drive. That keeps the sword arm steady and the swings visible.
-- Two joint types are supported:
--   * Motor6D (classic joints): we change C0.
--   * AnimationConstraint (Roblox's newer avatar joints): we change the CFrame
--     of its Attachment0, which plays the same role as C0.
-- (The game sets StarterPlayer.AvatarJointUpgrade = Disabled so characters
-- normally use Motor6D; the second path is a safety net.)
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
local baseC0 = setmetatable({}, { __mode = "k" }) -- [joint] = its original C0 / Attachment0 CFrame
local RETRY_MISSING = 2 -- seconds before looking again for a joint that wasn't found

-- Numbers for the diagnostics report.
local debugInfo = { Frames = 0, Updates = 0, JointsSet = 0, Errors = 0, LastError = "", MissingJoints = {}, JointKinds = {} }

-- Pose a joint: offset * pose * Transform^-1 * Transform = offset * pose,
-- whatever the Animator writes into Transform.
local function setJoint(joint, pose)
	if joint:IsA("Motor6D") then
		local base = baseC0[joint]
		if not base then
			base = joint.C0
			baseC0[joint] = base
		end
		joint.C0 = base * pose * joint.Transform:Inverse()
	else -- AnimationConstraint
		local attachment = joint.Attachment0
		if not attachment then
			return
		end
		local base = baseC0[joint]
		if not base then
			base = attachment.CFrame
			baseC0[joint] = base
		end
		attachment.CFrame = base * pose * joint.Transform:Inverse()
	end
end

local function releaseJoint(joint)
	local base = baseC0[joint]
	if not base then
		return
	end
	if joint:IsA("Motor6D") then
		joint.C0 = base
	elseif joint.Attachment0 then
		joint.Attachment0.CFrame = base
	end
	baseC0[joint] = nil
end

local function toCFrame(e)
	return CFrame.Angles(math.rad(e[1]), math.rad(e[2]), math.rad(e[3]))
end

local function getMotor(model, joint)
	local cache = motorCache[model]
	if not cache then
		cache = {}
		motorCache[model] = cache
	end
	local found = cache[joint]
	if typeof(found) == "Instance" and found.Parent then
		return found
	end
	if typeof(found) == "number" and os.clock() < found then
		return nil -- looked recently and it wasn't there
	end
	-- Usual place first, then anywhere in the model.
	local part = model:FindFirstChild(JOINT_PARTS[joint])
	local candidate = part and part:FindFirstChild(joint)
	if not (candidate and (candidate:IsA("Motor6D") or candidate:IsA("AnimationConstraint"))) then
		candidate = nil
		for _, d in model:GetDescendants() do
			if d.Name == joint and (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) then
				candidate = d
				break
			end
		end
	end
	if candidate then
		cache[joint] = candidate
		debugInfo.JointKinds[candidate.ClassName] = true
		return candidate
	end
	cache[joint] = os.clock() + RETRY_MISSING
	debugInfo.MissingJoints[model.Name .. "." .. joint] = true
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
	for joint in cur do
		if not target[joint] then
			-- No longer ours: hand the joint back to Roblox's animations.
			local motor = getMotor(model, joint)
			if motor then
				releaseJoint(motor)
			end
			cur[joint] = nil
		end
	end
	for joint, cf in target do
		local motor = getMotor(model, joint)
		if motor then
			local blended = if cur[joint] then cur[joint]:Lerp(cf, alpha) else cf
			setJoint(motor, blended)
			debugInfo.JointsSet += 1
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
	debugInfo.Frames += 1

	local function update(model, blocking)
		debugInfo.Updates += 1
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

	local function safeUpdate(model, blocking)
		local ok, err = pcall(update, model, blocking)
		if not ok then
			debugInfo.Errors += 1
			debugInfo.LastError = tostring(err)
		end
	end

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			safeUpdate(character, player:GetAttribute("Blocking") == true)
		end
	end
	local enemies = Workspace:FindFirstChild("Enemies")
	if enemies then
		for _, model in enemies:GetChildren() do
			safeUpdate(model, false)
		end
	end
end

-- For the diagnostics report: counters, plus a look at the local character's arm joint.
function SwordAnimator.GetDebugInfo()
	local info = table.clone(debugInfo)
	local missing = {}
	for name in debugInfo.MissingJoints do
		table.insert(missing, name)
	end
	info.MissingJoints = table.concat(missing, ",")
	local kinds = {}
	for name in debugInfo.JointKinds do
		table.insert(kinds, name)
	end
	info.JointKinds = table.concat(kinds, ",")
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	info.RigType = humanoid and humanoid.RigType.Name or "?"
	local joint = character and getMotor(character, "RightShoulder")
	if joint then
		info.ShoulderJointType = joint.ClassName
		info.ShoulderPosed = baseC0[joint] ~= nil
		local x, y, z = joint.Transform:ToEulerAnglesXYZ()
		info.ShoulderTransformDeg = ("%d,%d,%d"):format(math.deg(x), math.deg(y), math.deg(z))
	end
	local joints = {}
	if character then
		for _, d in character:GetDescendants() do
			if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
				table.insert(joints, d.ClassName .. ":" .. d.Name)
			end
		end
	end
	info.CharacterJoints = table.concat(joints, ",")
	return info
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

-- Right before each frame is drawn, using that frame's animation values.
RunService.PreRender:Connect(step)

return SwordAnimator
