-- Sfx (ModuleScript)
-- Location: ReplicatedStorage > Shared > Sfx
--
-- Phase 8: plays sound effects on the client (names from SoundConfig.Effects).
--   Sfx.Play(name)                 -> a 2D sound (UI, your own actions)
--   Sfx.Play(name, position)       -> a 3D sound in the world at `position`
--   Sfx.Play(name, nil, volumeScale)
-- Respects the player's "SfxVolume" attribute and limits how many sounds
-- play at once so big fights stay pleasant.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local SoundConfig = require(script.Parent:WaitForChild("SoundConfig"))

local Sfx = {}

local MAX_PER_WINDOW = 10
local WINDOW = 0.25
local recent = {}
local random = Random.new()
local templates = {}

local function template(name)
	local cfg = SoundConfig.Effects[name]
	if not cfg then
		return nil
	end
	local sound = templates[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "Sfx_" .. name
		sound.SoundId = cfg.Id
		sound.Volume = cfg.Volume
		sound.RollOffMinDistance = 12
		sound.RollOffMaxDistance = 180
		templates[name] = sound
	end
	return sound, cfg
end

local function allowed()
	local now = os.clock()
	local i = 1
	while i <= #recent do
		if now - recent[i] > WINDOW then
			table.remove(recent, i)
		else
			i += 1
		end
	end
	if #recent >= MAX_PER_WINDOW then
		return false
	end
	table.insert(recent, now)
	return true
end

function Sfx.Play(name, position, volumeScale)
	local player = Players.LocalPlayer
	local setting = player and player:GetAttribute("SfxVolume")
	local master = if type(setting) == "number" then setting else 0.8
	if master <= 0 or not allowed() then
		return
	end
	local base, cfg = template(name)
	if not base then
		return
	end
	local sound = base:Clone()
	sound.Volume = cfg.Volume * master * (volumeScale or 1) * 1.25
	local pitch = cfg.Pitch
	if type(pitch) == "table" then
		sound.PlaybackSpeed = random:NextNumber(pitch[1], pitch[2])
	elseif type(pitch) == "number" then
		sound.PlaybackSpeed = pitch
	end
	if typeof(position) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.Name = "SfxPoint"
		attachment.WorldPosition = position
		attachment.Parent = Workspace.Terrain
		sound.Parent = attachment
		sound:Play()
		Debris:AddItem(attachment, 8)
	else
		sound.Parent = SoundService
		sound:Play()
		Debris:AddItem(sound, 8)
	end
end

-- Makes sure the sounds are downloaded early (call once on the client).
function Sfx.Preload()
	local ContentProvider = game:GetService("ContentProvider")
	local list = {}
	for name in SoundConfig.Effects do
		local sound = template(name)
		if sound then
			table.insert(list, sound)
		end
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

return Sfx
