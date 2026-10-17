-- Point d'entrée serveur : charge tous les services, puis appelle Init() et Start().
-- Init() sert à récupérer les autres services, Start() à brancher les événements.

local ORDER = {
	"DataService",
	"StatsService",
	"BodyService",
	"MinigameService",
	"ExerciseService",
	"BossService",
	"HelpService",
	"StyleService",
	"PropService",
	"DoorService",
	"PlotService",
	"FurnitureService",
	"TravelService",
	"DayNightService",
	"StatueService",
	"DisplayService",
	"VendorService",
	"MentorService",
	"TutorialService",
	"LookService",
	"BoostService",
	"SocialService",
	"EventService",
	"SettingsService",
	"SeatService",
	"WeeklyService",
	"DuelService",
	"DevService",
}

local services = {}
for _, name in ORDER do
	services[name] = require(script.Services[name])
end

for _, name in ORDER do
	local service = services[name]
	if service.Init then
		service.Init(services)
	end
end

for _, name in ORDER do
	local service = services[name]
	if service.Start then
		service.Start()
	end
end

print("[MOG LIFE] Serveur prêt")
