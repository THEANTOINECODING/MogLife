-- Commandes de test, disponibles UNIQUEMENT dans Roblox Studio (jamais en jeu publié).
-- Utilisées par les tests automatiques (MCP) pour lire ou modifier les données d'un joueur :
--   ServerStorage.DevCommands:Invoke("Get", userId)                 -> copie des données
--   ServerStorage.DevCommands:Invoke("Set", userId, field, value)   -> modifie un champ + resynchronise

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataService
local StatsService

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
		return true
	end,
}

function DevService.Init(services)
	DataService = services.DataService
	StatsService = services.StatsService
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
