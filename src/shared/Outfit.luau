-- Monte une tenue complète sans personnage : corps d'un stade + objets de style, au repos, posés au sol.
-- Utilisé par les présentoirs des magasins (DisplayService), par l'aperçu d'essayage de la boutique
-- (ShopController) et par le menu de création (CreatorController). Mêmes modèles, mêmes décalages et mêmes
-- couleurs que sur les joueurs (BodyService, src/shared/Look.luau).
-- Le modèle rendu a son origine au sol, sous le personnage, face vers -Z ; à l'appelant de le placer (PivotTo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BodySkeleton = require(ReplicatedStorage.Shared.Config.BodySkeleton)
local Look = require(ReplicatedStorage.Shared.Look)

local MANNEQUIN_COLOR = Color3.fromRGB(236, 234, 228)

export type Options = {
	mannequin: boolean?, -- corps blanc mat (vitrine) au lieu de la peau
	bust: boolean?, -- tête seule (les objets portés ailleurs sont ignorés)
	look: Look.LookData?, -- apparence (genre, couleurs, expression) ; sinon l'apparence par défaut
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

local function place(template: Instance?, cframe: CFrame, parent: Instance, whiten: boolean, color: Color3?)
	if not template or not template:IsA("BasePart") then
		return
	end
	local clone = template:Clone()
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanTouch = false
	clone.CanQuery = false
	clone.CFrame = cframe
	if color then
		clone.Color = color
	end
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
	local look = opts.look or Look.Default()
	local bodyKey = Look.BodyKey(stage, look, bodies)
	local whiten = opts.mannequin == true
	for _, entry in Look.Pieces(bodyKey, look, items, { bust = opts.bust, noBaseHair = whiten }) do
		local folder = if entry.folder == "Bodies" then bodies else styles
		-- Mannequin : le corps est blanchi ; sur les objets exposés, ce qui prend la couleur de peau prend celle
		-- du mannequin, et les cheveux la couleur de cheveux par défaut
		local isBody = entry.folder == "Bodies"
		local color = if entry.tint then Look.Color(look, entry.tint) else nil
		if whiten and entry.tint == "Skin" then
			color = MANNEQUIN_COLOR
		end
		place(
			folder:FindFirstChild(entry.template),
			CFrame.new(skeleton[entry.part] + entry.offset),
			model,
			whiten and isBody,
			color
		)
	end
	model.WorldPivot = CFrame.new()
	return model
end

return Outfit
