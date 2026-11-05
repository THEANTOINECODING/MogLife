-- Garde anti-inondation : compte les demandes de chaque client sur chaque remote. Un client qui dépasse de loin le
-- rythme d'un joueur humain (Balance.Guard) est exclu : c'est un script de triche, qui sinon ferait ramer le serveur
-- pour tout le monde. Chaque service valide aussi ses propres arguments et délais : ceci n'est qu'un filet de sécurité.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GUARD = Balance.Guard

type Counter = { started: number, total: number, perRemote: { [string]: number } }
local counters: { [Player]: Counter } = {}
local kicked: { [Player]: boolean } = {}

local GuardService = {}

local function count(player: Player, name: string)
	if kicked[player] then
		return
	end
	local now = os.clock()
	local counter = counters[player]
	if not counter or now - counter.started > GUARD.Window then
		counter = { started = now, total = 0, perRemote = {} }
		counters[player] = counter
	end
	counter.total += 1
	local onRemote = (counter.perRemote[name] or 0) + 1
	counter.perRemote[name] = onRemote
	if onRemote > GUARD.PerRemote or counter.total > GUARD.Total then
		kicked[player] = true
		warn(`[GuardService] Kicking {player.Name}: {onRemote} x {name}, {counter.total} total in {GUARD.Window}s`)
		player:Kick(Texts.Get("Guard.Kicked"))
	end
end

function GuardService.Start()
	for name, remote in Remotes :: any do
		if typeof(remote) == "Instance" and remote:IsA("RemoteEvent") then
			remote.OnServerEvent:Connect(function(player)
				count(player, name)
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		counters[player] = nil
		kicked[player] = nil
	end)
end

return GuardService
