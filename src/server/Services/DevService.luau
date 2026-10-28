-- Commandes de test, disponibles UNIQUEMENT dans Roblox Studio (jamais en jeu publié).
-- Utilisées par les tests automatiques (MCP) pour lire ou modifier les données d'un joueur :
--   ServerStorage.DevCommands:Invoke("Get", userId)                 -> copie des données
--   ServerStorage.DevCommands:Invoke("Set", userId, field, value)   -> modifie un champ + resynchronise
--   ServerStorage.DevCommands:Invoke("Pump", userId, exerciseId, quality) -> vérifie les habits gonflés

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataService
local StatsService
local BodyService
local StyleService
local HelpService
local BossService
local FurnitureService
local EventService
local DuelService
local WeeklyService
local PumpGodService

local DevService = {}

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

local commands = {
	Get = function(player: Player)
		return deepCopy(DataService.Get(player))
	end,
	Set = function(player: Player, field: string, value: any)
		local data = DataService.Get(player)
		if not data or data[field] == nil then
			return false
		end
		data[field] = deepCopy(value)
		StatsService.Refresh(player)
		StyleService.Refresh(player)
		FurnitureService.Refresh(player)
		return true
	end,
	-- Gonfle un groupe musculaire sans terminer une série, pour vérifier l'ajustement des habits en Studio.
	Pump = function(player: Player, exerciseId: string, quality: string)
		BodyService.Pump(player, exerciseId, quality)
		return true
	end,
	-- Combat du Dieu du Pump au Colisée (tranche 2, D90) : action "Start" ou "Stop"
	-- action : "Start", "Stop", "Round" (value = manche, 4 = finale), "Cheer" (value = encouragements simulés)
	PumpGod = function(player: Player, action: string, value: number?)
		if action == "Stop" then
			PumpGodService.Stop(player)
			return true
		elseif action == "Round" then
			return PumpGodService.DevRound(player, value or 2)
		elseif action == "Cheer" then
			return PumpGodService.DevCheer(value or 20)
		end
		return PumpGodService.Begin(player)
	end,
	-- Simule le déclenchement du prompt d'un habitant (les prompts ne marchent pas si Studio est réduit)
	StartHelp = function(player: Player, helpId: string)
		HelpService.StartHelp(player, helpId)
		return true
	end,
	-- Lance un événement de ville tout de suite (kind : GoldenDumbbells, FreeShakes, RunawayPiano)
	StartEvent = function(_player: Player, kind: string)
		EventService.Stop()
		return EventService.Run(kind)
	end,
	-- Duel d'entraînement contre un mannequin (teste le bras de fer seul) ; perfect / good : sa précision (0 à 1)
	DuelBot = function(player: Player, perfect: number?, good: number?)
		local skill = if perfect then { perfect = perfect, good = good or 0 } else nil
		return DuelService.StartBotDuel(player, skill)
	end,
	-- Ajoute à un compteur des défis de la semaine
	WeeklyTrack = function(player: Player, stat: string, amount: number?)
		WeeklyService.Track(player, stat, amount)
		return true
	end,
	-- Simule le prompt d'un boss (affiche la fenêtre de défi)
	ShowChallenge = function(player: Player, bossId: string)
		BossService.ShowChallenge(player, bossId)
		return true
	end,
}

function DevService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
	BodyService = services.BodyService
	StyleService = services.StyleService
	HelpService = services.HelpService
	BossService = services.BossService
	FurnitureService = services.FurnitureService
	EventService = services.EventService
	DuelService = services.DuelService
	WeeklyService = services.WeeklyService
	PumpGodService = services.PumpGodService
end

function DevService.Start()
	if not RunService:IsStudio() then
		return
	end
	local bindable = Instance.new("BindableFunction")
	bindable.Name = "DevCommands"
	bindable.OnInvoke = function(command: string, userId: number, ...)
		local player = Players:GetPlayerByUserId(userId)
		local handler = commands[command]
		if not player or not handler then
			return nil
		end
		return handler(player, ...)
	end
	bindable.Parent = ServerStorage
end

return DevService
