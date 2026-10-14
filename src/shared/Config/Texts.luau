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
	["Hud.ComingSoon"] = "Next boss: {boss} (coming soon!)",

	-- Stations
	["Station.Train"] = "Train",

	-- Exercices
	["Exercise.Curl"] = "Watermelon Curl",
	["Exercise.PushUp"] = "Push-ups",
	["Exercise.BenchPress"] = "Bench Press",
	["Exercise.Squat"] = "Squat",
	["Exercise.PullUp"] = "Pull-ups",
	["Exercise.JumpRope"] = "Jump Rope",

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
	["Minigame.Hint.Alternate"] = "One hand, then the other, on the beat!",
	["Minigame.Hint.Rope"] = "Jump when the rope passes under your feet!",
	["Minigame.Hint.Twist"] = "Twist the lid in circles: one turn per pulse!",
	["Minigame.Hint.Pressure"] = "Pump to keep the needle in the green!",
	["Minigame.Hint.Hammer"] = "Tap when the hammer is right above the nail!",
	["Minigame.Hint.Steer"] = "Keep the car on the road!",
	["Minigame.Hint.Lanes"] = "Dodge the vases! (left / right)",
	["Minigame.Hint.Stack"] = "Drop each chair right on top of the stack!",
	["Minigame.Hint.Catch"] = "Catch the groceries with the basket!",
	["Minigame.Hint.Sequence"] = "Remember the arrows, then repeat them!",
	["Minigame.Hint.Reaction"] = "Copy Kevin's pose as fast as you can!",
	["Minigame.Hint.Spotlight"] = "Stay in the sun to out-tan Brayan!",
	["Minigame.Hint.Beats"] = "Hit the notes on the line, left or right!",
	["Minigame.Hint.Wobble"] = "Stay balanced in the middle!",
	["Minigame.Hint.Combo"] = "Type the combo before the fan blows it away!",

	-- Séries
	["Series.Complete"] = "Series complete! +{mog} Mog",
	["Series.Continue"] = "Keep going",
	["Series.Done"] = "Done",
	["Series.TooFar"] = "You walked away from the station.",
	["Series.Locked"] = "Unlocks after beating {boss}.",

	-- Boss : défi et Mog-off
	["Boss.Challenge"] = "Challenge",
	["Boss.Required"] = "Required: {required} Mog (you have {mog})",
	["Boss.Ready"] = "You're ready. If you lose the Mog-off, you drop {cash} Cash.",
	["Boss.NotReady"] = "He looks WAY too strong for you. If you lose, you drop {cash} Cash.",
	["Boss.NotReadyFuture"] = "Beat {boss} first! If you fight now, you drop {cash} Cash.",
	["Boss.Rematch"] = "Rematch for fun. No reward, no risk.",
	["Boss.Fight"] = "Fight!",
	["Boss.FightAnyway"] = "Fight anyway",
	["Boss.Later"] = "Later",
	["Boss.RoundTitle"] = "Round {round} / {rounds}: out-mog {boss}!",
	["Boss.RoundWon"] = "Round {round}: {score} vs {opponent}. You win it!",
	["Boss.RoundLost"] = "Round {round}: {score} vs {opponent}. He takes it!",
	["Boss.Scoreboard"] = "You {score}  vs  {opponent} {boss}",
	["Boss.Mogged"] = "MOGGED with one look! You dropped {cash} Cash.",
	["Boss.Victory"] = "VICTORY! {boss} got mogged into orbit!",
	["Boss.NewStage"] = "You are now a {stage}!",
	["Boss.RewardCash"] = "+{cash} Cash",
	["Boss.RewardItem"] = "New style item: {item}",
	["Boss.RematchWon"] = "You mogged {boss} again. Legend.",
	["Boss.Defeat"] = "{boss} wins this time. You dropped {cash} Cash. Train and come back!",
	["Boss.DefeatRematch"] = "{boss} wins this time. Train and come back!",
	["Boss.Aborted"] = "You left the fight.",
	["Boss.Ok"] = "Let's go!",
	["BossLine.Kevin"] = "I'll start Monday. Which Monday? A Monday.",
	["BossLine.Brayan"] = "I don't tan. I glow.",
	["BossLine.CoachTurbo"] = "YOU'RE INCREDIBLE, TURBO! ...Oh, you're here too.",
	["BossLine.NoLegs"] = "Legs are a myth. Balance is a lifestyle.",
	["BossLine.BlockKing"] = "Kneel before the fan. The fan is the crown.",

	-- Habitants et aides
	["Npc.Mom"] = "Mom",
	["Npc.Courier"] = "Stressed Courier",
	["Npc.Kid"] = "Little Neighbor",
	["Npc.Neighbor"] = "The Neighbor",
	["Npc.MrsDoRe"] = "Mrs. Do-Re",
	["Npc.Lifeguard"] = "Overworked Lifeguard",
	["Npc.Grocer"] = "Clumsy Grocer",
	["Npc.Tourist"] = "Lost Tourist",
	["Help.BeachChairs"] = "Stack the lifeguard's beach chairs",
	["Help.Groceries"] = "Catch the grocer's groceries",
	["Help.Directions"] = "Show the tourist the way",
	["HelpLine.BeachChairs"] = "Finally, a tower worthy of my whistle.",
	["HelpLine.Groceries"] = "Not a single egg cracked! A miracle!",
	["HelpLine.Directions"] = "Left, left, up... I'll just follow your shadow.",
	["Help.Action"] = "Help",
	["Help.OpenJar"] = "Open Mom's pickle jar",
	["Help.PumpTire"] = "Pump the courier's bike tire",
	["Help.Nails"] = "Hammer the treehouse nails",
	["Help.PushCar"] = "Push the neighbor's car",
	["Help.Piano"] = "Carry Mrs. Do-Re's piano",
	["HelpLine.OpenJar"] = "That jar has been mocking me for three years.",
	["HelpLine.PumpTire"] = "My deliveries are saved! Mostly.",
	["HelpLine.Nails"] = "Best. Treehouse. Ever.",
	["HelpLine.PushCar"] = "It usually starts. Usually.",
	["HelpLine.Piano"] = "Careful, it's tuned!",
	["Help.Done"] = '{npc}: "{line}" +{cash} Cash',
	["Help.Thanks"] = "{npc}: Thanks, champ! +{cash} Cash",
	["Help.Cooldown"] = "{npc} needs a breather. Come back in {seconds}s.",
	["Help.Available"] = "!",
	["Help.LockedBadge"] = "🔒",
	["Help.CooldownBadge"] = "⏳ {seconds}s",

	-- Boutique de style (miroir)
	["Shop.Prompt"] = "Style",
	["Shop.Mirror"] = "Mirror",
	["Shop.Title"] = "Style Mirror",
	["Shop.Cash"] = "💵 {value}",
	["Shop.Cosmetic"] = "Looks only. No power, just style.",
	["Shop.Category.Hair"] = "Hair",
	["Shop.Category.Top"] = "Tops",
	["Shop.Category.Accessory"] = "Extras",
	["Shop.Buy"] = "Buy: {price}",
	["Shop.Confirm"] = "Confirm {price}?",
	["Shop.Equip"] = "Wear",
	["Shop.Equipped"] = "Wearing ✔",
	["Shop.BossReward"] = "Beat {boss}",
	["Shop.Close"] = "Close",
	["Shop.NotEnough"] = "Not enough Cash! Help people around town.",
	["Shop.Bought"] = "New look: {item}!",

	-- Objets de style
	["Style.Banana"] = "Giant Banana Quiff",
	["Style.Mullet"] = "Business Mullet",
	["Style.Mohawk"] = "Pink Mohawk",
	["Style.ShinyBald"] = "Shiny Bald",
	["Style.Pompadour"] = "One-Meter Pompadour",
	["Style.TightTank"] = "Way Too Tight Tank",
	["Style.MogTank"] = "Black Mog Tank",
	["Style.Hawaiian"] = "Hawaiian Shirt",
	["Style.TrackJacket"] = "Retro Track Jacket",
	["Style.BoxerRobe"] = "Boxer Robe",
	["Style.Headband"] = "Sweat Headband",
	["Style.Sweatbands"] = "Wrist Sweatbands",
	["Style.DumbbellShades"] = "Dumbbell Shades",
	["Style.ShakerBackpack"] = "Protein Shaker Backpack",
	["Style.GoldChain"] = "Giant Gold Chain",
	["Style.PajamaTop"] = "Kevin's Lucky Pajama",
	["Style.BronzeMedal"] = "Bronze Medal of Bronzing",
	["Style.CoachWhistle"] = "Turbo Whistle",
	["Style.TinySocks"] = "Mr. No-Legs' Giant Socks",
	["Style.RoyalFan"] = "The Royal Fan",

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
