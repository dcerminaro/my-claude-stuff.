-- AimDot (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > AimDot
--
-- A small white dot showing where your weapon attacks land: straight ahead
-- (attacks go the way your character faces) at your weapon's reach, or on the
-- first thing in the way. Bows reach much further than swords.
-- Only shown when a weapon is in your hand AND you are in a fighting area
-- (an arena / trial run, or on the Practice Field).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))

local DOT_SIZE = 10
local field = CombatConfig.PracticeField

local gui = Instance.new("ScreenGui")
gui.Name = "AimDot"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
dot.BackgroundColor3 = Color3.new(1, 1, 1)
dot.BorderSizePixel = 0
dot.Visible = false
dot.Parent = gui
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0.5, 0)
round.Parent = dot
local outline = Instance.new("UIStroke") -- thin dark edge so it shows on white marble too
outline.Color = Color3.new(0, 0, 0)
outline.Transparency = 0.5
outline.Thickness = 1
outline.Parent = dot

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true -- ignore see-through effects and markers

local function inFightingArea(root)
	local runId = player:GetAttribute("ArenaRunId")
	if runId ~= nil and runId ~= "" and runId ~= 0 then
		return true
	end
	local offset = root.Position - field.Center
	return math.abs(offset.X) <= field.Size.X / 2 and math.abs(offset.Z) <= field.Size.Z / 2 and math.abs(offset.Y) < 25
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = Workspace.CurrentCamera
	if not root or not humanoid or humanoid.Health <= 0 or not camera
		or not character:FindFirstChild("DivineSword") or not inFightingArea(root) then
		dot.Visible = false
		return
	end

	local weapon = WeaponConfig.Types[player:GetAttribute("WeaponType") or "Sword"] or WeaponConfig.Types.Sword
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then
		dot.Visible = false
		return
	end
	look = look.Unit
	local origin = root.Position + Vector3.new(0, 0.5, 0)
	rayParams.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(origin, look * weapon.Range, rayParams)
	local target = if hit then hit.Position else origin + look * weapon.Range

	local screen, onScreen = camera:WorldToViewportPoint(target)
	if not onScreen then
		dot.Visible = false
		return
	end
	dot.Position = UDim2.fromOffset(screen.X, screen.Y)
	dot.Visible = true
end)
