-- Récompenses et rendez-vous (D131, design/ANALYSE_JEU_2026-11-19.md, réglages : Config/Rewards.luau) :
-- - pack de départ (produit Robux unique, Products.StarterPack), proposé une fois après la première victoire de boss ;
-- - groupe Roblox : titre « Gym Family » + Cash, vérifié par le serveur ;
-- - codes : une fois par joueur, saisis dans la fenêtre des nouveautés ;
-- - nouveautés : version vue (pastille sur la case du menu) ;
-- - ami invité (JoinData.ReferredByPlayerId) : à sa première série, celui qui l'a invité (sur le serveur) est récompensé ;
-- - bonus d'équipe : Mog des exercices +10 % par ami Roblox présent (plafonné) ;
-- - Golden Pump Hour : chaque semaine à heure fixe, Mog des exercices × 1,5 pour tout le serveur ;
-- - shaker de protéines : Cash gagné pendant l'absence (plafonné à 8 h), versé au retour. Jamais de pénalité.
-- Le client ne fait que demander (RewardsAction) ; tout est vérifié ici.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage.Shared.Config.Products)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Throttle = require(script.Parent.Parent.Throttle)
local Analytics = require(script.Parent.Parent.Analytics)

local STARTER = Products.StarterPack
local GOLDEN = Rewards.GoldenHour

local DataService
local StatsService
local BoostService
local LookService
local MinigameService
local PurchaseService

-- Amis Roblox présents sur le serveur : joueur -> { [ami] = true }
local friends: { [Player]: { [Player]: boolean } } = {}
local lastCode: { [Player]: number } = {}

local RewardsService = {}

-- ------------------------------------------------------------------ état envoyé au client

local function sendState(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	Remotes.RewardsState:FireClient(player, {
		newsVersion = Rewards.News.Version,
		newsSeen = data.NewsSeen or 0,
		starterOwned = data.Unlocks.DayOne == true,
		starterProduct = STARTER.productId,
		starterRobux = STARTER.robux,
		groupId = Rewards.Group.GroupId,
		groupClaimed = data.Unlocks[Rewards.Group.Title] == true,
	})
end

local function unlock(player: Player, data, id: string)
	if data.Unlocks[id] then
		return
	end
	data.Unlocks[id] = true
	LookService.CheckTitles(player)
end

-- ------------------------------------------------------------------ pack de départ

function RewardsService.OfferStarterPack(player: Player)
	local data = DataService.Get(player)
	if not data or STARTER.productId == 0 or data.Unlocks.DayOne or data.Tips.StarterOffer then
		return
	end
	data.Tips.StarterOffer = true
	Remotes.RewardsPopup:FireClient(player, {
		kind = "Starter",
		delay = STARTER.OfferDelay,
		productId = STARTER.productId,
		robux = STARTER.robux,
		cash = STARTER.cash,
		minutes = math.floor(STARTER.boostDuration / 60 + 0.5),
	})
end

local function starterHandler(player: Player): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	-- Racheté malgré tout (deux fenêtres d'achat ouvertes) : le joueur reçoit quand même le Cash et le boost
	StatsService.Add(player, "Cash", STARTER.cash)
	BoostService.GrantPaid(player, STARTER.boostMultiplier, STARTER.boostDuration)
	unlock(player, data, STARTER.unlock)
	Remotes.PurchaseDone:FireClient(player, { kind = "Cash", amount = STARTER.cash })
	sendState(player)
	return true
end

local function buyStarter(player: Player)
	local data = DataService.Get(player)
	if not data or STARTER.productId == 0 or data.Unlocks.DayOne or MinigameService.IsBusy(player) then
		return
	end
	MarketplaceService:PromptProductPurchase(player, STARTER.productId)
end

-- ------------------------------------------------------------------ groupe, codes, nouveautés

local function claimGroup(player: Player)
	local group = Rewards.Group
	local data = DataService.Get(player)
	if group.GroupId == 0 or not data or data.Unlocks[group.Title] then
		return
	end
	local ok, member = pcall(function()
		return player:IsInGroupAsync(group.GroupId)
	end)
	if not ok then
		Remotes.Notify:FireClient(player, { key = "Rewards.TryLater" })
		return
	end
	if not member then
		Remotes.Notify:FireClient(player, { key = "Rewards.GroupJoinFirst" })
		return
	end
	StatsService.Add(player, "Cash", group.Cash)
	unlock(player, data, group.Title)
	Remotes.Notify:FireClient(player, { key = "Rewards.GroupThanks", args = { amount = group.Cash } })
	Analytics.Event(player, "GroupReward")
	sendState(player)
end

local function redeem(player: Player, raw: unknown)
	if typeof(raw) ~= "string" or #raw == 0 or #raw > Rewards.CodeMaxLength * 2 then
		return
	end
	local now = os.clock()
	if now - (lastCode[player] or -math.huge) < Rewards.CodeCooldown then
		return
	end
	lastCode[player] = now
	local data = DataService.Get(player)
	if not data then
		return
	end
	local code = string.upper((string.gsub(raw, "%s", "")))
	local entry = if #code <= Rewards.CodeMaxLength then Rewards.Codes[code] else nil
	if not entry or (entry.Expires and entry.Expires > 0 and os.time() > entry.Expires) then
		Remotes.Notify:FireClient(player, { key = "Rewards.CodeInvalid" })
		return
	end
	if data.Codes[code] then
		Remotes.Notify:FireClient(player, { key = "Rewards.CodeUsed" })
		return
	end
	data.Codes[code] = true
	if entry.Cash then
		StatsService.Add(player, "Cash", entry.Cash)
		Remotes.Notify:FireClient(player, { key = "Rewards.CodeCash", args = { amount = entry.Cash } })
	end
	if entry.BoostMultiplier and entry.BoostSeconds then
		BoostService.GrantPaid(player, entry.BoostMultiplier, entry.BoostSeconds)
		Remotes.Notify:FireClient(player, {
			key = "Rewards.CodeBoost",
			args = { multiplier = entry.BoostMultiplier, minutes = math.floor(entry.BoostSeconds / 60 + 0.5) },
		})
	end
	Analytics.Event(player, "CodeRedeemed", 1, code)
end

local function onAction(player: Player, action: unknown, arg: unknown)
	if action == "SeeNews" then
		local data = DataService.Get(player)
		if data and data.NewsSeen ~= Rewards.News.Version then
			data.NewsSeen = Rewards.News.Version
			sendState(player)
		end
	elseif action == "ClaimGroup" then
		claimGroup(player)
	elseif action == "Redeem" then
		redeem(player, arg)
	elseif action == "BuyStarter" then
		buyStarter(player)
	end
end

-- ------------------------------------------------------------------ ami invité

local function rememberReferral(player: Player, data)
	-- Seulement un nouveau joueur (aucune série encore faite)
	if data.ReferredBy ~= 0 or data.Funnel.FirstRep then
		return
	end
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local by = ok and typeof(joinData) == "table" and tonumber(joinData.ReferredByPlayerId) or 0
	if by and by > 0 and by ~= player.UserId then
		data.ReferredBy = by
	end
end

-- Appelé par ExerciseService à la fin d'une série avec au moins une répétition
function RewardsService.OnSeriesDone(player: Player)
	local data = DataService.Get(player)
	if not data or data.ReferredBy == 0 or data.ReferralPaid then
		return
	end
	local referrer = Players:GetPlayerByUserId(data.ReferredBy)
	local referrerData = referrer and DataService.Get(referrer)
	if not referrer or not referrerData then
		return -- réessayé à la série suivante (celui qui a invité peut arriver plus tard)
	end
	data.ReferralPaid = true
	StatsService.Add(referrer, "Cash", Rewards.Referral.Cash)
	unlock(referrer, referrerData, Rewards.Referral.Title)
	Remotes.Notify:FireClient(
		referrer,
		{ key = "Rewards.ReferralThanks", args = { name = player.DisplayName, amount = Rewards.Referral.Cash } }
	)
	Analytics.Event(referrer, "ReferralReward")
end

-- ------------------------------------------------------------------ bonus d'équipe

local function friendCount(player: Player): number
	local count = 0
	for other in friends[player] or {} do
		if other.Parent == Players then
			count += 1
		end
	end
	return count
end

local function refreshFriendBonus(player: Player)
	local bonus = math.min(friendCount(player) * Rewards.Friends.BonusPerFriend, Rewards.Friends.MaxBonus)
	-- Affiché par le client à côté du Mog (en pourcentage entier)
	player:SetAttribute("FriendBonus", if bonus > 0 then math.floor(bonus * 100 + 0.5) else nil)
end

local function linkFriends(a: Player, b: Player)
	local ok, isFriend = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	if not ok or not isFriend or a.Parent ~= Players or b.Parent ~= Players then
		return
	end
	friends[a] = friends[a] or {}
	friends[b] = friends[b] or {}
	friends[a][b] = true
	friends[b][a] = true
	refreshFriendBonus(a)
	refreshFriendBonus(b)
end

function RewardsService.FriendMultiplier(player: Player): number
	return 1 + math.min(friendCount(player) * Rewards.Friends.BonusPerFriend, Rewards.Friends.MaxBonus)
end

-- ------------------------------------------------------------------ Golden Pump Hour

-- Début et fin de la prochaine Golden Pump Hour (ou de celle en cours), en os.time()
local function goldenWindow(now: number): (number, number)
	local today = os.date("!*t", now) :: any
	local midnight = now - (today.hour * 3600 + today.min * 60 + today.sec)
	for offset = -1, 7 do
		local day = midnight + offset * 86400
		local weekDay = (os.date("!*t", day) :: any).wday
		if weekDay == GOLDEN.WeekDay then
			local starts = day + GOLDEN.Hour * 3600
			if starts + GOLDEN.Duration > now then
				return starts, starts + GOLDEN.Duration
			end
		end
	end
	return math.huge, math.huge
end

function RewardsService.GoldenMultiplier(): number
	local now = os.time()
	local starts, ends = goldenWindow(now)
	return if now >= starts and now < ends then GOLDEN.Multiplier else 1
end

local function tickGolden(wasActive: boolean): boolean
	local now = os.time()
	local starts, ends = goldenWindow(now)
	local active = now >= starts and now < ends
	-- Le client affiche le compte à rebours ou le temps restant d'après ces deux heures
	workspace:SetAttribute("GoldenHourStart", if starts < math.huge then starts else nil)
	workspace:SetAttribute("GoldenHourEnd", if ends < math.huge then ends else nil)
	if active and not wasActive then
		Remotes.Notify:FireAllClients({ key = "Rewards.GoldenStarted", args = { multiplier = GOLDEN.Multiplier } })
	end
	return active
end

-- ------------------------------------------------------------------ shaker de protéines (absence)

local function awayReward(player: Player, data)
	local now = os.time()
	local last = tonumber(data.LastSeen) or 0
	data.LastSeen = now
	if last <= 0 or now - last < Rewards.Away.MinSeconds then
		return
	end
	local seconds = math.min(now - last, Rewards.Away.MaxSeconds)
	local rates = Rewards.Away.CashPerHourByStage
	local rate = rates[math.clamp(data.Stage, 1, #rates)]
	local cash = math.floor(rate * seconds / 3600)
	if cash <= 0 then
		return
	end
	StatsService.Add(player, "Cash", cash)
	Remotes.RewardsPopup:FireClient(player, {
		kind = "Away",
		cash = cash,
		hours = math.floor(seconds / 3600 * 10 + 0.5) / 10,
		capped = now - last >= Rewards.Away.MaxSeconds,
	})
end

-- ------------------------------------------------------------------ démarrage

local function onLoaded(player: Player, data)
	rememberReferral(player, data)
	awayReward(player, data)
	sendState(player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(linkFriends, player, other)
		end
	end
end

function RewardsService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
	BoostService = services.BoostService
	LookService = services.LookService
	MinigameService = services.MinigameService
	PurchaseService = services.PurchaseService
end

function RewardsService.Start()
	PurchaseService.Register(STARTER.productId, starterHandler)
	Remotes.RewardsAction.OnServerEvent:Connect(Throttle.Wrap(0.3, onAction))
	DataService.PlayerLoaded:Connect(onLoaded)
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data then
			task.spawn(onLoaded, player, data)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		local data = DataService.Get(player)
		if data then
			data.LastSeen = os.time()
		end
		for other in friends[player] or {} do
			if friends[other] then
				friends[other][player] = nil
				refreshFriendBonus(other)
			end
		end
		friends[player] = nil
		lastCode[player] = nil
	end)
	-- Heure de présence (gain pendant l'absence) et Golden Pump Hour
	task.spawn(function()
		local golden = false
		local sinceSave = 0
		while true do
			golden = tickGolden(golden)
			sinceSave += 15
			if sinceSave >= Rewards.Away.SaveEvery then
				sinceSave = 0
				local now = os.time()
				for _, player in Players:GetPlayers() do
					local data = DataService.Get(player)
					if data then
						data.LastSeen = now
					end
				end
			end
			task.wait(15)
		end
	end)
end

return RewardsService
