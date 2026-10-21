-- Cadrage sans obstacle : choisit, parmi des directions de caméra données par ordre de préférence, la première d'où
-- l'on voit vraiment le sujet (aucun mur, toit ou décor entre la caméra et lui), et rapproche la caméra si toutes
-- sont gênées. Utilisé par le gros plan des activités (ActivityController) et la caméra de duel (BossController).
-- Les joueurs et les pièces presque invisibles (zones de collision, repères, vitres) ne gênent jamais ; les PNJ oui.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraFraming = {}

local MIN_DISTANCE = 5 -- studs : la caméra ne vient jamais plus près que ça du sujet
local MARGIN = 0.8 -- studs gardés devant l'obstacle
local SOLID_SIZE = 30 -- studs : en dessous, un obstacle est « petit » (estompé plutôt qu'évité)

local function ignoreList(extra: { Instance }?): { Instance }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	-- Les PNJ gênent la vue comme le décor (sauf le boss affronté, passé par l'appelant)
	for _, name in { "CityEvents" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(list, folder)
		end
	end
	-- Objets créés le temps d'une activité (bocal, pompe, corde…) : ils font partie de la scène filmée
	for _, child in workspace:GetChildren() do
		if child:GetAttribute("ActivityProps") then
			table.insert(list, child)
		end
	end
	for _, instance in extra or {} do
		table.insert(list, instance)
	end
	return list
end

-- Distance libre depuis `from` dans la direction `direction` (jusqu'à maxDistance)
-- solidOnly : seuls les grands décors (murs, bâtiments, toits) arrêtent le rayon ; les petits obstacles (PNJ, arbres,
-- poteaux) sont traversés, car ils seront estompés pendant l'activité
function CameraFraming.ClearDistance(
	from: Vector3,
	direction: Vector3,
	maxDistance: number,
	ignore: { Instance },
	solidOnly: boolean?
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
		-- Vitres et pièces presque invisibles : on voit au travers
		local small = solidOnly and part:IsA("BasePart") and part.Size.Magnitude < SOLID_SIZE
		if part:IsA("BasePart") and part.Transparency < 0.45 and part.Material ~= Enum.Material.Glass and not small then
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

-- Part des points visibles depuis l'œil (aucun décor entre l'œil et le point)
local function visibleShare(eye: Vector3, points: { Vector3 }, ignore: { Instance }, solidOnly: boolean?): number
	if #points == 0 then
		return 1
	end
	-- Chaque point compte pour trois rayons (centre et de chaque côté) : un poteau fin devant le corps le cache
	-- en partie, ça doit compter
	local seen, total = 0, 0
	for _, point in points do
		local offset = point - eye
		local side = offset:Cross(Vector3.new(0, 1, 0))
		side = if side.Magnitude > 0.01 then side.Unit * 0.6 else Vector3.zero
		for _, shift in { Vector3.zero, side, -side } do
			local target = offset + shift
			total += 1
			if
				CameraFraming.ClearDistance(eye, target, target.Magnitude, ignore, solidOnly)
				>= target.Magnitude - 0.05
			then
				seen += 1
			end
		end
	end
	return seen / total
end

-- Meilleure position de caméra : renvoie la position de l'œil. directions : par ordre de préférence (vecteurs depuis
-- le sujet vers la caméra, non normalisés : leur longueur est la distance voulue). points : parties du corps qui
-- doivent être visibles (tête, torse, mains, pieds) ; un angle n'est retenu tel quel que si on les voit toutes,
-- sinon on garde celui qui en montre le plus (la caméra se rapproche si un mur est juste derrière elle).
function CameraFraming.Best(
	focus: Vector3,
	directions: { Vector3 },
	extraIgnore: { Instance }?,
	points: { Vector3 }?
): Vector3
	local ignore = ignoreList(extraIgnore)
	local targets = points or { focus }
	local bestEye, bestScore = nil, -1
	for index, direction in directions do
		local wanted = direction.Magnitude
		-- Seuls les grands décors rapprochent la caméra ou cachent vraiment le corps (le reste sera estompé)
		local clear = CameraFraming.ClearDistance(focus, direction, wanted + MARGIN, ignore, true)
		local eye = if clear >= wanted
			then focus + direction
			else focus + direction.Unit * math.max(clear - MARGIN, MIN_DISTANCE)
		local share = visibleShare(eye, targets, ignore, true)
		-- Corps entièrement visible derrière les grands décors, avec tout le recul voulu : l'angle préféré est pris
		-- tel quel (les petits obstacles, arbre ou PNJ, seront estompés)
		if share >= 1 and clear >= wanted then
			return eye
		end
		local clean = visibleShare(eye, targets, ignore, false)
		-- Score : ce qu'on voit du corps ET le recul disponible comptent autant (une caméra collée au personnage est
		-- pire qu'un pied caché), puis l'absence de petits obstacles, puis l'ordre de préférence
		local score = share * 10 + math.min(clear / wanted, 1) * 10 + clean - index * 0.01
		if score > bestScore then
			bestScore, bestEye = score, eye
		end
	end
	return bestEye or (focus + directions[1])
end

-- Points du corps à garder visibles
function CameraFraming.BodyPoints(character: Model): { Vector3 }
	local points = {}
	for _, name in { "Head", "UpperTorso", "LeftHand", "RightHand", "LeftFoot", "RightFoot" } do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			-- Pieds : un peu au-dessus du sol (au ras du sol, le moindre rebord de la dalle les « cacherait »)
			local lift = if string.find(name, "Foot") then Vector3.new(0, 0.6, 0) else Vector3.zero
			table.insert(points, part.Position + lift)
		end
	end
	return points
end

-- Angles par défaut : de face-côté vers profil, puis en plongée. { degrés autour du sujet, part de plongée }
local DEFAULT_STEPS = {
	{ 25, 0 },
	{ -25, 0 },
	{ 50, 0 },
	{ -50, 0 },
	{ 0, 0 },
	{ 80, 0 },
	{ -80, 0 },
	{ 30, 1 },
	{ -30, 1 },
	-- Mur juste devant : plongée raide par-dessus, puis de trois quarts arrière
	{ 15, 1.8 },
	{ -15, 1.8 },
	{ 120, 0.5 },
	{ -120, 0.5 },
}

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

-- Estompeur : ce qui passe entre la caméra et le personnage (PNJ, arbres, petits décors) devient transparent sur
-- son écran seulement, puis revient. Les rayons partent de la caméra vers chaque point du corps, plus deux rayons
-- décalés de côté (un PNJ fin entre deux rayons masquerait quand même le corps).
local FADE = 0.75
local MAX_FADE_SIZE = SOLID_SIZE -- les grands murs et bâtiments ne sont jamais estompés (le cadrage les évite)

export type Fader = { parts: { [BasePart]: boolean } }

function CameraFraming.NewFader(): Fader
	return { parts = {} }
end

function CameraFraming.Fade(fader: Fader, eye: Vector3, points: { Vector3 }, extraIgnore: { Instance }?)
	local ignore = ignoreList(extraIgnore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit: { [BasePart]: boolean } = {}
	for _, point in points do
		local toPoint = point - eye
		local side = toPoint:Cross(Vector3.new(0, 1, 0))
		side = if side.Magnitude > 0.01 then side.Unit * 0.7 else Vector3.zero
		for _, shift in { Vector3.zero, side, -side } do
			local result = workspace:Raycast(eye, toPoint + shift, params)
			local part = result and result.Instance
			if part and part:IsA("BasePart") and part.Size.Magnitude < MAX_FADE_SIZE then
				hit[part] = true
			end
		end
	end
	for part in hit do
		part.LocalTransparencyModifier = FADE
	end
	for part in fader.parts do
		if not hit[part] and part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
	fader.parts = hit
end

function CameraFraming.ClearFade(fader: Fader)
	for part in fader.parts do
		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
	fader.parts = {}
end

-- ------------------------------------------------------------------ caméra stable (activités, duels)
-- La caméra choisit son angle UNE fois, d'après le corps au repos, puis reste fixe par rapport au sujet : elle ne
-- suit pas chaque répétition (le torse qui monte et descend), seulement un vrai déplacement (pousser la voiture),
-- en douceur. Elle ne change d'angle que si un grand décor (mur, bâtiment) cache durablement le corps, en glissant.
-- Le zoom (champ de vision) est fixé pendant toute l'activité. Les petits obstacles sont estompés.
export type FollowOptions = {
	anchor: () -> Vector3?, -- position de référence du sujet (racine du personnage) ; nil = sujet disparu
	plan: () -> (Vector3, Vector3), -- calcule (œil, point visé) pour la position actuelle du sujet
	points: () -> { Vector3 }, -- points du corps à garder visibles (estompage, contrôle de l'angle)
	ignore: () -> { Instance }, -- objets qui ne gênent jamais (station, objet tenu, boss)
	enterTime: number?, -- secondes pour arriver depuis la caméra du joueur
}

local FOV = 70
local REPLAN_MOVE = 4 -- studs : le sujet s'est vraiment déplacé, l'angle est recalculé
local BLOCK_CHECK = 1.2 -- secondes entre deux contrôles de visibilité
local BLOCK_TIME = 1.5 -- secondes de corps caché (par un grand décor) avant de changer d'angle
local GLIDE = 0.9 -- secondes pour glisser vers un nouvel angle

function CameraFraming.Follow(options: FollowOptions): () -> ()
	local camera = workspace.CurrentCamera
	local start = options.anchor()
	if not camera or not start then
		return function() end
	end
	local savedFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FOV
	local startCF = camera.CFrame
	local t0 = os.clock()
	local enter = options.enterTime or 0.7

	-- Angle choisi : décalages de l'œil et du point visé par rapport au sujet
	local planned = start
	local eye, aim = options.plan()
	local eyeOffset, aimOffset = eye - start, aim - start
	local fromEye, fromAim, glideStart = eyeOffset, aimOffset, -math.huge
	local smoothAnchor = start
	local viewport = camera.ViewportSize
	local fader = CameraFraming.NewFader()
	local nextFade, nextCheck, hiddenSince = 0, 0, nil :: number?

	local function replan(anchor: Vector3)
		local newEye, newAim = options.plan()
		fromEye, fromAim = eyeOffset, aimOffset
		eyeOffset, aimOffset = newEye - anchor, newAim - anchor
		glideStart = os.clock()
		planned = anchor
		hiddenSince = nil
	end

	local connection = RunService.RenderStepped:Connect(function(dt)
		local anchor = options.anchor()
		if not anchor then
			return
		end
		local now = os.clock()
		-- Suit les vrais déplacements, en douceur (pas les mouvements des répétitions : la racine bouge peu)
		smoothAnchor = smoothAnchor:Lerp(anchor, math.min(dt * 3, 1))
		if camera.ViewportSize ~= viewport or (anchor - planned).Magnitude > REPLAN_MOVE then
			viewport = camera.ViewportSize
			replan(anchor)
		end
		-- Contrôle de visibilité : si un grand décor cache le corps trop longtemps, nouvel angle
		if now >= nextCheck then
			nextCheck = now + BLOCK_CHECK
			local ignore = ignoreList(options.ignore())
			local seen = visibleShare(camera.CFrame.Position, options.points(), ignore, true)
			if seen < 0.5 then
				hiddenSince = hiddenSince or now
				if now - hiddenSince >= BLOCK_TIME then
					replan(anchor)
				end
			else
				hiddenSince = nil
			end
		end
		local g = math.clamp((now - glideStart) / GLIDE, 0, 1)
		g = g * g * (3 - 2 * g)
		local eyeNow = smoothAnchor + fromEye:Lerp(eyeOffset, g)
		local aimNow = smoothAnchor + fromAim:Lerp(aimOffset, g)
		local wanted = CFrame.lookAt(eyeNow, aimNow)
		local e = math.clamp((now - t0) / enter, 0, 1)
		camera.CFrame = if e < 1 then startCF:Lerp(wanted, e * e * (3 - 2 * e)) else wanted
		camera.FieldOfView = math.max(camera.FieldOfView, FOV - 6) -- un « punch » ne peut pas s'accumuler
		-- Petits obstacles devant le corps : estompés
		if now >= nextFade then
			nextFade = now + 0.15
			CameraFraming.Fade(fader, camera.CFrame.Position, options.points(), options.ignore())
		end
	end)

	return function()
		connection:Disconnect()
		CameraFraming.ClearFade(fader)
		camera.FieldOfView = savedFov
		camera.CameraType = Enum.CameraType.Custom
	end
end

CameraFraming.Fov = FOV

return CameraFraming
