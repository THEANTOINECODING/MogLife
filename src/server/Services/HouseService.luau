-- Maisons visitables (D112) :
-- - Un visiteur qui reste quelques secondes dans la maison d'un autre joueur peut l'aimer (« J'aime »), une seule
--   fois par maison (sauvegardé). Le propriétaire reçoit un peu de Cash et le compteur s'affiche sur son panneau.
-- - Classement des maisons du serveur (avec un bouton pour y aller) et classement mondial (OrderedDataStore), lus
--   à la demande depuis le menu.
-- Le client ne décide rien : le serveur vérifie la présence dans la maison, la durée de la visite, le délai et
-- l'unicité du « J'aime ».

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local HOUSE = Balance.House
local STORE_NAME = "HouseLikesV1"

local DataService
local StatsService
local PlotService
local FurnitureService
local MinigameService
local BossService

-- Visite en cours : maison où se trouve le joueur, depuis combien de temps, et maisons dont la visite est validée
type Visit = { plot: Model?, since: number, valid: { [number]: number }, sent: string }
local visits: { [Player]: Visit } = {}
local lastLike: { [Player]: number } = {}
local lastVisit: { [Player]: number } = {}
local lastRanking: { [Player]: number } = {}
local dirty: { [number]: number } = {} -- UserId -> « J'aime » à écrire dans le classement mondial
local globalTop: { { userId: number, name: string, likes: number } } = {}
local names: { [number]: string } = {}

local store: OrderedDataStore? = nil

local HouseService = {}

local function likesOf(player: Player): number
	local data = DataService.Get(player)
	return data and data.HouseLikes or 0
end

local function hasLiked(liker: Player, ownerUserId: number): boolean
	local data = DataService.Get(liker)
	return data ~= nil and data.HousesLiked[tostring(ownerUserId)] == true
end

local function sendState(player: Player, visit: Visit)
	local plot = visit.plot
	local owner = plot and PlotService.GetOwner(plot)
	local state
	if owner and owner ~= player then
		local valid = visit.valid[owner.UserId]
		state = {
			visiting = owner.UserId,
			name = owner.DisplayName,
			likes = likesOf(owner),
			liked = hasLiked(player, owner.UserId),
			canLike = valid ~= nil,
		}
	else
		state = { likes = likesOf(player) }
	end
	-- N'envoie que les changements
	local key = `{state.visiting}|{state.likes}|{state.liked}|{state.canLike}`
	if key ~= visit.sent then
		visit.sent = key
		Remotes.HouseState:FireClient(player, state)
	end
end

local function checkVisit(player: Player, visit: Visit, now: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plot = root and PlotService.PlotAt(root.Position, 0)
	if plot ~= visit.plot then
		visit.plot = plot
		visit.since = now
	end
	local owner = plot and PlotService.GetOwner(plot)
	if owner and owner ~= player and now - visit.since >= HOUSE.VisitSeconds then
		visit.valid[owner.UserId] = now
	end
	for userId, at in visit.valid do
		if now - at > HOUSE.VisitMemory and not (owner and owner.UserId == userId) then
			visit.valid[userId] = nil
		end
	end
	sendState(player, visit)
end

local function onLike(player: Player, ownerUserId: unknown)
	if typeof(ownerUserId) ~= "number" or ownerUserId % 1 ~= 0 then
		return
	end
	local now = os.clock()
	if now - (lastLike[player] or 0) < HOUSE.LikeCooldown then
		return
	end
	lastLike[player] = now
	local visit = visits[player]
	local _, owner = PlotService.GetPlotOfUserId(ownerUserId)
	local likerData = DataService.Get(player)
	if not visit or not owner or owner == player or not likerData then
		return
	end
	if not visit.valid[ownerUserId] then
		Remotes.Notify:FireClient(player, { key = "House.VisitFirst" })
		return
	end
	local key = tostring(ownerUserId)
	if likerData.HousesLiked[key] then
		return
	end
	local ownerData = DataService.Get(owner)
	if not ownerData then
		return
	end
	-- Une sauvegarde bornée : au-delà, on oublie la plus ancienne (ordre non garanti, mais sans croissance infinie)
	local count = 0
	for _ in likerData.HousesLiked do
		count += 1
	end
	if count >= HOUSE.MaxRemembered then
		local oldest = next(likerData.HousesLiked)
		if oldest then
			likerData.HousesLiked[oldest] = nil
		end
	end
	likerData.HousesLiked[key] = true
	ownerData.HouseLikes += 1
	dirty[ownerUserId] = ownerData.HouseLikes
	StatsService.Add(owner, "Cash", HOUSE.LikeCash)
	PlotService.RefreshSign(owner)
	Remotes.Notify:FireClient(owner, {
		key = "House.LikedYours",
		args = { name = player.DisplayName, cash = HOUSE.LikeCash },
	})
	Remotes.Notify:FireClient(player, { key = "House.YouLiked", args = { name = owner.DisplayName } })
	visit.sent = ""
	sendState(player, visit)
	local ownerVisit = visits[owner]
	if ownerVisit then
		ownerVisit.sent = ""
		sendState(owner, ownerVisit)
	end
end

local function onVisit(player: Player, ownerUserId: unknown)
	if typeof(ownerUserId) ~= "number" or ownerUserId % 1 ~= 0 then
		return
	end
	local now = os.clock()
	if now - (lastVisit[player] or 0) < HOUSE.VisitCooldown then
		return
	end
	if MinigameService.IsBusy(player) or BossService.IsFighting(player) then
		return
	end
	local plot, owner = PlotService.GetPlotOfUserId(ownerUserId)
	local character = player.Character
	if not plot or not owner or not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	local target = PlotService.GetHomeCFrame(owner)
	if not target then
		return
	end
	lastVisit[player] = now
	character:PivotTo(target)
end

local function serverRanking(viewer: Player)
	local list = {}
	for _, player in Players:GetPlayers() do
		if PlotService.GetPlot(player) and DataService.Get(player) then
			table.insert(list, {
				userId = player.UserId,
				name = player.DisplayName,
				likes = likesOf(player),
				comfort = FurnitureService.Comfort(player),
				liked = hasLiked(viewer, player.UserId),
				mine = player == viewer,
			})
		end
	end
	table.sort(list, function(a, b)
		if a.likes ~= b.likes then
			return a.likes > b.likes
		end
		return a.comfort > b.comfort
	end)
	return list
end

local function onRankingRequest(player: Player)
	local now = os.clock()
	if now - (lastRanking[player] or 0) < HOUSE.RankingCooldown then
		return
	end
	lastRanking[player] = now
	Remotes.HouseRanking:FireClient(player, { server = serverRanking(player), global = globalTop })
end

-- ------------------------------------------------------------------ classement mondial

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

local function flushDirty()
	local current = store
	if not current then
		return
	end
	for userId, likes in dirty do
		dirty[userId] = nil
		local ok, err = pcall(current.SetAsync, current, tostring(userId), likes)
		if not ok then
			warn(`[HouseService] Global ranking write failed: {err}`)
			dirty[userId] = likes
			return
		end
	end
end

local function readGlobal()
	local current = store
	if not current then
		return
	end
	local ok, pages = pcall(current.GetSortedAsync, current, false, HOUSE.GlobalSize)
	if not ok then
		warn(`[HouseService] Global ranking read failed: {pages}`)
		return
	end
	local top = {}
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId and typeof(entry.value) == "number" and entry.value > 0 then
			table.insert(top, { userId = userId, name = nameOf(userId), likes = entry.value })
		end
	end
	globalTop = top
end

-- Accès pour les tests unitaires dans Studio (tools/test_house_likes.luau) : rien n'est exposé au client
HouseService._test = { visits = visits, checkVisit = checkVisit, onLike = onLike }

-- ------------------------------------------------------------------ cycle

function HouseService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
	PlotService = services.PlotService
	FurnitureService = services.FurnitureService
	MinigameService = services.MinigameService
	BossService = services.BossService
end

function HouseService.Start()
	PlotService.SetLikesProvider(likesOf)
	Remotes.LikeHouse.OnServerEvent:Connect(onLike)
	Remotes.VisitHouse.OnServerEvent:Connect(onVisit)
	Remotes.HouseRankingRequest.OnServerEvent:Connect(onRankingRequest)
	local function track(player: Player)
		visits[player] = { plot = nil, since = os.clock(), valid = {}, sent = "" }
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		visits[player] = nil
		lastLike[player] = nil
		lastVisit[player] = nil
		lastRanking[player] = nil
	end)
	-- Le propriétaire voit ses « J'aime » dès que sa maison lui est attribuée
	PlotService.OnAssigned(function(player)
		PlotService.RefreshSign(player)
		local likes = likesOf(player)
		if likes > 0 then
			dirty[player.UserId] = likes
		end
	end)
	task.spawn(function()
		while true do
			task.wait(HOUSE.CheckInterval)
			local now = os.clock()
			for player, visit in visits do
				local ok, err = pcall(checkVisit, player, visit, now)
				if not ok then
					warn(`[HouseService] {err}`)
				end
			end
		end
	end)
	-- Classement mondial : DataStore indisponible dans une place jamais publiée ou sans accès API (Studio)
	local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, STORE_NAME)
	if ok then
		store = result
	else
		warn(`[HouseService] Global ranking disabled: {result}`)
	end
	task.spawn(function()
		readGlobal()
		local sinceRead = 0
		while true do
			task.wait(HOUSE.GlobalWrite)
			flushDirty()
			sinceRead += HOUSE.GlobalWrite
			if sinceRead >= HOUSE.GlobalRefresh then
				sinceRead = 0
				readGlobal()
			end
		end
	end)
	game:BindToClose(function()
		if not RunService:IsStudio() then
			flushDirty()
		end
	end)
end

return HouseService
