-- UITheme (ModuleScript)
-- Location: ReplicatedStorage > Shared > UITheme
--
-- Phase 8: the "divine glass" look for every menu. The menus were first
-- built in a light marble style; client/UIRestyler swaps those colours for
-- these (dark violet glass, cream text, shimmering gold edges) everywhere,
-- including menus opened later. To retheme the game, edit the maps below.

local UITheme = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

UITheme.Colors = {
	Glass = rgb(30, 26, 48),
	GlassLight = rgb(52, 46, 76),
	Cream = rgb(246, 238, 220),
	Lilac = rgb(196, 186, 214),
	Gold = rgb(212, 175, 55),
	GoldBright = rgb(255, 222, 130),
	Shadow = rgb(10, 8, 18),
}

-- Old background colour -> new background colour (and transparency).
UITheme.Backgrounds = {
	["246,242,232"] = { rgb(30, 26, 48), 0.08 },   -- marble panels
	["228,220,204"] = { rgb(52, 46, 76), 0.1 },    -- marble rows
	["240,226,180"] = { rgb(78, 64, 40), 0.05 },   -- prestige row
	["215,225,240"] = { rgb(40, 52, 80), 0.05 },   -- party bar
	["200,190,170"] = { rgb(70, 64, 95), 0 },      -- progress bar backs
	["60,52,44"] = { rgb(40, 34, 56), 0 },         -- XP bar back
}

-- Old text colour -> new text colour.
UITheme.Texts = {
	["58,44,28"] = rgb(246, 238, 220),   -- main text
	["110,95,75"] = rgb(196, 186, 214),  -- secondary text
	["140,92,45"] = rgb(232, 196, 110),  -- bronze headings
	["175,55,35"] = rgb(255, 130, 110),  -- warnings
	["190,50,40"] = rgb(255, 120, 105),  -- danger
}

function UITheme.Key(color)
	return ("%d,%d,%d"):format(math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
end

return UITheme
