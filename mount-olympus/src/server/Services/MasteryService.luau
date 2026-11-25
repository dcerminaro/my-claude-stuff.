-- MasteryService (ModuleScript)
-- Location: ServerScriptService > Services > MasteryService
--
-- Phase 7E part 3 (settings in Shared/MasteryConfig):
--   * Divine Mastery: mastery XP and level per god (data.Mastery[god] =
--     { Level, XP }), earned for the god you worship from GameEvents (kills,
--     arena/challenge wins, worship, abilities). Small attack/health bonus
--     (GodService.GetBonuses reads it) and cosmetics on your character.
--   * Divine Incarnation (Elder God): Divine Energy from hitting/defeating
--     enemies; when full, "Activate" transforms you for a while: opening
--     blast, heal, buffs (through AbilityService.AddBuff) and a glowing form.
-- Client attributes: MasteryJson, IncarnationUnlocked, DivineEnergy,
-- IncarnationUntil (server time), IncarnationForm.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MasteryConfig = require(Shared:WaitForChild("MasteryConfig"))
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local ArenaConfig = require(Shared:WaitForChild("ArenaConfig"))
local GodConfig = require(Shared:WaitForChild("GodConfig"))

local GameEvents = require(script.Parent:WaitForChild("GameEvents"))

local MasteryService = {}

local DataService = nil
local ProgressionService = nil
local AbilityService = nil
local notifyRemote = nil
local fxRemote = nil

local INC = MasteryConfig.Incarnation
local energy = {} -- [Player] = { Energy, Until }

local function message(player, text)
	if notifyRemote and player.Parent then
		notifyRemote:FireClient(player, "Message", text)
	end
end

local function masteryOf(data, godId)
	if type(data.Mastery) ~= "table" then
		data.Mastery = {}
	end
	local entry = data.Mastery[godId]
	if type(entry) ~= "table" then
		entry = { Level = 1, XP = 0 }
		data.Mastery[godId] = entry
	end
	entry.Level = math.clamp(math.floor(tonumber(entry.Level) or 1), 1, MasteryConfig.MaxLevel)
	entry.XP = math.max(0, tonumber(entry.XP) or 0)
	return entry
end

-- Mastery level of the god this player worships (0 = no god yet).
function MasteryService.GetLevel(player)
	local data = DataService.GetData(player)
	if not data or data.SelectedGod == "" then
		return 0
	end
	return masteryOf(data, data.SelectedGod).Level
end

local function push(player, data)
	local levels = {}
	for godId in GodConfig.Gods do
		local entry = type(data.Mastery) == "table" and data.Mastery[godId]
		levels[godId] = if type(entry) == "table" then entry.Level or 1 else 1
	end
	local current = if data.SelectedGod ~= "" then masteryOf(data, data.SelectedGod) else { Level = 0, XP = 0 }
	player:SetAttribute("MasteryGod", data.SelectedGod)
	player:SetAttribute("MasteryJson", HttpService:JSONEncode({
		God = data.SelectedGod,
		Level = current.Level,
		XP = math.floor(current.XP),
		Need = if current.Level >= 1 and current.Level < MasteryConfig.MaxLevel then MasteryConfig.XPForLevel(current.Level) else 0,
		Levels = levels,
	}))
end

--------------------------------------------------------------------------
-- Cosmetics (all parented to the HumanoidRootPart, which avatar changes
-- never replace; rebuilt whenever god or level changes)
--------------------------------------------------------------------------
local function clearCosmetics(character, prefix)
	for _, item in character:GetDescendants() do
		if item.Name:sub(1, #prefix) == prefix then
			item:Destroy()
		end
	end
end

local function weldedRing(character, root, prefix, offsetY, radius, count, color, thickness)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local part = Instance.new("Part")
		part.Name = prefix .. i
		part.Size = Vector3.new(2 * math.pi * radius / count * 1.05, thickness, thickness)
		part.Material = Enum.Material.Neon
		part.Color = color
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		part.CFrame = root.CFrame * CFrame.new(0, offsetY, 0) * CFrame.Angles(0, -angle, 0) * CFrame.new(0, 0, radius)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = character
	end
end

local function applyCosmetics(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local data = DataService.GetData(player)
	if not root or not data then
		return
	end
	local godId = data.SelectedGod
	local level = if godId ~= "" then masteryOf(data, godId).Level else 0
	local signature = godId .. "|" .. level
	if root:GetAttribute("MasteryLook") == signature and root:FindFirstChild("Mastery_Marker") then
		return
	end
	clearCosmetics(character, "Mastery_")
	root:SetAttribute("MasteryLook", signature)
	local marker = Instance.new("Folder")
	marker.Name = "Mastery_Marker"
	marker.Parent = root
	if level <= 0 then
		return
	end
	local god = GodConfig.Gods[godId]
	local colors = GodConfig.GetColors(godId)
	local glow = colors.Glow or colors.Accent

	if level >= 5 then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "Mastery_Sparks"
		sparks.Color = ColorSequence.new(glow)
		sparks.LightEmission = 1
		sparks.Rate = if level >= 25 then 10 else 5
		sparks.Lifetime = NumberRange.new(1, 1.8)
		sparks.Speed = NumberRange.new(0.5, 1.5)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Size = NumberSequence.new(0.22, 0)
		sparks.Parent = root
	end
	local title = MasteryConfig.Title(god and god.DisplayName or godId, level)
	if title then
		local gui = Instance.new("BillboardGui")
		gui.Name = "Mastery_Title"
		gui.Size = UDim2.fromOffset(220, 26)
		gui.StudsOffset = Vector3.new(0, 4.2, 0)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = colors.Accent
		label.TextStrokeTransparency = 0.3
		label.Text = title
		label.Parent = gui
		gui.Parent = root
	end
	if level >= 15 then
		local a0 = Instance.new("Attachment")
		a0.Name = "Mastery_TrailA"
		a0.Position = Vector3.new(0, -2.6, 0)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "Mastery_TrailB"
		a1.Position = Vector3.new(0, -1.9, 0)
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "Mastery_Trail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(glow)
		trail.LightEmission = 1
		trail.Lifetime = 0.6
		trail.Transparency = NumberSequence.new(0.3, 1)
		trail.Parent = root
	end
	if level >= 30 then
		local light = Instance.new("PointLight")
		light.Name = "Mastery_Glow"
		light.Color = glow
		light.Range = 10
		light.Brightness = 1.2
		light.Parent = root
	end
	if level >= 50 then
		weldedRing(character, root, "Mastery_Crown", 3.3, 0.9, 10, colors.Accent, 0.25)
	end
end

--------------------------------------------------------------------------
-- Mastery XP
--------------------------------------------------------------------------
function MasteryService.AddXP(player, amount)
	local data = DataService.GetData(player)
	amount = tonumber(amount)
	if not data or data.SelectedGod == "" or not amount or amount <= 0 or amount ~= amount then
		return
	end
	local godId = data.SelectedGod
	local entry = masteryOf(data, godId)
	if entry.Level >= MasteryConfig.MaxLevel then
		return
	end
	entry.XP += amount
	local startLevel = entry.Level
	while entry.Level < MasteryConfig.MaxLevel and entry.XP >= MasteryConfig.XPForLevel(entry.Level) do
		entry.XP -= MasteryConfig.XPForLevel(entry.Level)
		entry.Level += 1
	end
	local gained = entry.Level > startLevel
	if gained then
		-- One message however many levels were gained at once.
		local god = GodConfig.Gods[godId]
		message(player, ("%s Mastery level %d! (+%.1f%% attack and health)"):format(god and god.DisplayName or godId, entry.Level, entry.Level * MasteryConfig.AttackPercentPerLevel))
		for _, unlock in MasteryConfig.Unlocks do
			if unlock.Level > startLevel and unlock.Level <= entry.Level then
				message(player, "Unlocked: " .. unlock.Name .. "!")
			end
		end
	end
	if entry.Level >= MasteryConfig.MaxLevel then
		entry.XP = 0
	end
	push(player, data)
	if gained then
		ProgressionService.RefreshStats(player) -- the attack/health bonus
		applyCosmetics(player)
	end
end

local function onEvent(eventType, player, target, amount)
	if not player or not player.Parent then
		return
	end
	local src = MasteryConfig.Sources
	if eventType == "KillEnemy" then
		local cfg = CombatConfig.Enemies[target]
		if cfg and (cfg.XP or 0) > 0 then
			MasteryService.AddXP(player, cfg.XP * src.KillXPShare)
		end
		MasteryService.AddEnergy(player, if cfg and cfg.Boss then INC.EnergyPerBossKill else INC.EnergyPerKill)
	elseif eventType == "HitEnemy" then
		MasteryService.AddEnergy(player, INC.EnergyPerHit)
	elseif eventType == "WinArena" then
		local arena = ArenaConfig.ById[target]
		if arena and arena.Rewards and arena.Rewards.XP then
			MasteryService.AddXP(player, arena.Rewards.XP * src.ArenaXPShare)
		end
	elseif eventType == "WinChallenge" then
		MasteryService.AddXP(player, src.ChallengeWin)
	elseif eventType == "Worship" then
		MasteryService.AddXP(player, src.Worship)
	elseif eventType == "UseAbility" then
		MasteryService.AddXP(player, src.UseAbility * (amount or 1))
	end
end

--------------------------------------------------------------------------
-- Divine Incarnation
--------------------------------------------------------------------------
local function unlocked(player)
	local data = DataService.GetData(player)
	return data ~= nil and (data.RankIndex or 1) >= INC.RequiredRank
end

local function pushEnergy(player)
	local st = energy[player]
	if st then
		player:SetAttribute("IncarnationUnlocked", unlocked(player))
		player:SetAttribute("DivineEnergy", math.floor(st.Energy))
	end
end

function MasteryService.AddEnergy(player, amount)
	local st = energy[player]
	if not st or not unlocked(player) or os.clock() < st.Until then
		return -- no charging while transformed
	end
	local before = st.Energy
	st.Energy = math.min(INC.EnergyMax, st.Energy + amount)
	if math.floor(st.Energy) ~= math.floor(before) then
		pushEnergy(player)
		if st.Energy >= INC.EnergyMax and before < INC.EnergyMax then
			message(player, "Divine Energy full! Incarnate to take your god's form.")
		end
	end
end

local function addFormLook(player, form, colors, duration)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	clearCosmetics(character, "Incarnation_")
	local glow = colors.Glow or colors.Accent
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Incarnation_Aura"
	aura.Color = ColorSequence.new(glow, colors.Accent)
	aura.LightEmission = 1
	aura.Rate = 40
	aura.Lifetime = NumberRange.new(0.6, 1.1)
	aura.Speed = NumberRange.new(2, 5)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Size = NumberSequence.new(0.9, 0)
	aura.Transparency = NumberSequence.new(0.2, 1)
	aura.Parent = root
	local light = Instance.new("PointLight")
	light.Name = "Incarnation_Light"
	light.Color = glow
	light.Range = 22
	light.Brightness = 3
	light.Parent = root
	local fire = Instance.new("Fire")
	fire.Name = "Incarnation_Fire"
	fire.Color = colors.Fire or glow
	fire.SecondaryColor = colors.Accent
	fire.Size = 7
	fire.Heat = 12
	fire.Parent = root
	weldedRing(character, root, "Incarnation_Halo", 3.9, 1.6, 16, colors.Accent, 0.3)
	weldedRing(character, root, "Incarnation_Wing", 0.6, 2.4, 6, glow, 0.2)
	player:SetAttribute("IncarnationForm", form.Name)
	task.delay(duration, function()
		if character.Parent then
			clearCosmetics(character, "Incarnation_")
		end
	end)
end

-- Transforms the player if their Divine Energy is full. Returns true if it did.
function MasteryService.Activate(player)
	local st = energy[player]
	local data = DataService.GetData(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not st or not data or not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	if not unlocked(player) then
		message(player, "Divine Incarnation unlocks at Elder God.")
		return false
	end
	if os.clock() < st.Until then
		return false
	end
	if st.Energy < INC.EnergyMax then
		message(player, ("Divine Energy %d/%d: keep fighting!"):format(math.floor(st.Energy), INC.EnergyMax))
		return false
	end
	local level = MasteryService.GetLevel(player)
	local duration = INC.BaseDuration + INC.DurationPerMastery * level
	local form = MasteryConfig.Forms[data.SelectedGod] or MasteryConfig.DefaultForm
	local colors = GodConfig.GetColors(data.SelectedGod)
	st.Energy = 0
	st.Until = os.clock() + duration
	player:SetAttribute("IncarnationUntil", Workspace:GetServerTimeNow() + duration)
	pushEnergy(player)

	AbilityService.AddBuff(player, "Incarnation", form, duration)
	AbilityService.Heal(player, humanoid.MaxHealth * INC.HealPercent / 100)
	local blast = AbilityService.BaseDamage(player) * INC.BlastDamage
	AbilityService.DamageArea(player, root.Position, INC.BlastRadius, blast, 25)
	if fxRemote then
		fxRemote:FireAllClients("Shockwave", root.Position, colors.Accent, INC.BlastRadius)
		fxRemote:FireAllClients("Lightning", root.Position, colors.Glow or colors.Accent, 6, true) -- beam from the sky
	end
	addFormLook(player, form, colors, duration)
	message(player, ("You become the %s!"):format(form.Name))
	GameEvents.Fire("Incarnate", player, data.SelectedGod)
	return true
end

--------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------
function MasteryService.Init(dataService, progressionService, abilityService, gameEvents, notifyRemoteEvent, fxRemoteEvent, incarnationRemote)
	DataService = dataService
	ProgressionService = progressionService
	AbilityService = abilityService
	notifyRemote = notifyRemoteEvent
	fxRemote = fxRemoteEvent
	gameEvents.Connect(onEvent)
	if incarnationRemote then
		local last = {}
		incarnationRemote.OnServerEvent:Connect(function(player, action)
			local t = os.clock()
			if last[player] and t - last[player] < 0.5 then
				return
			end
			last[player] = t
			if action == "Activate" then
				MasteryService.Activate(player)
			end
		end)
	end
	-- Keep cosmetics right (god change, rank looks rebuilding the avatar...).
	task.spawn(function()
		while true do
			task.wait(3)
			for _, player in Players:GetPlayers() do
				if energy[player] then
					local data = DataService.GetData(player)
					if data and player:GetAttribute("MasteryGod") ~= data.SelectedGod then
						push(player, data) -- the player changed god
					end
					applyCosmetics(player)
					pushEnergy(player)
				end
			end
		end
	end)
end

function MasteryService.SetupPlayer(player)
	energy[player] = { Energy = 0, Until = 0 }
	player:SetAttribute("IncarnationUntil", 0)
	local data = DataService.GetData(player)
	if data then
		push(player, data)
	end
	pushEnergy(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		applyCosmetics(player)
	end)
	task.defer(applyCosmetics, player)
end

function MasteryService.ReleasePlayer(player)
	energy[player] = nil
end

-- Re-sends mastery (e.g. after a god change).
function MasteryService.Refresh(player)
	local data = DataService.GetData(player)
	if data then
		push(player, data)
		applyCosmetics(player)
	end
end

return MasteryService
