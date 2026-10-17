-- Création de personnage (D55) : apparence choisie par le joueur (genre, peau, cheveux, yeux, expression, tenue de
-- départ, surnom). Le client n'envoie qu'une demande ; le serveur valide chaque champ (src/shared/Look.luau).
-- - Premier passage (data.Look.Created = false, nouveaux joueurs ET joueurs existants une fois) : le menu de
--   création s'ouvre ; une fois validé, le tutoriel (intro de Muscle City) peut commencer (TutorialService).
-- - Ensuite, l'apparence se change gratuitement au miroir de sa maison (créé ici dans chaque maison).
-- - Les coupes de départ (StyleItems, starter = true) sont possédées par tous.
-- - Le surnom (prénom + titre choisis dans une liste) s'affiche au-dessus de la tête (Humanoid.DisplayName).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local StyleItems = require(ReplicatedStorage.Shared.Config.StyleItems)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Look = require(ReplicatedStorage.Shared.Look)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PLOT_TAG = "Plot"
local MIRROR_NAME = "HomeMirror"
-- Miroir de la maison : contre le mur droit du salon (surface intérieure à 12,1 studs du centre), entre la lampe
-- et la télé, sur une partie de mur sans fenêtre (repère du sol de la maison ; la vitre regarde vers le salon)
local MIRROR_OFFSET = CFrame.new(11.95, 4.3, -8) * CFrame.Angles(0, math.pi / 2, 0)

local DataService
local StyleService
local TutorialService
local PlotService

local lastRequest: { [Player]: number } = {}

local LookService = {}

local function lookOf(player: Player): Look.LookData?
	local data = DataService.Get(player)
	return data and Look.Sanitize(data.Look, nil)
end

-- Titres exclusifs débloqués (trophées de la semaine, victoires en duel)
local function unlockedTitles(data: any): { [string]: boolean }
	return Look.UnlockedTitles(data.Weekly.Trophies, data.Duels.Wins)
end

-- Surnom au-dessus de la tête, avec le nombre de victoires en duel s'il y en a (D67)
local function applyNickname(player: Player)
	local data = DataService.Get(player)
	local look = lookOf(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if data and look and humanoid then
		humanoid.DisplayName = Look.Nickname(look, data.Duels.Wins)
	end
end

local function openCreator(player: Player, mode: string)
	local data = DataService.Get(player)
	if not data then
		return
	end
	Remotes.OpenCreator:FireClient(player, {
		mode = mode,
		look = Look.Sanitize(data.Look, nil),
		hair = data.StyleEquipped.Hair or "",
		titles = unlockedTitles(data),
		trophies = data.Weekly.Trophies,
		duelWins = data.Duels.Wins,
	})
end

-- Coupe demandée : "" (coupe de base) ou une coupe possédée (les coupes de départ le sont toutes)
local function validHair(data: any, hair: unknown): (boolean, string?)
	if hair == "" then
		return true, nil
	end
	if typeof(hair) ~= "string" then
		return false, nil
	end
	local item = StyleItems[hair]
	if item and item.category == "Hair" and (item.starter or data.StyleOwned[hair]) then
		return true, hair
	end
	return false, nil
end

local function onSetLook(player: Player, raw: unknown, hair: unknown)
	local data = DataService.Get(player)
	local now = os.clock()
	if not data or now - (lastRequest[player] or 0) < Balance.Look.RequestCooldown then
		return
	end
	lastRequest[player] = now
	local firstTime = not data.Look.Created
	local look = Look.Sanitize(raw, Look.Sanitize(data.Look, nil), unlockedTitles(data))
	look.Created = true
	data.Look = look
	local ok, hairId = validHair(data, hair)
	if ok then
		data.StyleEquipped.Hair = hairId
	end
	StyleService.Refresh(player)
	applyNickname(player)
	Remotes.Notify:FireClient(player, { key = "Creator.Saved" })
	if firstTime then
		TutorialService.LookCreated(player)
	end
end

-- Miroir de chaque maison : seul son propriétaire peut s'en servir
local function setupHomeMirror(plot: Instance)
	if not plot:IsA("Model") or plot:FindFirstChild(MIRROR_NAME, true) then
		return
	end
	local floor = plot:FindFirstChild("HouseFloor", true)
	if not floor or not floor:IsA("BasePart") then
		return
	end
	local base = floor.CFrame * MIRROR_OFFSET
	local mirror = Instance.new("Model")
	mirror.Name = MIRROR_NAME
	local frame = Instance.new("Part")
	frame.Name = "Frame"
	frame.Size = Vector3.new(3.2, 5.6, 0.25)
	frame.CFrame = base
	frame.Color = Color3.fromRGB(212, 168, 70)
	frame.Material = Enum.Material.SmoothPlastic
	frame.Anchored = true
	frame.CanCollide = false
	frame.Parent = mirror
	local glass = Instance.new("Part")
	glass.Name = "Glass"
	glass.Size = Vector3.new(2.7, 5.1, 0.1)
	glass.CFrame = base * CFrame.new(0, 0, -0.12)
	glass.Color = Color3.fromRGB(200, 226, 245)
	glass.Material = Enum.Material.Glass
	glass.Reflectance = 0.35
	glass.Transparency = 0.1
	glass.Anchored = true
	glass.CanCollide = false
	glass.Parent = mirror
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Mirror.Prompt")
	prompt.ObjectText = Texts.Get("Mirror.Object")
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = glass
	prompt.Triggered:Connect(function(player)
		if PlotService.GetPlot(player) ~= plot then
			Remotes.Notify:FireClient(player, { key = "Mirror.NotYours" })
			return
		end
		openCreator(player, "Edit")
	end)
	mirror.Parent = plot
end

local function onPlayerLoaded(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	-- La validation ne reprend jamais « Created » (le client ne doit pas pouvoir le forcer) : on le garde à part,
	-- sinon le menu de création se rouvrirait à chaque connexion
	local created = typeof(data.Look) == "table" and data.Look.Created == true
	data.Look = Look.Sanitize(data.Look, nil) :: any
	data.Look.Created = created
	for itemId, item in StyleItems do
		if item.starter then
			data.StyleOwned[itemId] = true
		end
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		applyNickname(player)
	end)
	applyNickname(player)
	if not data.Look.Created then
		-- Laisse le client charger son interface avant d'ouvrir le menu
		task.delay(Balance.Look.OpenDelay, function()
			if player.Parent then
				openCreator(player, "Create")
			end
		end)
	end
end

-- Met à jour le surnom affiché (nouvelle victoire en duel)
function LookService.RefreshNickname(player: Player)
	applyNickname(player)
end

-- Annonce les titres exclusifs qui viennent d'être débloqués (une seule fois chacun, mémorisé dans Tips)
function LookService.CheckTitles(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	for id in unlockedTitles(data) do
		local key = `Title.{id}`
		if not data.Tips[key] then
			data.Tips[key] = true
			Remotes.Notify:FireClient(
				player,
				{ key = "Title.Unlocked", args = { title = { key = `Nick.Title.{id}` } } }
			)
		end
	end
end

-- Le joueur a-t-il déjà créé son personnage ?
function LookService.IsCreated(player: Player): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.Look ~= nil and data.Look.Created == true
end

function LookService.Init(services)
	DataService = services.DataService
	StyleService = services.StyleService
	TutorialService = services.TutorialService
	PlotService = services.PlotService
end

function LookService.Start()
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		setupHomeMirror(plot)
	end
	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(setupHomeMirror)
	DataService.PlayerLoaded:Connect(onPlayerLoaded)
	for _, player in Players:GetPlayers() do
		if DataService.Get(player) then
			task.spawn(onPlayerLoaded, player)
		end
	end
	Remotes.SetLook.OnServerEvent:Connect(onSetLook)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return LookService
