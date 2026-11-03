-- Réglages du joueur (Config/Settings.luau) : interrupteurs sauvegardés, appliqués par le client
-- (SettingsController). Le serveur ne fait que valider et mémoriser.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Throttle = require(script.Parent.Parent.Throttle)

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
	if key == "Duels" then
		-- Les autres clients ne proposent plus de duel à ce joueur
		player:SetAttribute("DuelsOff", if value then nil else true)
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
			player:SetAttribute("DuelsOff", if data.Settings.Duels then nil else true)
		end
		send(player)
	end)
	Remotes.SetSetting.OnServerEvent:Connect(onSet)
	Remotes.RequestStats.OnServerEvent:Connect(Throttle.Wrap(Balance.RemoteThrottle.RequestStats, send))
	Players.PlayerRemoving:Connect(function(player)
		lastChange[player] = nil
	end)
end

return SettingsService
