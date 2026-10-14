--[[
	Simulation de la progression et de l'économie de MOG LIFE (MVP : Normie -> Gigachad).
	Demandée par design/03_PROGRESSION.md avant toute retouche globale des chiffres.

	UTILISATION : ouvrir le jeu dans Roblox Studio (Rojo connecté), copier tout ce fichier dans la
	barre de commande de Studio (Affichage > Barre de commande), Entrée. Le rapport s'affiche dans la Sortie.
	Les valeurs viennent directement de src/shared/Config/ (Balance, Exercises, Stages, Helps, StyleItems).

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

local BOSS = Balance.Boss
local LAST_STAGE = 6 -- le MVP s'arrête à Gigachad (le Dieu du Pump arrive plus tard)

-- Hypothèses communes (secondes)
local ASSUME = {
	SeriesOverhead = 4, -- écran de fin + relance
	WalkBetweenSpots = 6, -- trajet entre station, habitant, boss, miroir
	HelpOverhead = 3,
	BossOverhead = 10, -- fenêtre de défi, scènes, pauses
	MaxMinutes = 150,
}

-- Profils : répartition Perfect / Good en jeu actif, et comportement
local PROFILES = {
	{ name = "1. Mode auto, aucune aide", auto = true, helps = false, perfect = 0.3, good = 0.5 },
	{ name = "2. Joueur moyen, aides", helps = true, perfect = 0.3, good = 0.5 },
	{ name = "3. Joueur précis, aides", helps = true, perfect = 0.6, good = 0.32 },
	{ name = "4. Joueur moyen qui progresse", helps = true, perfect = 0.3, good = 0.5, improves = true },
	{ name = "5. Dépense tout en style", helps = true, perfect = 0.3, good = 0.5, spend = true },
}

local function expectedScore(perfect: number, good: number): number
	local q = BOSS.QualityScore
	return perfect * q.Perfect + good * q.Good + math.max(1 - perfect - good, 0) * q.Miss
end

local function trainingMultiplier(profile): number
	if profile.auto then
		return Balance.Quality.Auto
	end
	local miss = 1 - profile.perfect - profile.good
	return profile.perfect * Balance.Quality.Perfect + profile.good * Balance.Quality.Good + miss * Balance.Quality.Miss
end

-- Le joueur gagne-t-il le Mog-off ? (le mode auto est interdit en combat : le joueur « auto » joue normalement)
local function winsFight(profile, boss): (boolean, string)
	local wins, details = 0, {}
	for round = 1, BOSS.Rounds do
		local scale = BOSS.TimingScaleByRound[round] or 1
		-- Fenêtres plus serrées : une partie des Perfect devient Good, une partie des Good devient Miss
		local perfect = profile.perfect * scale
		local good = profile.good * scale + profile.perfect * (1 - scale)
		local player = expectedScore(perfect, good)
		local bonus = (round - 1) * 0.05
		local opponent = expectedScore(boss.skill.perfect + bonus, boss.skill.good)
		table.insert(details, `{math.floor(player)}-{math.floor(opponent)}`)
		if player > opponent then
			wins += 1
		end
	end
	return wins >= BOSS.RoundsToWin, table.concat(details, " ")
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
		if item.price and not owned[id] and item.price <= cash and item.price < bestPrice then
			bestId, bestPrice = id, item.price
		end
	end
	return bestId, bestPrice
end

local function fmt(seconds: number?): string
	if not seconds then
		return "—"
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function simulate(baseProfile)
	local profile = table.clone(baseProfile)
	local t, mog, cash, stage = 0, 0, 0, 1
	local owned, cooldowns, milestones = {}, {}, {}
	local cashEarned, cashSpent, cashLost = 0, 0, 0
	local longestTraining, trainingStreak = 0, 0

	local function mark(name)
		if not milestones[name] then
			milestones[name] = t
		end
	end

	while t < ASSUME.MaxMinutes * 60 and stage < LAST_STAGE do
		local boss = Stages.List[stage].boss
		local acted = false

		-- 1. Défier le boss dès que le Mog requis est atteint
		if boss and mog >= boss.mogRequired then
			t += ASSUME.WalkBetweenSpots + ASSUME.BossOverhead + BOSS.Rounds * BOSS.RepsPerRound * boss.interval
			local won, details = winsFight(profile, boss)
			if won then
				stage += 1
				cash += boss.firstWinCash
				cashEarned += boss.firstWinCash
				mark(`Boss {boss.id} battu ({details})`)
			else
				local loss = math.min(math.floor(cash * BOSS.MogOffLossPercent), BOSS.MogOffLossCap[stage])
				cash -= loss
				cashLost += loss
				if profile.improves then
					-- Le joueur s'entraîne et devient un peu plus précis à chaque défaite
					profile.perfect = math.min(profile.perfect + 0.05, 0.9)
					profile.good = math.min(profile.good, 0.95 - profile.perfect)
					mark(`Défaite contre {boss.id} ({details}), le joueur progresse`)
				else
					mark(`BLOQUÉ par {boss.id} ({details})`)
					break
				end
			end
			trainingStreak = 0
			acted = true
		end

		-- 2. Aider quelqu'un si une aide est disponible
		if not acted and profile.helps then
			local bestHelp, bestCash = nil, 0
			for id, help in Helps do
				if stage >= help.requiredStage and (cooldowns[id] or 0) <= t and help.cash > bestCash then
					bestHelp, bestCash = id, help.cash
				end
			end
			if bestHelp then
				local help = Helps[bestHelp]
				t += ASSUME.WalkBetweenSpots + ASSUME.HelpOverhead + (help.reps or Balance.Helps.Reps) * help.interval
				cash += help.cash
				cashEarned += help.cash
				cooldowns[bestHelp] = t + Balance.Helps.Cooldown
				mark("Première aide")
				trainingStreak = 0
				acted = true
			end
		end

		-- 3. Acheter du style
		if not acted then
			local itemId, price = cheapestAffordable(cash, owned)
			if itemId and (profile.spend or not milestones["Premier achat"]) then
				t += ASSUME.WalkBetweenSpots
				cash -= price
				cashSpent += price
				owned[itemId] = true
				mark("Premier achat")
				acted = true
			end
		end

		-- 4. Sinon, une série du meilleur exercice débloqué
		if not acted then
			local id, exercise = bestExercise(stage)
			local duration = Balance.SeriesLength * exercise.repInterval + ASSUME.SeriesOverhead
			t += duration
			mog += Balance.SeriesLength * exercise.mogPerRep * trainingMultiplier(profile)
			trainingStreak += duration
			longestTraining = math.max(longestTraining, trainingStreak)
			mark(`Exercice {id}`)
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
		cash = cash,
		cashEarned = cashEarned,
		cashSpent = cashSpent,
		cashLost = cashLost,
		items = count,
		longestTraining = longestTraining,
	}
end

local lines = { "", "===== SIMULATION ÉCONOMIE MOG LIFE (MVP jusqu'à Gigachad) =====" }
for _, profile in PROFILES do
	local r = simulate(profile)
	table.insert(lines, "")
	table.insert(lines, `--- {profile.name} (entraînement x{string.format("%.2f", trainingMultiplier(profile))})`)
	local entries = {}
	for name, at in r.milestones do
		table.insert(entries, { name = name, at = at })
	end
	table.sort(entries, function(a, b)
		return a.at < b.at
	end)
	for _, e in entries do
		table.insert(lines, `  {fmt(e.at)}  {e.name}`)
	end
	table.insert(
		lines,
		`  Fin {fmt(r.finalTime)} | Mog {math.floor(r.mog)} | Cash gagné {r.cashEarned}, dépensé {r.cashSpent}, perdu {r.cashLost}, restant {r.cash} | objets {r.items}`
	)
	table.insert(lines, `  Plus longue période d'entraînement seul : {fmt(r.longestTraining)}`)
end
local report = table.concat(lines, "\n")
print(report)
return report
