-- Tous les textes affichés dans le jeu, en anglais (langue source de la localisation Roblox).
-- Utilisation : Texts.Get("Series.Complete", { mog = 12 })
-- Phrases complètes avec emplacements {nom}, jamais de morceaux concaténés.

local STRINGS: { [string]: string } = {
	-- HUD
	["Hud.Mog"] = "🗿 {value}",
	["Hud.Cash"] = "💵 {value}",
	["Hud.NextBoss"] = "Next boss: {boss}",
	["Hud.BossProgress"] = "{current} / {required} Mog",
	["Hud.BossReady"] = "Ready to face {boss}!",
	["Hud.MaxStage"] = "You are a GOD MOGGER",

	-- Stations
	["Station.Train"] = "Train",

	-- Exercices
	["Exercise.Curl"] = "Watermelon Curl",
	["Exercise.PushUp"] = "Push-ups",
	["Exercise.BenchPress"] = "Bench Press",
	["Exercise.Squat"] = "Squat",

	-- Mini-jeux
	["Minigame.Perfect"] = "PERFECT!",
	["Minigame.Good"] = "GOOD",
	["Minigame.Miss"] = "MISS",
	["Minigame.Auto"] = "AUTO",
	["Minigame.Gain"] = "+{value} Mog",
	["Minigame.RepCounter"] = "{reps} / {total}",
	["Minigame.Stop"] = "Stop",
	["Minigame.AutoButton"] = "Hold: AUTO",
	["Minigame.Hint.Swipe"] = "Move up and down with the dumbbell!",
	["Minigame.Hint.Ring"] = "Tap when the ring hits the circle!",
	["Minigame.Hint.HoldRelease"] = "Hold to push, release in the green zone!",
	["Minigame.Hint.Tilt"] = "Keep the bar straight! (A / D or move left and right)",

	-- Séries
	["Series.Complete"] = "Series complete! +{mog} Mog",
	["Series.Continue"] = "Keep going",
	["Series.Done"] = "Done",
	["Series.TooFar"] = "You walked away from the station.",
	["Series.Locked"] = "Unlocks after beating {boss}.",

	-- Boss : défi et Mog-off
	["Boss.Challenge"] = "Challenge",
	["Boss.Required"] = "Required: {required} Mog (you have {mog})",
	["Boss.Ready"] = "You're ready. Show him who's the Mogger!",
	["Boss.NotReady"] = "He looks WAY too strong for you. If you lose, you drop {cash} Cash.",
	["Boss.NotReadyFuture"] = "Beat {boss} first! If you fight now, you drop {cash} Cash.",
	["Boss.Rematch"] = "Rematch for fun. No reward, no risk.",
	["Boss.Fight"] = "Fight!",
	["Boss.FightAnyway"] = "Fight anyway",
	["Boss.Later"] = "Later",
	["Boss.RoundTitle"] = "Round {round} / {rounds}: beat {target}!",
	["Boss.RoundWon"] = "Round {round}: {score} vs {target}. You win it!",
	["Boss.RoundLost"] = "Round {round}: {score} vs {target}. He takes it!",
	["Boss.Mogged"] = "MOGGED with one look! You dropped {cash} Cash.",
	["Boss.Victory"] = "VICTORY! {boss} got mogged into orbit!",
	["Boss.NewStage"] = "You are now a {stage}!",
	["Boss.RewardCash"] = "+{cash} Cash",
	["Boss.RewardItem"] = "New style item: {item}",
	["Boss.RematchWon"] = "You mogged {boss} again. Legend.",
	["Boss.Defeat"] = "{boss} wins this time. Train and come back! (no loss)",
	["Boss.Aborted"] = "You left the fight.",
	["Boss.Ok"] = "Let's go!",
	["BossLine.Kevin"] = "I'll start Monday. Which Monday? A Monday.",
	["BossLine.Brayan"] = "I don't tan. I glow.",
	["BossLine.CoachTurbo"] = "YOU'RE INCREDIBLE, TURBO! ...Oh, you're here too.",

	-- Objets de style
	["Style.PajamaTop"] = "Kevin's Lucky Pajama",
	["Style.BronzeMedal"] = "Bronze Medal of Bronzing",
	["Style.CoachWhistle"] = "Turbo Whistle",

	-- Stades
	["Stage.Normie"] = "Normie",
	["Stage.GymRat"] = "Gym Rat",
	["Stage.Bro"] = "Bro",
	["Stage.Alpha"] = "Alpha",
	["Stage.Chad"] = "Chad",
	["Stage.Gigachad"] = "Gigachad",
	["Stage.GodMogger"] = "GOD MOGGER",

	-- Boss
	["Boss.Kevin"] = 'Kevin "I\'ll Start Tomorrow"',
	["Boss.Brayan"] = "Brayan the Bronzed",
	["Boss.CoachTurbo"] = "Coach Turbo",
	["Boss.NoLegs"] = "Mr. No-Legs",
	["Boss.BlockKing"] = "King of the Block",
	["Boss.PumpGod"] = "The Pump God",
}

local Texts = {}

function Texts.Get(key: string, args: { [string]: any }?): string
	local text = STRINGS[key]
	if text == nil then
		warn(`[Texts] Missing key: {key}`)
		return key
	end
	if args then
		text = string.gsub(text, "{(%w+)}", function(name)
			local value = args[name]
			return if value ~= nil then tostring(value) else nil
		end)
	end
	return text
end

return Texts
