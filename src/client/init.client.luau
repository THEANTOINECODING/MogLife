-- Point d'entrée client : charge tous les contrôleurs, puis appelle Init() et Start().

local ORDER = {
	"UIController",
	"MobileCameraController",
	"SprintController",
	"MinigameController",
	"ActivityController",
	"BodyFxController",
	"BossController",
	"HelpController",
	"ShopController",
	"FurnitureController",
	"HouseController",
	"TravelController",
	"WayfindingController",
	"AmbienceController",
	"TutorialController",
	"SoundController",
	"BoostController",
	"SnackController",
	"ObjectiveController",
	"CutsceneController",
	"CreatorController",
	"EmoteController",
	"EventController",
	"EventFxController",
	"WeeklyController",
	"SettingsController",
	"GamepadController",
	"OutfitFxController",
	"LuxuryController",
	"DuelController",
	"NpcController",
	"MotionController",
	"ColosseumController",
	"StatueWallController",
	"PumpGodController",
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

-- Chaque Start démarre dans son propre fil (D83) : un contrôleur qui attend quelque chose ne bloque plus ceux qui le
-- suivent. L'ordre reste le même tant qu'aucun n'attend. Dans Studio, ceux qui attendent encore sont signalés.
local waiting: { [string]: boolean } = {}
for _, name in ORDER do
	local controller = controllers[name]
	if controller.Start then
		waiting[name] = true
		task.spawn(function()
			controller.Start()
			waiting[name] = nil
		end)
	end
end
if game:GetService("RunService"):IsStudio() then
	task.delay(10, function()
		for name in waiting do
			warn(`[Client] {name}.Start attend encore après 10 s`)
		end
	end)
end
