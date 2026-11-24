-- HUDController (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > HUDController
--
-- Builds the Phase 1 interface in code: loading screen, level / rank / XP
-- panel, currency panel, travel buttons, and pop-up notifications.
-- Display only: it reads values the server publishes as Player Attributes
-- and never changes any game data itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Progression = require(Shared:WaitForChild("Progression"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyRemote = Remotes:WaitForChild("Notify")
local teleportRemote = Remotes:WaitForChild("RequestTeleport")

local THEME = {
	Marble = Color3.fromRGB(246, 242, 232),
	Gold = Color3.fromRGB(212, 175, 55),
	Bronze = Color3.fromRGB(140, 92, 45),
	Text = Color3.fromRGB(58, 44, 28),
	BarBack = Color3.fromRGB(60, 52, 44),
	Night = Color3.fromRGB(18, 22, 38),
	White = Color3.new(1, 1, 1),
	Warning = Color3.fromRGB(175, 55, 35),
}
local TITLE_FONT = Enum.Font.Garamond
local BODY_FONT = Enum.Font.GothamBold

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

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color, thickness)
	return create("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function padding(px)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

--------------------------------------------------------------------------
-- Loading screen (hidden once the server says data is loaded)
--------------------------------------------------------------------------
local loadingGui = create("ScreenGui", {
	Name = "LoadingScreen",
	IgnoreGuiInset = true,
	DisplayOrder = 100,
	ResetOnSpawn = false,
	Parent = playerGui,
})
local loadingFrame = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = THEME.Night,
	Parent = loadingGui,
})
create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromScale(0.8, 0.12),
	BackgroundTransparency = 1,
	Text = "MOUNT OLYMPUS",
	Font = TITLE_FONT,
	TextScaled = true,
	TextColor3 = THEME.Gold,
	Parent = loadingFrame,
})
create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.6, 0.06),
	BackgroundTransparency = 1,
	Text = "Rise of the Gods",
	Font = TITLE_FONT,
	TextScaled = true,
	TextColor3 = THEME.Marble,
	Parent = loadingFrame,
})
create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.64),
	Size = UDim2.fromScale(0.6, 0.04),
	BackgroundTransparency = 1,
	Text = "Loading your progress...",
	Font = BODY_FONT,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(190, 190, 205),
	Parent = loadingFrame,
})

local function updateLoading()
	if player:GetAttribute("DataLoaded") == true then
		loadingGui.Enabled = false
	end
end
player:GetAttributeChangedSignal("DataLoaded"):Connect(updateLoading)
updateLoading()

--------------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------------
local hud = create("ScreenGui", {
	Name = "HUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})
local uiScale = create("UIScale", { Parent = hud })

-- Shrink/grow the whole HUD to fit phones, tablets and PCs.
local function updateScale()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local scale = math.min(viewport.X / 1280, viewport.Y / 720)
	uiScale.Scale = math.clamp(scale, 0.7, 1.2)
end
updateScale()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- Level / rank / XP panel (top-left)
local statsPanel = create("Frame", {
	Name = "StatsPanel",
	Position = UDim2.fromOffset(12, 12),
	Size = UDim2.fromOffset(290, 92),
	BackgroundColor3 = THEME.Marble,
	BackgroundTransparency = 0.05,
	Parent = hud,
}, { corner(10), stroke(THEME.Gold, 2), padding(10) })

local levelLabel = create("TextLabel", {
	Name = "Level",
	Size = UDim2.fromOffset(80, 26),
	BackgroundTransparency = 1,
	Text = "Lv. 1",
	Font = BODY_FONT,
	TextSize = 22,
	TextColor3 = THEME.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = statsPanel,
})

local rankBadge = create("TextLabel", {
	Name = "Rank",
	Position = UDim2.fromOffset(84, 0),
	Size = UDim2.new(1, -84, 0, 26),
	BackgroundColor3 = GameConfig.Ranks[1].Color,
	Text = "Mortal",
	Font = TITLE_FONT,
	TextSize = 22,
	TextColor3 = THEME.White,
	TextStrokeTransparency = 0.6,
	Parent = statsPanel,
}, { corner(6) })

local xpBack = create("Frame", {
	Name = "XPBar",
	Position = UDim2.fromOffset(0, 32),
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundColor3 = THEME.BarBack,
	Parent = statsPanel,
}, { corner(6) })

local xpFill = create("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = THEME.Gold,
	Parent = xpBack,
}, { corner(6) })

local xpText = create("TextLabel", {
	Name = "XPText",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "0 / 100 XP",
	Font = BODY_FONT,
	TextSize = 14,
	TextColor3 = THEME.White,
	TextStrokeTransparency = 0.4,
	ZIndex = 2,
	Parent = xpBack,
})

local trialLabel = create("TextLabel", {
	Name = "TrialReady",
	Position = UDim2.fromOffset(0, 56),
	Size = UDim2.new(1, 0, 0, 16),
	BackgroundTransparency = 1,
	Text = "Level cap reached! Your ascension trial awaits.",
	Font = BODY_FONT,
	TextScaled = true,
	TextColor3 = THEME.Warning,
	TextXAlignment = Enum.TextXAlignment.Left,
	Visible = false,
	Parent = statsPanel,
}, { create("UITextSizeConstraint", { MaxTextSize = 14 }) })

-- Currency panel (top-right)
local currencyPanel = create("Frame", {
	Name = "CurrencyPanel",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(200, 100),
	BackgroundColor3 = THEME.Marble,
	BackgroundTransparency = 0.05,
	Parent = hud,
}, {
	corner(10),
	stroke(THEME.Gold, 2),
	padding(10),
	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local currencyLabels = {}
for i, name in GameConfig.Currencies do
	local info = GameConfig.CurrencyInfo[name]
	local row = create("Frame", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = i,
		Parent = currencyPanel,
	})
	create("Frame", {
		Name = "Icon",
		Position = UDim2.new(0, 0, 0.5, -8),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = info.Color,
		Parent = row,
	}, { corner(8), stroke(THEME.Bronze, 1) })
	create("TextLabel", {
		Name = "Name",
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(0.55, -24, 1, 0),
		BackgroundTransparency = 1,
		Text = info.DisplayName,
		Font = BODY_FONT,
		TextSize = 15,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	currencyLabels[name] = create("TextLabel", {
		Name = "Amount",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.45, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "0",
		Font = BODY_FONT,
		TextSize = 18,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
end

-- Travel buttons (under the stats panel; clear of mobile thumbstick and jump button)
local travelBar = create("Frame", {
	Name = "TravelBar",
	Position = UDim2.fromOffset(12, 112),
	Size = UDim2.fromOffset(290, 42),
	BackgroundTransparency = 1,
	Parent = hud,
}, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local function makeButton(text, order)
	return create("TextButton", {
		Name = text,
		Size = UDim2.new(0.5, -5, 1, 0),
		BackgroundColor3 = THEME.Bronze,
		Text = text,
		Font = BODY_FONT,
		TextSize = 17,
		TextColor3 = THEME.White,
		LayoutOrder = order,
		AutoButtonColor = true,
		Parent = travelBar,
	}, { corner(8), stroke(THEME.Gold, 2) })
end
local templeButton = makeButton("My Temple", 1)
local plazaButton = makeButton("Plaza", 2)

-- Pop-up notification (upper centre)
local toast = create("Frame", {
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.2, 0),
	Size = UDim2.fromOffset(380, 54),
	BackgroundColor3 = THEME.Marble,
	Visible = false,
	Parent = hud,
}, { corner(10), padding(8) })
local toastStroke = stroke(THEME.Gold, 3)
toastStroke.Parent = toast
local toastLabel = create("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	Font = BODY_FONT,
	TextScaled = true,
	TextColor3 = THEME.Text,
	Parent = toast,
}, { create("UITextSizeConstraint", { MaxTextSize = 20 }) })

local toastToken = 0
local function showToast(text, color)
	toastToken += 1
	local myToken = toastToken

	toastLabel.Text = text
	toastStroke.Color = color or THEME.Gold
	toast.BackgroundTransparency = 1
	toastLabel.TextTransparency = 1
	toastStroke.Transparency = 1
	toast.Position = UDim2.new(0.5, 0, 0.2, -20)
	toast.Visible = true

	local inInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(toast, inInfo, { Position = UDim2.new(0.5, 0, 0.2, 0), BackgroundTransparency = 0.05 }):Play()
	TweenService:Create(toastLabel, inInfo, { TextTransparency = 0 }):Play()
	TweenService:Create(toastStroke, inInfo, { Transparency = 0 }):Play()

	task.delay(2.8, function()
		if myToken ~= toastToken then
			return
		end
		local outInfo = TweenInfo.new(0.4)
		TweenService:Create(toast, outInfo, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(toastLabel, outInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(toastStroke, outInfo, { Transparency = 1 }):Play()
		task.wait(0.4)
		if myToken == toastToken then
			toast.Visible = false
		end
	end)
end

--------------------------------------------------------------------------
-- Keep the HUD in sync with the server's attributes
--------------------------------------------------------------------------
local function updateStats()
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("XP") or 0
	local need = player:GetAttribute("XPToNext") or 0
	local rankIndex = player:GetAttribute("RankIndex") or 1
	local rank = Progression.GetRank(rankIndex)

	levelLabel.Text = "Lv. " .. level
	rankBadge.Text = rank.Name
	rankBadge.BackgroundColor3 = rank.Color

	local ratio = 1
	if need > 0 then
		ratio = math.clamp(xp / need, 0, 1)
		xpText.Text = Progression.FormatNumber(xp) .. " / " .. Progression.FormatNumber(need) .. " XP"
	else
		xpText.Text = "MAX LEVEL"
	end
	TweenService:Create(xpFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(ratio, 1) }):Play()

	trialLabel.Visible = player:GetAttribute("TrialReady") == true
end

local function updateCurrency(name)
	currencyLabels[name].Text = Progression.FormatNumber(player:GetAttribute(name) or 0)
end

for _, attribute in { "Level", "XP", "XPToNext", "RankIndex", "TrialReady" } do
	player:GetAttributeChangedSignal(attribute):Connect(updateStats)
end
for _, name in GameConfig.Currencies do
	player:GetAttributeChangedSignal(name):Connect(function()
		updateCurrency(name)
	end)
	updateCurrency(name)
end
updateStats()

--------------------------------------------------------------------------
-- Server notifications
--------------------------------------------------------------------------
notifyRemote.OnClientEvent:Connect(function(kind, value)
	if kind == "LevelUp" then
		showToast("LEVEL UP! You reached level " .. tostring(value), THEME.Gold)
	elseif kind == "RankUp" then
		showToast("ASCENSION! Your new rank: " .. tostring(value), Color3.fromRGB(120, 200, 255))
	elseif kind == "Message" then
		showToast(tostring(value), THEME.Bronze)
	end
end)

--------------------------------------------------------------------------
-- Travel buttons
--------------------------------------------------------------------------
local lastTravel = 0
local function requestTeleport(destination)
	if os.clock() - lastTravel < GameConfig.Teleport.Cooldown then
		showToast("The gods need a moment...", THEME.Bronze)
		return
	end
	lastTravel = os.clock()
	teleportRemote:FireServer(destination)
end

templeButton.Activated:Connect(function()
	requestTeleport("Temple")
end)
plazaButton.Activated:Connect(function()
	requestTeleport("Plaza")
end)
