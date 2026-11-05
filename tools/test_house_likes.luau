-- Test unitaire des « J'aime » des maisons (D112), sans second joueur : à coller dans la barre de commande de Studio
-- pendant un test (contexte Serveur). HouseService est chargé dans une copie isolée, avec de faux services et deux
-- faux joueurs ; aucune vraie sauvegarde n'est touchée. Renvoie la liste des vérifications.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Remotes) -- copie propre au contexte de la barre de commande
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local HOUSE = Balance.House

local sent = {}
local function fake(name)
	return {
		FireClient = function(_, player, message)
			table.insert(sent, { remote = name, to = player.DisplayName, message = message })
		end,
		FireAllClients = function() end,
		OnServerEvent = { Connect = function() end },
	}
end
for _, name in { "Notify", "HouseState", "HouseRanking", "LikeHouse", "VisitHouse", "HouseRankingRequest" } do
	(Remotes :: any)[name] = fake(name)
end

local function fakePlayer(userId: number, name: string, position: Vector3)
	local root = { Position = position }
	local character = {
		FindFirstChild = function(_, child)
			return if child == "HumanoidRootPart" then root else nil
		end,
	}
	return { UserId = userId, DisplayName = name, Name = name, Character = character, root = root }
end

local plot = { Name = "FakePlot" }
local owner = fakePlayer(1, "Owner", Vector3.zero)
local visitor = fakePlayer(2, "Visitor", Vector3.zero)
local data = {
	[owner] = { HouseLikes = 0, HousesLiked = {}, Cash = 0 },
	[visitor] = { HouseLikes = 0, HousesLiked = {}, Cash = 0 },
}
local cash = {}
local services = {
	DataService = {
		Get = function(player)
			return data[player]
		end,
	},
	StatsService = {
		Add = function(player, stat, amount)
			cash[player] = (cash[player] or 0) + if stat == "Cash" then amount else 0
		end,
	},
	PlotService = {
		SetLikesProvider = function() end,
		RefreshSign = function() end,
		OnAssigned = function() end,
		GetOwner = function(p)
			return if p == plot then owner else nil
		end,
		GetPlotOfUserId = function(userId)
			if userId == owner.UserId then
				return plot, owner
			end
			return nil, nil
		end,
		PlotAt = function(position)
			return if position.Magnitude < 10 then plot else nil
		end,
	},
	FurnitureService = { Comfort = function()
		return 0
	end },
	MinigameService = { IsBusy = function()
		return false
	end },
	BossService = { IsFighting = function()
		return false
	end },
}

local House = require(ServerScriptService.Server.Services.HouseService:Clone())
House.Init(services)
local t = House._test
local checks = {}
local function check(label, ok)
	table.insert(checks, (if ok then "OK   " else "FAIL ") .. label)
end

t.visits[visitor] = { plot = nil, since = 0, valid = {}, sent = "" }
t.visits[owner] = { plot = nil, since = 0, valid = {}, sent = "" }

-- 1. Like avant d'avoir visité : refusé
t.checkVisit(visitor, t.visits[visitor], 100)
t.onLike(visitor, owner.UserId)
check("like refused before the visit time", data[owner].HouseLikes == 0)

-- 2. Après VisitSeconds dans la maison : accepté, Cash au propriétaire, une seule fois
task.wait(HOUSE.LikeCooldown + 0.1)
t.checkVisit(visitor, t.visits[visitor], 100 + HOUSE.VisitSeconds + 0.1)
t.onLike(visitor, owner.UserId)
check("like accepted after the visit", data[owner].HouseLikes == 1)
check("owner paid LikeCash", cash[owner] == HOUSE.LikeCash)
check("visitor remembers the house", data[visitor].HousesLiked["1"] == true)
task.wait(HOUSE.LikeCooldown + 0.1)
t.onLike(visitor, owner.UserId)
check("second like on the same house refused", data[owner].HouseLikes == 1)

-- 3. Le propriétaire ne peut pas s'aimer lui-même ; arguments invalides ignorés
task.wait(HOUSE.LikeCooldown + 0.1)
t.onLike(owner, owner.UserId)
check("owner cannot like own house", data[owner].HouseLikes == 1)
for _, bad in { "1", 0 / 0, math.huge, 1.5, {} } do
	t.onLike(visitor, bad :: any)
end
check("invalid arguments ignored", data[owner].HouseLikes == 1)

-- 4. La visite expire après VisitMemory hors de la maison
visitor.root.Position = Vector3.new(500, 0, 0)
data[visitor].HousesLiked = {}
t.checkVisit(visitor, t.visits[visitor], 100 + HOUSE.VisitSeconds + HOUSE.VisitMemory + 5)
check("visit forgotten after VisitMemory", t.visits[visitor].valid[owner.UserId] == nil)

local states = 0
for _, entry in sent do
	if entry.remote == "HouseState" then
		states += 1
	end
end
check("house state sent to the visitor", states > 0)
return table.concat(checks, "\n")
