-- Boutique de style : achat (Cash), équipement par catégorie, visuels sur le personnage.
-- Purement esthétique. Visuels PROVISOIRES (blocs soudés à l'avatar) en attendant le personnage du jeu.
-- Les miroirs (tag "Mirror") des boutiques reçoivent un prompt ; c'est le client qui ouvre la boutique quand il est
-- déclenché. Attributs du miroir : Store (« Clothes », « Barber ») et Categories (« Top,Accessory », « Hair »).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StyleItems = require(ReplicatedStorage.Shared.Config.StyleItems)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MIRROR_TAG = "Mirror"
local VISUALS_NAME = "StyleVisuals"
local CATEGORIES = { Hair = true, Top = true, Accessory = true }

local DataService
local StatsService

local StyleService = {}

local function sendState(player: Player)
	local data = DataService.Get(player)
	if data then
		Remotes.StyleState:FireClient(player, { owned = data.StyleOwned, equipped = data.StyleEquipped })
	end
end

-- Cache (ou réaffiche) les cheveux et chapeaux de l'avatar Roblox quand une coupe du jeu est portée
local function setAvatarHairHidden(character: Model, hidden: boolean)
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") then
			local kind = accessory.AccessoryType
			if kind == Enum.AccessoryType.Hair or kind == Enum.AccessoryType.Hat then
				local handle = accessory:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") then
					handle.Transparency = if hidden then 1 else 0
				end
			end
		end
	end
end

local function buildVisuals(player: Player)
	local data = DataService.Get(player)
	local character = player.Character
	if not data or not character then
		return
	end
	local old = character:FindFirstChild(VISUALS_NAME)
	if old then
		old:Destroy()
	end

	local folder = Instance.new("Model")
	folder.Name = VISUALS_NAME
	for category, itemId in data.StyleEquipped do
		local item = StyleItems[itemId]
		if not item or item.category ~= category then
			continue
		end
		for index, piece in item.pieces do
			local attach = character:FindFirstChild(piece.attach)
			if not attach or not attach:IsA("BasePart") then
				continue
			end
			local part = Instance.new("Part")
			part.Name = `{itemId}_{index}`
			part.Size = attach.Size * piece.size
			part.CFrame = attach.CFrame * CFrame.new(attach.Size * piece.offset)
			part.Color = piece.color
			part.Material = piece.material or Enum.Material.SmoothPlastic
			part.Shape = piece.shape or Enum.PartType.Block
			part.Transparency = piece.transparency or 0
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.CastShadow = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = attach
			weld.Part1 = part
			weld.Parent = part
			part.Parent = folder
		end
	end
	folder.Parent = character
	setAvatarHairHidden(character, data.StyleEquipped.Hair ~= nil)
end

-- Reconstruit les visuels quand la taille du corps change (le Mog élargit l'avatar), avec un délai
local function watchBodyScale(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	local pending = false
	for _, name in { "BodyWidthScale", "BodyDepthScale" } do
		local value = humanoid:FindFirstChild(name)
		if value and value:IsA("NumberValue") then
			value.Changed:Connect(function()
				if pending then
					return
				end
				pending = true
				task.delay(0.5, function()
					pending = false
					if player.Character == character then
						buildVisuals(player)
					end
				end)
			end)
		end
	end
end

local function onBuy(player: Player, itemId: unknown)
	if typeof(itemId) ~= "string" then
		return
	end
	local item = StyleItems[itemId]
	local data = DataService.Get(player)
	if not item or not data or not item.price or data.StyleOwned[itemId] then
		return
	end
	if data.Cash < item.price then
		Remotes.Notify:FireClient(player, { key = "Shop.NotEnough" })
		return
	end

	StatsService.Add(player, "Cash", -item.price)
	data.StyleOwned[itemId] = true
	data.StyleEquipped[item.category] = itemId
	buildVisuals(player)
	sendState(player)
	Remotes.Notify:FireClient(player, { key = "Shop.Bought", args = { item = { key = `Style.{itemId}` } } })
end

local function onEquip(player: Player, category: unknown, itemId: unknown)
	if typeof(category) ~= "string" or not CATEGORIES[category] then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	if itemId == nil then
		data.StyleEquipped[category] = nil
	elseif typeof(itemId) == "string" then
		local item = StyleItems[itemId]
		if not item or item.category ~= category or not data.StyleOwned[itemId] then
			return
		end
		data.StyleEquipped[category] = itemId
	else
		return
	end
	buildVisuals(player)
	sendState(player)
end

local function setupMirror(mirror: Instance)
	if not mirror:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Shop.Prompt")
	local store = mirror:GetAttribute("Store")
	prompt.ObjectText = Texts.Get(if typeof(store) == "string" then `Shop.Store.{store}` else "Shop.Mirror")
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = mirror
end

local function onPlayerLoaded(player: Player)
	local function onCharacter(character: Model)
		character:WaitForChild("UpperTorso", 10)
		buildVisuals(player)
		task.spawn(watchBodyScale, player, character)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	sendState(player)
end

-- Rafraîchit visuels et état (après une modification directe des données, ex. récompense de boss)
function StyleService.Refresh(player: Player)
	buildVisuals(player)
	sendState(player)
end

function StyleService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
end

function StyleService.Start()
	for _, mirror in CollectionService:GetTagged(MIRROR_TAG) do
		setupMirror(mirror)
	end
	CollectionService:GetInstanceAddedSignal(MIRROR_TAG):Connect(setupMirror)

	DataService.PlayerLoaded:Connect(onPlayerLoaded)
	Remotes.BuyStyle.OnServerEvent:Connect(onBuy)
	Remotes.EquipStyle.OnServerEvent:Connect(onEquip)
	Remotes.RequestStats.OnServerEvent:Connect(sendState)
end

return StyleService
