-- Zones d'attaque du Dieu du Pump (D90), dessinées au sol de la piste à l'heure du serveur.
-- Règle de lisibilité (D89) : jamais d'attaque sans zone ; contour épais et clair, remplissage rouge qui grandit
-- jusqu'à l'impact (on voit le temps qui reste), clignotement blanc juste avant.
--   Zones.Circle(at, radius, start, impact)              cercle (foudre)
--   Zones.Band(a, b, width, start, impact)               bande (haltère qui roule)
--   Zones.Ring(at, start, impact, speed, thickness, max) anneau qui part du dieu et s'élargit (onde : sauter)
--   Zones.Cone, Zones.Tiles (dalles), Zones.Storm (toute la piste sauf des cercles sûrs), Zones.Chase (cercle qui suit
--   le combattant puis se fige), Zones.Sweep (rayon qui balaie la piste)
-- Chaque fonction renvoie un objet avec :Destroy(). Tout est local (aucune collision, ni requête).

local RunService = game:GetService("RunService")

local Zones = {}

local RED = Color3.fromRGB(255, 50, 40)
local EDGE = Color3.fromRGB(255, 235, 220)
local GOLD = Color3.fromRGB(255, 200, 70)
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- cylindre de Roblox : axe X -> vertical

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function part(parent: Instance, size: Vector3, color: Color3, transparency: number, cylinder: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Size = size
	if cylinder then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = parent
	return p
end

local function folder(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = workspace
	return f
end

-- Progression 0 -> 1 entre start et impact
local function progress(start: number, impact: number): number
	return math.clamp((serverNow() - start) / math.max(impact - start, 0.05), 0, 1)
end

-- Clignotement blanc dans le dernier quart d'avertissement
local function blink(k: number): boolean
	return k > 0.75 and math.floor(serverNow() * 14) % 2 == 0
end

function Zones.Circle(at: Vector3, radius: number, start: number, impact: number)
	local f = folder("ZoneCircle")
	local base = CFrame.new(at + Vector3.new(0, 0.06, 0)) * UPRIGHT
	local edge = part(f, Vector3.new(0.08, radius * 2 + 0.6, radius * 2 + 0.6), EDGE, 0.25, true)
	edge.CFrame = base
	local area = part(f, Vector3.new(0.1, radius * 2, radius * 2), RED, 0.6, true)
	area.CFrame = base * CFrame.new(0.02, 0, 0)
	local fill = part(f, Vector3.new(0.12, 0.1, 0.1), RED, 0.15, true)
	local connection = RunService.RenderStepped:Connect(function()
		local k = progress(start, impact)
		local d = math.max(radius * 2 * k, 0.1)
		fill.Size = Vector3.new(0.12, d, d)
		fill.CFrame = base * CFrame.new(0.04, 0, 0)
		edge.Color = if blink(k) then Color3.new(1, 1, 1) else EDGE
		edge.Transparency = if blink(k) then 0 else 0.25
	end)
	return {
		Destroy = function()
			connection:Disconnect()
			f:Destroy()
		end,
	}
end

function Zones.Band(a: Vector3, b: Vector3, width: number, start: number, impact: number)
	local f = folder("ZoneBand")
	local length = (b - a).Magnitude
	local mid = (a + b) / 2 + Vector3.new(0, 0.06, 0)
	local frame = CFrame.lookAt(mid, mid + (b - a))
	local edge = part(f, Vector3.new(width + 0.6, 0.08, length + 0.6), EDGE, 0.3)
	edge.CFrame = frame
	local area = part(f, Vector3.new(width, 0.1, length), RED, 0.6)
	area.CFrame = frame * CFrame.new(0, 0.02, 0)
	-- Le remplissage avance dans le sens où l'haltère va rouler
	local fill = part(f, Vector3.new(width, 0.12, 0.1), RED, 0.2)
	-- Chevrons qui indiquent le sens
	local chevrons = {}
	for k = 1, 4 do
		chevrons[k] = part(f, Vector3.new(width * 0.6, 0.14, 0.6), EDGE, 0.2)
	end
	local connection = RunService.RenderStepped:Connect(function()
		local k = progress(start, impact)
		local l = math.max(length * k, 0.1)
		fill.Size = Vector3.new(width, 0.12, l)
		fill.CFrame = frame * CFrame.new(0, 0.04, length / 2 - l / 2)
		for i, c in chevrons do
			local z = length / 2 - ((serverNow() * 8 + i * length / 4) % length)
			c.CFrame = frame * CFrame.new(0, 0.06, z) * CFrame.Angles(0, math.rad(45), 0)
		end
		edge.Color = if blink(k) then Color3.new(1, 1, 1) else EDGE
	end)
	return {
		Destroy = function()
			connection:Disconnect()
			f:Destroy()
		end,
	}
end

-- Cône devant le dieu (coup de poing au sol) : éventail de lames fines qui se remplissent depuis lui
function Zones.Cone(at: Vector3, dir: Vector3, angle: number, length: number, start: number, impact: number)
	local f = folder("ZoneCone")
	local base = CFrame.lookAt(at + Vector3.new(0, 0.06, 0), at + Vector3.new(dir.X, 0.06, dir.Z))
	local count = math.max(math.ceil(angle / 6), 3)
	local step = math.rad(angle) / count
	local width = 2 * length * math.tan(step / 2) + 0.3
	local slices = {}
	for k = 1, count do
		local a = -math.rad(angle) / 2 + step * (k - 0.5)
		local frame = base * CFrame.Angles(0, -a, 0)
		local area = part(f, Vector3.new(width, 0.1, length), RED, 0.6)
		area.CFrame = frame * CFrame.new(0, 0, -length / 2)
		local fill = part(f, Vector3.new(width, 0.12, 0.1), RED, 0.2)
		slices[k] = { frame = frame, fill = fill }
	end
	-- Bords du cône, bien visibles
	local edges = {}
	for k, a in { -math.rad(angle) / 2, math.rad(angle) / 2 } do
		local edge = part(f, Vector3.new(0.5, 0.14, length), EDGE, 0.2)
		edge.CFrame = base * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0.03, -length / 2)
		edges[k] = edge
	end
	local connection = RunService.RenderStepped:Connect(function()
		local k = progress(start, impact)
		local l = math.max(length * k, 0.1)
		for _, slice in slices do
			slice.fill.Size = Vector3.new(width, 0.12, l)
			slice.fill.CFrame = slice.frame * CFrame.new(0, 0.04, -l / 2)
		end
		for _, edge in edges do
			edge.Color = if blink(k) then Color3.new(1, 1, 1) else EDGE
		end
	end)
	return {
		Destroy = function()
			connection:Disconnect()
			f:Destroy()
		end,
	}
end

-- Onde : avant le départ, un cercle doré qui palpite autour du dieu ; ensuite un anneau d'énergie (un mur bas, à
-- sauter) qui s'élargit jusqu'au mur de la piste
function Zones.Ring(at: Vector3, start: number, go: number, speed: number, thickness: number, maxRadius: number)
	local f = folder("ZoneRing")
	local base = CFrame.new(at + Vector3.new(0, 0.06, 0))
	local warn = part(f, Vector3.new(0.1, 8, 8), GOLD, 0.4, true)
	local segments = {}
	local count = 48
	for k = 1, count do
		segments[k] = part(f, Vector3.new(1, 1.4, thickness), RED, 0.25)
		segments[k].Transparency = 1
	end
	local connection = RunService.RenderStepped:Connect(function()
		local t = serverNow()
		if t < go then
			local k = progress(start, go)
			local d = 6 + 6 * math.abs(math.sin(t * 9)) + 4 * k
			warn.Size = Vector3.new(0.1, d, d)
			warn.CFrame = base * UPRIGHT
			warn.Color = if blink(k) then Color3.new(1, 1, 1) else GOLD
			return
		end
		warn.Transparency = 1
		local radius = (t - go) * speed
		local fade = math.clamp((radius - (maxRadius - 6)) / 6, 0, 1)
		local width = 2 * radius * math.sin(math.pi / count) + 0.4
		for k, seg in segments do
			local a = 2 * math.pi * k / count
			local pos = base * CFrame.new(math.cos(a) * radius, 0.7, math.sin(a) * radius)
			seg.Size = Vector3.new(width, 1.4, thickness)
			seg.CFrame = CFrame.lookAt(pos.Position, base.Position + Vector3.new(0, 0.7, 0))
			seg.Transparency = 0.2 + 0.8 * fade
			seg.Color = if k % 2 == 0 then RED else GOLD
		end
	end)
	return {
		Destroy = function()
			connection:Disconnect()
			f:Destroy()
		end,
	}
end

-- Dalles de mosaïque (manche 2) : chaque case du motif s'allume et se remplit depuis son centre
function Zones.Tiles(cells: { Vector3 }, cell: number, start: number, impact: number)
	local f = folder("ZoneTiles")
	local fills = {}
	local edges = {}
	for k, at in cells do
		local base = CFrame.new(at + Vector3.new(0, 0.06, 0))
		local edge = part(f, Vector3.new(cell - 0.5, 0.08, cell - 0.5), EDGE, 0.35)
		edge.CFrame = base
		edges[k] = edge
		local area = part(f, Vector3.new(cell - 1.3, 0.1, cell - 1.3), RED, 0.6)
		area.CFrame = base * CFrame.new(0, 0.02, 0)
		fills[k] = { part = part(f, Vector3.new(0.1, 0.12, 0.1), RED, 0.15), base = base }
	end
	local connection = RunService.RenderStepped:Connect(function()
		local k = progress(start, impact)
		local d = math.max((cell - 1.3) * k, 0.1)
		for _, fill in fills do
			fill.part.Size = Vector3.new(d, 0.12, d)
			fill.part.CFrame = fill.base * CFrame.new(0, 0.04, 0)
		end
		local color = if blink(k) then Color3.new(1, 1, 1) else EDGE
		for _, edge in edges do
			edge.Color = color
		end
	end)
	return {
		Destroy = function()
			connection:Disconnect()
			f:Destroy()
		end,
	}
end

-- Orage (manche 3) : toute la piste se remplit de rouge depuis le centre, sauf les cercles sûrs (dorés, au-dessus)
function Zones.Storm(at: Vector3, radius: number, safes: { Vector3 }, safeRadius: number, start: number, impact: number)
	local f = folder("ZoneStorm")
	local base = CFrame.new(at + Vector3.new(0, 0.06, 0)) * UPRIGHT
	local area = part(f, Vector3.new(0.1, radius * 2, radius * 2), RED, 0.7, true)
	area.CFrame = base
	local fill = part(f, Vector3.new(0.12, 0.1, 0.1), RED, 0.3, true)
	local rims = {}
	for k, safe in safes do
		local frame = CFrame.new(safe + Vector3.new(0, 0.1, 0)) * UPRIGHT
		local rim = part(f, Vector3.new(0.22, safeRadius * 2 + 0.8, safeRadius * 2 + 0.8), GOLD, 0, true)
		rim.CFrame = frame
		rims[k] = rim
		local inside =
			part(f, Vector3.new(0.26, safeRadius * 2, safeRadius * 2), Color3.fromRGB(90, 220, 120), 0.1, true)
		inside.Material = Enum.Material.SmoothPlastic
		inside.CFrame = frame * CFrame.new(0.02, 0, 0)
	end
	local connection = RunService.RenderStepped:Connect(function()
		local k = progress(start, impact)
		local d = math.max(radius * 2 * k, 0.1)
		fill.Size = Vector3.new(0.12, d, d)
		fill.CFrame = base * CFrame.new(0.02, 0, 0)
		local pulse = 0.5 + 0.5 * math.sin(serverNow() * 10)
		for _, rim in rims do
			rim.Color = GOLD:Lerp(Color3.new(1, 1, 1), pulse)
		end
	end)
	return {
		Destroy = function()
			connection:Disconnect()
			f:Destroy()
		end,
	}
end

-- Saut du dieu (manche 2) : un cercle suit `follow()` (le combattant), puis se fige (:Lock) là où il va retomber
function Zones.Chase(follow: () -> Vector3?, radius: number, start: number, impact: number)
	local f = folder("ZoneChase")
	local edge = part(f, Vector3.new(0.08, radius * 2 + 0.6, radius * 2 + 0.6), EDGE, 0.25, true)
	local area = part(f, Vector3.new(0.1, radius * 2, radius * 2), RED, 0.6, true)
	local fill = part(f, Vector3.new(0.12, 0.1, 0.1), RED, 0.15, true)
	local locked: Vector3? = nil
	local last = follow() or Vector3.zero
	local connection = RunService.RenderStepped:Connect(function()
		local at = locked or follow() or last
		last = at
		local base = CFrame.new(at + Vector3.new(0, 0.06, 0)) * UPRIGHT
		local k = progress(start, impact)
		local d = math.max(radius * 2 * k, 0.1)
		edge.CFrame = base
		area.CFrame = base * CFrame.new(0.02, 0, 0)
		fill.Size = Vector3.new(0.12, d, d)
		fill.CFrame = base * CFrame.new(0.04, 0, 0)
		edge.Color = if locked and blink(k) then Color3.new(1, 1, 1) else EDGE
		edge.Transparency = if locked then 0 else 0.25
	end)
	return {
		Lock = function(at: Vector3)
			locked = at
		end,
		Destroy = function()
			connection:Disconnect()
			f:Destroy()
		end,
	}
end

-- Regard brûlant (manche 3) : avant, l'éventail balayé est marqué (deux bords et un trait qui palpite au départ) ;
-- ensuite une bande rouge tourne au sol depuis le géant, de l'angle `from` à `to` (radians, comme cos / sin en X / Z)
function Zones.Sweep(
	at: Vector3,
	from: number,
	to: number,
	width: number,
	length: number,
	start: number,
	go: number,
	ends: number
)
	local f = folder("ZoneSweep")
	local base = at + Vector3.new(0, 0.08, 0)
	local function frameAt(a: number, l: number): CFrame
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		return CFrame.lookAt(base + dir * l / 2, base + dir * l)
	end
	for _, a in { from, to } do
		local edge = part(f, Vector3.new(0.5, 0.1, length), EDGE, 0.3)
		edge.CFrame = frameAt(a, length)
	end
	local beam = part(f, Vector3.new(width, 0.14, length), RED, 0.5)
	local connection = RunService.RenderStepped:Connect(function()
		local t = serverNow()
		if t < go then
			local k = progress(start, go)
			beam.CFrame = frameAt(from, length)
			beam.Transparency = 0.7 - 0.5 * math.abs(math.sin(t * 8)) * k
			beam.Color = if blink(k) then Color3.new(1, 1, 1) else RED
			return
		end
		local k = math.clamp((t - go) / math.max(ends - go, 0.05), 0, 1)
		beam.CFrame = frameAt(from + (to - from) * k, length)
		beam.Transparency = 0.15
		beam.Color = RED
	end)
	return {
		Destroy = function()
			connection:Disconnect()
			f:Destroy()
		end,
	}
end

Zones.ServerNow = serverNow

return Zones
