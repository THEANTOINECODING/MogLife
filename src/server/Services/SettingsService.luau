-- Réglages du joueur (Config/Settings.luau) : interrupteurs sauvegardés, appliqués par le client
-- (SettingsController). Le serveur ne fait que valider et mémoriser.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService

local lastChange: { [Player]: number } = {}

local SettingsService = {}

local function send(player: Player)
	local data = DataService.Get(player)
	if data then
		Remotes.SettingsState:FireClient(player, data.Settings)
	end
end

local function onSet(player: Player, key: unknown, value: unknown)
	if typeof(key) ~= "string" or typeof(value) ~= "boolean" or not table.find(Settings.List, key) then
		return
	end
	local now = os.clock()
	if now - (lastChange[player] or 0) < 0.1 then
		return
	end
	lastChange[player] = now
	local data = DataService.Get(player)
	if data then
		data.Settings[key] = value
	end
end

function SettingsService.Init(services)
	DataService = services.DataService
end

function SettingsService.Start()
	DataService.PlayerLoaded:Connect(function(player)
		local data = DataService.Get(player)
		if data then
			-- Un réglage ajouté plus tard est activé par défaut
			for _, key in Settings.List do
				if typeof(data.Settings[key]) ~= "boolean" then
					data.Settings[key] = true
				end
			end
		end
		send(player)
	end)
	Remotes.SetSetting.OnServerEvent:Connect(onSet)
	Remotes.RequestStats.OnServerEvent:Connect(send)
	Players.PlayerRemoving:Connect(function(player)
		lastChange[player] = nil
	end)
end

return SettingsService
