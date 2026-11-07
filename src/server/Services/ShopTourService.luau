-- Visite guidée d'un magasin à la première entrée (D121) : la carte a un volume invisible par magasin (tag ShopZone,
-- attribut Store). Quand un joueur y entre et n'a jamais vu la visite de ce magasin, le serveur la lui propose
-- (Remotes.ShopTour) ; le client la joue (ShopTourController, 5 à 8 s, qu'on peut passer) puis répond
-- (Remotes.ShopTourDone). Vue ou passée, elle est enregistrée dans la sauvegarde (ShopTours) et ne revient plus.
-- Si le client n'a pas pu la jouer (série, cinématique…), elle sera reproposée à la prochaine entrée.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ZONE_TAG = "ShopZone"

local DataService
local MinigameService

local pending: { [Player]: string } = {} -- visite proposée, réponse attendue
local pendingSince: { [Player]: number } = {}
local inside: { [Player]: string } = {} -- magasin où se trouve le joueur (une proposition par entrée)

local ShopTourService = {}

local function zoneAt(position: Vector3): string?
	for _, zone in CollectionService:GetTagged(ZONE_TAG) do
		if zone:IsA("BasePart") then
			local p = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				local store = zone:GetAttribute("Store")
				return if typeof(store) == "string" then store else nil
			end
		end
	end
	return nil
end

local function check(player: Player)
	local data = DataService.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not root or not root:IsA("BasePart") then
		return
	end
	-- Client qui n'a jamais répondu (déconnexion de l'interface, plantage) : on oublie la proposition
	if pending[player] and os.clock() - (pendingSince[player] or 0) > Balance.ShopTour.AnswerTimeout then
		pending[player] = nil
	end
	local store = zoneAt(root.Position)
	local previous = inside[player]
	inside[player] = store
	if not store or store == previous or pending[player] then
		return
	end
	if typeof(data.ShopTours) ~= "table" then
		data.ShopTours = {}
	end
	if data.ShopTours[store] or MinigameService.IsBusy(player) then
		return
	end
	pending[player] = store
	pendingSince[player] = os.clock()
	Remotes.ShopTour:FireClient(player, store)
end

local function onDone(player: Player, store: unknown, played: unknown)
	if typeof(store) ~= "string" or pending[player] ~= store then
		return
	end
	pending[player] = nil
	local data = DataService.Get(player)
	if data and played == true then
		data.ShopTours[store] = true
	end
end

-- Pour les tests dans Studio : magasin dont la visite attend une réponse
function ShopTourService.Pending(player: Player): string?
	return pending[player]
end

function ShopTourService.Init(services)
	DataService = services.DataService
	MinigameService = services.MinigameService
end

function ShopTourService.Start()
	Remotes.ShopTourDone.OnServerEvent:Connect(onDone)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		pendingSince[player] = nil
		inside[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Balance.ShopTour.CheckInterval)
			for _, player in Players:GetPlayers() do
				check(player)
			end
		end
	end)
end

return ShopTourService
