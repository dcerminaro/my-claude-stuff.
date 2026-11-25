-- AimDot (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > AimDot
--
-- A small white dot fixed in the centre of the screen. In a fighting area your
-- attacks (swings, arrows, abilities) go where it points: the character turns
-- to face it as you attack (see Shared/AimHelper).
-- Only shown when a weapon is in your hand AND you are in a fighting area
-- (an arena / trial / challenge run, or on the Practice Field).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local AimHelper = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AimHelper"))

local DOT_SIZE = 10

local gui = Instance.new("ScreenGui")
gui.Name = "AimDot"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true -- true centre of the screen
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
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

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	dot.Visible = root ~= nil and humanoid ~= nil and humanoid.Health > 0
		and character:FindFirstChild("DivineSword") ~= nil and AimHelper.InFightingArea(root)
end)
