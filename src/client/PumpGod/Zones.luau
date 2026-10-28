-- Zones d'attaque du Dieu du Pump (D90), dessinées au sol de la piste à l'heure du serveur.
-- Règle de lisibilité (D89) : jamais d'attaque sans zone ; contour épais et clair, remplissage rouge qui grandit
-- jusqu'à l'impact (on voit le temps qui reste), clignotement blanc juste avant.
--   Zones.Circle(at, radius, start, impact)              cercle (foudre)
--   Zones.Band(a, b, width, start, impact)               bande (haltère qui roule)
--   Zones.Ring(at, start, impact, speed, thickness, max) anneau qui part du dieu et s'élargit (onde : sauter)
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

Zones.ServerNow = serverNow

return Zones
