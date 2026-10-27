-- Place du joueur devant un habitant (D86) : l'habitant est debout au centre d'une dalle de 6 × 6 studs, haute d'un
-- stud. À `Distance` de son centre, le joueur se tient entièrement à côté de la dalle, sur le sol (à 3,6 studs, ses
-- talons montaient sur le rebord : il flottait à moitié au-dessus du sol).
-- Devant la dalle, il peut y avoir un obstacle (la haie du jardin de Maman, un banc…) : on essaie alors les autres
-- côtés de la dalle et on prend la première place dégagée.

local Ground = require(script.Parent.Parent.Ground)

local HelperStand = {}

HelperStand.Distance = 4.3

local BODY = Vector3.new(2.6, 4.2, 2) -- volume du joueur (un peu plus large que lui)
-- Côtés essayés, dans l'ordre (degrés autour de la dalle ; 0 = devant l'habitant)
local SIDES = { 0, 90, -90, 45, -45, 135, -135, 180 }

local function blocked(position: Vector3, ground: number): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	local npcs = workspace:FindFirstChild("Npcs")
	if npcs then
		table.insert(ignore, npcs)
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	-- Le volume commence un peu au-dessus du sol (le sol lui-même ne compte pas)
	local center = CFrame.new(position.X, ground + 0.25 + BODY.Y / 2, position.Z)
	for _, part in workspace:GetPartBoundsInBox(center, BODY, params) do
		if part.CanCollide and part.Transparency < 0.95 then
			return true
		end
	end
	return false
end

-- Place du joueur autour de la dalle `top` (repère du dessus de la dalle) : à `distance` du centre, décalé de
-- `lateral` studs sur le côté, tourné vers la dalle. Première place dégagée parmi les côtés essayés.
function HelperStand.Around(top: CFrame, distance: number?, lateral: number?): CFrame
	local reach = distance or HelperStand.Distance
	local side = lateral or 0
	local first: CFrame? = nil
	for _, angle in SIDES do
		local turned = top * CFrame.Angles(0, math.rad(angle), 0)
		local stand = turned * CFrame.new(side, 0, -reach) * CFrame.Angles(0, math.pi, 0)
		first = first or stand
		local ground = Ground.Height(stand.Position)
		if ground and math.abs(ground - top.Y) < 3 and not blocked(stand.Position, ground) then
			return stand
		end
	end
	return first :: CFrame
end

return HelperStand
