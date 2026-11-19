-- Mog Rush (D132, Config/MogRush.luau) : classement mondial du Mog gagné aux exercices pendant la manche de 30 min.
-- - Manche = os.time() // RoundSeconds : la même sur tous les serveurs, sans coordination.
-- - Chaque serveur additionne le Mog de ses joueurs et l'envoie (IncrementAsync) dans un OrderedDataStore propre à la
--   manche ; il lit régulièrement les 10 premiers et y mêle les scores frais de ses propres joueurs.
-- - À la fin d'une manche : tout repart de 0 ; une minute plus tard, les champions de la manche finie sont lus et
--   annoncés à tout le serveur.
-- Sans accès aux DataStores (Studio sans accès API), le tableau fonctionne quand même avec les joueurs du serveur.

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
local stored: { Entry } = {} -- 10 premiers lus dans le classement mondial
local podium: { Entry } = {} -- champions de la manche précédente
local names: { [number]: string } = {}
local storeDisabled = false
-- Les tests dans Studio ont leur propre classement : ils ne se mélangent jamais aux vrais joueurs
local STORE_NAME = if RunService:IsStudio() then `{MogRush.StoreName}_Studio` else MogRush.StoreName

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

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
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

local function readTop(roundId: number, size: number): { Entry }?
	local store = storeFor(roundId)
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
			table.insert(list, { userId = userId, name = nameOf(userId), score = item.value })
		end
	end
	return list
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

-- Classement affiché : le mondial, avec les scores frais des joueurs du serveur
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
				byUser[player.UserId] = { userId = player.UserId, name = nameOf(player.UserId), score = score }
			end
		end
	end
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
	while #list > MogRush.TopSize do
		table.remove(list)
	end
	return list
end

local function send(target: Player?)
	local top = merged()
	local endsAt = (round + 1) * MogRush.RoundSeconds
	for _, player in if target then { target } else Players:GetPlayers() do
		local rank = nil
		for index, entry in top do
			if entry.userId == player.UserId then
				rank = index
				break
			end
		end
		Remotes.MogRushState:FireClient(player, {
			round = round,
			endsAt = endsAt,
			top = top,
			podium = podium,
			you = { score = math.floor(gained[player] or 0), rank = rank },
		})
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

function MogRushService.Start()
	round = roundNow()
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local amount = pending[player]
		gained[player] = nil
		pending[player] = nil
		if amount and amount >= 1 then
			task.spawn(flush, round, { [player] = amount })
		end
	end)
	game:BindToClose(function()
		flush(round, table.clone(pending))
	end)

	task.spawn(function()
		local first = readTop(round, MogRush.TopSize)
		if first then
			stored = first
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
			end
			if sinceRead >= MogRush.ReadEvery then
				sinceRead = 0
				local roundAtRead = round
				local list = readTop(roundAtRead, MogRush.TopSize)
				if list and round == roundAtRead then
					stored = list
				end
			end
			send()
		end
	end)
end

return MogRushService
