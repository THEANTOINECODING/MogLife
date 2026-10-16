-- Corps du personnage du joueur selon son stade : proportions du squelette R15 + coque Blender (D28, D39).
-- Les parties Roblox d'origine deviennent invisibles ; chaque pièce de la coque est soudée à sa partie,
-- donc les animations (Roblox et ActivityController) la font suivre.
-- Le personnage prend du muscle à chaque séance (D40) : chaque pièce est épaissie selon
--   - la croissance permanente du stade (progression du Mog vers le boss suivant),
--   - le pump des muscles travaillés pendant une série (redescend en quelques secondes).
-- Changer de stade = transformation (signal BodyTransform à tous les clients pour l'effet visuel).
-- Les objets de style équipés (coupes, barbes, hauts, accessoires) sont des pièces modélisées pour chaque corps
-- (ReplicatedStorage.Style, StylePieces.luau) : soudées comme le corps, elles suivent pump et croissance.
-- Une coupe équipée remplace la coupe de base du corps.
-- Apparence choisie à la création (D55, src/shared/Look.luau) : corps masculin ou féminin, et couleur de chaque
-- pièce teintable (peau, cheveux, yeux, tenue de départ) ; seule l'expression choisie est posée.
-- Si le corps d'un stade n'est pas importé, l'apparence provisoire de StatsService s'applique.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Bodies = require(ReplicatedStorage.Shared.Config.Bodies)
local StyleItems = require(ReplicatedStorage.Shared.Config.StyleItems)
local StylePieces = require(ReplicatedStorage.Shared.Config.StylePieces)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Look = require(ReplicatedStorage.Shared.Look)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SHELL_NAME = "BodyShell"
local GROWTH = Balance.Growth

type Piece = { part: BasePart, kind: string, size: Vector3 }
type State = {
	character: Model,
	stageId: string,
	styleKey: string, -- objets équipés et apparence au moment de la construction (pour savoir s'il faut reconstruire)
	pieces: { Piece },
	pump: { [string]: number }, -- gonflement en cours par type de muscle (UpperArm, UpperTorso…)
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
			table.insert(items, itemId)
		end
	end
	table.sort(items)
	return items
end

-- Les objets de style ont-ils leurs modèles importés ? (sinon StyleService garde les blocs de secours)
function BodyService.HasStyleModels(): boolean
	return ReplicatedStorage:FindFirstChild("Style") ~= nil
end

local function buildShell(character: Model, bodyKey: string, look: Look.LookData, styleItems: { string }): { Piece }
	local old = character:FindFirstChild(SHELL_NAME)
	if old then
		old:Destroy()
	end
	local shell = Instance.new("Model")
	shell.Name = SHELL_NAME
	local pieces = {}

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
		local color = entry.tint and Look.Color(look, entry.tint)
		if color then
			clone.Color = color
		end
		local weld = Instance.new("Weld")
		weld.Part0 = target
		weld.Part1 = clone
		weld.C0 = CFrame.new(offset)
		weld.Parent = clone
		clone.Parent = shell
		table.insert(pieces, { part = clone, kind = kindOf(entry.part), size = template.Size })
	end
	shell.Parent = character
	return pieces
end

-- Épaisseur de chaque pièce = croissance permanente du stade + pump en cours
local function applySizes(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local growth = GROWTH.MaxScale * BodyService.Progress(player)
	for _, piece in state.pieces do
		local weight = GROWTH.Weights[piece.kind] or 0
		local extra = (growth + (state.pump[piece.kind] or 0)) * weight
		local thick = 1 + extra
		local long = 1 + extra * GROWTH.LengthShare
		piece.part.Size = piece.size * Vector3.new(thick, long, thick)
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
	local bodyKey = Look.BodyKey(stageId, look, ReplicatedStorage:FindFirstChild("Bodies"))
	local styleItems = equippedStyle(player, bodyKey)
	local styleKey = `{bodyKey}|{table.concat(styleItems, ",")}|{Look.Key(look)}`
	local sameCharacter = previous ~= nil and previous.character == character
	if sameCharacter and previous.stageId == stageId and not force then
		-- Même corps : on ne reconstruit que si les objets équipés ont changé
		if previous.styleKey ~= styleKey then
			previous.pieces = buildShell(character, bodyKey, look, styleItems)
			previous.styleKey = styleKey
		end
		applySizes(player)
		return
	end
	applyProportions(humanoid, body)
	hideOriginalBody(character)
	states[player] = {
		character = character,
		stageId = stageId,
		styleKey = styleKey,
		pieces = buildShell(character, bodyKey, look, styleItems),
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
