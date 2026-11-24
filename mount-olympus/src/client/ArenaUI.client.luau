-- ArenaUI (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > ArenaUI
--
-- Phase 5 interface:
--   * Arena Gate menu: arenas with level ranges / lock reasons, Fight Solo,
--     Join Party, and the party list with Start / Leave.
--   * During a run: wave and enemies-left tracker, countdowns, boss health bar,
--     and a Leave button.
--   * Results screen (victory or defeat) with rewards.
-- Display only: the server runs the arena and decides everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaConfig = require(Shared:WaitForChild("ArenaConfig"))
local Progression = require(Shared:WaitForChild("Progression"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRemote = Remotes:WaitForChild("ArenaAction")
local eventRemote = Remotes:WaitForChild("ArenaEvent")
local notifyRemote = Remotes:WaitForChild("Notify")

local THEME = {
	Marble = Color3.fromRGB(246, 242, 232),
	MarbleDark = Color3.fromRGB(228, 220, 204),
	Gold = Color3.fromRGB(212, 175, 55),
	Bronze = Color3.fromRGB(140, 92, 45),
	Text = Color3.fromRGB(58, 44, 28),
	SubText = Color3.fromRGB(110, 95, 75),
	White = Color3.new(1, 1, 1),
	Ready = Color3.fromRGB(70, 150, 70),
	Party = Color3.fromRGB(70, 110, 180),
	Locked = Color3.fromRGB(130, 130, 140),
	Danger = Color3.fromRGB(190, 50, 40),
}
local TITLE_FONT = Enum.Font.Garamond
local BODY_FONT = Enum.Font.GothamBold
local SMALL_FONT = Enum.Font.Gotham

--------------------------------------------------------------------------
-- Small UI helpers
--------------------------------------------------------------------------
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
local function stroke(color, thickness)
	return create("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function padding(px)
	return create("UIPadding", { PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px) })
end
local function text(props)
	props.BackgroundTransparency = 1
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextColor3 = props.TextColor3 or THEME.Text
	props.Font = props.Font or SMALL_FONT
	return create("TextLabel", props)
end
local function button(props)
	props.AutoButtonColor = true
	props.Font = props.Font or BODY_FONT
	props.TextColor3 = props.TextColor3 or THEME.White
	props.TextSize = props.TextSize or 15
	return create("TextButton", props, { corner(8) })
end

local gui = create("ScreenGui", { Name = "ArenaUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 7, Parent = playerGui })
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

local function serverNow()
	return Workspace:GetServerTimeNow()
end

--------------------------------------------------------------------------
-- 1. Arena Gate menu
--------------------------------------------------------------------------
local menu = create("Frame", {
	Name = "Menu",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(640, 500),
	BackgroundColor3 = THEME.Marble,
	Visible = false,
	Parent = gui,
}, { corner(12), stroke(Color3.fromRGB(230, 90, 50), 3), padding(14) })
text({ Size = UDim2.new(1, -50, 0, 36), Font = TITLE_FONT, TextSize = 34, Text = "Arena Gate", Parent = menu })
local closeMenu = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = THEME.Bronze, Text = "X", TextSize = 20, Parent = menu })
text({ Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = THEME.SubText, Text = "5 waves, a boss in the last one. Fight alone or with up to 4 players.", Parent = menu })

local partyBar = create("Frame", {
	Name = "Party",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 56),
	BackgroundColor3 = Color3.fromRGB(215, 225, 240),
	Visible = false,
	Parent = menu,
}, { corner(8), padding(8) })
local partyLabel = text({ Size = UDim2.new(1, -240, 1, 0), Font = BODY_FONT, TextSize = 14, TextWrapped = true, Text = "", Parent = partyBar })
local startParty = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -112, 0.5, 0), Size = UDim2.fromOffset(110, 40), BackgroundColor3 = THEME.Ready, Text = "Start", Parent = partyBar })
local leaveParty = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(104, 40), BackgroundColor3 = THEME.Bronze, Text = "Leave party", Parent = partyBar })

local list = create("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 64),
	Size = UDim2.new(1, 0, 1, -64),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = THEME.Bronze,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = menu,
}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }), create("UIPadding", { PaddingRight = UDim.new(0, 10) }) })

local rows = {}
for order, arena in ArenaConfig.Arenas do
	local row = create("Frame", { Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = THEME.MarbleDark, LayoutOrder = order, Parent = list }, { corner(8), padding(8) })
	text({ Size = UDim2.new(1, -240, 0, 22), Font = BODY_FONT, TextSize = 17, TextColor3 = arena.Color or THEME.Text, Text = arena.DisplayName, Parent = row })
	text({ Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -240, 0, 18), TextSize = 13, TextColor3 = THEME.SubText, Text = ("Levels %d-%d · %s"):format(arena.MinLevel, arena.MaxLevel, arena.Description), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	local status = text({ Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, -240, 0, 16), Font = BODY_FONT, TextSize = 13, TextColor3 = THEME.Danger, Text = "", Parent = row })
	local solo = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -116, 0.5, 0), Size = UDim2.fromOffset(110, 44), BackgroundColor3 = THEME.Ready, Text = "Fight Solo", Parent = row })
	local party = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(110, 44), BackgroundColor3 = THEME.Party, Text = "Join Party", Parent = row })
	solo.Activated:Connect(function()
		if not ArenaConfig.LockReason(arena, player:GetAttribute("Level") or 1, player:GetAttribute("RankIndex") or 1) then
			actionRemote:FireServer("StartSolo", arena.Id)
			menu.Visible = false
		end
	end)
	party.Activated:Connect(function()
		if not ArenaConfig.LockReason(arena, player:GetAttribute("Level") or 1, player:GetAttribute("RankIndex") or 1) then
			actionRemote:FireServer("JoinQueue", arena.Id)
		end
	end)
	rows[arena.Id] = { Arena = arena, Status = status, Solo = solo, Party = party }
end

local function refreshMenu()
	local level = player:GetAttribute("Level") or 1
	for _, r in rows do
		local reason = ArenaConfig.LockReason(r.Arena, level, player:GetAttribute("RankIndex") or 1)
		r.Status.Text = if reason then "Locked: " .. reason else ""
		r.Solo.Visible = reason == nil
		r.Party.Visible = reason == nil
	end
end
player:GetAttributeChangedSignal("Level"):Connect(refreshMenu)
refreshMenu()

closeMenu.Activated:Connect(function()
	menu.Visible = false
end)
startParty.Activated:Connect(function()
	actionRemote:FireServer("StartParty")
	menu.Visible = false
end)
leaveParty.Activated:Connect(function()
	actionRemote:FireServer("LeaveQueue")
end)

--------------------------------------------------------------------------
-- 2. In-run tracker and boss bar (top centre)
--------------------------------------------------------------------------
local tracker = create("Frame", {
	Name = "Tracker",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(420, 64),
	BackgroundColor3 = THEME.Marble,
	BackgroundTransparency = 0.05,
	Visible = false,
	Parent = gui,
}, { corner(10), stroke(THEME.Gold, 2), padding(8) })
local trackerTitle = text({ Size = UDim2.new(1, -90, 0, 22), Font = TITLE_FONT, TextSize = 22, Text = "", Parent = tracker })
local trackerStatus = text({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -90, 0, 22), Font = BODY_FONT, TextSize = 16, Text = "", Parent = tracker })
local leaveButton = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(80, 40), BackgroundColor3 = THEME.Danger, Text = "Leave", Parent = tracker })
leaveButton.Activated:Connect(function()
	actionRemote:FireServer("Leave")
end)

local bossFrame = create("Frame", {
	Name = "Boss",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 80),
	Size = UDim2.fromOffset(520, 46),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})
local bossName = text({ Size = UDim2.new(1, 0, 0, 20), Font = TITLE_FONT, TextSize = 22, TextColor3 = THEME.White, TextStrokeTransparency = 0.3, TextXAlignment = Enum.TextXAlignment.Center, Text = "", Parent = bossFrame })
local bossBack = create("Frame", { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = Color3.fromRGB(40, 25, 25), Parent = bossFrame }, { corner(6), stroke(THEME.Gold, 2) })
local bossFill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 60, 45), Parent = bossBack }, { corner(6) })
local bossHp = text({ Size = UDim2.fromScale(1, 1), Font = BODY_FONT, TextSize = 13, TextColor3 = THEME.White, TextStrokeTransparency = 0.4, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2, Text = "", Parent = bossBack })

local function findBoss(runId)
	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		return nil
	end
	for _, model in enemies:GetChildren() do
		if model:GetAttribute("IsBoss") and model:GetAttribute("RunId") == runId then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				return model, humanoid
			end
		end
	end
	return nil
end

local function updateTracker()
	local runId = player:GetAttribute("ArenaRunId")
	tracker.Visible = runId ~= nil
	if not runId then
		bossFrame.Visible = false
		return
	end
	local state = player:GetAttribute("ArenaState") or ""
	local wave = player:GetAttribute("ArenaWave") or 0
	local waves = player:GetAttribute("ArenaWaves") or 5
	local left = player:GetAttribute("ArenaEnemiesLeft") or 0
	local timer = math.max(0, math.ceil((player:GetAttribute("ArenaTimerEnd") or 0) - serverNow()))
	trackerTitle.Text = player:GetAttribute("ArenaName") or "Arena"
	if state == "Countdown" then
		trackerStatus.Text = ("Get ready... %d"):format(timer)
	elseif state == "Fighting" then
		trackerStatus.Text = ("Wave %d / %d   ·   Enemies left: %d"):format(wave, waves, left)
	elseif state == "Intermission" then
		trackerStatus.Text = ("Wave %d cleared! Next wave in %d"):format(wave, timer)
	elseif state == "Victory" then
		trackerStatus.Text = ("Victory! Returning in %d"):format(timer)
	elseif state == "Failed" then
		trackerStatus.Text = ("Defeated. Returning in %d"):format(timer)
	end

	local boss, humanoid = findBoss(runId)
	bossFrame.Visible = boss ~= nil
	if boss then
		local enraged = boss:GetAttribute("Enraged") == true
		bossName.Text = (boss:GetAttribute("DisplayName") or boss.Name) .. (if enraged then "  (ENRAGED)" else "")
		bossFill.BackgroundColor3 = if enraged then Color3.fromRGB(235, 40, 30) else Color3.fromRGB(200, 60, 45)
		bossFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
		bossHp.Text = ("%s / %s"):format(Progression.FormatNumber(math.ceil(humanoid.Health)), Progression.FormatNumber(humanoid.MaxHealth))
	end
end

task.spawn(function()
	while true do
		task.wait(0.1)
		updateTracker()
	end
end)

--------------------------------------------------------------------------
-- 3. Results screen
--------------------------------------------------------------------------
local results = create("Frame", {
	Name = "Results",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(440, 340),
	BackgroundColor3 = THEME.Marble,
	Visible = false,
	ZIndex = 5,
	Parent = gui,
}, { corner(14), padding(16) })
local resultsStroke = stroke(THEME.Gold, 4)
resultsStroke.Parent = results
local resultsTitle = text({ Size = UDim2.new(1, 0, 0, 50), Font = TITLE_FONT, TextSize = 46, TextXAlignment = Enum.TextXAlignment.Center, Text = "", Parent = results })
local resultsInfo = text({ Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 40), TextSize = 15, TextColor3 = THEME.SubText, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Text = "", Parent = results })
local resultsRewards = text({ Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 130), Font = BODY_FONT, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Text = "", Parent = results })
local homeButton = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(220, 48), BackgroundColor3 = THEME.Gold, TextColor3 = THEME.Text, TextSize = 18, Text = "Return to Olympus", ZIndex = 6, Parent = results })
homeButton.Activated:Connect(function()
	results.Visible = false
	actionRemote:FireServer("Leave")
end)

local REWARD_NAMES = { XP = "XP", Gold = "Gold", DivineFavor = "Divine Favor", Ambrosia = "Ambrosia" }
local REWARD_ORDER = { "XP", "Gold", "DivineFavor", "Ambrosia" }

--------------------------------------------------------------------------
-- Server events
--------------------------------------------------------------------------
eventRemote.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Queue" then
		local arena = a and ArenaConfig.ById[a]
		partyBar.Visible = arena ~= nil
		if arena then
			partyLabel.Text = ("Party for %s (%d/%d): %s"):format(arena.DisplayName, #b, ArenaConfig.Party.MaxPlayers, table.concat(b, ", "))
		end
	elseif kind == "Result" and type(a) == "table" then
		local victory = a.Victory == true
		resultsTitle.Text = if victory then "VICTORY!" else "DEFEATED"
		resultsTitle.TextColor3 = if victory then THEME.Gold else THEME.Danger
		resultsStroke.Color = if victory then THEME.Gold else THEME.Danger
		local seconds = tonumber(a.Seconds) or 0
		resultsInfo.Text = ("%s · waves cleared %d/%d · time %d:%02d"):format(tostring(a.Arena), a.WavesCleared or 0, a.Waves or 5, seconds // 60, seconds % 60)
		local lines = {}
		for _, key in REWARD_ORDER do
			local value = type(a.Rewards) == "table" and a.Rewards[key]
			if value and value > 0 then
				table.insert(lines, ("+%s %s"):format(Progression.FormatNumber(value), REWARD_NAMES[key]))
			end
		end
		resultsRewards.Text = if #lines > 0 then table.concat(lines, "\n") else "No rewards this time.\nClear more waves for a bigger share!"
		results.Visible = true
		task.delay(ArenaConfig.ReturnDelay + 1, function()
			results.Visible = false
		end)
	end
end)

notifyRemote.OnClientEvent:Connect(function(kind)
	if kind == "OpenArenaMenu" then
		refreshMenu()
		menu.Visible = true
	end
end)
