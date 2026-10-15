-- Corps du personnage du joueur selon son stade : proportions du squelette R15 + coque Blender.
-- Les parties Roblox d'origine deviennent invisibles ; chaque pièce de la coque est soudée à sa partie,
-- donc les animations Roblox standard fonctionnent telles quelles.
-- Si le modèle d'un stade n'est pas encore importé, l'apparence provisoire de StatsService s'applique.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BodyPieces = require(ReplicatedStorage.Shared.Config.BodyPieces)
local Bodies = require(ReplicatedStorage.Shared.Config.Bodies)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)

local SHELL_NAME = "BodyShell"

local DataService

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

local function buildShell(character: Model, stageId: string)
	local old = character:FindFirstChild(SHELL_NAME)
	if old then
		old:Destroy()
	end
	local folder = ReplicatedStorage:FindFirstChild("Bodies") :: Folder
	local shell = Instance.new("Model")
	shell.Name = SHELL_NAME
	-- Chaque pièce est soudée à sa partie R15, à son décalage de repos (BodyPieces) : elle suit les animations
	for piece, offset in BodyPieces[stageId] or {} do
		local template = folder:FindFirstChild(`{stageId}_{piece}`)
		local target = character:FindFirstChild(string.split(piece, "_")[1])
		if not template or not template:IsA("BasePart") or not target or not target:IsA("BasePart") then
			continue
		end
		local clone = template:Clone()
		clone.Anchored = false
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.Massless = true
		clone.CFrame = target.CFrame * CFrame.new(offset)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = target
		weld.Part1 = clone
		weld.Parent = clone
		clone.Parent = shell
	end
	shell.Parent = character
end

-- Applique (ou retire) le corps du stade sur le personnage actuel du joueur
function BodyService.Refresh(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local body, stageId = BodyService.BodyFor(player)
	if not body or not stageId then
		local old = character:FindFirstChild(SHELL_NAME)
		if old then
			old:Destroy()
		end
		return
	end
	applyProportions(humanoid, body)
	hideOriginalBody(character)
	buildShell(character, stageId)
end

function BodyService.Init(services)
	DataService = services.DataService
end

function BodyService.Start()
	DataService.PlayerLoaded:Connect(function(player)
		player.CharacterAppearanceLoaded:Connect(function()
			BodyService.Refresh(player)
		end)
		if player.Character and player:HasAppearanceLoaded() then
			task.spawn(BodyService.Refresh, player)
		end
	end)
end

return BodyService
