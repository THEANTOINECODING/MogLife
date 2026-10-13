--[[
	Simulation de la progression et de l'économie de MOG LIFE (MVP : Normie -> Alpha).
	Demandée par design/03_PROGRESSION.md avant toute retouche globale des chiffres.

	UTILISATION : ouvrir le jeu dans Roblox Studio (Rojo connecté), copier tout ce fichier dans la
	barre de commande de Studio (Affichage > Barre de commande), Entrée. Le rapport s'affiche dans la Sortie.
	Les valeurs viennent directement de src/shared/Config/ (Balance, Exercises, Stages, Helps, StyleItems).

	Ce n'est PAS une session humaine : c'est une borne théorique avec des hypothèses déclarées ci-dessous.
	Comparer ensuite avec de vrais tests joueurs.
]]

local Config = game:GetService("ReplicatedStorage").Shared.Config
local Balance = require(Config.Balance)
local Exercises = require(Config.Exercises)
local Stages = require(Config.Stages)
local Helps = require(Config.Helps)
local StyleItems = require(Config.StyleItems)

-- Hypothèses communes (secondes)
local ASSUME = {
	SeriesOverhead = 4, -- écran de fin + relance
	WalkBetweenSpots = 6, -- trajet entre station, habitant, boss, miroir
	HelpOverhead = 3,
	BossOverhead = 8, -- fenêtre de défi, scènes, pauses
	MaxMinutes = 90,
}

-- Profils : répartition Perfect / Good / Miss en jeu actif, et comportement
local PROFILES = {
	{ name = "1. Mode auto, aucune aide", auto = true, helps = false, perfect = 0.2, good = 0.5, spend = false },
	{ name = "2. Joueur moyen, aides", auto = false, helps = true, perfect = 0.3, good = 0.5, spend = false },
	{ name = "3. Joueur précis, aides", auto = false, helps = true, perfect = 0.7, good = 0.25, spend = false },
	{ name = "4. Dépense tout en style", auto = false, helps = true, perfect = 0.3, good = 0.5, spend = true },
	{ name = "5. Défie les boss trop tôt", auto = false, helps = true, perfect = 0.3, good = 0.5, early = true },
}

local function averageMultiplier(profile): number
	if profile.auto then
		return Balance.Quality.Auto
	end
	local miss = 1 - profile.perfect - profile.good
	return profile.perfect * Balance.Quality.Perfect + profile.good * Balance.Quality.Good + miss * Balance.Quality.Miss
end

-- Score moyen de Mog-off : le mode auto est interdit en combat, le joueur « auto » joue alors comme un moyen
local function bossScore(profile): number
	local perfect, good = profile.perfect, profile.good
	if profile.auto then
		perfect, good = 0.3, 0.5
	end
	local q = Balance.Boss.QualityScore
	return perfect * q.Perfect + good * q.Good + (1 - perfect - good) * q.Miss
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

local function simulate(profile)
	local t, mog, cash, stage = 0, 0, 0, 1
	local owned, cooldowns = {}, {}
	local milestones = {}
	local cashEarned, cashSpent, cashLost = 0, 0, 0
	local longestTraining, trainingStreak = 0, 0
	local multiplier = averageMultiplier(profile)
	local triedEarly = {}

	local function mark(name)
		if not milestones[name] then
			milestones[name] = t
		end
	end

	while t < ASSUME.MaxMinutes * 60 and stage <= 3 do
		local boss = Stages.List[stage].boss
		local acted = false

		-- 1. Défier le boss si prêt (ou trop tôt pour le profil 5, une fois par boss)
		if boss and (mog >= boss.mogRequired or (profile.early and not triedEarly[stage] and mog >= boss.mogRequired / 2)) then
			local reps = Balance.Boss.Rounds * Balance.Boss.RepsPerRound
			t += ASSUME.WalkBetweenSpots + ASSUME.BossOverhead + reps * 1.2 * Balance.Boss.SpeedFactor
			if mog < boss.mogRequired then
				triedEarly[stage] = true
				local loss = math.min(math.floor(cash * Balance.Boss.DefeatCashLossPercent), Balance.Boss.DefeatCashLossCap[stage])
				cash -= loss
				cashLost += loss
				mark(`Défaite auto {boss.id}`)
			elseif bossScore(profile) >= boss.targetScore then
				stage += 1
				cash += boss.firstWinCash
				cashEarned += boss.firstWinCash
				mark(`Boss {boss.id} battu`)
			else
				mark(`Bloqué par {boss.id} (score {math.floor(bossScore(profile))} < {boss.targetScore})`)
				break
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
				t += ASSUME.WalkBetweenSpots + ASSUME.HelpOverhead + Balance.Helps.Reps * help.interval
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
			mog += Balance.SeriesLength * exercise.mogPerRep * multiplier
			trainingStreak += duration
			longestTraining = math.max(longestTraining, trainingStreak)
			mark(`Exercice {id}`)
		end
	end

	return {
		milestones = milestones,
		finalTime = t,
		mog = mog,
		cash = cash,
		cashEarned = cashEarned,
		cashSpent = cashSpent,
		cashLost = cashLost,
		owned = owned,
		longestTraining = longestTraining,
	}
end

local lines = { "", "===== SIMULATION ÉCONOMIE MOG LIFE (MVP) =====" }
table.insert(
	lines,
	`Hypothèses : fin de série +{ASSUME.SeriesOverhead}s, trajet {ASSUME.WalkBetweenSpots}s, aide +{ASSUME.HelpOverhead}s, boss +{ASSUME.BossOverhead}s`
)
for _, profile in PROFILES do
	local r = simulate(profile)
	table.insert(lines, "")
	table.insert(lines, `--- {profile.name} (multiplicateur moyen x{string.format("%.2f", averageMultiplier(profile))}, score boss {math.floor(bossScore(profile))})`)
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
	local count = 0
	for _ in r.owned do
		count += 1
	end
	table.insert(
		lines,
		`  Fin : {fmt(r.finalTime)} | Mog {math.floor(r.mog)} | Cash gagné {r.cashEarned}, dépensé {r.cashSpent}, perdu {r.cashLost}, restant {r.cash} | objets {count}`
	)
	table.insert(lines, `  Plus longue période d'entraînement sans autre activité : {fmt(r.longestTraining)}`)
end
local report = table.concat(lines, "\n")
print(report)
return report
