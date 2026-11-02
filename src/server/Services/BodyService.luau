-- Corps du personnage du joueur selon son stade : proportions du squelette R15 + coque Blender (D28, D39).
-- Les parties Roblox d'origine deviennent invisibles ; chaque pièce de la coque est soudée à sa partie,
-- donc les animations (Roblox et ActivityController) la font suivre.
-- Le personnage prend du muscle à chaque séance (D40), EN CONTINU (D60) : pendant un stade, chaque pièce et le
-- squelette lui-même (largeur, hauteur, profondeur) se rapprochent de ceux du corps du stade suivant, au rythme de la
-- progression du Mog vers le boss. Au Mog du boss, le corps a exactement la taille du suivant : battre le boss ne
-- change plus que les détails (définition, formes), pas la taille. Au dernier stade, l'ancienne croissance continue.
-- S'y ajoute le pump des muscles travaillés pendant une série (redescend en quelques secondes).
-- Changer de stade = transformation (signal BodyTransform à tous les clients : l'éclat doré masque le changement).
-- Les objets de style équipés (coupes, barbes, hauts, accessoires) sont des pièces modélisées pour chaque corps
-- (ReplicatedStorage.Style, StylePieces.luau) : soudées comme le corps, elles suivent pump et croissance.
-- Une coupe équipée remplace la coupe de base du corps.
-- Apparence choisie à la création (D55, src/shared/Look.luau) : corps masculin ou féminin, et couleur de chaque
-- pièce teintable (peau, cheveux, yeux, tenue de départ) ; seule l'expression choisie est posée.
-- Si le corps d'un stade n'est pas importé, l'apparence provisoire de StatsService s'applique.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BodyPieces = require(ReplicatedStorage.Shared.Config.BodyPieces)
local Bodies = require(ReplicatedStorage.Shared.Config.Bodies)
local StyleItems = require(ReplicatedStorage.Shared.Config.StyleItems)
local StylePieces = require(ReplicatedStorage.Shared.Config.StylePieces)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Look = require(ReplicatedStorage.Shared.Look)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SHELL_NAME = "BodyShell"
local GROWTH = Balance.Growth

-- Une pièce posée : sa taille et son décalage dans ce corps, et ceux de sa jumelle dans le corps du stade suivant
type Piece = {
	part: BasePart,
	weld: Weld,
	kind: string,
	size: Vector3,
	offset: Vector3,
	growthRatio: Vector3?,
	nextSize: Vector3?,
	nextOffset: Vector3?,
}
type State = {
	character: Model,
	stageId: string,
	bodyKey: string, -- corps porté (<Stade> ou <Stade>F) : un changement de genre réapplique les proportions
	styleKey: string, -- objets équipés et apparence au moment de la construction (pour savoir s'il faut reconstruire)
	pieces: { Piece },
	pump: { [string]: number }, -- gonflement en cours par type de muscle (UpperArm, UpperTorso…)
	scale: Bodies.Body, -- proportions du squelette de ce corps
	nextScale: Bodies.Body?, -- celles du corps du stade suivant (nil au dernier stade)
	appliedScale: number?, -- dernière progression appliquée au squelette (évite de le redimensionner pour rien)
}

local DataService

local states: { [Player]: State } = {}

local BodyService = {}

-- Corps prévu pour le stade du joueur (et l'id du stade), seulement si ses pièces sont importées
function BodyService.BodyFor(player: Player): (Bodies.Body?, string?)
	local data = DataService.Get(player)
	local stage = data and Stages.List[data.Stage]
	local body = stage and Bodies[stage.id]
	local folder = ReplicatedStorage:FindFirstChild("Bodies")
	if body and folder and folder:FindFirstChild(stage.id .. "_UpperTorso") then
		return body, stage.id
	end
	return nil, nil
end

-- Stade suivant (nil au dernier stade, ou si son corps n'est pas importé)
local function nextStageId(player: Player): string?
	local data = DataService.Get(player)
	local nextStage = data and Stages.List[data.Stage + 1]
	local folder = ReplicatedStorage:FindFirstChild("Bodies")
	if nextStage and Bodies[nextStage.id] and folder and folder:FindFirstChild(nextStage.id .. "_UpperTorso") then
		return nextStage.id
	end
	return nil
end

-- Progression (0 à 1) du Mog entre le boss battu précédent et le boss du stade actuel
function BodyService.Progress(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local stage = Stages.List[data.Stage]
	local previous = Stages.List[data.Stage - 1]
	if not stage or not stage.boss then
		return 1
	end
	local from = if previous and previous.boss then previous.boss.mogRequired else 0
	local to = stage.boss.mogRequired
	return math.clamp((data.Mog - from) / math.max(to - from, 1), 0, 1)
end

local function applyProportions(humanoid: Humanoid, body: Bodies.Body)
	local description = humanoid:GetAppliedDescription()
	description.WidthScale = body.width
	description.HeightScale = body.height
	description.DepthScale = body.depth
	description.HeadScale = body.head
	description.ProportionScale = 0
	description.BodyTypeScale = 0
	-- Parties standard (tailles prévisibles), sans accessoires ni vêtements : la coque les remplace
	description.Head = 0
	description.Torso = 0
	description.LeftArm = 0
	description.RightArm = 0
	description.LeftLeg = 0
	description.RightLeg = 0
	description.Face = 0
	description.Shirt = 0
	description.Pants = 0
	description.GraphicTShirt = 0
	description:SetAccessories({}, true)
	humanoid:ApplyDescription(description)
end

local function hideOriginalBody(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			child.Transparency = 1
			for _, decal in child:GetChildren() do
				if decal:IsA("Decal") then
					decal.Transparency = 1
				end
			end
		end
	end
end

-- Type de muscle d'une pièce : LeftUpperArm -> UpperArm, Head_Hair -> Head_Hair
local function kindOf(piece: string): string
	local kind = string.gsub(piece, "^Left", "")
	kind = string.gsub(kind, "^Right", "")
	return kind
end

-- Apparence du joueur (création de personnage), validée
local function lookOf(player: Player): Look.LookData
	local data = DataService.Get(player)
	return Look.Sanitize(data and data.Look, nil)
end

-- Objets de style équipés dont les modèles existent pour ce corps
local function equippedStyle(player: Player, bodyKey: string): { string }
	local data = DataService.Get(player)
	local folder = ReplicatedStorage:FindFirstChild("Style")
	local items = {}
	if not data or not folder then
		return items
	end
	for category, itemId in data.StyleEquipped do
		local item = StyleItems[itemId]
		local pieces = StylePieces[bodyKey] and StylePieces[bodyKey][itemId]
		if item and item.category == category and pieces then
			local complete = true
			for key in pieces do
				if not folder:FindFirstChild(`{bodyKey}__{itemId}__{key}`) then
					complete = false
					break
				end
			end
			if complete then
				table.insert(items, itemId)
			end
		end
	end
	table.sort(items)
	return items
end

-- Les objets de style ont-ils leurs modèles importés ? (sinon StyleService garde les blocs de secours)
function BodyService.HasStyleModels(): boolean
	return ReplicatedStorage:FindFirstChild("Style") ~= nil
end

-- Jumelle d'une pièce dans le corps du stade suivant : même pièce si elle existe, sinon la pièce de base de la même
-- partie (ex. une manche de t-shirt qui n'existe plus au stade torse nu suit le bras)
local function twinOf(entry: Look.Piece, bodyKey: string, nextKey: string): (Vector3?, Vector3?)
	local folder = ReplicatedStorage:FindFirstChild(entry.folder)
	local bodies = ReplicatedStorage:FindFirstChild("Bodies")
	if not folder or not bodies then
		return nil, nil
	end
	local nextTemplate, nextOffset
	if entry.item then
		nextTemplate = folder:FindFirstChild(`{nextKey}__{entry.item}__{entry.key}`)
		nextOffset = StylePieces[nextKey]
			and StylePieces[nextKey][entry.item]
			and StylePieces[nextKey][entry.item][entry.key]
	else
		nextTemplate = folder:FindFirstChild(`{nextKey}_{entry.key}`)
		nextOffset = BodyPieces[nextKey] and BodyPieces[nextKey][entry.key]
	end
	local template = folder:FindFirstChild(entry.template)
	if nextTemplate and nextTemplate:IsA("BasePart") and nextOffset and template and template:IsA("BasePart") then
		return nextTemplate.Size, nextOffset
	end
	-- Pas de jumelle : la pièce grandit comme la pièce de base de sa partie
	local base = bodies:FindFirstChild(`{bodyKey}_{entry.part}`)
	local nextBase = bodies:FindFirstChild(`{nextKey}_{entry.part}`)
	if not base or not nextBase or not base:IsA("BasePart") or not nextBase:IsA("BasePart") or not template then
		return nil, nil
	end
	-- Taille : proportionnelle à la pièce de base, mais jamais plus de 30 % plus grosse qu'elle (une manche sur un
	-- bras de spaghetti qui devient musclé exploserait) ; position : même écart à la pièce de base qu'aujourd'hui
	local size = ((template :: BasePart).Size * (nextBase.Size / base.Size)):Min(nextBase.Size * 1.3)
	local baseOffset = BodyPieces[bodyKey] and BodyPieces[bodyKey][entry.part]
	local nextBaseOffset = BodyPieces[nextKey] and BodyPieces[nextKey][entry.part]
	if not baseOffset or not nextBaseOffset then
		return nil, nil
	end
	return size, nextBaseOffset + (entry.offset - baseOffset)
end

-- Toutes les coques d'une même partie R15 grandissent selon la taille de son corps.
-- Des interpolations indépendantes de chaque MeshPart décalent les tissus de la peau entre deux stades.
local function bodyGrowthRatio(bodyKey: string, nextKey: string, part: string): Vector3?
	local folder = ReplicatedStorage:FindFirstChild("Bodies")
	if not folder then
		return nil
	end
	local function template(key: string): BasePart?
		for _, suffix in { "", "_Shorts", "_Top" } do
			local candidate = folder:FindFirstChild(`{key}_{part}{suffix}`)
			if candidate and candidate:IsA("BasePart") then
				return candidate
			end
		end
		return nil
	end
	local current = template(bodyKey)
	local nextPart = template(nextKey)
	if not current or not nextPart then
		return nil
	end
	return nextPart.Size / current.Size
end

local function buildShell(
	character: Model,
	bodyKey: string,
	nextKey: string?,
	look: Look.LookData,
	styleItems: { string }
): { Piece }
	local old = character:FindFirstChild(SHELL_NAME)
	if old then
		old:Destroy()
	end
	local shell = Instance.new("Model")
	shell.Name = SHELL_NAME
	local pieces = {}
	local growthRatios: { [string]: Vector3? } = {}

	-- Chaque pièce est soudée à sa partie R15, à son décalage de repos : elle suit les animations
	for _, entry in Look.Pieces(bodyKey, look, styleItems) do
		local folder = ReplicatedStorage:FindFirstChild(entry.folder)
		local template = folder and folder:FindFirstChild(entry.template)
		local target = character:FindFirstChild(entry.part)
		if not template or not template:IsA("BasePart") or not target or not target:IsA("BasePart") then
			continue
		end
		local offset = entry.offset
		local clone = template:Clone()
		clone.Anchored = false
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.Massless = true
		clone.CFrame = target.CFrame * CFrame.new(offset)
		-- Couleur choisie, visible au travers des zones semi-transparentes de la texture
		local color = entry.color or entry.tint and Look.Color(look, entry.tint)
		if color then
			clone.Color = color
			-- L'atlas importé rend son voile alpha noir/blanc opaque sur les cheveux dans Roblox.
			-- Sans cette texture, la couleur choisie reste uniforme sur chaque coupe et barbe.
			if (entry.tint == "Hair" or entry.color) and clone:IsA("MeshPart") then
				clone.TextureID = ""
			end
		end
		local weld = Instance.new("Weld")
		weld.Part0 = target
		weld.Part1 = clone
		weld.C0 = CFrame.new(offset)
		weld.Parent = clone
		clone.Parent = shell
		local nextSize, nextOffset = nil, nil
		if nextKey then
			nextSize, nextOffset = twinOf(entry, bodyKey, nextKey)
			if not growthRatios[entry.part] then
				growthRatios[entry.part] = bodyGrowthRatio(bodyKey, nextKey, entry.part)
			end
		end
		table.insert(pieces, {
			part = clone,
			weld = weld,
			kind = kindOf(entry.part),
			size = template.Size,
			offset = offset,
			growthRatio = growthRatios[entry.part],
			nextSize = nextSize,
			nextOffset = nextOffset,
		})
	end
	shell.Parent = character
	return pieces
end

local SCALE_VALUES = {
	{ "BodyWidthScale", "width" },
	{ "BodyHeightScale", "height" },
	{ "BodyDepthScale", "depth" },
	{ "HeadScale", "head" },
}

-- Squelette : proportions entre celles de ce corps et celles du suivant, selon la progression
local function applySkeleton(state: State, progress: number)
	local nextScale = state.nextScale
	if not nextScale then
		return
	end
	if state.appliedScale and math.abs(state.appliedScale - progress) < GROWTH.SkeletonStep then
		return
	end
	state.appliedScale = progress
	local humanoid = state.character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	for _, pair in SCALE_VALUES do
		local value = humanoid:FindFirstChild(pair[1])
		if value and value:IsA("NumberValue") then
			local from, to = (state.scale :: any)[pair[2]], (nextScale :: any)[pair[2]]
			value.Value = from + (to - from) * progress
		end
	end
end

-- Taille de chaque pièce : chemin vers le corps du stade suivant (croissance continue) + pump en cours
local function applySizes(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local progress = BodyService.Progress(player)
	applySkeleton(state, progress)
	-- Dernier stade (pas de corps suivant) : l'ancienne croissance en épaisseur
	local lastStage = state.nextScale == nil
	local growth = if lastStage then GROWTH.MaxScale * progress else 0
	for _, piece in state.pieces do
		local weight = GROWTH.Weights[piece.kind] or 0
		local extra = (growth + (state.pump[piece.kind] or 0)) * weight
		local pump = Vector3.new(1 + extra, 1 + extra * GROWTH.LengthShare, 1 + extra)
		local size, offset = piece.size, piece.offset
		if piece.growthRatio then
			local scale = Vector3.new(1, 1, 1):Lerp(piece.growthRatio, progress)
			size *= scale
			offset *= scale
		elseif piece.nextSize and piece.nextOffset then
			size = size:Lerp(piece.nextSize, progress)
			offset = offset:Lerp(piece.nextOffset, progress)
		end
		piece.part.Size = size * pump
		piece.weld.C0 = CFrame.new(offset)
	end
end

-- Applique (ou retire) le corps du stade sur le personnage actuel du joueur.
-- force : tout reconstruire même si rien n'a changé (ex. l'apparence Roblox vient de finir de charger et a pu
-- remettre des accessoires ou des parties visibles)
function BodyService.Refresh(player: Player, force: boolean?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local body, stageId = BodyService.BodyFor(player)
	local previous = states[player]
	if not body or not stageId then
		local old = character:FindFirstChild(SHELL_NAME)
		if old then
			old:Destroy()
		end
		states[player] = nil
		return
	end
	local look = lookOf(player)
	local bodiesFolder = ReplicatedStorage:FindFirstChild("Bodies")
	local bodyKey = Look.BodyKey(stageId, look, bodiesFolder)
	local nextStage = nextStageId(player)
	local nextKey = if nextStage then Look.BodyKey(nextStage, look, bodiesFolder) else nil
	local styleItems = equippedStyle(player, bodyKey)
	local styleKey = `{bodyKey}>{nextKey or ""}|{table.concat(styleItems, ",")}|{Look.Key(look)}`
	local sameCharacter = previous ~= nil and previous.character == character
	if sameCharacter and previous.bodyKey == bodyKey and not force then
		-- Même corps : on ne reconstruit que si les objets équipés ont changé
		if previous.styleKey ~= styleKey then
			previous.pieces = buildShell(character, bodyKey, nextKey, look, styleItems)
			previous.styleKey = styleKey
		end
		applySizes(player)
		return
	end
	-- Proportions du squelette du corps porté (les corps féminins ont les leurs) ; la croissance continue les
	-- rapproche ensuite de celles du corps suivant (applySkeleton)
	local scale = Bodies[bodyKey] or body
	applyProportions(humanoid, scale)
	hideOriginalBody(character)
	states[player] = {
		character = character,
		stageId = stageId,
		bodyKey = bodyKey,
		scale = scale,
		nextScale = if nextKey then Bodies[nextKey] else nil,
		styleKey = styleKey,
		pieces = buildShell(character, bodyKey, nextKey, look, styleItems),
		pump = if sameCharacter then previous.pump else {},
	}
	applySizes(player)
	-- Nouveau stade sur le même personnage : transformation (effet visuel chez tout le monde)
	if sameCharacter and previous.stageId ~= stageId then
		Remotes.BodyTransform:FireAllClients(player, stageId)
	end
end

-- Le Mog a changé : la croissance permanente suit
function BodyService.UpdateGrowth(player: Player)
	applySizes(player)
end

-- Une répétition d'exercice validée gonfle les muscles travaillés
function BodyService.Pump(player: Player, exerciseId: string, quality: string)
	local state = states[player]
	local muscles = GROWTH.PumpMuscles[exerciseId]
	local amount = GROWTH.PumpPerRep[quality]
	if not state or not muscles or not amount then
		return
	end
	for _, muscle in muscles do
		state.pump[muscle] = math.min((state.pump[muscle] or 0) + amount, GROWTH.PumpMax)
	end
	applySizes(player)
end

-- Le pump redescend doucement
local function decayPump()
	local step = GROWTH.PumpMax / GROWTH.PumpDecayTime * GROWTH.PumpUpdateInterval
	for player, state in states do
		local changed = false
		for muscle, value in state.pump do
			if value > 0 then
				state.pump[muscle] = math.max(value - step, 0)
				changed = true
			end
		end
		if changed then
			applySizes(player)
		end
	end
end

function BodyService.Init(services)
	DataService = services.DataService
end

function BodyService.Start()
	DataService.PlayerLoaded:Connect(function(player)
		player.CharacterAppearanceLoaded:Connect(function()
			BodyService.Refresh(player, true)
		end)
		if player.Character and player:HasAppearanceLoaded() then
			task.spawn(BodyService.Refresh, player, true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(GROWTH.PumpUpdateInterval)
			decayPump()
		end
	end)
end

return BodyService
