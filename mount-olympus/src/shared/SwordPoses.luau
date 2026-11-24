-- SwordPoses (ModuleScript)
-- Location: ReplicatedStorage > Shared > SwordPoses
--
-- Our own sword animations, written as joint angles (degrees) for R15
-- characters. SwordAnimator plays them on every player's screen.
-- Each pose: { JointName = { X, Y, Z } }
--   Shoulder/Elbow/Wrist X+ = swing the limb forward/up, Z+ = out to the
--   right (for the right arm), Waist Y+ = turn the upper body to the left.
-- Each move: a list of { time in seconds, pose }. Missing joints = neutral.
-- Tweak the numbers here to change how attacks look.

local Poses = {}

-- Standing ready: sword held up in front.
Poses.Hold = {
	RightShoulder = { 30, 0, 10 },
	RightElbow = { 60, 0, 0 },
	RightWrist = { -20, 0, 0 },
}

-- Blocking: sword across the body, other arm braced.
Poses.Block = {
	RightShoulder = { 70, 0, -20 },
	RightElbow = { 60, 0, 0 },
	RightWrist = { -10, 70, 0 },
	LeftShoulder = { 60, 0, 20 },
	LeftElbow = { 70, 0, 0 },
	Waist = { 0, 10, 0 },
}

-- Slash 1: high on the right, cutting down to the lower left.
local slash1Up = {
	RightShoulder = { 160, 0, 35 },
	RightElbow = { 30, 0, 0 },
	RightWrist = { -10, 0, 0 },
	LeftShoulder = { 20, 0, -10 },
	Waist = { 0, -25, 0 },
}
local slash1Down = {
	RightShoulder = { 55, 0, -45 },
	RightElbow = { 10, 0, 0 },
	RightWrist = { -70, 0, 0 },
	LeftShoulder = { -15, 0, -10 },
	Waist = { 0, 30, 0 },
}

-- Slash 2: backhand, from the left across to the right.
local slash2Start = {
	RightShoulder = { 110, 0, -55 },
	RightElbow = { 80, 0, 0 },
	RightWrist = { -30, 0, 0 },
	LeftShoulder = { 10, 0, -10 },
	Waist = { 0, 30, 0 },
}
local slash2End = {
	RightShoulder = { 85, 0, 60 },
	RightElbow = { 5, 0, 0 },
	RightWrist = { -80, 0, 0 },
	LeftShoulder = { -10, 0, -15 },
	Waist = { 0, -30, 0 },
}

-- Lunge: pull back, then thrust straight forward.
local lungeBack = {
	RightShoulder = { 20, 0, 15 },
	RightElbow = { 110, 0, 0 },
	RightWrist = { -120, 0, 0 },
	LeftShoulder = { 40, 0, -20 },
	Waist = { 0, -20, 0 },
}
local lungeThrust = {
	RightShoulder = { 90, 0, 0 },
	RightElbow = { 0, 0, 0 },
	RightWrist = { -90, 0, 0 },
	LeftShoulder = { -30, 0, -20 },
	Waist = { 0, 15, 0 },
}

Poses.Moves = {
	Slash1 = { { 0, Poses.Hold }, { 0.09, slash1Up }, { 0.2, slash1Down }, { 0.42, Poses.Hold } },
	Slash2 = { { 0, Poses.Hold }, { 0.08, slash2Start }, { 0.19, slash2End }, { 0.42, Poses.Hold } },
	Lunge = { { 0, Poses.Hold }, { 0.1, lungeBack }, { 0.21, lungeThrust }, { 0.5, Poses.Hold } },
}
Poses.ComboOrder = { "Slash1", "Slash2", "Lunge" }

-- Enemies raise their weapon during the red warning, then strike.
function Poses.EnemyAttack(windup)
	return {
		{ 0, Poses.Hold },
		{ windup * 0.6, slash1Up },
		{ windup, slash1Up },
		{ windup + 0.12, slash1Down },
		{ windup + 0.45, Poses.Hold },
	}
end

-- For the preview renderer / tests.
Poses.Named = {
	Hold = Poses.Hold,
	Block = Poses.Block,
	Slash1Up = slash1Up,
	Slash1Down = slash1Down,
	Slash2Start = slash2Start,
	Slash2End = slash2End,
	LungeBack = lungeBack,
	LungeThrust = lungeThrust,
}

return Poses
