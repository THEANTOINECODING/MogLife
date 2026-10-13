-- Sauvegarde des joueurs avec ProfileStore (verrouillage de session, sauvegarde périodique).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local STORE_NAME = "PlayerData_v1"

local store = ProfileStore.New(STORE_NAME, Balance.StartingData)
local profiles = {}
local loadedEvent = Instance.new("BindableEvent")

local DataService = {}

-- Déclenché avec (player, data) quand les données d'un joueur sont prêtes
DataService.PlayerLoaded = loadedEvent.Event

function DataService.Get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		player:Kick("Impossible de charger tes données. Reconnecte-toi.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Session terminée. Reconnecte-toi.")
	end)

	if player.Parent == Players then
		profiles[player] = profile
		loadedEvent:Fire(player, profile.Data)
	else
		profile:EndSession()
	end
end

function DataService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end
	end)
end

return DataService
