-- Cycle jour / nuit : le serveur fait avancer l'heure (Lighting.ClockTime, répliquée à tous les joueurs).
-- La nuit passe plus vite que le jour. Les lampadaires sont allumés côté client (AmbienceController).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local CYCLE = Balance.DayNight
local DAY_START, DAY_END = 6, 18

local DayNightService = {}

-- Heures de jeu qui passent par seconde réelle, selon qu'il fait jour ou nuit
local function hoursPerSecond(clock: number): number
	if clock >= DAY_START and clock < DAY_END then
		return (DAY_END - DAY_START) / (CYCLE.DayMinutes * 60)
	end
	return (24 - (DAY_END - DAY_START)) / (CYCLE.NightMinutes * 60)
end

function DayNightService.Start()
	local clock = CYCLE.StartClock
	Lighting.ClockTime = clock
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		clock = (clock + hoursPerSecond(clock) * dt) % 24
		-- Mise à jour 4 fois par seconde : suffisant pour un ciel fluide, sans saturer le réseau
		accumulated += dt
		if accumulated >= 0.25 then
			accumulated = 0
			Lighting.ClockTime = clock
		end
	end)
end

return DayNightService
