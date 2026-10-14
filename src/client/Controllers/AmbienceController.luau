-- Ambiance : les lampadaires (tag "StreetLight") s'allument la nuit et s'éteignent le jour.
-- L'heure vient du serveur (DayNightService) via Lighting.ClockTime ; ce changement est local à chaque joueur.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local STREET_LIGHT_TAG = "StreetLight"
local CYCLE = Balance.DayNight
local OFF_COLOR = Color3.fromRGB(150, 150, 140)

local isOn: boolean? = nil
local onColors: { [BasePart]: Color3 } = {}

local AmbienceController = {}

local function apply(part: Instance, on: boolean)
	if not part:IsA("BasePart") then
		return
	end
	onColors[part] = onColors[part] or part.Color
	part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Color = if on then onColors[part] else OFF_COLOR
	for _, child in part:GetChildren() do
		if child:IsA("Light") then
			child.Enabled = on
		end
	end
end

local function update()
	local clock = Lighting.ClockTime
	local on = clock >= CYCLE.LightsOn or clock < CYCLE.LightsOff
	if on == isOn then
		return
	end
	isOn = on
	for _, part in CollectionService:GetTagged(STREET_LIGHT_TAG) do
		apply(part, on)
	end
end

function AmbienceController.Start()
	CollectionService:GetInstanceAddedSignal(STREET_LIGHT_TAG):Connect(function(part)
		apply(part, isOn == true)
	end)
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(update)
	update()
end

return AmbienceController
