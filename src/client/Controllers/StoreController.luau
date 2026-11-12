-- Boutique Robux (D122, refaite en D128 : une seule fenêtre à onglets, ouverte par la case « Shop » du menu) :
-- - Tenues : les tenues Robux (Game Pass, Config/GamePasses.luau) avec un grand aperçu 3D qui tourne, leur aura
--   (PreviewFx) et ce qu'elles donnent ; une tenue possédée se porte d'ici ;
-- - Boosts : boosts de Mog (Products.Boost), avec le temps qui reste ;
-- - Cash : coffres de Cash (Products.Cash, montant fixe et affiché : jamais de contenu au hasard) ;
-- - Mog : packs de Mog (Products.Mog, grandissent avec le stade ; le serveur recalcule au moment de l'achat).
-- Le « + » des compteurs Mog et Cash ouvre le bon onglet ; les mannequins du magasin de vêtements ouvrent leur tenue.
-- Après une défaite contre le boss de son stade, une carte propose de le passer en Robux (choix d'Antoine).
-- Un produit dont l'identifiant vaut 0 est caché dans le jeu ; dans Studio seulement, il s'affiche grisé
-- (« Not on sale yet ») pour pouvoir régler la boutique avant de créer les produits.
-- Le client ne décide de rien : le serveur (PurchaseService, StyleService) n'accorde que ce que Roblox confirme.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Format = require(ReplicatedStorage.Shared.Format)
local GamePasses = require(ReplicatedStorage.Shared.Config.GamePasses)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local StoreConfig = require(ReplicatedStorage.Shared.Config.Store)
local StylePieces = require(ReplicatedStorage.Shared.Config.StylePieces)
local StyleSets = require(ReplicatedStorage.Shared.Config.StyleSets)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Look = require(ReplicatedStorage.Shared.Look)
local Outfit = require(ReplicatedStorage.Shared.Outfit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Preview3D = require(script.Parent.Parent.Preview3D)
local PreviewFx = require(script.Parent.Parent.PreviewFx)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer
local STUDIO = RunService:IsStudio()
local GOLD = Color3.fromRGB(255, 210, 60)
local GREEN = Color3.fromRGB(60, 190, 90)
local GREY = Color3.fromRGB(96, 92, 110)
local CARD = Color3.fromRGB(35, 28, 55)
local TABS = StoreConfig.Tabs

local UIController
local MinigameController
local MenuController

local StoreController = {}

local gui: ScreenGui
local panel: Frame
local content: Frame
local tabBar: Frame
local tabButtons: { [string]: TextButton } = {}
local viewport: ViewportFrame
local world: WorldModel
local previewFx
local previewModel: Model? = nil
local previewKey = ""
local spin = 0
local portrait = false
local currentTab = TABS[1].id
local selectedSet: string? = nil
local boostStatus: TextLabel? = nil -- ligne « x2 Mog : 12:34 left » de l'onglet Boosts

local offerCard: Frame
local offerText: TextLabel
local offerButton: TextButton
local offerToken = 0
local currentOffer: { [string]: any }? = nil

local stage = 1
local owned: { [string]: boolean } = {}
local equipped: { [string]: string } = {}
local look: Look.LookData? = nil
local paid = { multiplier = 1, endsAt = 0 } -- boost Robux : fin estimée sur l'horloge locale (os.clock)

local render

-- ------------------------------------------------------------------ prix (lus sur Roblox, une fois)

local prices: { [string]: number } = {}
local asked: { [string]: boolean } = {}
local function priceOf(id: number, infoType: Enum.InfoType, fallback: number?): number?
	local key = `{infoType.Name}:{id}`
	if id ~= 0 and not asked[key] then
		asked[key] = true
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, infoType)
			end)
			if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
				prices[key] = info.PriceInRobux
				if render and panel.Visible then
					render()
				end
			end
		end)
	end
	return prices[key] or fallback
end

-- ------------------------------------------------------------------ ce qui est en vente

-- Un produit s'affiche si son identifiant existe ; dans Studio, toujours (grisé tant qu'il vaut 0)
local function listed(id: number): boolean
	return id ~= 0 or STUDIO
end

local function passOf(set): number
	return GamePasses.StyleSets[set.id] or 0
end

local function setOwned(set): boolean
	return owned[set.top] == true and owned[set.bottom] == true
end

local function modelsReady(set): boolean
	for _, pieces in StylePieces do
		return pieces[set.top] ~= nil
	end
	return false
end

local function outfitSets(): { any }
	local sets = {}
	for _, set in StyleSets.List do
		if set.robux and modelsReady(set) and (setOwned(set) or listed(passOf(set))) then
			table.insert(sets, set)
		end
	end
	return sets
end

local function packsOf(kind: string): { any }
	local packs = {}
	for _, pack in (Products :: any)[kind] do
		if listed(pack.productId) then
			table.insert(packs, pack)
		end
	end
	return packs
end

local function tabHasItems(id: string): boolean
	if id == "Outfits" then
		return #outfitSets() > 0
	end
	return #packsOf(if id == "Boosts" then "Boost" else id) > 0
end

local function firstTab(): string?
	for _, tab in TABS do
		if tabHasItems(tab.id) then
			return tab.id
		end
	end
	return nil
end

local function clock(seconds: number): string
	local total = math.max(math.floor(seconds), 0)
	if total >= 3600 then
		return string.format("%d:%02d:%02d", total // 3600, total % 3600 // 60, total % 60)
	end
	return string.format("%d:%02d", total // 60, total % 60)
end

-- ------------------------------------------------------------------ pièces communes

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child ~= viewport and not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

-- Bouton d'achat : vert avec le prix ; gris et inactif si le produit n'existe pas encore (Studio)
local function buyButton(props: { [string]: any }, id: number, price: number?, onBuy: () -> ()): TextButton
	local onSale = id ~= 0
	props.BackgroundColor3 = if onSale then GREEN else GREY
	props.Text = if not onSale
		then Texts.Get("Store.NotOnSale")
		elseif price then Texts.Get("Shop.BuyRobux", { price = price })
		else Texts.Get("Shop.BuyRobuxNoPrice")
	local button = Ui.button(props)
	Ui.stroke(Ui.Ink, 2).Parent = button
	if onSale then
		Ui.juice(button)
		button.Activated:Connect(onBuy)
	else
		button.AutoButtonColor = false
	end
	return button
end

-- Coffre de Cash en 3D (trois tailles : bois cerclé de fer, bois cerclé d'or, tout en or) pour la vignette du pack
local function buildChest(tier: number): Model
	local spec = StoreConfig.Chests[math.clamp(tier, 1, #StoreConfig.Chests)]
	local model = Instance.new("Model")
	local function part(size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
		local piece = Instance.new("Part")
		piece.Size = size
		piece.CFrame = cframe
		piece.Color = color
		piece.Material = material or Enum.Material.SmoothPlastic
		piece.Shape = shape or Enum.PartType.Block
		piece.Anchored = true
		piece.Parent = model
		return piece
	end
	local w, h, d = 2.6 * spec.scale, 1.3 * spec.scale, 1.7 * spec.scale
	part(Vector3.new(w, h, d), CFrame.new(0, h / 2, 0), spec.body, Enum.Material.Wood)
	-- Couvercle bombé : un cylindre couché, dont la moitié basse reste dans la caisse
	part(Vector3.new(w, d, d), CFrame.new(0, h, 0), spec.body, Enum.Material.Wood, Enum.PartType.Cylinder)
	for _, x in { -w * 0.32, w * 0.32 } do
		part(
			Vector3.new(0.26 * spec.scale, h + 0.04, d + 0.08),
			CFrame.new(x, h / 2, 0),
			spec.band,
			Enum.Material.Metal
		)
		part(
			Vector3.new(0.26 * spec.scale, d + 0.08, d + 0.08),
			CFrame.new(x, h, 0),
			spec.band,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end
	part(
		Vector3.new(0.5, 0.6, 0.2) * spec.scale,
		CFrame.new(0, h * 0.95, -d / 2 - 0.06),
		spec.band,
		Enum.Material.Metal
	)
	-- Liasses et pièces posées devant, de plus en plus nombreuses
	local rng = Random.new(tier * 31)
	for index = 1, spec.bills do
		local x = (index - (spec.bills + 1) / 2) * 0.62
		part(
			Vector3.new(0.5, 0.16, 0.9),
			CFrame.new(x, 0.08 + (index % 2) * 0.16, -d / 2 - 0.75) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
			Color3.fromRGB(70, 185, 95)
		)
	end
	for _ = 1, spec.coins do
		local coin = part(
			Vector3.new(0.09, 0.42, 0.42),
			CFrame.new(rng:NextNumber(-w * 0.55, w * 0.55), 0.05, -d / 2 - rng:NextNumber(0.3, 1.3))
				* CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(255, 205, 60),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		coin.Reflectance = 0.2
	end
	return model
end

-- Carte d'un pack : vignette (3D ou icône), titre, sous-titre, bouton d'achat. `wide` : en ligne (téléphone debout)
type CardSpec = {
	order: number,
	accent: Color3,
	icon: string?,
	chest: number?,
	title: string,
	subtitle: string?,
	productId: number,
	robux: number,
}
local function packCard(parent: Instance, spec: CardSpec, wide: boolean, count: number)
	local card = Ui.create("Frame", {
		Name = "Pack" .. spec.order,
		LayoutOrder = spec.order,
		Size = if wide then UDim2.new(1, 0, 0, 104) else UDim2.new(1 / count, -8, 1, 0),
		BackgroundColor3 = CARD,
		Parent = parent,
	}, { Ui.corner(UDim.new(0, 14)), Ui.stroke(spec.accent, 2, 0.2) })
	Ui.create("UISizeConstraint", { MaxSize = Vector2.new(if wide then math.huge else 230, math.huge), Parent = card })
	local art = if wide
		then { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(88, 88) }
		else {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.new(1, -20, 0.42, 0),
		}
	if spec.chest then
		local view = Preview3D.new(card, art)
		view.frame.BackgroundTransparency = 1
		local stroke = view.frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke:Destroy()
		end
		local chest = buildChest(spec.chest)
		Preview3D.Show(view, chest)
		chest:Destroy()
	else
		art.Text = spec.icon or ""
		art.TextStrokeTransparency = 1
		art.Parent = card
		Ui.label(art)
	end
	local title = Ui.label({
		Position = if wide then UDim2.fromOffset(104, 10) else UDim2.fromScale(0.05, 0.5),
		Size = if wide then UDim2.new(1, -262, 0, 40) else UDim2.fromScale(0.9, 0.16),
		TextXAlignment = if wide then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		TextColor3 = spec.accent,
		Text = spec.title,
		Parent = card,
	})
	Ui.outline(title, 2)
	if spec.subtitle then
		Ui.label({
			Position = if wide then UDim2.fromOffset(104, 54) else UDim2.fromScale(0.05, 0.66),
			Size = if wide then UDim2.new(1, -262, 0, 26) else UDim2.fromScale(0.9, 0.09),
			TextXAlignment = if wide then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			TextColor3 = Color3.fromRGB(215, 210, 230),
			Font = Enum.Font.GothamMedium,
			Text = spec.subtitle,
			Parent = card,
		})
	end
	buyButton(
		if wide
			then {
				Name = "Buy",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(142, 64),
				Parent = card,
			}
			else {
				Name = "Buy",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -16, 0.2, 0),
				Parent = card,
			},
		spec.productId,
		priceOf(spec.productId, Enum.InfoType.Product, spec.robux),
		function()
			MarketplaceService:PromptProductPurchase(player, spec.productId)
		end
	)
end

-- Rangée de cartes (paysage) ou liste qui défile (téléphone debout), sous un titre d'une ligne ; renvoie la zone
-- libre sous les cartes (hauteur `footer`) pour une note
local function packArea(titleKey: string, footer: number): (Instance, Frame?)
	Ui.label({
		Name = "Heading",
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = Texts.Get(titleKey),
		Parent = content,
	})
	local holder
	if portrait then
		holder = Ui.create("ScrollingFrame", {
			Name = "Cards",
			Position = UDim2.fromOffset(0, 38),
			Size = UDim2.new(1, 0, 1, -38 - footer),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Parent = content,
		}, {
			Ui.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			Ui.create("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2) }),
		})
	else
		holder = Ui.create("Frame", {
			Name = "Cards",
			Position = UDim2.fromOffset(0, 38),
			Size = UDim2.new(1, 0, 1, -38 - footer),
			BackgroundTransparency = 1,
			Parent = content,
		}, {
			Ui.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end
	local note = if footer > 0
		then Ui.create("Frame", {
			Name = "Footer",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, footer - 6),
			BackgroundTransparency = 1,
			Parent = content,
		})
		else nil
	return holder, note
end

-- ------------------------------------------------------------------ onglets Cash, Mog, Boosts

local function renderPacks(kind: string)
	local packs = packsOf(kind)
	local holder = packArea(`Store.{kind}Title`, 0)
	local accent = if kind == "Cash" then Color3.fromRGB(140, 255, 140) else GOLD
	for order, pack in packs do
		local value = if kind == "Cash" then pack.amount or 0 else Products.MogAmount(pack, stage)
		packCard(holder, {
			order = order,
			accent = accent,
			icon = pack.icon,
			chest = if kind == "Cash" then order else nil,
			title = Texts.Get(`Store.{kind}Amount`, { amount = Format.Short(value) }),
			subtitle = Texts.Get(`Store.{kind}Pack{math.min(order, 3)}`),
			productId = pack.productId,
			robux = pack.robux,
		}, portrait, #packs)
	end
end

local function updateBoostStatus()
	local label = boostStatus
	if not label or not label.Parent then
		return
	end
	local left = paid.endsAt - os.clock()
	label.Text = if left > 0
		then Texts.Get("Store.BoostActive", { multiplier = paid.multiplier, time = clock(left) })
		else Texts.Get("Store.BoostNote")
	label.TextColor3 = if left > 0 then GOLD else Color3.fromRGB(215, 210, 230)
end

local function renderBoosts()
	local packs = packsOf("Boost")
	local holder, footer = packArea("Store.BoostTitle", 44)
	for order, pack in packs do
		packCard(holder, {
			order = order,
			accent = GOLD,
			icon = pack.icon,
			title = Texts.Get("Store.BoostName", { multiplier = pack.multiplier }),
			subtitle = Texts.Get("Store.BoostTime", { minutes = math.floor(pack.duration / 60 + 0.5) }),
			productId = pack.productId,
			robux = pack.robux,
		}, portrait, #packs)
	end
	boostStatus = Ui.label({
		Name = "Status",
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamMedium,
		Parent = footer,
	})
	updateBoostStatus()
end

-- ------------------------------------------------------------------ onglet Tenues

local function refreshPreview(set)
	local stageInfo = Stages.List[stage]
	local outfit = table.clone(equipped)
	outfit.Top = set.top
	outfit.Bottom = set.bottom
	local items = {}
	for _, itemId in outfit do
		table.insert(items, itemId)
	end
	table.sort(items)
	local key = `{stageInfo and stageInfo.id}:{table.concat(items, ",")}:{look and Look.Key(look) or ""}`
	if key == previewKey and previewModel then
		return
	end
	previewKey = key
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
	local model = stageInfo and Outfit.Build(stageInfo.id, items, { look = look })
	if not model then
		previewFx:Set({}, nil)
		return
	end
	model.Parent = world
	previewModel = model
	previewFx:Set(items, model)
	local head = Outfit.HeadCenter(stageInfo.id, look) :: Vector3
	local center = head.Y * 0.52
	local distance = head.Y * 1.9 + 2.5
	local camera = viewport.CurrentCamera :: Camera
	camera.CFrame = CFrame.lookAt(Vector3.new(0, center + 0.4, -distance), Vector3.new(0, center, 0))
end

local function renderOutfits()
	local sets = outfitSets()
	local chosen = selectedSet and StyleSets.ById[selectedSet]
	if not chosen or not table.find(sets, chosen) then
		chosen = sets[1]
	end
	if not chosen then
		return
	end
	selectedSet = chosen.id
	viewport.Visible = true
	-- Zones : aperçu à gauche et le reste à droite (paysage) ; aperçu en haut (téléphone debout)
	local side = if portrait then UDim2.fromOffset(0, 236) else UDim2.new(0.42, 6, 0, 0)
	local sideSize = if portrait then UDim2.new(1, 0, 1, -236) else UDim2.new(0.58, -6, 1, 0)
	viewport.Position = UDim2.new()
	viewport.Size = if portrait then UDim2.new(1, 0, 0, 228) else UDim2.new(0.42, -6, 1, 0)
	refreshPreview(chosen)

	local right = Ui.create("Frame", {
		Name = "Details",
		Position = side,
		Size = sideSize,
		BackgroundTransparency = 1,
		Parent = content,
	})
	local name = Ui.label({
		Name = "SetName",
		Size = UDim2.new(1, 0, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		Text = Texts.Get(`StyleSet.{chosen.id}`),
		Parent = right,
	})
	Ui.outline(name, 2)
	Ui.label({
		Name = "Perks",
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 38),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(215, 210, 230),
		Text = Texts.Get("Store.OutfitPerks", { bonus = math.floor(Balance.Drip.RobuxBossBonus * 100 + 0.5) }),
		Parent = right,
	})
	-- Liste des tenues : deux colonnes (paysage) ou une bande qui défile de côté (téléphone debout)
	local list = Ui.create("ScrollingFrame", {
		Name = "Sets",
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 1, -82 - 70),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollingDirection = if portrait then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = if portrait then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = right,
	}, {
		if portrait
			then Ui.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			else Ui.create("UIGridLayout", {
				CellSize = UDim2.new(0.5, -8, 0, 56),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		Ui.create("UIPadding", {
			PaddingTop = UDim.new(0, 3),
			PaddingLeft = UDim.new(0, 3),
			PaddingRight = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 3),
		}),
	})
	for order, set in sets do
		local isChosen = set == chosen
		local card = Ui.create("TextButton", {
			Name = set.id,
			LayoutOrder = order,
			Size = UDim2.fromOffset(150, 56),
			BackgroundColor3 = if isChosen then Ui.shade(CARD, 1.25) else CARD,
			AutoButtonColor = false,
			Text = "",
			Parent = list,
		}, {
			Ui.corner(UDim.new(0, 12)),
			Ui.stroke(if isChosen then GOLD else set.color, if isChosen then 3 else 2, if isChosen then 0 else 0.35),
		})
		Ui.create("Frame", {
			Name = "Swatch",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = set.color,
			Parent = card,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Ui.Ink, 2) })
		Ui.label({
			Position = UDim2.fromOffset(42, 6),
			Size = UDim2.new(1, -50, 0, if setOwned(set) then 26 else 44),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = Texts.Get(`StyleSet.{set.id}`),
			Parent = card,
		})
		if setOwned(set) then
			Ui.label({
				Position = UDim2.fromOffset(42, 32),
				Size = UDim2.new(1, -50, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Enum.Font.GothamMedium,
				TextColor3 = Color3.fromRGB(140, 255, 140),
				Text = Texts.Get("Store.Owned"),
				Parent = card,
			})
		end
		Ui.juice(card)
		card.Activated:Connect(function()
			selectedSet = set.id
			render()
		end)
	end
	-- Bouton du bas : acheter, porter, ou déjà portée
	local action = {
		Name = "Action",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 62),
		Parent = right,
	}
	if setOwned(chosen) then
		local wearing = equipped.Top == chosen.top and equipped.Bottom == chosen.bottom
		action.BackgroundColor3 = if wearing then GREY else Color3.fromRGB(45, 150, 235)
		action.Text = Texts.Get(if wearing then "Store.Wearing" else "Store.Wear");
		(action :: any).AutoButtonColor = not wearing
		local button = Ui.button(action)
		Ui.stroke(Ui.Ink, 2).Parent = button
		if not wearing then
			Ui.juice(button)
			button.Activated:Connect(function()
				Remotes.EquipStyleSet:FireServer(chosen.id)
			end)
		end
	else
		local passId = passOf(chosen)
		buyButton(action, passId, priceOf(passId, Enum.InfoType.GamePass, nil), function()
			MarketplaceService:PromptGamePassPurchase(player, passId)
		end)
	end
end

-- ------------------------------------------------------------------ fenêtre

local function styleTab(button: TextButton, on: boolean, color: Color3)
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		local base = if on then color else Ui.shade(color, 0.45)
		gradient.Color = ColorSequence.new(Ui.shade(base, 1.25), base)
	end
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if on then Color3.new(1, 1, 1) else Ui.Ink
	end
end

render = function()
	if not panel.Visible then
		return
	end
	if not tabHasItems(currentTab) then
		local first = firstTab()
		if not first then
			return
		end
		currentTab = first
	end
	local shown = 0
	for _, tab in TABS do
		local button = tabButtons[tab.id]
		button.Visible = tabHasItems(tab.id)
		if button.Visible then
			shown += 1
		end
		styleTab(button, tab.id == currentTab, tab.color)
	end
	for _, tab in TABS do
		local button = tabButtons[tab.id]
		button.Size = if portrait then UDim2.new(1 / math.max(shown, 1), -6, 1, 0) else UDim2.new(1, 0, 0, 62)
	end
	clear(content)
	boostStatus = nil
	viewport.Visible = false
	if currentTab == "Outfits" then
		renderOutfits()
	elseif currentTab == "Boosts" then
		renderBoosts()
	else
		renderPacks(currentTab)
	end
end

local function layout()
	portrait = Ui.isPhonePortrait()
	panel.Size = if portrait then UDim2.fromOffset(420, 700) else UDim2.fromOffset(800, 452)
	local list = tabBar:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	if portrait then
		tabBar.Position = UDim2.fromOffset(14, 60)
		tabBar.Size = UDim2.new(1, -28, 0, 54)
		list.FillDirection = Enum.FillDirection.Horizontal
		content.Position = UDim2.fromOffset(14, 124)
		content.Size = UDim2.new(1, -28, 1, -138)
	else
		tabBar.Position = UDim2.fromOffset(14, 64)
		tabBar.Size = UDim2.new(0, 150, 1, -78)
		list.FillDirection = Enum.FillDirection.Vertical
		content.Position = UDim2.fromOffset(176, 64)
		content.Size = UDim2.new(1, -190, 1, -78)
	end
	render()
end

local function close()
	if not panel.Visible then
		return
	end
	panel.Visible = false
	UIController.SetStatsHidden(false, "Store")
end

local function open(tab: string?, setId: string?)
	if MinigameController.IsGameplayLocked() then
		return
	end
	local target = if tab and tabHasItems(tab) then tab else firstTab()
	if not target then
		return
	end
	currentTab = target
	if setId and StyleSets.ById[setId] then
		selectedSet = setId
	end
	panel.Visible = true
	UIController.SetStatsHidden(true, "Store")
	layout()
end

local function buildGui()
	gui = Ui.create("ScreenGui", { Name = "Store", ResetOnSpawn = false, DisplayOrder = 12 })
	panel = Ui.panel({
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(800, 452),
		Visible = false,
		Parent = gui,
	})
	Ui.fitToScreen(panel, 12)
	local title = Ui.label({
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -90, 0, 42),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		Text = Texts.Get("Store.Title"),
		Parent = panel,
	})
	Ui.outline(title, 2.5)
	local closeButton = Ui.closeButton({ Text = Texts.Get("Shop.Close"), Parent = panel })
	Ui.onBack(closeButton, close)
	Ui.markModal(panel)

	tabBar = Ui.create("Frame", { Name = "Tabs", BackgroundTransparency = 1, Parent = panel }, {
		Ui.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for order, tab in TABS do
		local button = Ui.create("TextButton", {
			Name = tab.id,
			LayoutOrder = order,
			BackgroundColor3 = Color3.new(1, 1, 1),
			AutoButtonColor = false,
			Text = "",
			Parent = tabBar,
		}, { Ui.corner(UDim.new(0, 14)), Ui.gradient(tab.color, tab.color), Ui.stroke(Ui.Ink, 2.5) })
		Ui.label({
			Name = "Icon",
			Position = UDim2.fromScale(0.04, 0.12),
			Size = UDim2.fromScale(0.3, 0.76),
			Text = Texts.Get(`Store.Icon{tab.id}`),
			TextStrokeTransparency = 1,
			Parent = button,
		})
		local caption = Ui.label({
			Name = "Caption",
			Position = UDim2.fromScale(0.36, 0.2),
			Size = UDim2.fromScale(0.6, 0.6),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = Texts.Get(`Store.Tab{tab.id}`),
			Parent = button,
		})
		Ui.outline(caption, 2)
		Ui.juice(button)
		button.Activated:Connect(function()
			currentTab = tab.id
			render()
		end)
		tabButtons[tab.id] = button
	end
	content = Ui.create("Frame", { Name = "Content", BackgroundTransparency = 1, Parent = panel })

	-- Aperçu 3D des tenues (gardé d'un rendu à l'autre : seul le modèle change)
	viewport = Ui.create("ViewportFrame", {
		Name = "Preview",
		BackgroundColor3 = Color3.fromRGB(30, 26, 44),
		BackgroundTransparency = 0.1,
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(-0.5, -1, 0.6),
		Visible = false,
		Parent = content,
	}, { Ui.corner(UDim.new(0, 14)), Ui.stroke(GOLD, 2, 0.4) })
	world = Ui.create("WorldModel", { Parent = viewport })
	viewport.CurrentCamera = Ui.create("Camera", { FieldOfView = 35, Parent = viewport })
	previewFx = PreviewFx.new(world, viewport.CurrentCamera :: Camera)

	-- Carte « passer ce boss » (après une défaite)
	offerCard = Ui.panel({
		Name = "BossWin",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(420, 150),
		Visible = false,
		Parent = gui,
	})
	offerText = Ui.label({
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 56),
		Parent = offerCard,
	})
	offerButton = Ui.button({
		Name = "Buy",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -12),
		Size = UDim2.new(0.6, -20, 0, 60),
		BackgroundColor3 = GREEN,
		Parent = offerCard,
	})
	local later = Ui.button({
		Name = "Later",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -12),
		Size = UDim2.new(0.4, -14, 0, 60),
		BackgroundColor3 = Color3.fromRGB(90, 90, 90),
		Text = Texts.Get("Store.NoThanks"),
		Parent = offerCard,
	})
	offerButton.Activated:Connect(function()
		local offer = currentOffer
		if offer then
			Remotes.BuyBossWin:FireServer(offer.bossId)
		end
	end)
	Ui.onBack(later, function()
		offerToken += 1
		currentOffer = nil
		offerCard.Visible = false
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	Ui.watchViewport(function()
		if panel.Visible and Ui.isPhonePortrait() ~= portrait then
			task.defer(layout)
		end
	end)
end

local function showOffer(offer)
	if typeof(offer) ~= "table" or typeof(offer.bossId) ~= "string" or typeof(offer.productId) ~= "number" then
		return
	end
	offerToken += 1
	local token = offerToken
	task.delay(tonumber(offer.delay) or 0, function()
		if token ~= offerToken then
			return
		end
		currentOffer = offer
		local function setText()
			if token == offerToken then
				offerButton.Text = Texts.Get("Shop.BuyRobux", {
					price = priceOf(offer.productId, Enum.InfoType.Product, tonumber(offer.robux) or 0),
				})
			end
		end
		offerText.Text = Texts.Get("Store.BossWin", { boss = Texts.Get(`Boss.{offer.bossId}`) })
		setText()
		-- Le prix réel arrive un peu après : on le relit
		task.delay(1.5, setText)
		offerCard.Visible = true
		local scale = offerCard:FindFirstChildOfClass("UIScale") or Ui.create("UIScale", { Parent = offerCard })
		scale.Scale = 0.6
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		-- L'offre disparaît d'elle-même à la fin de sa fenêtre (le serveur la refuse ensuite)
		task.delay(tonumber(offer.window) or 60, function()
			if token == offerToken then
				currentOffer = nil
				offerCard.Visible = false
			end
		end)
	end)
end

-- Case « Shop » du menu (MenuController) : seulement s'il y a quelque chose à vendre (ou dans Studio)
function StoreController.HasProducts(): boolean
	return firstTab() ~= nil
end

-- `tab` : "Outfits", "Boosts", "Cash" ou "Mog" (sinon le premier onglet) ; `setId` : tenue à montrer
function StoreController.Open(tab: string?, setId: string?)
	open(tab, setId)
end

-- Temps restant du boost Robux (secondes) et son multiplicateur, pour le badge du HUD (BoostController)
function StoreController.PaidBoost(): (number, number)
	return math.max(paid.endsAt - os.clock(), 0), paid.multiplier
end

function StoreController.Init(controllers)
	UIController = controllers.UIController
	MinigameController = controllers.MinigameController
	MenuController = controllers.MenuController
end

function StoreController.Start()
	buildGui()
	if #packsOf("Mog") > 0 then
		UIController.AttachCounterButton("Mog", Color3.fromRGB(230, 160, 30), function()
			open("Mog")
		end)
	end
	if #packsOf("Cash") > 0 then
		UIController.AttachCounterButton("Cash", GREEN, function()
			open("Cash")
		end)
	end
	Remotes.StatsChanged.OnClientEvent:Connect(function(stats)
		if typeof(stats) == "table" and typeof(stats.Stage) == "number" and stats.Stage ~= stage then
			stage = stats.Stage
			previewKey = ""
			render()
		end
	end)
	Remotes.StyleState.OnClientEvent:Connect(function(state)
		if typeof(state) ~= "table" then
			return
		end
		local had = firstTab() ~= nil
		owned = state.owned or {}
		equipped = state.equipped or {}
		look = state.look
		previewKey = ""
		render()
		if had ~= (firstTab() ~= nil) and MenuController then
			MenuController.Refresh()
		end
	end)
	Remotes.BoostState.OnClientEvent:Connect(function(state)
		local info = typeof(state) == "table" and state.paid
		if typeof(info) == "table" and typeof(info.remaining) == "number" then
			paid = { multiplier = tonumber(info.multiplier) or 1, endsAt = os.clock() + info.remaining }
			updateBoostStatus()
		end
	end)
	Remotes.PurchaseDone.OnClientEvent:Connect(function(result)
		if typeof(result) ~= "table" then
			return
		end
		if result.kind == "Boost" then
			UIController.Toast(
				Texts.Get("Store.BoostGot", { multiplier = result.multiplier, minutes = result.minutes }),
				3
			)
			return
		end
		if typeof(result.amount) ~= "number" then
			return
		end
		local kind = if result.kind == "Mog" then "Mog" else "Cash"
		close()
		UIController.FlyToCounter(kind)
		UIController.Toast(Texts.Get(`Store.{kind}Got`, { amount = Format.Short(result.amount) }), 3)
	end)
	Remotes.BossWinOffer.OnClientEvent:Connect(showOffer)
	-- Victoire accordée (achetée ou gagnée) : l'offre n'a plus lieu d'être
	Remotes.BossUpdate.OnClientEvent:Connect(function(update)
		if typeof(update) == "table" and update.state == "Victory" then
			offerToken += 1
			currentOffer = nil
			offerCard.Visible = false
		end
	end)
	-- L'aperçu tourne ; le minuteur du boost avance
	local sinceStatus = 0
	RunService.RenderStepped:Connect(function(dt)
		if not panel.Visible then
			return
		end
		if currentTab == "Outfits" and previewModel then
			spin += dt * StoreConfig.PreviewSpin
			previewModel:PivotTo(CFrame.Angles(0, spin, 0))
			previewFx:Step(dt)
		end
		sinceStatus += dt
		if sinceStatus >= 0.5 then
			sinceStatus = 0
			updateBoostStatus()
		end
	end)
end

return StoreController
