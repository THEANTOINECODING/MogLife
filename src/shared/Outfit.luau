-- Monte une tenue complète sans personnage : corps d'un stade + objets de style, au repos, posés au sol.
-- Utilisé par les présentoirs des magasins (DisplayService) et par l'aperçu d'essayage de la boutique
-- (ShopController). Mêmes modèles et mêmes décalages que sur les joueurs (BodyService).
-- Le modèle rendu a son origine au sol, sous le personnage, face vers -Z ; à l'appelant de le placer (PivotTo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BodyPieces = require(ReplicatedStorage.Shared.Config.BodyPieces)
local BodySkeleton = require(ReplicatedStorage.Shared.Config.BodySkeleton)
local StyleItems = require(ReplicatedStorage.Shared.Config.StyleItems)
local StylePieces = require(ReplicatedStorage.Shared.Config.StylePieces)

local MANNEQUIN_COLOR = Color3.fromRGB(236, 234, 228)

export type Options = {
	mannequin: boolean?, -- corps blanc mat (vitrine) au lieu de la peau
	bust: boolean?, -- tête seule (les objets portés ailleurs sont ignorés)
}

local Outfit = {}

-- Les modèles nécessaires sont-ils importés ?
function Outfit.Available(): boolean
	return ReplicatedStorage:FindFirstChild("Bodies") ~= nil and ReplicatedStorage:FindFirstChild("Style") ~= nil
end

-- Hauteur du sommet de la tête d'un stade (pour cadrer une caméra ou poser une tête)
function Outfit.HeadCenter(stage: string): Vector3?
	local skeleton = BodySkeleton[stage]
	return skeleton and skeleton.Head
end

local function place(template: Instance?, cframe: CFrame, parent: Instance, whiten: boolean)
	if not template or not template:IsA("BasePart") then
		return
	end
	local clone = template:Clone()
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanTouch = false
	clone.CanQuery = false
	clone.CFrame = cframe
	if whiten and clone:IsA("MeshPart") then
		clone.TextureID = ""
		clone.Color = MANNEQUIN_COLOR
		clone.Material = Enum.Material.SmoothPlastic
	end
	clone.Parent = parent
end

-- Modèle de la tenue (nil si le stade est inconnu ou les modèles absents)
function Outfit.Build(stage: string, items: { string }, options: Options?): Model?
	local opts = options or {}
	local bodies = ReplicatedStorage:FindFirstChild("Bodies")
	local styles = ReplicatedStorage:FindFirstChild("Style")
	local skeleton = BodySkeleton[stage]
	if not bodies or not styles or not skeleton then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Outfit"
	local hasHair = false
	for _, itemId in items do
		local item = StyleItems[itemId]
		if item and item.category == "Hair" then
			hasHair = true
		end
	end
	for piece, offset in BodyPieces[stage] or {} do
		local part = string.split(piece, "_")[1]
		local skip = (opts.bust and part ~= "Head") or (piece == "Head_Hair" and (hasHair or opts.mannequin == true))
		if not skip then
			place(
				bodies:FindFirstChild(`{stage}_{piece}`),
				CFrame.new(skeleton[part] + offset),
				model,
				opts.mannequin == true
			)
		end
	end
	for _, itemId in items do
		for part, offset in (StylePieces[stage] and StylePieces[stage][itemId]) or {} do
			if not opts.bust or part == "Head" then
				place(
					styles:FindFirstChild(`{stage}__{itemId}__{part}`),
					CFrame.new(skeleton[part] + offset),
					model,
					false
				)
			end
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

return Outfit
