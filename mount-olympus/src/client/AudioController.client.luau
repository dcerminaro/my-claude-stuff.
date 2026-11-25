-- AudioController (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > AudioController
--
-- Phase 8: music, ambience and sound effects.
--   * Music zones (SoundConfig.Music): Olympus (ethereal) everywhere, Battle
--     during an arena/trial/challenge run, Boss while a boss of your run is
--     alive. Tracks are shuffled and crossfaded.
--   * Soft mountain wind under the Olympus music.
--   * Sound effects for every combat effect the server sends (hits, crits,
--     blocks, deaths, god abilities...), level ups, arena waves, bosses
--     appearing, rewards and button clicks.
--   * Two small buttons (bottom left): Music and Effects on/off, saved.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundConfig = require(Shared:WaitForChild("SoundConfig"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local fxRemote = Remotes:WaitForChild("CombatFX")
local notifyRemote = Remotes:WaitForChild("Notify")
local arenaEvent = Remotes:WaitForChild("ArenaEvent")
local settingsRemote = Remotes:WaitForChild("SettingsAction")

Sfx.Preload()

local function musicSetting()
	local value = player:GetAttribute("MusicVolume")
	return if type(value) == "number" then value else 0.5
end

--------------------------------------------------------------------------
-- Music
--------------------------------------------------------------------------
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "OlympusMusic"
musicGroup.Parent = SoundService

local random = Random.new()
local zone = nil
local current = nil -- the Sound playing now
local playlistIndex = {}
local FADE = 2.5

local function fadeOut(sound)
	if not sound then
		return
	end
	local tween = TweenService:Create(sound, TweenInfo.new(FADE), { Volume = 0 })
	tween:Play()
	tween.Completed:Connect(function()
		sound:Destroy()
	end)
end

local function nextTrack(zoneName)
	local cfg = SoundConfig.Music[zoneName]
	local order = playlistIndex[zoneName]
	if not order or order.Position > #order.List then
		local list = table.clone(cfg.Tracks)
		for i = #list, 2, -1 do
			local j = random:NextInteger(1, i)
			list[i], list[j] = list[j], list[i]
		end
		order = { List = list, Position = 1 }
		playlistIndex[zoneName] = order
	end
	local id = order.List[order.Position]
	order.Position += 1
	return id, cfg.Volume
end

local playTrack
playTrack = function(zoneName)
	local id, volume = nextTrack(zoneName)
	local sound = Instance.new("Sound")
	sound.Name = "Music_" .. zoneName
	sound.SoundId = id
	sound.Volume = 0
	sound.SoundGroup = musicGroup
	sound:SetAttribute("BaseVolume", volume)
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(FADE), { Volume = volume * musicSetting() }):Play()
	fadeOut(current)
	current = sound
	sound.Ended:Connect(function()
		if current == sound and zone == zoneName then
			playTrack(zoneName) -- next song in the same zone
		end
	end)
end

local function setZone(newZone)
	if newZone == zone then
		return
	end
	zone = newZone
	playTrack(newZone)
end

local function applyMusicVolume()
	if current then
		current.Volume = (current:GetAttribute("BaseVolume") or 0.35) * musicSetting()
	end
end
player:GetAttributeChangedSignal("MusicVolume"):Connect(applyMusicVolume)

-- Wind ambience
local wind = Instance.new("Sound")
wind.Name = "MountainWind"
wind.SoundId = SoundConfig.Ambience.Id
wind.Looped = true
wind.Volume = 0
wind.Parent = SoundService
wind:Play()

local function myRunId()
	local id = player:GetAttribute("ArenaRunId")
	return if id ~= nil and id ~= "" and id ~= 0 then id else nil
end

local function bossAlive(runId)
	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		return false
	end
	for _, model in enemies:GetChildren() do
		if model:GetAttribute("IsBoss") and model:GetAttribute("RunId") == runId then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				return true
			end
		end
	end
	return false
end

task.spawn(function()
	while true do
		local runId = myRunId()
		local state = player:GetAttribute("ArenaState")
		local fighting = runId and state ~= "Victory" and state ~= "Failed"
		if fighting then
			setZone(if bossAlive(runId) then "Boss" else "Battle")
		else
			setZone("Olympus")
		end
		local windTarget = if zone == "Olympus" then SoundConfig.Ambience.Volume * musicSetting() * 2 else 0
		wind.Volume += (windTarget - wind.Volume) * 0.3
		task.wait(1)
	end
end)

--------------------------------------------------------------------------
-- Sound effects from combat events
--------------------------------------------------------------------------
local DAMAGE_SOUNDS = {
	Enemy = "Hit", Crit = "Crit", Player = "Hurt", Blocked = "Block", Countered = "Block", Dodged = "Whoosh",
}
local ABILITY_SOUNDS = {
	Lightning = "Thunder", Chain = "Thunder", Shockwave = "Slam", Cleave = "HeavySwing", DashTrail = "Dash",
	Aura = "Magic", Beam = "Fire", Vortex = "Water", Wave = "Water", Dome = "Magic", HealBurst = "Heal",
}

fxRemote.OnClientEvent:Connect(function(kind, position, a, b)
	if kind == "Swing" and typeof(position) == "Instance" then
		local character = position.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			Sfx.Play("Swing", root.Position, 0.7)
		end
		return
	end
	if typeof(position) ~= "Vector3" then
		return
	end
	if kind == "Damage" then
		local style = b
		if a == 0 and style ~= "Dodged" and style ~= "Countered" then
			return
		end
		local name = DAMAGE_SOUNDS[style or "Enemy"]
		if name then
			Sfx.Play(name, position)
		end
	elseif kind == "Death" then
		Sfx.Play("Death", position)
	elseif kind == "EnemyAttack" then
		local windup = if typeof(b) == "number" then b else 0.5
		task.delay(math.max(0, windup - 0.05), function()
			Sfx.Play("HeavySwing", position, 0.6)
		end)
	elseif kind == "Reward" then
		Sfx.Play("Coins", nil, 0.6)
	elseif ABILITY_SOUNDS[kind] then
		Sfx.Play(ABILITY_SOUNDS[kind], position)
	end
end)

notifyRemote.OnClientEvent:Connect(function(kind)
	if kind == "LevelUp" then
		Sfx.Play("Chimes")
	elseif kind == "RankUp" then
		Sfx.Play("Gong")
		task.delay(0.4, Sfx.Play, "Chimes")
	end
end)

arenaEvent.OnClientEvent:Connect(function(kind, data)
	if kind == "Result" and type(data) == "table" then
		if data.Victory then
			Sfx.Play("Chimes")
			Sfx.Play("Coins", nil, 0.8)
		else
			Sfx.Play("Gong", nil, 0.6)
		end
	end
end)

player:GetAttributeChangedSignal("ArenaWave"):Connect(function()
	if myRunId() and (player:GetAttribute("ArenaWave") or 0) > 0 then
		Sfx.Play("Gong", nil, 0.7)
	end
end)

-- A boss of your run appears: a roar.
task.spawn(function()
	local enemies = Workspace:WaitForChild("Enemies", 60)
	if not enemies then
		return
	end
	enemies.ChildAdded:Connect(function(model)
		task.wait(0.2)
		if model:GetAttribute("IsBoss") and model:GetAttribute("RunId") == myRunId() then
			local root = model:FindFirstChild("HumanoidRootPart")
			Sfx.Play("Roar", root and root.Position)
		end
	end)
end)

--------------------------------------------------------------------------
-- Button clicks (menus only; not the combat and ability buttons)
--------------------------------------------------------------------------
local SILENT_GUIS = { CombatHUD = true, CombatTouchButtons = true, AbilityButtons = true, IncarnationUI = true }
local function hookButton(button)
	if not button:IsA("GuiButton") or button:GetAttribute("SfxHooked") then
		return
	end
	local screen = button:FindFirstAncestorWhichIsA("ScreenGui")
	if screen and SILENT_GUIS[screen.Name] then
		return
	end
	button:SetAttribute("SfxHooked", true)
	button.Activated:Connect(function()
		Sfx.Play("Click")
	end)
end
for _, item in playerGui:GetDescendants() do
	hookButton(item)
end
playerGui.DescendantAdded:Connect(hookButton)

--------------------------------------------------------------------------
-- Music / Effects toggles (bottom left, above the version label)
--------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "AudioToggles"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.Parent = playerGui

local function toggle(label, attribute, x)
	local b = Instance.new("TextButton")
	b.Name = attribute
	b.AnchorPoint = Vector2.new(0, 1)
	b.Position = UDim2.new(0, x, 1, -26)
	b.Size = UDim2.fromOffset(86, 26)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = Color3.fromRGB(40, 34, 52)
	b.BackgroundTransparency = 0.25
	b.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(212, 175, 55)
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local function refresh()
		local value = player:GetAttribute(attribute)
		local on = (if type(value) == "number" then value else 0.5) > 0
		b.Text = label .. (if on then ": On" else ": Off")
		stroke.Color = if on then Color3.fromRGB(212, 175, 55) else Color3.fromRGB(120, 120, 130)
	end
	b.Activated:Connect(function()
		local value = player:GetAttribute(attribute)
		local on = (if type(value) == "number" then value else 0.5) > 0
		settingsRemote:FireServer(attribute, if on then 0 else (if attribute == "MusicVolume" then 0.5 else 0.8))
	end)
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
	refresh()
	b.Parent = gui
end
toggle("Music", "MusicVolume", 8)
toggle("Effects", "SfxVolume", 100)
