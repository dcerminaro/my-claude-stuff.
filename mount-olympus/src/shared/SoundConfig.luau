-- SoundConfig (ModuleScript)
-- Location: ReplicatedStorage > Shared > SoundConfig
--
-- Phase 8: music and sound effects. All tracks are from Roblox's licensed
-- libraries (APM Music, DistroKid, ProSoundEffects, Roblox UI sounds), which
-- any experience may use. To change a sound, replace its id.

local SoundConfig = {}

local function id(n)
	return "rbxassetid://" .. n
end

-- Music playlists (shuffled, crossfaded). Volume is multiplied by the
-- player's Music setting.
SoundConfig.Music = {
	-- Ethereal, floating: the plaza, temples and practice field.
	Olympus = {
		Volume = 0.35,
		Tracks = {
			id(9043657051),      -- Star Chasing (Underscore): soaring ethereal strings and bells
			id(1837463526),      -- Ethereal Drone: celestial ambient synth textures
			id(9043678446),      -- Arcturus (Underscore): swirling, graceful
			id(111151323492777), -- Floating Through Silence
			id(106135664783553), -- Clouds Unfurl
		},
	},
	-- Arena waves.
	Battle = {
		Volume = 0.4,
		Tracks = {
			id(122783941148304), -- Heroic Orchestral Battle Music
			id(1842337366),      -- Might of Arms
			id(1842960322),      -- Shoulders Of Giants
		},
	},
	-- When a boss is on the field.
	Boss = {
		Volume = 0.45,
		Tracks = {
			id(128007000574959), -- Epic Boss Battle
			id(80766740746561),  -- Rise of Vaurinox (epic boss battle film score)
			id(76918130388475),  -- Last Stand
		},
	},
}

-- Soft wind on the mountain top (looped under the Olympus music).
SoundConfig.Ambience = { Id = id(9114057128), Volume = 0.12 } -- Desert Wind, light gusts

-- Sound effects. Volume is multiplied by the player's Effects setting.
-- Pitch can be a number or { min, max } for variety.
SoundConfig.Effects = {
	Swing = { Id = id(9126229255), Volume = 0.45, Pitch = { 0.95, 1.15 } },  -- fast airy whoosh
	HeavySwing = { Id = id(9120972321), Volume = 0.5, Pitch = { 0.8, 0.9 } }, -- slicing air
	Hit = { Id = id(9113530386), Volume = 0.45, Pitch = { 0.9, 1.1 } },       -- body impact
	Crit = { Id = id(9125672726), Volume = 0.5, Pitch = { 1.0, 1.1 } },       -- metal impact
	Block = { Id = id(9119072660), Volume = 0.55, Pitch = { 0.95, 1.05 } },   -- shield clang
	Hurt = { Id = id(9119072674), Volume = 0.35, Pitch = { 0.7, 0.8 } },
	Dash = { Id = id(9125807267), Volume = 0.4, Pitch = { 1.0, 1.1 } },       -- rising whoosh
	Arrow = { Id = id(9113166206), Volume = 0.45 },
	Death = { Id = id(9113470802), Volume = 0.45 },                           -- heavy body fall
	Thunder = { Id = id(9120016256), Volume = 0.5 },
	Fire = { Id = id(9117985933), Volume = 0.5 },
	Slam = { Id = id(9118588626), Volume = 0.55, Pitch = { 0.8, 0.9 } },
	Magic = { Id = id(9116394545), Volume = 0.5 },                            -- soft chiming magic
	Heal = { Id = id(9116395089), Volume = 0.5 },
	Water = { Id = id(9125703162), Volume = 0.5 },
	Whoosh = { Id = id(9126228631), Volume = 0.45 },
	Chimes = { Id = id(9119447936), Volume = 0.5 },                           -- level up / quest
	Coins = { Id = id(9113849492), Volume = 0.45 },
	Gong = { Id = id(9114630316), Volume = 0.5 },                             -- arena waves, boss
	Roar = { Id = id(9113980319), Volume = 0.6, Pitch = { 0.8, 0.9 } },       -- boss appears
	Click = { Id = id(15675059323), Volume = 0.4 },                           -- UI buttons
	UIWhoosh = { Id = id(15674975792), Volume = 0.3 },                        -- menus opening
}

return SoundConfig
