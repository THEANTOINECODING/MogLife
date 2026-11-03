--[[
	Simulation de la progression et de l'économie de MOG LIFE (Normie -> seuil de Pump God).
	Demandée par design/03_PROGRESSION.md avant toute retouche globale des chiffres.

	UTILISATION : ouvrir le jeu dans Roblox Studio (Rojo connecté), copier tout ce fichier dans la
	barre de commande de Studio (Affichage > Barre de commande), Entrée. Le rapport s'affiche dans la Sortie.
	Les valeurs viennent directement de src/shared/Config/ (y compris boosts et événements).
	Le script ne lit ni ne modifie les données d'un joueur.

	Ce n'est PAS une session humaine : c'est une estimation avec des hypothèses déclarées ci-dessous.
	Les combats de boss sont estimés avec le score MOYEN du joueur et du boss à chaque manche
	(manches de plus en plus dures pour le joueur, boss de plus en plus précis).
]]

local Config = game:GetService("ReplicatedStorage").Shared.Config
local Balance = require(Config.Balance)
local Exercises = require(Config.Exercises)
local Stages = require(Config.Stages)
local Helps = require(Config.Helps)
local StyleItems = require(Config.StyleItems)
local Boosts = require(Config.Boosts)
local Events = require(Config.Events)

local BOSS = Balance.Boss
local LAST_STAGE = 6 -- Pump God est annoncé mais pas encore jouable

-- Hypothèses communes (secondes)
local ASSUME = {
	SeriesOverhead = 4, -- écran de fin + relance
	WalkBetweenSpots = 6, -- trajet entre station, habitant, boss, miroir
	HelpOverhead = 3,
	BossOverhead = 10, -- fenêtre de défi, scènes, pauses
	SeriesBetweenHelps = 2, -- le joueur fait 2 séries d'entraînement entre deux aides
	EventDetour = 8,
	ShopDetour = 6,
	MaxMinutes = 150,
	-- Le Dieu du Pump (arène, D94) n'a pas de Mog-off : on l'approxime par un Mog-off de ce niveau
	ArenaBoss = { interval = 2.2, skill = { perfect = 0.55, good = 0.4 } },
}

-- Profils : répartition Perfect / Good en jeu actif, et comportement
local PROFILES = {
	-- Le mode auto a été retiré (D79) : le profil le plus faible est un joueur maladroit sans aides
	{ name = "1. Joueur faible, aucune aide", helps = false, perfect = 0.15, good = 0.45 },
	{
		name = "2. Joueur moyen, aides + événements",
		helps = true,
		events = 0.5,
		perfect = 0.3,
		good = 0.5,
		improves = true,
	},
	{ name = "3. Joueur précis, aides + événements", helps = true, events = 0.5, perfect = 0.6, good = 0.32 },
	{
		name = "4. Joueur moyen, boosts + pareur",
		helps = true,
		events = 0.5,
		boosts = true,
		spotter = true,
		perfect = 0.3,
		good = 0.5,
		improves = true,
	},
	{
		name = "5. Un look par stade",
		helps = true,
		events = 0.5,
		perfect = 0.3,
		good = 0.5,
		improves = true,
		spend = true,
	},
	-- Ces trois variantes reprennent les tirages du profil 2 pour isoler l'effet des boosts et du pareur.
	{
		name = "6. Joueur moyen, boosts seuls",
		seed = #"2. Joueur moyen, aides + événements" * 104729,
		helps = true,
		events = 0.5,
		boosts = true,
		perfect = 0.3,
		good = 0.5,
		improves = true,
	},
	{
		name = "7. Joueur moyen, pareur seul",
		seed = #"2. Joueur moyen, aides + événements" * 104729,
		helps = true,
		events = 0.5,
		spotter = true,
		perfect = 0.3,
		good = 0.5,
		improves = true,
	},
	{
		name = "8. Joueur moyen, boosts + pareur (mêmes tirages)",
		seed = #"2. Joueur moyen, aides + événements" * 104729,
		helps = true,
		events = 0.5,
		boosts = true,
		spotter = true,
		perfect = 0.3,
		good = 0.5,
		improves = true,
	},
}

local function expectedScore(perfect: number, good: number): number
	local q = BOSS.QualityScore
	return perfect * q.Perfect + good * q.Good + math.max(1 - perfect - good, 0) * q.Miss
end

local function comboMultiplier(streak: number): number
	local multiplier = 1
	for _, step in Balance.Combo.Steps do
		if streak >= step.at then
			multiplier = step.multiplier
		end
	end
	return multiplier
end

-- Le joueur gagne-t-il le Mog-off ?
local function winsFight(profile, boss): (boolean, number)
	local wins = 0
	for round = 1, BOSS.Rounds do
		local scale = BOSS.TimingScaleByRound[round] or 1
		-- Fenêtres plus serrées : une partie des Perfect devient Good, une partie des Good devient Miss
		local perfect = profile.perfect * scale
		local good = profile.good * scale + profile.perfect * (1 - scale)
		local player = expectedScore(perfect, good)
		local bonus = (round - 1) * BOSS.BossSkillBonusPerRound
		local skill = boss.skill or ASSUME.ArenaBoss.skill
		local opponent = expectedScore(skill.perfect + bonus, skill.good)
		if player > opponent then
			wins += 1
		end
		if wins >= BOSS.RoundsToWin or round - wins > BOSS.Rounds - BOSS.RoundsToWin then
			return wins >= BOSS.RoundsToWin, round
		end
	end
	return wins >= BOSS.RoundsToWin, BOSS.Rounds
end

local function bestExercise(stage: number)
	local bestId, bestRate = nil, 0
	for id, exercise in Exercises do
		if stage >= exercise.requiredStage then
			local rate = exercise.mogPerRep / exercise.repInterval
			if rate > bestRate then
				bestId, bestRate = id, rate
			end
		end
	end
	return bestId, Exercises[bestId]
end

local function cheapestAffordable(cash: number, owned)
	local bestId, bestPrice = nil, math.huge
	for id, item in StyleItems do
		if
			item.price
			and item.price > 0
			and not item.starter
			and not owned[id]
			and item.price <= cash
			and (item.price < bestPrice or (item.price == bestPrice and (not bestId or id < bestId)))
		then
			bestId, bestPrice = id, item.price
		end
	end
	return bestId, bestPrice
end

local function affordableStyle(cash: number, owned): string
	local count, examples = 0, {}
	for id, item in StyleItems do
		if item.price and item.price > 0 and not item.starter and not owned[id] and item.price <= cash then
			count += 1
			table.insert(examples, { id = id, price = item.price })
		end
	end
	table.sort(examples, function(a, b)
		return a.price < b.price or (a.price == b.price and a.id < b.id)
	end)
	local first = {}
	for i = 1, math.min(#examples, 3) do
		table.insert(first, string.format("%s (%d)", examples[i].id, examples[i].price))
	end
	return string.format("%d looks : %s", count, if #first > 0 then table.concat(first, ", ") else "aucun")
end

local function fmt(seconds: number?): string
	if not seconds then
		return "—"
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function simulate(baseProfile)
	local profile = table.clone(baseProfile)
	local randomState = profile.seed or #profile.name * 104729
	local function roll(): number
		randomState = (randomState * 16807) % 2147483647
		return randomState / 2147483647
	end
	local function quality(): string
		local value = roll()
		return if value < profile.perfect
			then "Perfect"
			elseif value < profile.perfect + profile.good then "Good"
			else "Miss"
	end

	local t, mog, cash, stage = 0, 0, 0, 1
	local owned, cooldowns, helpsDone, milestones, reached, styledStage = {}, {}, {}, {}, {}, {}
	local cashEarned, cashSpent, cashLost, eventCash, helpCash, boostCash = 0, 0, 0, 0, 0, 0
	local longestTraining, trainingStreak, seriesSinceHelp, seriesCount = 0, 0, 0, 0
	local nextEvent, eventNumber, eventsCaught = Events.FirstDelay, 0, 0
	local boostId, boostEnds = nil, 0
	local partnerMog, boughtBoosts, defeats = 0, 0, 0
	local blocked

	local function mark(name)
		table.insert(milestones, { name = name, at = t, cash = cash, styles = affordableStyle(cash, owned) })
	end
	local function checkFirstStyle()
		if not reached.firstStyle and cheapestAffordable(cash, owned) then
			reached.firstStyle = true
			mark("Premier style accessible")
		end
	end

	local eventKinds = { "GoldenDumbbells", "FreeShakes", "RunawayPiano" }
	local function processEvents()
		while t >= nextEvent do
			eventNumber += 1
			local kind = eventKinds[(eventNumber - 1) % #eventKinds + 1]
			if profile.events and roll() < profile.events then
				eventsCaught += 1
				t += ASSUME.EventDetour
				if kind == "FreeShakes" then
					local freeId = Events.FreeShakes.Boost
					local free = Boosts[freeId]
					if free and boostId == freeId and boostEnds > t then
						boostEnds = math.min(boostEnds + free.duration, t + Balance.BoostShop.MaxDuration)
					elseif
						free and (not boostId or boostEnds <= t or Boosts[boostId].mogMultiplier < free.mogMultiplier)
					then
						boostId, boostEnds = freeId, t + free.duration
					end
				else
					local amount = Events[kind].CashByStage[stage]
					cash += amount
					cashEarned += amount
					eventCash += amount
					checkFirstStyle()
				end
			end
			nextEvent += (Events.Interval[1] + Events.Interval[2]) / 2
		end
	end

	while t < ASSUME.MaxMinutes * 60 and stage <= LAST_STAGE do
		processEvents()
		local boss = Stages.List[stage].boss
		if boss and mog >= boss.mogRequired then
			if not reached[boss.id] then
				reached[boss.id] = true
				mark(boss.id .. " prêt")
			end
			if boss.comingSoon then
				break
			end
			local won, rounds = winsFight(profile, boss)
			local fightTime = ASSUME.WalkBetweenSpots + ASSUME.BossOverhead + BOSS.IntroTime
			for round = 1, rounds do
				fightTime += BOSS.RepsPerRound * (boss.interval or ASSUME.ArenaBoss.interval) * (BOSS.SpeedByRound[round] or 1)
			end
			t += fightTime + (rounds - 1) * BOSS.PauseBetweenRounds
			if won then
				stage += 1
				cash += boss.firstWinCash
				cashEarned += boss.firstWinCash
				mark(boss.id .. " battu")
				checkFirstStyle()
			else
				defeats += 1
				local loss = math.min(math.floor(cash * BOSS.MogOffLossPercent), BOSS.MogOffLossCap[stage])
				cash -= loss
				cashLost += loss
				if profile.improves then
					profile.perfect = math.min(profile.perfect + 0.05, 0.9)
					profile.good = math.min(profile.good, 0.95 - profile.perfect)
				else
					blocked = boss.id
					break
				end
			end
			trainingStreak, seriesSinceHelp = 0, 0
			continue
		end

		if profile.helps and seriesSinceHelp >= ASSUME.SeriesBetweenHelps then
			local bestHelp, bestCash = nil, -1
			for id, help in Helps do
				local value = if not helpsDone[id] then math.max(help.cash, help.firstCash or 0) else help.cash
				if stage >= help.requiredStage and (cooldowns[id] or 0) <= t and value > bestCash then
					bestHelp, bestCash = id, value
				end
			end
			if bestHelp then
				local help = Helps[bestHelp]
				local reps = help.reps or Balance.Helps.Reps
				local earned, streak, chain, misses = 0, 0, 0, 0
				for _ = 1, reps do
					local q = quality()
					streak = if q == "Miss" then 0 else streak + 1
					chain = if q == "Perfect" then chain + 1 else 0
					if q == "Miss" then
						misses += 1
					end
					local chainBonus = 1
						+ math.min(
							math.max(chain - 1, 0) * Balance.Helps.Reward.PerfectChainStep,
							Balance.Helps.Reward.PerfectChainMax
						)
					earned += help.cash / reps * Balance.Helps.Reward.Scale * (Balance.Helps.Reward.Quality[q] or 0) * comboMultiplier(
						streak
					) * chainBonus
				end
				local paid = math.floor(earned * (if misses == 0 then Balance.Helps.Reward.Flawless else 1) + 0.5)
				if paid > 0 and not helpsDone[bestHelp] and help.firstCash then
					paid = math.max(paid, help.firstCash)
				end
				t += ASSUME.WalkBetweenSpots + ASSUME.HelpOverhead + reps * help.interval
				cash += paid
				cashEarned += paid
				helpCash += paid
				if paid > 0 then
					helpsDone[bestHelp] = true
					cooldowns[bestHelp] = t + Balance.Helps.Cooldown
				end
				checkFirstStyle()
				trainingStreak, seriesSinceHelp = 0, 0
				continue
			end
		end

		if profile.spend and not styledStage[stage] then
			local itemId, price = cheapestAffordable(cash, owned)
			if itemId then
				t += ASSUME.ShopDetour
				cash -= price
				cashSpent += price
				owned[itemId] = true
				styledStage[stage] = true
				mark("Style acheté : " .. itemId)
				continue
			end
		end

		if profile.boosts and t >= boostEnds then
			local chosenId, chosen
			for id, boost in Boosts do
				if
					stage >= boost.requiredStage
					and cash >= boost.price
					and (not chosen or boost.mogMultiplier > chosen.mogMultiplier)
				then
					chosenId, chosen = id, boost
				end
			end
			if chosen then
				t += ASSUME.ShopDetour
				cash -= chosen.price
				cashSpent += chosen.price
				boostCash += chosen.price
				boostId, boostEnds = chosenId, t + chosen.duration
				boughtBoosts += 1
			end
		end

		local id, exercise = bestExercise(stage)
		local duration = Balance.SeriesLength * exercise.repInterval + ASSUME.SeriesOverhead
		seriesCount += 1
		local spotted = profile.spotter and seriesCount % 2 == 0
		local streak = 0
		for rep = 1, Balance.SeriesLength do
			local q = quality()
			streak = if q == "Miss" then 0 else streak + 1
			local boost = if boostId and t + rep * exercise.repInterval < boostEnds
				then Boosts[boostId].mogMultiplier
				else 1
			local spot = if spotted then 1 + Balance.Spot.LifterBonus else 1
			local gain = exercise.mogPerRep * Balance.Quality[q] * comboMultiplier(streak) * boost * spot
			mog += gain
			if spotted then
				partnerMog += gain * Balance.Spot.SpotterShare
			end
		end
		t += duration
		trainingStreak += duration
		seriesSinceHelp += 1
		longestTraining = math.max(longestTraining, trainingStreak)
		if not reached["Exercice " .. id] then
			reached["Exercice " .. id] = true
			mark("Exercice " .. id)
		end
	end

	local count = 0
	for _ in owned do
		count += 1
	end
	return {
		milestones = milestones,
		finalTime = t,
		mog = mog,
		stage = stage,
		cash = cash,
		cashEarned = cashEarned,
		cashSpent = cashSpent,
		cashLost = cashLost,
		helpCash = helpCash,
		eventCash = eventCash,
		boostCash = boostCash,
		boughtBoosts = boughtBoosts,
		eventsCaught = eventsCaught,
		partnerMog = partnerMog,
		defeats = defeats,
		blocked = blocked,
		items = count,
		longestTraining = longestTraining,
	}
end
local lines = {
	"===== SIMULATION ÉCONOMIE MOG LIFE : règles actuelles =====",
	"Hypothèses : serveur neuf, événements toutes les 10 min 30 (types alternés), 2 séries entre aides.",
	"Le profil moyen gagne 5 points de Perfect après chaque défaite ; le pareur aide une série sur deux.",
	"Profils 2, 6, 7 et 8 : mêmes tirages aléatoires pour comparer séparément boosts et pareur.",
	"Les coûts de style sont affichés sans achat sauf dans le profil 5 ; Pump God reste coming soon.",
}
for _, profile in PROFILES do
	local r = simulate(profile)
	table.insert(lines, "")
	table.insert(lines, "--- " .. profile.name)
	for _, entry in r.milestones do
		table.insert(
			lines,
			string.format("  %s  %s | Cash %d | %s", fmt(entry.at), entry.name, entry.cash, entry.styles)
		)
	end
	table.insert(
		lines,
		string.format(
			"  Fin %s | stade %d | Mog %d | Cash gagné %d (aides %d, événements %d), dépensé %d (boosts %d), perdu %d, restant %d | looks %d",
			fmt(r.finalTime),
			r.stage,
			math.floor(r.mog),
			r.cashEarned,
			r.helpCash,
			r.eventCash,
			r.cashSpent,
			r.boostCash,
			r.cashLost,
			r.cash,
			r.items
		)
	)
	table.insert(
		lines,
		string.format(
			"  Défaites %d | événements saisis %d | boosts achetés %d | Mog du pareur %.0f | entraînement seul max %s",
			r.defeats,
			r.eventsCaught,
			r.boughtBoosts,
			r.partnerMog,
			fmt(r.longestTraining)
		)
	)
	if r.blocked then
		table.insert(lines, "  Progression bloquée par " .. r.blocked .. " avec la précision supposée.")
	end
end
local report = table.concat(lines, "\n")
print(report)
return report
