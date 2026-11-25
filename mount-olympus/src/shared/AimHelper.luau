-- AimHelper (ModuleScript)
-- Location: ReplicatedStorage > Shared > AimHelper
--
-- Shared by AimDot, CombatController and AbilityController (client only).
-- In a fighting area your attacks go where the centre of the screen points
-- (the white dot), so the character turns to face the camera's direction
-- right before an attack.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local AimHelper = {}

local field = CombatConfig.PracticeField

-- In an arena / trial / challenge run, or on the Practice Field.
function AimHelper.InFightingArea(root)
	local player = Players.LocalPlayer
	local runId = player:GetAttribute("ArenaRunId")
	if runId ~= nil and runId ~= "" and runId ~= 0 then
		return true
	end
	if not root then
		return false
	end
	local offset = root.Position - field.Center
	return math.abs(offset.X) <= field.Size.X / 2 and math.abs(offset.Z) <= field.Size.Z / 2 and math.abs(offset.Y) < 25
end

-- The flat (no up/down) direction the camera looks, or nil.
function AimHelper.CameraDirection()
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local look = camera.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude < 0.05 then
		return nil
	end
	return look.Unit
end

-- Turns the character to face the dot. Returns the aim direction to send to
-- the server, or nil when not in a fighting area (attacks go where you face).
function AimHelper.FaceAim(root)
	if not root or not AimHelper.InFightingArea(root) then
		return nil
	end
	local direction = AimHelper.CameraDirection()
	if not direction then
		return nil
	end
	local position = root.Position
	root.CFrame = CFrame.lookAt(position, position + direction)
	return direction
end

return AimHelper
