-- TitanGateUI (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > TitanGateUI
--
-- Phase 7E: the Titan Gate menu (opened from the gate's prompt). Lists the
-- Olympian Challenges with Heroic and Mythic buttons, what each pays, and
-- your clears / best times. Display only: the server checks ranks and runs
-- the fight.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChallengeConfig = require(Shared:WaitForChild("ChallengeConfig"))
local Progression = require(Shared:WaitForChild("Progression"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local challengeRemote = Remotes:WaitForChild("ChallengeAction")
local notifyRemote = Remotes:WaitForChild("Notify")

local THEME = {
	Marble = Color3.fromRGB(246, 242, 232),
	MarbleDark = Color3.fromRGB(228, 220, 204),
	Bronze = Color3.fromRGB(140, 92, 45),
	Text = Color3.fromRGB(58, 44, 28),
	SubText = Color3.fromRGB(110, 95, 75),
	White = Color3.new(1, 1, 1),
	Locked = Color3.fromRGB(150, 150, 158),
	Danger = Color3.fromRGB(190, 50, 40),
	Titan = Color3.fromRGB(150, 70, 200),
	Cleared = Color3.fromRGB(70, 150, 70),
}

local function create(className, props, children)
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local function corner(r)
	return create("UICorner", { CornerRadius = UDim.new(0, r) })
end
local function stroke(color, t)
	return create("UIStroke", { Color = color, Thickness = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function padding(px)
	return create("UIPadding", { PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px) })
end
local function text(props)
	props.BackgroundTransparency = 1
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextColor3 = props.TextColor3 or THEME.Text
	props.Font = props.Font or Enum.Font.Gotham
	return create("TextLabel", props)
end
local function button(props)
	props.AutoButtonColor = true
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or THEME.White
	props.TextSize = props.TextSize or 14
	return create("TextButton", props, { corner(8) })
end


local gui = create("ScreenGui", { Name = "TitanGateUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10, Parent = playerGui })
local uiScale = create("UIScale", { Parent = gui })
local function updateScale()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	uiScale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.7, 1.2)
end
updateScale()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
local function updateEnabled()
	gui.Enabled = player:GetAttribute("DataLoaded") == true
end
player:GetAttributeChangedSignal("DataLoaded"):Connect(updateEnabled)
updateEnabled()


local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(720, 520),
	BackgroundColor3 = THEME.Marble, Visible = false, Parent = gui,
}, { corner(12), stroke(THEME.Titan, 3), padding(14) })
text({ Size = UDim2.new(1, -50, 0, 36), Font = Enum.Font.Garamond, TextSize = 34, Text = "Titan Gate: Olympian Challenges", Parent = panel })
local closeButton = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = THEME.Bronze, Text = "X", TextSize = 20, Parent = panel })
text({ Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 34), TextSize = 13, TextColor3 = THEME.SubText, TextWrapped = true,
	Text = "Solo rematches against much stronger bosses. Heroic: once you can enter that boss's arena. Mythic and the Gauntlet: Elder Gods only. First clear of each difficulty gives bonus Ambrosia.", Parent = panel })

local list = create("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 1, -78), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, ScrollBarImageColor3 = THEME.Bronze, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel,
}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }), create("UIPadding", { PaddingRight = UDim.new(0, 10) }) })

local function readRecords()
	local raw = player:GetAttribute("ChallengesJson")
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and type(decoded) == "table" then decoded else {}
end

local function rewardLine(challenge, difficulty)
	local gold = math.floor((challenge.Rewards.Gold or 0) * difficulty.Reward)
	local ambrosia = math.floor((challenge.Rewards.Ambrosia or 0) * difficulty.Reward)
	return ("%s Gold, %d Ambrosia"):format(Progression.FormatNumber(gold), ambrosia)
end

local rows = {}
for order, challenge in ChallengeConfig.Challenges do
	local row = create("Frame", { Size = UDim2.new(1, 0, 0, 92), BackgroundColor3 = THEME.MarbleDark, LayoutOrder = order, Parent = list }, { corner(8), padding(8) })
	text({ Size = UDim2.new(1, -300, 0, 22), Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = challenge.Color or THEME.Text, Text = challenge.Name, Parent = row })
	text({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -300, 0, 52), TextSize = 13, TextColor3 = THEME.SubText, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Text = challenge.Description, Parent = row })
	local buttons = {}
	for i, difficultyId in ChallengeConfig.DifficultyOrder do
		local difficulty = ChallengeConfig.Difficulties[difficultyId]
		local box = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(2 - i) * 146, 0.5, 0), Size = UDim2.fromOffset(140, 76), BackgroundTransparency = 1, Parent = row })
		local b = button({ Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = difficulty.Color, Text = difficulty.Name, TextSize = 16, Parent = box })
		local info = text({ Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 34), TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Text = "", Parent = box })
		b.Activated:Connect(function()
			if not ChallengeConfig.LockReason(challenge, difficultyId, player:GetAttribute("RankIndex") or 1) then
				challengeRemote:FireServer("Start", challenge.Id, difficultyId)
				panel.Visible = false
			end
		end)
		buttons[difficultyId] = { Button = b, Info = info, Difficulty = difficulty }
	end
	rows[challenge.Id] = { Challenge = challenge, Buttons = buttons }
end

local function refresh()
	local recordsById = readRecords()
	local rank = player:GetAttribute("RankIndex") or 1
	for _, r in rows do
		for difficultyId, entry in r.Buttons do
			local reason = ChallengeConfig.LockReason(r.Challenge, difficultyId, rank)
			local record = recordsById[ChallengeConfig.Key(r.Challenge.Id, difficultyId)]
			entry.Button.BackgroundColor3 = if reason then THEME.Locked else entry.Difficulty.Color
			entry.Button.AutoButtonColor = reason == nil
			entry.Button.Text = if reason then entry.Difficulty.Name .. " (locked)" else entry.Difficulty.Name
			if reason then
				entry.Info.Text = reason
				entry.Info.TextColor3 = THEME.Danger
			elseif type(record) == "table" and (record.Clears or 0) > 0 then
				local best = record.Best or 0
				entry.Info.Text = ("Cleared x%d · best %d:%02d\n%s"):format(record.Clears, best // 60, best % 60, rewardLine(r.Challenge, entry.Difficulty))
				entry.Info.TextColor3 = THEME.Cleared
			else
				entry.Info.Text = rewardLine(r.Challenge, entry.Difficulty) .. "\n+" .. entry.Difficulty.FirstClearAmbrosia .. " first clear"
				entry.Info.TextColor3 = THEME.Text
			end
		end
	end
end
player:GetAttributeChangedSignal("ChallengesJson"):Connect(refresh)
player:GetAttributeChangedSignal("RankIndex"):Connect(refresh)
refresh()

closeButton.Activated:Connect(function()
	panel.Visible = false
end)
notifyRemote.OnClientEvent:Connect(function(kind)
	if kind == "OpenTitanGate" then
		refresh()
		panel.Visible = true
	end
end)
