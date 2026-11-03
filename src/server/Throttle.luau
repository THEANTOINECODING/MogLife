-- Limite de débit des remotes (D108) : un client qui bombarde une demande voit les appels en trop ignorés.
-- Throttle.Wrap(secondes, handler) renvoie un handler à brancher sur OnServerEvent ; chaque handler enveloppé
-- a son propre délai par joueur. Les délais sont dans Balance.RemoteThrottle.

local Players = game:GetService("Players")

local Throttle = {}

function Throttle.Wrap<A...>(seconds: number, handler: (Player, A...) -> ()): (Player, A...) -> ()
	local last: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
	return function(player: Player, ...: A...)
		local now = os.clock()
		if now - (last[player] or -math.huge) < seconds then
			return
		end
		last[player] = now
		handler(player, ...)
	end
end

return Throttle
