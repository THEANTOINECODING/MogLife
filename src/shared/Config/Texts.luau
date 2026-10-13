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

	-- Séries
	["Series.Complete"] = "Series complete! +{mog} Mog",
	["Series.Continue"] = "Keep going",
	["Series.Done"] = "Done",
	["Series.TooFar"] = "You walked away from the station.",
	["Series.Locked"] = "Unlocks after beating {boss}.",

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
