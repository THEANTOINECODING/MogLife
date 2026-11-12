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

-- Centre de la tête d'un stade (pour cadrer une caméra ou poser une tête) ; avec l'apparence, celui du corps
-- féminin si c'est lui qui est porté
function Outfit.HeadCenter(stage: string, look: Look.LookData?): Vector3?
	local key = if look then Look.BodyKey(stage, look, ReplicatedStorage:FindFirstChild("Bodies")) else stage
	local skeleton = BodySkeleton[key] or BodySkeleton[stage]
	return skeleton and skeleton.Head
end

-- flat : sans la texture (cheveux et barbes : couleur unie, comme sur le personnage, voir BodyService)
local function place(
	template: Instance?,
	cframe: CFrame,
	parent: Instance,
	whiten: boolean,
	color: Color3?,
	flat: boolean?,
	glow: boolean?
)
	if not template or not template:IsA("BasePart") then
		return
	end
	local clone = template:Clone()
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanTouch = false
	clone.CanQuery = false
	clone.CFrame = cframe
	if color and not whiten then
		Look.Tint(clone, color, flat) -- voile en Overlay (D119)
	end
	if glow and not whiten then
		Look.Glow(clone) -- D125 : pièce lumineuse d'une tenue Robux
	end
	if whiten and clone:IsA("MeshPart") then
		clone.TextureID = ""
		local appearance = clone:FindFirstChildOfClass("SurfaceAppearance")
		if appearance then
			appearance:Destroy()
		end
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
	if not bodies or not styles then
		return nil
	end
	local look = opts.look or Look.Default()
	local bodyKey = Look.BodyKey(stage, look, bodies)
	-- Les corps féminins ont leur propre squelette (plus étroit)
	local skeleton = BodySkeleton[bodyKey] or BodySkeleton[stage]
	if not skeleton then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Outfit"
	local whiten = opts.mannequin == true
	for _, entry in Look.Pieces(bodyKey, look, items, { bust = opts.bust, noBaseHair = whiten }) do
		local folder = if entry.folder == "Bodies" then bodies else styles
		-- Mannequin : le corps est blanchi ; sur les objets exposés, ce qui prend la couleur de peau prend celle
		-- du mannequin, et les cheveux la couleur de cheveux par défaut
		local isBody = entry.folder == "Bodies"
		local color = entry.color or entry.skin or if entry.tint then Look.Color(look, entry.tint) else nil
		if whiten and entry.tint == "Skin" then
			color = MANNEQUIN_COLOR
		end
		place(
			folder:FindFirstChild(entry.template),
			CFrame.new(skeleton[entry.part] + entry.offset),
			model,
			whiten and isBody,
			color,
			entry.tint == "Hair" or entry.color ~= nil,
			entry.glow
		)
	end
	model.WorldPivot = CFrame.new()
	return model
end

return Outfit
