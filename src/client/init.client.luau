-- Point d'entrée client : charge tous les contrôleurs, puis appelle Init() et Start().

local ORDER = {
	"UIController",
	"MinigameController",
	"ActivityController",
	"BodyFxController",
	"BossController",
	"HelpController",
	"ShopController",
	"FurnitureController",
	"TravelController",
	"WayfindingController",
	"AmbienceController",
	"TutorialController",
	"SoundController",
}

local controllers = {}
for _, name in ORDER do
	controllers[name] = require(script.Controllers[name])
end

for _, name in ORDER do
	local controller = controllers[name]
	if controller.Init then
		controller.Init(controllers)
	end
end

for _, name in ORDER do
	local controller = controllers[name]
	if controller.Start then
		controller.Start()
	end
end
