-- GodUI (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > GodUI
--
-- Phase 3 interface:
--   * "Choose your god" intro screen (shown until you pick a god).
--   * God badge under the currency panel (the equipped god indicator).
--   * Gods & Blessings menu: loyalty, worship timer, bonuses, blessing tree,
--     and changing god.
-- Display only: reads Player Attributes and sends requests. The server decides.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GodConfig = require(Shared:WaitForChild("GodConfig"))
local Progression = require(Shared:WaitForChild("Progression"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local godRemote = Remotes:WaitForChild("GodAction")
local notifyRemote = Remotes:WaitForChild("Notify")

local THEME = {
	Marble = Color3.fromRGB(246, 242, 232),
	MarbleDark = Color3.fromRGB(228, 220, 204),
	Gold = Color3.fromRGB(212, 175, 55),
	Bronze = Color3.fromRGB(140, 92, 45),
	Text = Color3.fromRGB(58, 44, 28),
	SubText = Color3.fromRGB(110, 95, 75),
	White = Color3.new(1, 1, 1),
	Night = Color3.fromRGB(18, 22, 38),
	Ready = Color3.fromRGB(70, 150, 70),
	TooExpensive = Color3.fromRGB(175, 80, 55),
	Locked = Color3.fromRGB(130, 130, 140),
	Warning = Color3.fromRGB(175, 55, 35),
	Change = Color3.fromRGB(130, 80, 190),
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

local function text(props)
	props.BackgroundTransparency = 1
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextColor3 = props.TextColor3 or THEME.Text
	props.Font = props.Font or SMALL_FONT
	return create("TextLabel", props)
end

local function button(props, radius)
	props.AutoButtonColor = true
	props.Font = props.Font or BODY_FONT
	props.TextColor3 = props.TextColor3 or THEME.White
	return create("TextButton", props, { corner(radius or 8) })
end

local function serverNow()
	return Workspace:GetServerTimeNow()
end

local function godName(godId)
	local god = GodConfig.Gods[godId]
	return if god then god.DisplayName else ""
end

--------------------------------------------------------------------------
-- Screen + scaling
--------------------------------------------------------------------------
local gui = create("ScreenGui", {
	Name = "GodUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 6,
	Enabled = false,
	Parent = playerGui,
})
local uiScale = create("UIScale", { Parent = gui })
local chooserScale = nil -- created with the chooser below; extra shrink for small phones

local CHOOSER_SIZE = Vector2.new(940, 560)

local function updateScale()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	uiScale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.7, 1.2)
	if chooserScale then
		local fit = math.min(viewport.X * 0.96 / CHOOSER_SIZE.X, viewport.Y * 0.94 / CHOOSER_SIZE.Y) / uiScale.Scale
		chooserScale.Scale = math.min(1, fit)
	end
end

--------------------------------------------------------------------------
-- 1. God badge (top-right, under the currency panel)
--------------------------------------------------------------------------
local badge = button({
	Name = "GodBadge",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 120),
	Size = UDim2.fromOffset(200, 44),
	BackgroundColor3 = THEME.Marble,
	Text = "",
	Parent = gui,
}, 10)
stroke(THEME.Gold, 2).Parent = badge
local badgeName = text({
	Name = "God",
	Position = UDim2.fromOffset(10, 2),
	Size = UDim2.new(1, -20, 0, 24),
	Font = TITLE_FONT,
	TextSize = 24,
	Text = "",
	Parent = badge,
})
local badgeSub = text({
	Name = "Sub",
	Position = UDim2.fromOffset(10, 24),
	Size = UDim2.new(1, -20, 0, 16),
	TextSize = 13,
	TextColor3 = THEME.SubText,
	Text = "",
	Parent = badge,
})

--------------------------------------------------------------------------
-- 2. "Choose your god" screen
--------------------------------------------------------------------------
local chooser = create("Frame", {
	Name = "Chooser",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = THEME.Night,
	BackgroundTransparency = 0.15,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
})
local chooserInner = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(CHOOSER_SIZE.X, CHOOSER_SIZE.Y),
	BackgroundTransparency = 1,
	Parent = chooser,
})
chooserScale = create("UIScale", { Parent = chooserInner })
updateScale()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
text({
	Size = UDim2.new(1, 0, 0, 50),
	Font = TITLE_FONT,
	TextSize = 44,
	TextColor3 = THEME.Gold,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "Choose Your God",
	Parent = chooserInner,
})
text({
	Position = UDim2.fromOffset(0, 50),
	Size = UDim2.new(1, 0, 0, 24),
	TextSize = 16,
	TextColor3 = THEME.Marble,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "Your god grants your first blessing. You can change gods later at the Shrine of Change.",
	Parent = chooserInner,
})
local grid = create("Frame", {
	Position = UDim2.fromOffset(0, 90),
	Size = UDim2.new(1, 0, 1, -90),
	BackgroundTransparency = 1,
	Parent = chooserInner,
}, {
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(300, 225),
		CellPadding = UDim2.fromOffset(20, 18),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

for order, godId in GodConfig.Order do
	local god = GodConfig.Gods[godId]
	local card = create("Frame", {
		Name = godId,
		BackgroundColor3 = THEME.Marble,
		LayoutOrder = order,
		Parent = grid,
	}, { corner(12), stroke(god.Colors.Primary, 3), padding(12) })
	text({ Size = UDim2.new(1, 0, 0, 36), Font = TITLE_FONT, TextSize = 34, TextColor3 = god.Colors.Primary, Text = god.DisplayName, Parent = card })
	text({ Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 20), Font = BODY_FONT, TextSize = 16, Text = god.Title, Parent = card })
	text({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 36), TextSize = 14, TextColor3 = THEME.SubText, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Text = god.Specialty, Parent = card })

	local names = {}
	for _, blessing in god.Blessings do
		table.insert(names, blessing.Name)
	end
	text({
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 0, 50),
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = if #names > 0 then table.concat(names, " · ") else "Arrives in a later update.",
		Parent = card,
	})

	local choose = button({
		Name = "Choose",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = if god.Available then god.Colors.Primary else THEME.Locked,
		Text = if god.Available then "Worship " .. god.DisplayName else "Coming soon",
		TextSize = 17,
		Parent = card,
	})
	if not god.Available then
		choose.AutoButtonColor = false
	end
	choose.Activated:Connect(function()
		if god.Available then
			godRemote:FireServer("Choose", godId)
		end
	end)
end

--------------------------------------------------------------------------
-- 3. Gods & Blessings menu
--------------------------------------------------------------------------
local panel = create("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(620, 500),
	BackgroundColor3 = THEME.Marble,
	Visible = false,
	Parent = gui,
}, { corner(12), padding(14) })
local panelStroke = stroke(THEME.Gold, 3)
panelStroke.Parent = panel

local titleLabel = text({ Size = UDim2.new(1, -50, 0, 36), Font = TITLE_FONT, TextSize = 34, Text = "", Parent = panel })
local closeButton = button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = THEME.Bronze,
	Text = "X",
	TextSize = 20,
	Parent = panel,
})
local loyaltyLabel = text({ Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, -50, 0, 20), Font = BODY_FONT, TextSize = 16, TextColor3 = THEME.Bronze, Text = "", Parent = panel })
local worshipLabel = text({ Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = THEME.SubText, Text = "", Parent = panel })
local bonusLabel = text({ Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = THEME.SubText, Text = "", Parent = panel })

local list = create("ScrollingFrame", {
	Name = "List",
	Position = UDim2.fromOffset(0, 108),
	Size = UDim2.new(1, 0, 1, -108),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = THEME.Bronze,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	Parent = panel,
}, {
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
})

-- Five blessing rows (re-filled for whichever god you worship)
local blessingRows = {}
for tier = 1, #GodConfig.Tiers do
	local row = create("Frame", {
		Name = "Blessing" .. tier,
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundColor3 = THEME.MarbleDark,
		LayoutOrder = tier,
		Parent = list,
	}, { corner(8), padding(8) })
	local r = {
		Frame = row,
		Name = text({ Size = UDim2.new(1, -150, 0, 22), Font = BODY_FONT, TextSize = 17, Text = "", Parent = row }),
		Description = text({ Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -150, 0, 18), TextSize = 13, TextColor3 = THEME.SubText, TextTruncate = Enum.TextTruncate.AtEnd, Text = "", Parent = row }),
		Effect = text({ Position = UDim2.fromOffset(0, 41), Size = UDim2.new(1, -150, 0, 18), TextSize = 14, Text = "", Parent = row }),
		Status = text({ Position = UDim2.fromOffset(0, 59), Size = UDim2.new(1, -150, 0, 16), Font = BODY_FONT, TextSize = 13, TextColor3 = THEME.Warning, Text = "", Parent = row }),
		Button = button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(136, 56),
			BackgroundColor3 = THEME.Locked,
			Text = "",
			TextSize = 15,
			Parent = row,
		}),
		BlessingId = nil,
	}
	r.Button.Activated:Connect(function()
		if r.BlessingId then
			godRemote:FireServer("UpgradeBlessing", r.BlessingId)
		end
	end)
	blessingRows[tier] = r
end

-- Change-god section (last in the list)
local changeFrame = create("Frame", {
	Name = "ChangeGod",
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = THEME.MarbleDark,
	LayoutOrder = 100,
	Parent = list,
}, {
	corner(8),
	padding(8),
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
text({ Size = UDim2.new(1, 0, 0, 22), Font = BODY_FONT, TextSize = 17, Text = "Change God", LayoutOrder = 1, Parent = changeFrame })
local changeInfo = text({
	Size = UDim2.new(1, 0, 0, 36),
	TextSize = 13,
	TextColor3 = THEME.SubText,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	LayoutOrder = 2,
	Text = "",
	Parent = changeFrame,
})
local changeButtons = {}
for i, godId in GodConfig.Order do
	if GodConfig.IsPlayable(godId) then
		local b = button({
			Name = "SwitchTo" .. godId,
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = GodConfig.Gods[godId].Colors.Primary,
			Text = "Start switching to " .. godName(godId),
			TextSize = 15,
			LayoutOrder = 10 + i,
			Parent = changeFrame,
		})
		b.Activated:Connect(function()
			godRemote:FireServer("StartChange", godId)
		end)
		changeButtons[godId] = b
	end
end
local cancelButton = button({
	Name = "Cancel",
	Size = UDim2.new(1, 0, 0, 38),
	BackgroundColor3 = THEME.Bronze,
	Text = "Cancel god change",
	TextSize = 15,
	LayoutOrder = 50,
	Parent = changeFrame,
})
cancelButton.Activated:Connect(function()
	godRemote:FireServer("CancelChange")
end)

--------------------------------------------------------------------------
-- Refresh from attributes
--------------------------------------------------------------------------
local function statName(stat)
	if stat == "AttackPercent" then
		return "attack"
	elseif stat == "HealthPercent" then
		return "health"
	end
	return "speed"
end

local function refreshTimers()
	local now = serverNow()
	local worshipIn = math.ceil((player:GetAttribute("NextWorshipAt") or 0) - now)
	worshipLabel.Text = if worshipIn > 0
		then ("Worship again in %ds at your god's statue in the Hall of the Gods"):format(worshipIn)
		else "Worship is ready: visit your god's statue in the Hall of the Gods"

	local target = player:GetAttribute("GodChangeTarget") or ""
	if target ~= "" then
		local prayers = player:GetAttribute("GodChangePrayers") or 0
		local prayIn = math.ceil((player:GetAttribute("NextPrayerAt") or 0) - now)
		changeInfo.Text = ("Switching to %s: prayers %d / %d at the Shrine of Change%s. Your levels, currencies, temple and blessings are kept."):format(
			godName(target),
			prayers,
			GodConfig.GodChange.PrayersNeeded,
			if prayIn > 0 then (" (next prayer in %ds)"):format(prayIn) else ""
		)
	else
		changeInfo.Text = ("Start a change below, then pray %d times at the Shrine of Change. Your levels, currencies, temple and blessings are kept."):format(GodConfig.GodChange.PrayersNeeded)
	end
end

local function refresh()
	local godId = player:GetAttribute("SelectedGod") or ""
	local god = GodConfig.Gods[godId]
	local loaded = player:GetAttribute("DataLoaded") == true

	gui.Enabled = loaded
	chooser.Visible = loaded and godId == "" and player:GetAttribute("SelectedGod") ~= nil
	badge.Visible = god ~= nil

	if not god then
		panel.Visible = false
		return
	end

	local loyalty = player:GetAttribute("Loyalty") or 0
	badgeName.Text = god.DisplayName
	badgeName.TextColor3 = god.Colors.Primary
	badgeSub.Text = ("%s · Loyalty %s"):format(god.Title, Progression.FormatNumber(loyalty))

	titleLabel.Text = ("%s, %s"):format(god.DisplayName, god.Title)
	titleLabel.TextColor3 = god.Colors.Primary
	panelStroke.Color = god.Colors.Primary
	loyaltyLabel.Text = ("Loyalty %s   ·   Divine Favor %s"):format(
		Progression.FormatNumber(loyalty),
		Progression.FormatNumber(player:GetAttribute("DivineFavor") or 0)
	)
	bonusLabel.Text = ("Blessing bonuses: +%d%% attack   +%d%% health   +%d%% speed"):format(
		player:GetAttribute("BonusAttackPercent") or 0,
		player:GetAttribute("BonusHealthPercent") or 0,
		player:GetAttribute("BonusSpeedPercent") or 0
	)

	local favor = player:GetAttribute("DivineFavor") or 0
	local altarLevel = player:GetAttribute("Temple_MainAltar") or 0
	local rankIndex = player:GetAttribute("RankIndex") or 1

	for tier, r in blessingRows do
		local blessing = nil
		for _, b in god.Blessings do
			if b.Tier == tier then
				blessing = b
			end
		end
		r.Frame.Visible = blessing ~= nil
		r.BlessingId = blessing and blessing.Id
		if blessing then
			local level = player:GetAttribute("Blessing_" .. blessing.Id) or 0
			local info = GodConfig.GetBlessingUpgradeInfo(blessing.Id, level, altarLevel, loyalty, rankIndex)
			local per = blessing.Passive.PerLevel
			r.Name.Text = ("Tier %d: %s   Lv %d/%d"):format(tier, blessing.Name, level, GodConfig.MaxBlessingLevel)
			r.Description.Text = ("%s (%s ability, Phase 4)"):format(blessing.Description, blessing.Ability)
			if info.Maxed then
				r.Effect.Text = ("Bonus: +%d%% %s"):format(level * per, statName(blessing.Passive.Stat))
				r.Status.Text = ""
				r.Button.Text = "MAX"
				r.Button.BackgroundColor3 = THEME.Gold
			else
				r.Effect.Text = ("Bonus: +%d%% -> +%d%% %s"):format(level * per, (level + 1) * per, statName(blessing.Passive.Stat))
				if info.Blocked then
					r.Status.Text = "Locked: " .. info.Blocked
					r.Button.Text = "Locked"
					r.Button.BackgroundColor3 = THEME.Locked
				else
					local canAfford = favor >= info.Cost
					r.Status.Text = if canAfford then "" else "Not enough Divine Favor yet"
					r.Button.Text = (if level == 0 then "Unlock" else "Upgrade") .. "\n" .. Progression.FormatNumber(info.Cost) .. " Favor"
					r.Button.BackgroundColor3 = if canAfford then THEME.Ready else THEME.TooExpensive
				end
			end
		end
	end

	local target = player:GetAttribute("GodChangeTarget") or ""
	for id, b in changeButtons do
		b.Visible = target == "" and id ~= godId
	end
	cancelButton.Visible = target ~= ""
	refreshTimers()
end

local watched = {
	"DataLoaded", "SelectedGod", "Loyalty", "DivineFavor", "Temple_MainAltar", "RankIndex",
	"BonusAttackPercent", "BonusHealthPercent", "BonusSpeedPercent",
	"GodChangeTarget", "GodChangePrayers", "NextPrayerAt", "NextWorshipAt",
}
for blessingId in GodConfig.BlessingsById do
	table.insert(watched, "Blessing_" .. blessingId)
end
for _, attribute in watched do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end
refresh()

-- Tick the countdown timers once a second while the menu is open.
task.spawn(function()
	while true do
		task.wait(1)
		if panel.Visible then
			refreshTimers()
		end
	end
end)

--------------------------------------------------------------------------
-- Open / close
--------------------------------------------------------------------------
local function openMenu(section)
	if (player:GetAttribute("SelectedGod") or "") == "" then
		refresh() -- shows the chooser instead
		return
	end
	refresh()
	panel.Visible = true
	if section == "Change" then
		task.defer(function()
			list.CanvasPosition = Vector2.new(0, list.AbsoluteCanvasSize.Y)
		end)
	else
		list.CanvasPosition = Vector2.zero
	end
end

badge.Activated:Connect(function()
	if panel.Visible then
		panel.Visible = false
	else
		openMenu("Blessings")
	end
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)

-- The server opens the menu from the Hall of the Gods and the Shrine of Change.
notifyRemote.OnClientEvent:Connect(function(kind, section)
	if kind == "OpenGodMenu" then
		openMenu(section)
	end
end)
