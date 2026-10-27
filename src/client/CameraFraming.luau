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
local FOV = 70 -- champ de vision pendant une activité ou un duel

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

-- ------------------------------------------------------------------ zone libre de l'écran (D86)
-- Pendant un mini-jeu, l'interface couvre une partie de l'écran (panneau du jeu, colonne d'infos à gauche sur
-- téléphone) : la scène filmée doit tenir dans ce qui reste. MinigameController fournit cette zone.
local freeAreaGetter: (() -> (Vector2?, Vector2?))? = nil

-- getter() renvoie le coin haut-gauche et le coin bas-droit de la zone libre (pixels de l'écran), ou rien
function CameraFraming.SetFreeArea(getter: () -> (Vector2?, Vector2?))
	freeAreaGetter = getter
end

-- Zone libre de l'écran (pixels) : tout l'écran sans interface
function CameraFraming.FreeArea(): (Vector2, Vector2)
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	if freeAreaGetter then
		local low, high = freeAreaGetter()
		if low and high and high.X - low.X > 40 and high.Y - low.Y > 40 then
			return low, high
		end
	end
	return Vector2.zero, size
end

local FIT_MARGIN = 0.12 -- part de la zone libre gardée vide autour du sujet (mouvements, effets)

-- Place la caméra pour que tous les `points` tiennent dans la zone libre de l'écran, le plus près possible : la
-- caméra regarde dans la direction choisie (de `eye` vers `focus`), recule juste ce qu'il faut et se décale pour
-- centrer le sujet dans la zone libre. Renvoie (œil, point visé). minDistance : recul minimal.
function CameraFraming.Fit(focus: Vector3, eye: Vector3, points: { Vector3 }, minDistance: number?): (Vector3, Vector3)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local low, high = CameraFraming.FreeArea()
	local look = focus - eye
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local right = look:Cross(Vector3.new(0, 1, 0))
	right = if right.Magnitude > 0.01 then right.Unit else Vector3.xAxis
	local up = right:Cross(look)
	local tanY = math.tan(math.rad(FOV / 2))
	local tanX = tanY * viewport.X / math.max(viewport.Y, 1)
	-- Zone libre en coordonnées normalisées de l'écran (-1 à 1, Y vers le haut)
	local cx = ((low.X + high.X) / viewport.X) - 1
	local cy = 1 - ((low.Y + high.Y) / viewport.Y)
	local hx = (high.X - low.X) / viewport.X * (1 - FIT_MARGIN)
	local hy = (high.Y - low.Y) / viewport.Y * (1 - FIT_MARGIN)
	-- Le sujet : boîte des points autour de son centre, dans le repère de la caméra
	local minX, maxX, minY, maxY = 0, 0, 0, 0
	local center = Vector3.zero
	for _, point in points do
		center += point
	end
	center = if #points > 0 then center / #points else focus
	for _, point in points do
		local offset = point - center
		minX, maxX = math.min(minX, offset:Dot(right)), math.max(maxX, offset:Dot(right))
		minY, maxY = math.min(minY, offset:Dot(up)), math.max(maxY, offset:Dot(up))
	end
	local midX, midY = (minX + maxX) / 2, (minY + maxY) / 2
	local subject = center + right * midX + up * midY
	-- Recul : la largeur et la hauteur du sujet tiennent dans la zone libre
	local halfW, halfH = (maxX - minX) / 2, (maxY - minY) / 2
	local distance = math.max(halfW / (hx * tanX), halfH / (hy * tanY), minDistance or MIN_DISTANCE)
	-- La caméra se décale (sans tourner) pour que le sujet tombe au centre de la zone libre
	local shift = right * (-cx * distance * tanX) + up * (-cy * distance * tanY)
	local newEye = subject - look * distance + shift
	return newEye, newEye + look * distance
end

-- Points du sujet à faire tenir à l'écran : le corps (du sommet de la tête, plus `room` studs de marge, à la semelle
-- des pieds) et les coins des objets donnés (barre, voiture, transats… proches du personnage)
function CameraFraming.SubjectPoints(character: Model, parts: { Instance }?, room: number?): { Vector3 }
	local points = CameraFraming.BodyPoints(character)
	local origin = character:GetPivot().Position
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		table.insert(points, head.Position + Vector3.new(0, head.Size.Y / 2 + (room or 0.4), 0))
	end
	for _, name in { "LeftFoot", "RightFoot" } do
		local foot = character:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			table.insert(points, foot.Position - Vector3.new(0, foot.Size.Y / 2 + (room or 0.4) * 0.3, 0))
		end
	end
	for _, instance in parts or {} do
		local list = if instance:IsA("BasePart") then { instance } else instance:GetDescendants()
		for _, part in list do
			if part:IsA("BasePart") and part.Transparency < 0.95 and (part.Position - origin).Magnitude < 14 then
				local half = part.Size / 2
				for _, x in { -1, 1 } do
					for _, y in { -1, 1 } do
						for _, z in { -1, 1 } do
							table.insert(points, part.CFrame * Vector3.new(half.X * x, half.Y * y, half.Z * z))
						end
					end
				end
			end
		end
	end
	return points
end

-- Cadrage complet : l'angle d'où l'on voit le mieux (Best), puis le recul et le décalage pour que tout le sujet tienne
-- dans la zone libre de l'écran (Fit) ; si un grand décor est alors entre lui et la caméra, elle se rapproche.
-- Renvoie (œil, point visé).
function CameraFraming.Frame(
	focus: Vector3,
	directions: { Vector3 },
	extraIgnore: { Instance }?,
	points: { Vector3 },
	minDistance: number?
): (Vector3, Vector3)
	local chosen = CameraFraming.Best(focus, directions, extraIgnore, points)
	local eye, aim = CameraFraming.Fit(focus, chosen, points, minDistance)
	local back = eye - focus
	local clear = CameraFraming.ClearDistance(focus, back, back.Magnitude + MARGIN, ignoreList(extraIgnore), true)
	if clear < back.Magnitude then
		local closer = focus + back.Unit * math.max(clear - MARGIN, MIN_DISTANCE)
		return closer, closer + (aim - eye)
	end
	return eye, aim
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
	local areaLow, areaHigh = CameraFraming.FreeArea()
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
		-- Écran tourné, interface du mini-jeu apparue ou déplacée, vrai déplacement : nouvel angle
		local low, high = CameraFraming.FreeArea()
		if
			camera.ViewportSize ~= viewport
			or (low - areaLow).Magnitude > 8
			or (high - areaHigh).Magnitude > 8
			or (anchor - planned).Magnitude > REPLAN_MOVE
		then
			viewport = camera.ViewportSize
			areaLow, areaHigh = low, high
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
