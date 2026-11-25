-- QuestUI (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > QuestUI
--
-- Phase 7D: quests on screen.
--   * Tracker (right side, under the god badge): up to 3 quests with
--     progress bars; finished ones first. Tap it to open the quest log.
--   * "Quests" button (left, under Weapons) opens the quest log: every
--     active quest grouped as Daily / Story / other chains, with rewards and
--     a Claim button when done.
-- Display only: the server tracks progress and pays rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local questRemote = Remotes:WaitForChild("QuestAction")

local THEME = {
	Marble = Color3.fromRGB(246, 242, 232),
	MarbleDark = Color3.fromRGB(228, 220, 204),
	Gold = Color3.fromRGB(212, 175, 55),
	Bronze = Color3.fromRGB(140, 92, 45),
	Text = Color3.fromRGB(58, 44, 28),
	SubText = Color3.fromRGB(110, 95, 75),
	White = Color3.new(1, 1, 1),
	Ready = Color3.fromRGB(70, 150, 70),
	Bar = Color3.fromRGB(200, 190, 170),
	Quest = Color3.fromRGB(70, 110, 170),
	Daily = Color3.fromRGB(170, 90, 150),
}

local CATEGORY_ORDER = { "Daily", "Story", "Combat", "Boss", "Temple", "Worship", "Forge", "Challenge", "Mastery", "God" }
local CATEGORY_NAMES = {
	Daily = "Daily Quests (new ones every day)",
	Story = "Story",
	Combat = "Combat",
	Boss = "Boss Hunts",
	Temple = "Temple Building",
	Worship = "Devotion",
	Forge = "The Forge",
	Challenge = "Olympian Challenges",
	Mastery = "Divine Mastery",
	God = "Your God",
}
local CURRENCY_NAMES = { XP = "XP", Gold = "Gold", DivineFavor = "Favor", Ambrosia = "Ambrosia" }

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

local function rewardText(rewards)
	local parts = {}
	for _, currency in { "XP", "Gold", "DivineFavor", "Ambrosia" } do
		if rewards[currency] then
			table.insert(parts, ("+%d %s"):format(rewards[currency], CURRENCY_NAMES[currency]))
		end
	end
	return table.concat(parts, "  ")
end

local function progressBar(parent, position, size, fraction, color)
	local back = create("Frame", { Position = position, Size = size, BackgroundColor3 = THEME.Bar, BorderSizePixel = 0, Parent = parent }, { corner(4) })
	create("Frame", { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1), BackgroundColor3 = color, BorderSizePixel = 0, Parent = back }, { corner(4) })
	return back
end

local gui = create("ScreenGui", { Name = "QuestUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 8, Enabled = false, Parent = playerGui })
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

--------------------------------------------------------------------------
-- Open button (left, under "Weapons") and tracker (right, under god badge)
--------------------------------------------------------------------------
local openButton = button({
	Position = UDim2.fromOffset(12, 258), Size = UDim2.fromOffset(290, 40),
	BackgroundColor3 = THEME.Quest, Text = "Quests", TextSize = 17, Parent = gui,
})
stroke(THEME.Bronze, 2).Parent = openButton

local tracker = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 172), Size = UDim2.fromOffset(230, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = THEME.Marble, BackgroundTransparency = 0.15,
	AutoButtonColor = false, Text = "", Parent = gui,
}, { corner(10), stroke(THEME.Gold, 2), padding(8), create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

--------------------------------------------------------------------------
-- Quest log panel
--------------------------------------------------------------------------
local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 520),
	BackgroundColor3 = THEME.Marble, Visible = false, Parent = gui,
}, { corner(12), stroke(THEME.Quest, 3), padding(14) })
text({ Size = UDim2.new(1, -50, 0, 36), Font = Enum.Font.Garamond, TextSize = 34, Text = "Quests", Parent = panel })
local closeButton = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = THEME.Bronze, Text = "X", TextSize = 20, Parent = panel })
text({ Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 20), TextSize = 13, TextColor3 = THEME.SubText, Text = "Finish a quest, then press Claim to collect the reward. Claiming a story quest unlocks the next one.", TextWrapped = true, Parent = panel })

local list = create("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, ScrollBarImageColor3 = THEME.Bronze, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel,
}, { create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }), create("UIPadding", { PaddingRight = UDim.new(0, 10) }) })

local quests = {}

local function readQuests()
	local raw = player:GetAttribute("QuestsJson")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(decoded) == "table" then decoded else {}
end

local function questRow(quest, order)
	local color = if quest.Daily then THEME.Daily else THEME.Quest
	local row = create("Frame", { Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = THEME.MarbleDark, LayoutOrder = order, Parent = list }, { corner(8), padding(8) })
	text({ Size = UDim2.new(1, -130, 0, 20), Font = Enum.Font.GothamBold, TextSize = 16, Text = quest.Name, Parent = row })
	text({ Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, -130, 0, 18), TextSize = 13, TextColor3 = THEME.SubText, TextTruncate = Enum.TextTruncate.AtEnd, Text = quest.Description, Parent = row })
	progressBar(row, UDim2.fromOffset(0, 42), UDim2.new(1, -260, 0, 12), quest.Progress / math.max(1, quest.Count), if quest.Ready then THEME.Ready else color)
	text({ Position = UDim2.new(1, -255, 0, 38), Size = UDim2.fromOffset(120, 20), TextSize = 13, Text = ("%d / %d"):format(quest.Progress, quest.Count), Parent = row })
	text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -125, 0, 38), Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12, TextColor3 = THEME.Bronze, TextXAlignment = Enum.TextXAlignment.Right, Text = rewardText(quest.Rewards), Parent = row })
	local claim = button({
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(110, 44),
		BackgroundColor3 = if quest.Ready then THEME.Ready else THEME.Bar,
		Text = if quest.Ready then "Claim" else "In progress", TextSize = if quest.Ready then 16 else 12,
		AutoButtonColor = quest.Ready, Parent = row,
	})
	if quest.Ready then
		claim.Activated:Connect(function()
			claim.Text = "..."
			questRemote:FireServer("Claim", quest.Id)
		end)
	end
end

local function renderLog()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local order = 0
	for _, category in CATEGORY_ORDER do
		local inCategory = {}
		for _, quest in quests do
			local questCategory = if quest.Daily then "Daily" else quest.Category
			if questCategory == category then
				table.insert(inCategory, quest)
			end
		end
		if #inCategory > 0 then
			order += 1
			text({ Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.Garamond, TextSize = 22, TextColor3 = THEME.Bronze, Text = CATEGORY_NAMES[category] or category, LayoutOrder = order, Parent = list })
			for _, quest in inCategory do
				order += 1
				questRow(quest, order)
			end
		end
	end
	if order == 0 then
		text({ Size = UDim2.new(1, 0, 0, 40), TextSize = 16, Text = "No quests right now. Check back tomorrow for new daily quests!", LayoutOrder = 1, Parent = list })
	end
end

local function renderTracker()
	for _, child in tracker:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	-- Finished first, then story, then the rest in log order.
	local sorted = table.clone(quests)
	local rank = {}
	for i, category in CATEGORY_ORDER do
		rank[category] = i
	end
	table.sort(sorted, function(a, b)
		if a.Ready ~= b.Ready then
			return a.Ready
		end
		local ra = if a.Daily then 0 else rank[a.Category] or 99
		local rb = if b.Daily then 0 else rank[b.Category] or 99
		if a.Category == "Story" then
			ra = -1
		end
		if b.Category == "Story" then
			rb = -1
		end
		return ra < rb
	end)
	local readyCount = 0
	for _, quest in quests do
		if quest.Ready then
			readyCount += 1
		end
	end
	text({ Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = THEME.Bronze,
		Text = if readyCount > 0 then ("Quests  (%d to claim!)"):format(readyCount) else "Quests", LayoutOrder = 0, Parent = tracker })
	for i = 1, math.min(3, #sorted) do
		local quest = sorted[i]
		local item = create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = i, Parent = tracker })
		text({ Size = UDim2.new(1, -50, 0, 16), Font = Enum.Font.GothamMedium, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, Text = quest.Name, Parent = item })
		text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(50, 16), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if quest.Ready then THEME.Ready else THEME.SubText, Text = if quest.Ready then "Done!" else ("%d/%d"):format(quest.Progress, quest.Count), Parent = item })
		progressBar(item, UDim2.fromOffset(0, 20), UDim2.new(1, 0, 0, 8), quest.Progress / math.max(1, quest.Count), if quest.Ready then THEME.Ready elseif quest.Daily then THEME.Daily else THEME.Quest)
	end
	tracker.Visible = #sorted > 0
end

local function refresh()
	quests = readQuests()
	renderTracker()
	if panel.Visible then
		renderLog()
	end
	local readyCount = 0
	for _, quest in quests do
		if quest.Ready then
			readyCount += 1
		end
	end
	openButton.Text = if readyCount > 0 then ("Quests  (%d!)"):format(readyCount) else "Quests"
	openButton.BackgroundColor3 = if readyCount > 0 then THEME.Ready else THEME.Quest
end

local function open()
	panel.Visible = true
	renderLog()
end
openButton.Activated:Connect(function()
	if panel.Visible then
		panel.Visible = false
	else
		open()
	end
end)
tracker.Activated:Connect(open)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)

player:GetAttributeChangedSignal("QuestsJson"):Connect(refresh)
refresh()
