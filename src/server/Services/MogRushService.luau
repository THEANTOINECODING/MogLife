-- Mog Rush (D132, Config/MogRush.luau) : classement mondial du Mog gagné aux exercices pendant la manche de 30 min.
-- - Manche = os.time() // RoundSeconds : la même sur tous les serveurs, sans coordination.
-- - Chaque serveur additionne le Mog de ses joueurs et l'envoie (IncrementAsync) dans un OrderedDataStore propre à la
--   manche ; il lit régulièrement les 10 premiers et y mêle les scores frais de ses propres joueurs.
-- - À la fin d'une manche : tout repart de 0 ; une minute plus tard, les champions de la manche finie sont lus et
--   annoncés à tout le serveur.
-- Sans accès aux DataStores (Studio sans accès API), le tableau fonctionne quand même avec les joueurs du serveur.
-- Classement mondial du Mog total (demande d'Antoine, 21/11, deux faces du tableau sur quatre) : chaque serveur écrit
-- le Mog de ses joueurs (SetAsync, seulement s'il a changé) dans un autre OrderedDataStore et lit les 100 premiers.
-- Rang du joueur (bas du tableau, dans les deux classements) : exact jusqu'à la 100e place lue ; au-delà, le tableau
-- dit seulement qu'il n'est pas encore dans le top 100.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local MogRush = require(ReplicatedStorage.Shared.Config.MogRush)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

type Entry = { userId: number, name: string, score: number }

local MogRushService = {}

local round = 0
local gained: { [Player]: number } = {} -- Mog de la manche (affiché), y compris ce qui est déjà envoyé
local pending: { [Player]: number } = {} -- Mog pas encore envoyé au classement mondial
local stored: { Entry } = {} -- premiers lus dans le classement mondial de la manche (RankRead)
local worldStored: { Entry } = {} -- premiers lus dans le classement mondial du Mog total
local worldWritten: { [Player]: number } = {} -- dernier Mog total écrit pour ce joueur
local worldStore: OrderedDataStore? = nil
local DataService
local podium: { Entry } = {} -- champions de la manche précédente
local names: { [number]: string } = {}
local storeDisabled = false
-- Les tests dans Studio ont leur propre classement : ils ne se mélangent jamais aux vrais joueurs
local STORE_NAME = if RunService:IsStudio() then `{MogRush.StoreName}_Studio` else MogRush.StoreName
local WORLD_NAME = if RunService:IsStudio() then `{MogRush.World.StoreName}_Studio` else MogRush.World.StoreName

local function roundNow(): number
	return os.time() // MogRush.RoundSeconds
end

local function storeFor(roundId: number): OrderedDataStore?
	if storeDisabled then
		return nil
	end
	local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, STORE_NAME, `R{roundId}`)
	if not ok then
		storeDisabled = true
		warn(`[MogRushService] Global board disabled: {result}`)
		return nil
	end
	return result
end

local function nameOf(userId: number, noYield: boolean?): string
	local cached = names[userId]
	if cached then
		return cached
	end
	if noYield then
		task.spawn(nameOf, userId)
		return "…"
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok and typeof(name) == "string" then name else "?"
	return names[userId]
end

local function readStore(store: OrderedDataStore?, size: number): { Entry }?
	if not store then
		return nil
	end
	local ok, pages = pcall(store.GetSortedAsync, store, false, size)
	if not ok then
		warn(`[MogRushService] Global board read failed: {pages}`)
		if string.find(tostring(pages), "Studio", 1, true) then
			storeDisabled = true -- Studio sans accès API : inutile de réessayer
		end
		return nil
	end
	local list = {}
	for _, item in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId and typeof(item.value) == "number" and item.value > 0 then
			-- Noms cherchés seulement pour les lignes affichées (les autres servent au rang)
			local name = if #list < MogRush.TopSize then nameOf(userId) else names[userId] or "…"
			table.insert(list, { userId = userId, name = name, score = item.value })
		end
	end
	return list
end

local function readTop(roundId: number, size: number): { Entry }?
	return readStore(storeFor(roundId), size)
end

-- Envoie le Mog en attente de ces joueurs vers le classement de cette manche
local function flush(roundId: number, amounts: { [Player]: number })
	local store = storeFor(roundId)
	if not store then
		return
	end
	for player, amount in amounts do
		local whole = math.floor(amount)
		if whole >= 1 then
			local ok, err = pcall(store.IncrementAsync, store, tostring(player.UserId), whole)
			if ok then
				if roundId == round and pending[player] then
					pending[player] -= whole
				end
			else
				warn(`[MogRushService] Global board write failed: {err}`)
				return -- nouvel essai au prochain envoi
			end
		end
	end
end

local function sortList(byUser: { [number]: Entry }): { Entry }
	local list = {}
	for _, entry in byUser do
		entry.score = math.floor(entry.score)
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.userId < b.userId
	end)
	return list
end

-- Classement de la manche : le mondial, avec les scores frais des joueurs du serveur (liste complète)
local function merged(): { Entry }
	local byUser: { [number]: Entry } = {}
	for _, entry in stored do
		byUser[entry.userId] = table.clone(entry)
	end
	for player, score in gained do
		if score >= 1 then
			local entry = byUser[player.UserId]
			if entry then
				entry.score = math.max(entry.score, score)
			else
				byUser[player.UserId] = { userId = player.UserId, name = nameOf(player.UserId, true), score = score }
			end
		end
	end
	return sortList(byUser)
end

-- Classement du Mog total : le mondial, où les joueurs du serveur ont leur Mog actuel (il peut aussi baisser)
local function worldMerged(): { Entry }
	local byUser: { [number]: Entry } = {}
	for _, entry in worldStored do
		byUser[entry.userId] = table.clone(entry)
	end
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data and data.Mog >= 1 then
			byUser[player.UserId] = { userId = player.UserId, name = nameOf(player.UserId, true), score = data.Mog }
		elseif byUser[player.UserId] then
			byUser[player.UserId] = nil
		end
	end
	return sortList(byUser)
end

-- Les `TopSize` premiers (avec leur nom) et le rang de chaque joueur. Le rang n'est sûr que dans la partie lue
-- du classement mondial (`read` lignes) ; si le mondial en contient moins, il est complet et tout rang est sûr.
local function ranked(list: { Entry }, read: number): ({ Entry }, { [number]: number })
	local complete = read < MogRush.RankRead
	local ranks = {}
	local top = {}
	for index, entry in list do
		if index <= MogRush.TopSize then
			if entry.name == "…" then
				entry.name = nameOf(entry.userId, true)
			end
			table.insert(top, entry)
		end
		if complete or index <= MogRush.RankRead then
			ranks[entry.userId] = index
		end
	end
	return top, ranks
end

local function send(target: Player?)
	local top, ranks = ranked(merged(), #stored)
	local worldTop, worldRanks = ranked(worldMerged(), #worldStored)
	local endsAt = (round + 1) * MogRush.RoundSeconds
	for _, player in if target then { target } else Players:GetPlayers() do
		local data = DataService.Get(player)
		local score = math.floor(gained[player] or 0)
		Remotes.MogRushState:FireClient(player, {
			round = round,
			endsAt = endsAt,
			top = top,
			podium = podium,
			you = { score = score, rank = if score >= 1 then ranks[player.UserId] else nil },
			world = {
				top = worldTop,
				you = {
					score = if data then math.floor(data.Mog) else 0,
					rank = worldRanks[player.UserId],
				},
			},
		})
	end
end

-- Écrit le Mog total des joueurs du serveur qui a changé depuis la dernière écriture
local function flushWorld(only: Player?)
	local store = worldStore
	if not store then
		return
	end
	for _, player in if only then { only } else Players:GetPlayers() do
		local data = DataService.Get(player)
		local value = data and math.floor(data.Mog)
		if value and value >= 1 and value ~= worldWritten[player] then
			local ok, err = pcall(store.SetAsync, store, tostring(player.UserId), value)
			if ok then
				worldWritten[player] = value
			else
				warn(`[MogRushService] World board write failed: {err}`)
				return
			end
		end
	end
end

local function announcePodium(roundId: number)
	task.wait(MogRush.PodiumReadDelay)
	local list = readTop(roundId, MogRush.PodiumSize)
	if not list then
		-- Pas de classement mondial : les champions du serveur (gardés au moment du changement)
		return
	end
	podium = list
	local first = list[1]
	if first then
		Remotes.Notify:FireAllClients({
			key = "MogRush.Champion",
			args = { name = first.name, mog = Format.Short(first.score) },
		})
	end
	send()
end

-- Nouvelle manche : on envoie ce qui reste de l'ancienne, tout le monde repart de 0
local function rollIfNeeded()
	local now = roundNow()
	if now == round then
		return
	end
	local previous = round
	local leftover = pending
	local localPodium = merged()
	pending = {}
	for player in gained do
		gained[player] = 0
		pending[player] = 0
	end
	stored = {}
	round = now
	if previous > 0 then
		task.spawn(flush, previous, leftover)
		-- Sans DataStore, les champions sont ceux du serveur
		if storeDisabled then
			for _, entry in localPodium do
				entry.name = nameOf(entry.userId, true)
			end
			while #localPodium > MogRush.PodiumSize do
				table.remove(localPodium)
			end
			podium = localPodium
		end
		Remotes.Notify:FireAllClients({ key = "MogRush.NewRound" })
		if not storeDisabled then
			task.spawn(announcePodium, previous)
		end
	end
	send()
end

-- Mog gagné à un exercice (appelé par ExerciseService, après tous les multiplicateurs)
function MogRushService.Record(player: Player, amount: number)
	if typeof(amount) ~= "number" or amount <= 0 or amount ~= amount then
		return
	end
	rollIfNeeded()
	if not gained[player] then
		return
	end
	gained[player] += amount
	pending[player] += amount
end

local function onJoin(player: Player)
	gained[player] = 0
	pending[player] = 0
	names[player.UserId] = player.DisplayName
	-- Venu d'un autre serveur pendant la manche : on reprend son score mondial
	task.spawn(function()
		local roundAtJoin = round
		local store = storeFor(roundAtJoin)
		if store then
			local ok, value = pcall(store.GetAsync, store, tostring(player.UserId))
			if ok and typeof(value) == "number" and gained[player] and round == roundAtJoin then
				gained[player] += value
			end
		end
		send(player)
	end)
end

function MogRushService.Init(services)
	DataService = services.DataService
end

function MogRushService.Start()
	round = roundNow()
	local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, WORLD_NAME)
	if ok then
		worldStore = result
	else
		warn(`[MogRushService] World board disabled: {result}`)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		task.spawn(function()
			flushWorld(player)
			worldWritten[player] = nil
		end)
		local amount = pending[player]
		gained[player] = nil
		pending[player] = nil
		if amount and amount >= 1 then
			task.spawn(flush, round, { [player] = amount })
		end
	end)
	game:BindToClose(function()
		flush(round, table.clone(pending))
		flushWorld()
	end)

	task.spawn(function()
		local first = readTop(round, MogRush.RankRead)
		if first then
			stored = first
		end
		local world = readStore(worldStore, MogRush.RankRead)
		if world then
			worldStored = world
		end
		local sinceFlush, sinceRead = 0, 0
		while true do
			task.wait(MogRush.SendEvery)
			rollIfNeeded()
			sinceFlush += MogRush.SendEvery
			sinceRead += MogRush.SendEvery
			if sinceFlush >= MogRush.FlushEvery then
				sinceFlush = 0
				flush(round, table.clone(pending))
				flushWorld()
			end
			if sinceRead >= MogRush.ReadEvery then
				sinceRead = 0
				local roundAtRead = round
				local list = readTop(roundAtRead, MogRush.RankRead)
				if list and round == roundAtRead then
					stored = list
				end
				local worldList = readStore(worldStore, MogRush.RankRead)
				if worldList then
					worldStored = worldList
				end
			end
			send()
		end
	end)
end

return MogRushService
