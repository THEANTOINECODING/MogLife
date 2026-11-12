-- Mannequins des tenues Robux du magasin de vêtements (D128, demande d'Antoine : donner envie).
-- Un mannequin = une pièce invisible taguée « PremiumDisplay » (tools/build_map.py), attributs SetId (StyleSets) et
-- Stage (corps porté). Il porte la VRAIE tenue, avec ses couleurs, ses pièces lumineuses, son aura et sa lumière,
-- sur un corps de vitrine (tête et mains blanches, le reste à la couleur de peau de la tenue).
-- Monté chez chaque joueur seulement quand il s'approche (une tenue fait environ 240 pièces) et retiré quand il
-- s'éloigne. S'approcher affiche le nom, le prix lu sur Roblox et une invite « View » qui ouvre la boutique Robux sur
-- cette tenue (StoreController). Purement visuel : rien ne s'achète ici.

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePasses = require(ReplicatedStorage.Shared.Config.GamePasses)
local StoreConfig = require(ReplicatedStorage.Shared.Config.Store)
local StylePieces = require(ReplicatedStorage.Shared.Config.StylePieces)
local StyleSets = require(ReplicatedStorage.Shared.Config.StyleSets)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Outfit = require(ReplicatedStorage.Shared.Outfit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local TAG = "PremiumDisplay"
local CONFIG = StoreConfig.Display
local GOLD = Color3.fromRGB(255, 210, 60)

local player = Players.LocalPlayer

local StoreController
local OutfitFxController
local SettingsController

type Display = { anchor: BasePart, setId: string, stage: string, model: Model?, price: TextLabel? }

local displays: { [BasePart]: Display } = {}
local folder: Folder? = nil
local owned: { [string]: boolean } = {}
local prices: { [number]: number } = {}
local asked: { [number]: boolean } = {}

local PremiumDisplayController = {}

local function holder(): Folder
	if not folder or not folder.Parent then
		local created = Instance.new("Folder")
		created.Name = "PremiumDisplays"
		created.Parent = workspace
		folder = created
	end
	return folder :: Folder
end

local function modelsReady(set): boolean
	if not Outfit.Available() then
		return false
	end
	for _, pieces in StylePieces do
		return pieces[set.top] ~= nil
	end
	return false
end

local function priceText(display: Display): string
	local set = StyleSets.ById[display.setId]
	if set and owned[set.top] and owned[set.bottom] then
		return Texts.Get("Store.Owned")
	end
	local passId = GamePasses.StyleSets[display.setId] or 0
	local price = prices[passId]
	return if price then Texts.Get("Display.Price", { price = price }) else ""
end

local function refreshPrice(display: Display)
	local label = display.price
	if label and label.Parent then
		label.Text = priceText(display)
		label.Visible = label.Text ~= ""
	end
end

local function askPrice(display: Display)
	local passId = GamePasses.StyleSets[display.setId] or 0
	if passId == 0 or asked[passId] then
		return
	end
	asked[passId] = true
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
		end)
		if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
			prices[passId] = info.PriceInRobux
			for _, other in displays do
				refreshPrice(other)
			end
		end
	end)
end

local function invisible(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function build(display: Display)
	local set = StyleSets.ById[display.setId]
	if not set or not set.robux or not modelsReady(set) then
		return
	end
	local model = Outfit.Build(display.stage, { set.top, set.bottom }, { mannequin = true, setSkin = true })
	local head = Outfit.HeadCenter(display.stage)
	if not model or not head then
		return
	end
	model.Name = display.setId
	local anchor = display.anchor
	local base = anchor.CFrame * CFrame.new(0, -anchor.Size.Y / 2, 0)
	model:PivotTo(base)

	-- Aura et lumière de la tenue : un volume invisible autour du corps, un point aux pieds
	local body = invisible(
		"Aura",
		Vector3.new(head.Y * 0.45, head.Y * 0.5, head.Y * 0.3),
		base * CFrame.new(0, head.Y * 0.6, 0),
		model
	)
	local feet = Instance.new("Attachment")
	feet.Name = "Feet"
	feet.Position = Vector3.new(0, -head.Y * 0.6 + 0.15, 0)
	feet.Parent = body
	if SettingsController.Get("OutfitFx") then
		OutfitFxController.DisplayAura(display.setId, body, feet, CONFIG.AuraRateScale)
	end
	local aura = StyleSets.Auras[display.setId]
	if aura then
		local light = Instance.new("PointLight")
		light.Color = aura.light.color
		light.Brightness = aura.light.brightness
		light.Range = CONFIG.LightRange
		light.Shadows = false
		light.Parent = body
	end

	-- Étiquette : nom de la tenue et prix
	local top = invisible("Label", Vector3.one, base * CFrame.new(0, head.Y + CONFIG.LabelHeight, 0), model)
	local board = Ui.create("BillboardGui", {
		Name = "Tag",
		Size = UDim2.fromScale(7, 2),
		MaxDistance = CONFIG.LabelDistance,
		LightInfluence = 0,
		Parent = top,
	})
	local name = Ui.label({
		Size = UDim2.fromScale(1, 0.55),
		TextColor3 = GOLD,
		Text = Texts.Get(`StyleSet.{display.setId}`),
		Parent = board,
	})
	Ui.outline(name, 2.5)
	local price = Ui.label({
		Position = UDim2.fromScale(0.15, 0.55),
		Size = UDim2.fromScale(0.7, 0.42),
		Parent = board,
	})
	Ui.outline(price, 2)
	display.price = price
	refreshPrice(display)
	askPrice(display)

	-- Invite : ouvre la boutique Robux sur cette tenue
	local spot = invisible("Prompt", Vector3.one, base * CFrame.new(0, head.Y * 0.6, 0), model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Display.View")
	prompt.ObjectText = Texts.Get(`StyleSet.{display.setId}`)
	prompt.MaxActivationDistance = CONFIG.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = spot
	prompt.Triggered:Connect(function()
		StoreController.Open("Outfits", display.setId)
	end)

	model.Parent = holder()
	display.model = model
end

local function drop(display: Display)
	if display.model then
		display.model:Destroy()
		display.model = nil
		display.price = nil
	end
end

local function add(anchor: Instance)
	if not anchor:IsA("BasePart") or displays[anchor] then
		return
	end
	local setId = anchor:GetAttribute("SetId")
	local stage = anchor:GetAttribute("Stage")
	if typeof(setId) == "string" and typeof(stage) == "string" then
		displays[anchor] = { anchor = anchor, setId = setId, stage = stage }
	end
end

local function remove(anchor: Instance)
	local display = displays[anchor :: BasePart]
	if display then
		drop(display)
		displays[anchor :: BasePart] = nil
	end
end

-- Nombre de mannequins montés (tests dans Studio)
function PremiumDisplayController.Count(): number
	local count = 0
	for _, display in displays do
		if display.model then
			count += 1
		end
	end
	return count
end

function PremiumDisplayController.Init(controllers)
	StoreController = controllers.StoreController
	OutfitFxController = controllers.OutfitFxController
	SettingsController = controllers.SettingsController
end

function PremiumDisplayController.Start()
	for _, anchor in CollectionService:GetTagged(TAG) do
		add(anchor)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	Remotes.StyleState.OnClientEvent:Connect(function(state)
		if typeof(state) == "table" then
			owned = state.owned or {}
			for _, display in displays do
				refreshPrice(display)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(CONFIG.CheckEvery)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") then
				continue
			end
			for anchor, display in displays do
				if not anchor.Parent then
					continue
				end
				local distance = (anchor.Position - root.Position).Magnitude
				if display.model and distance > CONFIG.DropDistance then
					drop(display)
				elseif not display.model and distance < CONFIG.BuildDistance then
					build(display)
					task.wait() -- un mannequin par image : pas d'à-coup à l'approche du magasin
				end
			end
		end
	end)
end

return PremiumDisplayController
