-- Décor vivant (D97) : remplit d'eau Terrain les volumes de la carte (tag WaterVolume, pièces invisibles, cylindre
-- debout ou bloc), règle le rendu de l'eau et ajoute des nuages dynamiques. Les jets d'eau (particules) sont posés
-- côté client par AmbienceController.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambience = require(ReplicatedStorage.Shared.Config.Ambience)

local WATER_TAG = "WaterVolume"

local SceneryService = {}

local function fill(volume: Instance)
	if not volume:IsA("Part") then
		return
	end
	local terrain = workspace.Terrain
	if volume.Shape == Enum.PartType.Cylinder then
		-- Cylindre debout : son axe (X de la pièce) est vertical
		terrain:FillCylinder(CFrame.new(volume.Position), volume.Size.X, volume.Size.Y / 2, Enum.Material.Water)
	else
		terrain:FillBlock(volume.CFrame, volume.Size, Enum.Material.Water)
	end
end

function SceneryService.Start()
	local terrain = workspace.Terrain
	local water = Ambience.Water
	terrain.WaterColor = water.Color
	terrain.WaterTransparency = water.Transparency
	terrain.WaterWaveSize = water.WaveSize
	terrain.WaterWaveSpeed = water.WaveSpeed
	terrain.WaterReflectance = water.Reflectance

	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = Ambience.Clouds.Cover
	clouds.Density = Ambience.Clouds.Density
	clouds.Color = Ambience.Clouds.Color
	clouds.Parent = terrain

	for _, volume in CollectionService:GetTagged(WATER_TAG) do
		fill(volume)
	end
	CollectionService:GetInstanceAddedSignal(WATER_TAG):Connect(fill)
end

return SceneryService
