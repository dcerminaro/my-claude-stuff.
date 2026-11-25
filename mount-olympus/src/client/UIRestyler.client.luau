-- UIRestyler (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > UIRestyler
--
-- Phase 8: gives every menu the same "divine glass" look (Shared/UITheme):
-- dark violet glass panels with a soft top highlight, cream text, gold
-- edges with a slow shimmer, and gently shaded buttons. Works on menus
-- created at any time, and keeps up when menus change colours later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UITheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))

local SKIP_GUIS = { CombatHUD = true, CombatTouchButtons = true, AbilityButtons = true, IncarnationUI = true, AimDot = true, IntroScreen = true, CombatJuice = true }
local GOLD_KEY = UITheme.Key(UITheme.Colors.Gold)

local shimmering = {} -- UIGradients on gold strokes, rotated slowly
local hooked = setmetatable({}, { __mode = "k" })

local function skip(item)
	local screen = item:FindFirstAncestorWhichIsA("ScreenGui")
	return screen ~= nil and SKIP_GUIS[screen.Name] == true
end

local function restyleBackground(item)
	local mapped = UITheme.Backgrounds[UITheme.Key(item.BackgroundColor3)]
	if mapped then
		item.BackgroundColor3 = mapped[1]
		if item.BackgroundTransparency < 0.5 then
			item.BackgroundTransparency = math.max(item.BackgroundTransparency, mapped[2])
		end
		-- Panels (with an edge) get a soft highlight at the top
		if item:FindFirstChildOfClass("UIStroke") and not item:FindFirstChild("GlassShade") then
			local shade = Instance.new("UIGradient")
			shade.Name = "GlassShade"
			shade.Rotation = 90
			shade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 160, 200))
			shade.Parent = item
		end
	end
end

-- Colours that count as "dark glass" behind text (old marble ones get
-- converted to glass, so they count too).
local DARK_BACKS = {}
for key, mapped in UITheme.Backgrounds do
	DARK_BACKS[key] = true
	DARK_BACKS[UITheme.Key(mapped[1])] = true
end

-- Only lighten text that sits on a glass panel (not on gold/coloured buttons).
local function onGlass(item)
	local node = item
	while node and node:IsA("GuiObject") do
		if node.BackgroundTransparency < 0.5 then
			return DARK_BACKS[UITheme.Key(node.BackgroundColor3)] == true
		end
		node = node.Parent
	end
	return true
end

local function restyleText(item)
	local mapped = UITheme.Texts[UITheme.Key(item.TextColor3)]
	if mapped and onGlass(item) then
		item.TextColor3 = mapped
	end
end

local function restyleStroke(stroke)
	if UITheme.Key(stroke.Color) == GOLD_KEY and not stroke:FindFirstChild("Shimmer") then
		stroke.Color = Color3.new(1, 1, 1)
		local shimmer = Instance.new("UIGradient")
		shimmer.Name = "Shimmer"
		shimmer.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 130, 40)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 225, 140)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 248, 215)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 130, 40)),
		})
		shimmer.Parent = stroke
		table.insert(shimmering, shimmer)
		-- If a script later recolours the stroke (e.g. a different state), drop the shimmer.
		stroke:GetPropertyChangedSignal("Color"):Connect(function()
			if stroke.Color ~= Color3.new(1, 1, 1) and shimmer.Parent then
				shimmer:Destroy()
			end
		end)
	end
end

local function restyleButton(button)
	if button:IsA("TextButton") and not button:FindFirstChildOfClass("UIGradient") and button.BackgroundTransparency < 0.9 then
		local shade = Instance.new("UIGradient")
		shade.Name = "ButtonShade"
		shade.Rotation = 90
		shade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 185, 200))
		shade.Parent = button
	end
end

local function hook(item)
	if hooked[item] or skip(item) then
		return
	end
	if item:IsA("GuiObject") then
		hooked[item] = true
		restyleBackground(item)
		item:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
			restyleBackground(item)
		end)
		if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
			restyleText(item)
			item:GetPropertyChangedSignal("TextColor3"):Connect(function()
				restyleText(item)
			end)
		end
		if item:IsA("GuiButton") then
			restyleButton(item)
		end
	elseif item:IsA("UIStroke") then
		hooked[item] = true
		restyleStroke(item)
		local parent = item.Parent
		if parent and parent:IsA("GuiObject") then
			restyleBackground(parent) -- now that it has an edge, it may get its highlight
		end
	end
end

for _, item in playerGui:GetDescendants() do
	hook(item)
end
playerGui.DescendantAdded:Connect(function(item)
	task.defer(hook, item) -- after the creating script sets its properties
end)

-- Slow golden shimmer along the edges
RunService.RenderStepped:Connect(function()
	local angle = (os.clock() * 40) % 360
	for i = #shimmering, 1, -1 do
		local shimmer = shimmering[i]
		if shimmer.Parent then
			shimmer.Rotation = angle
		else
			table.remove(shimmering, i)
		end
	end
end)
