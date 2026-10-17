-- Cadrage sans obstacle : choisit, parmi des directions de caméra données par ordre de préférence, la première d'où
-- l'on voit vraiment le sujet (aucun mur, toit ou décor entre la caméra et lui), et rapproche la caméra si toutes
-- sont gênées. Utilisé par le gros plan des activités (ActivityController) et la caméra de duel (BossController).
-- Les personnages, les PNJ et les pièces presque invisibles (zones de collision, repères) ne gênent jamais.

local Players = game:GetService("Players")

local CameraFraming = {}

local MIN_DISTANCE = 3 -- studs : la caméra ne vient jamais plus près que ça du sujet
local MARGIN = 0.8 -- studs gardés devant l'obstacle

local function ignoreList(extra: { Instance }?): { Instance }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	for _, name in { "Npcs", "CityEvents" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(list, folder)
		end
	end
	for _, instance in extra or {} do
		table.insert(list, instance)
	end
	return list
end

-- Distance libre depuis `from` dans la direction `direction` (jusqu'à maxDistance)
function CameraFraming.ClearDistance(
	from: Vector3,
	direction: Vector3,
	maxDistance: number,
	ignore: { Instance }
): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = table.clone(ignore)
	params.FilterDescendantsInstances = list
	local origin = from
	local remaining = maxDistance
	local travelled = 0
	-- Les pièces presque transparentes (collisions exactes, repères) sont traversées
	for _ = 1, 8 do
		local hit = workspace:Raycast(origin, direction.Unit * remaining, params)
		if not hit then
			return maxDistance
		end
		local part = hit.Instance
		if part:IsA("BasePart") and part.Transparency < 0.9 then
			return travelled + hit.Distance
		end
		table.insert(list, part)
		params.FilterDescendantsInstances = list
		travelled += hit.Distance
		remaining -= hit.Distance
		origin = hit.Position
	end
	return maxDistance
end

-- Meilleure position de caméra : renvoie la position de l'œil. directions : par ordre de préférence (vecteurs depuis
-- le sujet vers la caméra, non normalisés : leur longueur est la distance voulue).
function CameraFraming.Best(focus: Vector3, directions: { Vector3 }, extraIgnore: { Instance }?): Vector3
	local ignore = ignoreList(extraIgnore)
	local bestEye, bestClear = nil, -1
	for _, direction in directions do
		local wanted = direction.Magnitude
		local clear = CameraFraming.ClearDistance(focus, direction, wanted + MARGIN, ignore)
		if clear >= wanted then
			return focus + direction -- vue dégagée, dans l'ordre de préférence
		end
		-- Sinon, on garde la direction la plus dégagée (la caméra se rapprochera)
		local ratio = clear / wanted
		if ratio > bestClear then
			bestClear = ratio
			bestEye = focus + direction.Unit * math.max(clear - MARGIN, MIN_DISTANCE)
		end
	end
	return bestEye or (focus + directions[1])
end

-- Angles par défaut : de face-côté vers profil, puis en plongée. { degrés autour du sujet, part de plongée }
local DEFAULT_STEPS =
	{ { 25, 0 }, { -25, 0 }, { 50, 0 }, { -50, 0 }, { 0, 0 }, { 80, 0 }, { -80, 0 }, { 30, 1 }, { -30, 1 } }

-- Directions autour d'un axe « devant », par préférence. steps : angles propres à une activité (ex. de profil et
-- un peu en hauteur pour un exercice allongé, où la barre cache le corps vu des pieds)
function CameraFraming.Around(
	front: Vector3,
	distance: number,
	height: number,
	sideBias: number?,
	steps: { { number } }?
): { Vector3 }
	local flat = Vector3.new(front.X, 0, front.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local bias = sideBias or 1
	local directions = {}
	for _, step in steps or DEFAULT_STEPS do
		local angle = math.rad(step[1] * bias)
		local rotated = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), angle):VectorToWorldSpace(flat)
		local up = height + step[2] * distance * 0.6 -- plongée : la caméra monte au-dessus des meubles
		table.insert(directions, rotated * distance + Vector3.new(0, up, 0))
	end
	return directions
end

return CameraFraming
