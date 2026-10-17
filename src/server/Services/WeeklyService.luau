-- Récompenses de la semaine (D67, Config/Weekly.luau) :
-- - 3 défis tirés au sort chaque lundi (les mêmes pour tous), suivis par WeeklyService.Track depuis les autres
--   services ; chaque défi réussi se réclame (Cash), les 3 réclamés donnent un trophée et un bonus ;
-- - un coffre : chaque jour où l'on joue quelques minutes coche une case ; il s'ouvre le dimanche.
-- Changement de semaine : ce qui était gagné mais pas réclamé (défis, bonus, coffre) est versé automatiquement,
-- jamais perdu. Le serveur décide de tout ; le client n'envoie que « réclamer tel défi ».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weekly = require(ReplicatedStorage.Shared.Config.Weekly)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DAY = 86_400
local WEEK = 7 * DAY
-- Le 1er janvier 1970 était un jeudi : le premier lundi 00:00 UTC tombe 4 jours plus tard
local FIRST_MONDAY = 4 * DAY

type Challenge = { id: string, stat: string, target: number }

local DataService
local StatsService
local LookService

local lastTick: { [Player]: number } = {}
local lastClaim: { [Player]: number } = {}
local pendingSend: { [Player]: boolean } = {}

local WeeklyService = {}

function WeeklyService.WeekIndex(t: number): number
	return (t - FIRST_MONDAY) // WEEK
end

-- Jour de la semaine : 1 = lundi … 7 = dimanche
local function weekDay(t: number): number
	return ((t - FIRST_MONDAY) % WEEK) // DAY + 1
end

local function findChallenge(id: string): Challenge?
	for _, pool in Weekly.Pools do
		for _, entry in pool do
			if entry.id == id then
				return entry
			end
		end
	end
	return nil
end

-- Les 3 défis de la semaine : un par groupe, tirés avec le numéro de la semaine (identiques sur tous les serveurs)
local function pick(week: number): { string }
	local rng = Random.new(week * 7919 + 17)
	local ids = {}
	for _, pool in Weekly.Pools do
		table.insert(ids, pool[rng:NextInteger(1, #pool)].id)
	end
	return ids
end

local function byStage(list: { number }, stage: number): number
	return list[math.clamp(stage, 1, #list)]
end

local function stamps(weekly: any): number
	local count = 0
	for day = 1, 7 do
		if weekly.Days[`D{day}`] then
			count += 1
		end
	end
	return count
end

local function chestCash(data: any, count: number): number
	if count <= 0 then
		return 0
	end
	local base = Weekly.ChestCash[math.min(count, #Weekly.ChestCash)]
	return math.floor(base * byStage(Weekly.ChestStageScale, data.Stage) + 0.5)
end

local function isDone(weekly: any, index: number): boolean
	local challenge = findChallenge(weekly.Challenges[index] or "")
	return challenge ~= nil and (weekly.Stats[challenge.stat] or 0) >= challenge.target
end

local function allClaimed(weekly: any): boolean
	if #weekly.Challenges == 0 then
		return false
	end
	for index in weekly.Challenges do
		if not weekly.Claimed[index] then
			return false
		end
	end
	return true
end

local function notify(player: Player, key: string, args: { [string]: any }?)
	Remotes.Notify:FireClient(player, { key = key, args = args })
end

-- ------------------------------------------------------------------ état envoyé au client

local function buildState(data: any)
	local weekly = data.Weekly
	local now = os.time()
	local today = weekDay(now)
	local challenges = {}
	for index, id in weekly.Challenges do
		local challenge = findChallenge(id)
		if challenge then
			table.insert(challenges, {
				id = id,
				target = challenge.target,
				progress = math.min(weekly.Stats[challenge.stat] or 0, challenge.target),
				claimed = weekly.Claimed[index] == true,
				cash = byStage(Weekly.ChallengeCash, data.Stage),
			})
		end
	end
	local days = {}
	for day = 1, 7 do
		days[day] = weekly.Days[`D{day}`] == true
	end
	local count = stamps(weekly)
	return {
		now = now,
		endsAt = FIRST_MONDAY + (weekly.Week + 1) * WEEK,
		day = today,
		challenges = challenges,
		bonus = {
			cash = byStage(Weekly.BonusCash, data.Stage),
			claimed = weekly.Bonus,
			ready = allClaimed(weekly) and not weekly.Bonus,
		},
		chest = {
			days = days,
			stamps = count,
			cash = chestCash(data, math.max(count, 1)),
			opened = weekly.Chest,
			openDay = Weekly.ChestDay,
			canOpen = not weekly.Chest and count > 0 and today >= Weekly.ChestDay,
			minutes = Weekly.MinutesForDay,
			todayDone = days[today],
		},
		trophies = weekly.Trophies,
		duels = { wins = data.Duels.Wins, losses = data.Duels.Losses, draws = data.Duels.Draws },
	}
end

local function send(player: Player)
	local data = DataService.Get(player)
	if data then
		Remotes.WeeklyState:FireClient(player, buildState(data))
	end
end

-- Plusieurs changements rapprochés (une série de Perfect) : un seul envoi
function WeeklyService.Refresh(player: Player)
	if pendingSend[player] then
		return
	end
	pendingSend[player] = true
	task.delay(0.5, function()
		pendingSend[player] = nil
		if player.Parent then
			send(player)
		end
	end)
end

-- ------------------------------------------------------------------ changement de semaine

-- Trophée de la semaine (les 3 défis réussis) ; les titres exclusifs qu'il débloque sont annoncés
local function grantTrophy(player: Player, data: any)
	data.Weekly.Trophies += 1
	LookService.CheckTitles(player)
end

-- Nouvelle semaine : on verse ce qui était gagné mais pas réclamé, puis on tire les nouveaux défis
local function rollover(player: Player, data: any)
	local weekly = data.Weekly
	local week = WeeklyService.WeekIndex(os.time())
	if weekly.Week == week then
		return
	end
	local owed = 0
	if weekly.Week > 0 then
		local everyDone = #weekly.Challenges > 0
		for index in weekly.Challenges do
			if isDone(weekly, index) then
				if not weekly.Claimed[index] then
					owed += byStage(Weekly.ChallengeCash, data.Stage)
				end
			else
				everyDone = false
			end
		end
		if everyDone and not weekly.Bonus then
			owed += byStage(Weekly.BonusCash, data.Stage)
			grantTrophy(player, data)
			notify(player, "Weekly.TrophyLate", { count = weekly.Trophies })
		end
		if not weekly.Chest then
			owed += chestCash(data, stamps(weekly))
		end
	end
	weekly.Week = week
	weekly.Challenges = pick(week)
	weekly.Claimed = { false, false, false }
	weekly.Bonus = false
	weekly.Days = {}
	weekly.Chest = false
	weekly.Stats = {}
	if owed > 0 then
		StatsService.Add(player, "Cash", owed)
		notify(player, "Weekly.Carried", { cash = owed })
	end
end

-- ------------------------------------------------------------------ suivi

-- Ajoute `amount` au compteur `stat` de la semaine (Config/Weekly.luau Pools). Annonce un défi qui vient d'être réussi.
function WeeklyService.Track(player: Player, stat: string, amount: number?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	rollover(player, data)
	local weekly = data.Weekly
	local before = {}
	for index in weekly.Challenges do
		before[index] = isDone(weekly, index)
	end
	weekly.Stats[stat] = (weekly.Stats[stat] or 0) + (amount or 1)
	local changed = false
	for index, id in weekly.Challenges do
		local challenge = findChallenge(id)
		if challenge and challenge.stat == stat then
			changed = true
			if not before[index] and isDone(weekly, index) then
				notify(player, "Weekly.ChallengeDone", { challenge = { key = `Weekly.Short.{id}` } })
			end
		end
	end
	if changed then
		WeeklyService.Refresh(player)
	end
end

-- Temps de jeu du jour : au bout de MinutesForDay minutes, la case du jour du coffre est cochée
local function tick(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	rollover(player, data)
	local weekly = data.Weekly
	local now = os.time()
	local clock = os.clock()
	local elapsed = math.min(clock - (lastTick[player] or clock), Weekly.TickSeconds * 2)
	lastTick[player] = clock
	local dayNumber = now // DAY
	if weekly.DayStamp ~= dayNumber then
		weekly.DayStamp = dayNumber
		weekly.Seconds = 0
	end
	weekly.Seconds += elapsed
	local key = `D{weekDay(now)}`
	if not weekly.Days[key] and weekly.Seconds >= Weekly.MinutesForDay * 60 then
		weekly.Days[key] = true
		notify(player, "Weekly.DayStamped", { count = stamps(weekly) })
		WeeklyService.Refresh(player)
	end
end

-- ------------------------------------------------------------------ réclamer

local function onClaim(player: Player, what: unknown, index: unknown)
	local data = DataService.Get(player)
	local clock = os.clock()
	if not data or typeof(what) ~= "string" or clock - (lastClaim[player] or 0) < 0.3 then
		return
	end
	lastClaim[player] = clock
	rollover(player, data)
	local weekly = data.Weekly
	if what == "Challenge" then
		if typeof(index) ~= "number" or index % 1 ~= 0 or weekly.Challenges[index] == nil then
			return
		end
		if weekly.Claimed[index] or not isDone(weekly, index) then
			return
		end
		weekly.Claimed[index] = true
		local cash = byStage(Weekly.ChallengeCash, data.Stage)
		StatsService.Add(player, "Cash", cash)
		notify(player, "Weekly.ClaimedCash", { cash = cash })
	elseif what == "Bonus" then
		if weekly.Bonus or not allClaimed(weekly) then
			return
		end
		weekly.Bonus = true
		local cash = byStage(Weekly.BonusCash, data.Stage)
		StatsService.Add(player, "Cash", cash)
		grantTrophy(player, data)
		notify(player, "Weekly.Trophy", { count = weekly.Trophies, cash = cash })
	elseif what == "Chest" then
		local count = stamps(weekly)
		if weekly.Chest or count == 0 or weekDay(os.time()) < Weekly.ChestDay then
			return
		end
		weekly.Chest = true
		local cash = chestCash(data, count)
		StatsService.Add(player, "Cash", cash)
		notify(player, "Weekly.ChestReward", { cash = cash, days = count })
	else
		return
	end
	send(player)
end

function WeeklyService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
	LookService = services.LookService
end

function WeeklyService.Start()
	DataService.PlayerLoaded:Connect(function(player)
		lastTick[player] = os.clock()
		tick(player)
		send(player)
	end)
	Remotes.WeeklyClaim.OnServerEvent:Connect(onClaim)
	Remotes.RequestStats.OnServerEvent:Connect(send)
	task.spawn(function()
		while true do
			task.wait(Weekly.TickSeconds)
			for _, player in Players:GetPlayers() do
				tick(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastTick[player] = nil
		lastClaim[player] = nil
		pendingSend[player] = nil
	end)
end

return WeeklyService
