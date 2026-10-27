-- Hauteur du vrai sol sous un point (D86) : pour poser les pieds (joueur, boss), les personnages et les accessoires
-- d'activité exactement sur ce qu'on voit, et pas sur une hauteur supposée (dalle d'un PNJ, rebord, pelouse…).
-- Ne compte que le décor sur lequel on peut marcher : ni les personnages, ni les PNJ, ni les accessoires créés le temps
-- d'une activité, ni les pièces invisibles ou sans collision (zones, repères).

local Players = game:GetService("Players")

local Ground = {}

local UP = 3 -- le rayon part un peu au-dessus du point (un pied enfoncé retrouve quand même le sol)
local DOWN = 14

-- La liste de base change peu (joueurs, dossiers d'accessoires) : recalculée au plus deux fois par seconde
local cached: { Instance }? = nil
local cachedAt = -math.huge

local function baseList(): { Instance }
	local now = os.clock()
	if cached and now - cachedAt < 0.5 then
		return cached
	end
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	local npcs = workspace:FindFirstChild("Npcs")
	if npcs then
		table.insert(list, npcs)
	end
	for _, child in workspace:GetChildren() do
		if child:GetAttribute("ActivityProps") then
			table.insert(list, child)
		end
	end
	cached, cachedAt = list, now
	return list
end

local function ignoreList(extra: { Instance }?): { Instance }
	local list = table.clone(baseList())
	for _, instance in extra or {} do
		table.insert(list, instance)
	end
	return list
end

-- Hauteur (Y monde) du sol sous `position`, ou nil s'il n'y a rien dessous. `extra` : objets à traverser en plus
-- (la pièce portée, le boss…).
function Ground.Height(position: Vector3, extra: { Instance }?): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = ignoreList(extra)
	params.FilterDescendantsInstances = list
	local origin = position + Vector3.new(0, UP, 0)
	local remaining = UP + DOWN
	for _ = 1, 6 do
		local hit = workspace:Raycast(origin, Vector3.new(0, -remaining, 0), params)
		if not hit then
			return nil
		end
		local part = hit.Instance
		if part:IsA("BasePart") and part.CanCollide and part.Transparency < 0.95 then
			return hit.Position.Y
		end
		-- Zone invisible ou sans collision : on la traverse
		table.insert(list, part)
		params.FilterDescendantsInstances = list
		remaining -= origin.Y - hit.Position.Y
		origin = hit.Position
	end
	return nil
end

return Ground
