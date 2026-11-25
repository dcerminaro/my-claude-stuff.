-- DecorAnimator (LocalScript)
-- Location: StarterPlayer > StarterPlayerScripts > DecorAnimator
--
-- Phase 8: gentle motion on each player's own screen (no server cost):
--   * "OlympusSpin" models (e.g. the golden rings around the Heart of
--     Olympus) rotate around their Pivot attribute at Speed (turns/second).
--   * "OlympusBob" models (sky islands) float up and down by Amplitude
--     studs every Period seconds.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local spinning = {} -- [Model] = { Base = CFrame, Pivot = Vector3, Speed = number }
local bobbing = {}  -- [Model] = { Base = CFrame, Amplitude, Period, Phase }

local function addSpin(model)
	if not model:IsA("Model") then
		return
	end
	local pivot = model:GetAttribute("Pivot")
	spinning[model] = {
		Base = model:GetPivot(),
		Pivot = if typeof(pivot) == "Vector3" then pivot else model:GetPivot().Position,
		Speed = model:GetAttribute("Speed") or 0.2,
	}
end

local function addBob(model)
	if not model:IsA("Model") then
		return
	end
	bobbing[model] = {
		Base = model:GetPivot(),
		Amplitude = model:GetAttribute("Amplitude") or 2,
		Period = model:GetAttribute("Period") or 8,
		Phase = math.random() * math.pi * 2,
	}
end

for _, model in CollectionService:GetTagged("OlympusSpin") do
	addSpin(model)
end
for _, model in CollectionService:GetTagged("OlympusBob") do
	addBob(model)
end
CollectionService:GetInstanceAddedSignal("OlympusSpin"):Connect(addSpin)
CollectionService:GetInstanceAddedSignal("OlympusBob"):Connect(addBob)
CollectionService:GetInstanceRemovedSignal("OlympusSpin"):Connect(function(model)
	spinning[model] = nil
end)
CollectionService:GetInstanceRemovedSignal("OlympusBob"):Connect(function(model)
	bobbing[model] = nil
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for model, info in spinning do
		if model.Parent then
			local pivot = CFrame.new(info.Pivot)
			local angle = t * info.Speed * math.pi * 2
			model:PivotTo(pivot * CFrame.Angles(0, angle, angle * 0.35) * pivot:Inverse() * info.Base)
		else
			spinning[model] = nil
		end
	end
	for model, info in bobbing do
		if model.Parent then
			local offset = math.sin(t / info.Period * math.pi * 2 + info.Phase) * info.Amplitude
			model:PivotTo(info.Base + Vector3.new(0, offset, 0))
		else
			bobbing[model] = nil
		end
	end
end)
