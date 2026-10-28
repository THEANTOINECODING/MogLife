-- Effets du combat du Dieu du Pump (D90, D91), tous locaux (aucune collision, ni requête), calés sur l'heure du serveur :
-- éclairs, haltère géant, impacts au sol, javelot d'éclair, disques d'haltère dorés, cercle de la pose sacrée, rayon
-- de Mog, étoiles de l'essoufflement, chiffres flottants.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Parent.Ui)
local Zones = require(script.Parent.Zones)

local Fx = {}

local BOLT_COLOR = Color3.fromRGB(190, 225, 255)
local GOLD = Color3.fromRGB(255, 210, 90)
local IRON = Color3.fromRGB(70, 70, 80)
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- cylindre de Roblox : axe X -> vertical
Fx.Gold = GOLD

function Fx.Part(size: Vector3, color: Color3, transparency: number, shape: Enum.PartType?): Part
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
	if shape then
		p.Shape = shape
	end
	p.Parent = workspace
	return p
end
local part = Fx.Part

function Fx.FadeOut(p: BasePart, time: number, grow: Vector3?)
	local goal: { [string]: any } = { Transparency = 1 }
	if grow then
		goal.Size = grow
	end
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, time + 0.05)
end
local fadeOut = Fx.FadeOut

-- Disque qui s'élargit au sol en s'effaçant (poussière, onde de choc)
function Fx.GroundBurst(at: Vector3, from: number, to: number, color: Color3, time: number?)
	local disc = part(Vector3.new(0.3, from, from), color, 0.1, Enum.PartType.Cylinder)
	disc.CFrame = CFrame.new(at + Vector3.new(0, 0.25, 0)) * UPRIGHT
	fadeOut(disc, time or 0.5, Vector3.new(0.3, to, to))
	return disc
end

-- Éclair en zigzag tombé du ciel (passant au-dessus de la main du dieu), puis poussière dorée au sol
function Fx.Bolt(at: Vector3, radius: number, from: Vector3)
	local top = Vector3.new(at.X, at.Y + 70, at.Z):Lerp(from, 0.25)
	local points = { top }
	local count = 7
	for k = 1, count - 1 do
		local p = top:Lerp(at, k / count)
		points[k + 1] = p + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 5
	end
	points[count + 1] = at
	for k = 1, count do
		local a, b = points[k], points[k + 1]
		local seg = part(Vector3.new(0.7, 0.7, (b - a).Magnitude), BOLT_COLOR, 0)
		seg.CFrame = CFrame.lookAt((a + b) / 2, b)
		fadeOut(seg, 0.3)
	end
	local disc = Fx.GroundBurst(at, radius, radius * 2.4, GOLD, 0.45)
	local light = Instance.new("PointLight")
	light.Color = BOLT_COLOR
	light.Range = 24
	light.Brightness = 6
	light.Parent = disc
end

-- Haltère géant : il tombe du ciel au début de la bande, puis roule jusqu'au bout. onLand() au moment où il touche.
function Fx.Dumbbell(message, alive: () -> boolean, onLand: () -> ()): Model
	local a, b = message.a :: Vector3, message.b :: Vector3
	local plate = message.height :: number
	local width = message.width :: number
	local model = Instance.new("Model")
	model.Name = "PumpGodDumbbell"
	local bar =
		part(Vector3.new(width, plate * 0.22, plate * 0.22), Color3.fromRGB(200, 200, 210), 0, Enum.PartType.Cylinder)
	bar.Material = Enum.Material.Metal
	bar.Parent = model
	local plates = {}
	for k, x in { -1, 1 } do
		local disc = part(Vector3.new(width * 0.16, plate, plate), IRON, 0, Enum.PartType.Cylinder)
		disc.Material = Enum.Material.SmoothPlastic
		disc.Parent = model
		local rim = part(Vector3.new(width * 0.17, plate * 0.45, plate * 0.45), GOLD, 0, Enum.PartType.Cylinder)
		rim.Parent = model
		plates[k] = { disc = disc, rim = rim, x = x * width * 0.4 }
	end
	model.Parent = workspace
	local frame = CFrame.lookAt(a, b)
	local length = (b - a).Magnitude
	local landed = false
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local s = (Zones.ServerNow() - message.impact) * message.speed
		if s > length + 4 or not alive() then
			connection:Disconnect()
			model:Destroy()
			return
		end
		local y = plate / 2
		if s < 0 then
			-- Chute pendant la dernière demi-seconde d'avertissement (avant : haut dans le ciel, invisible)
			local fall = math.clamp(-s / message.speed / 0.5, 0, 1)
			y += fall * fall * 60
			s = 0
		elseif not landed then
			landed = true
			local dust = Fx.GroundBurst(a, width, width * 2.5, Color3.fromRGB(230, 200, 150))
			dust.Material = Enum.Material.SmoothPlastic
			onLand()
		end
		local spin = -s / (plate / 2)
		local base = frame * CFrame.new(0, y, -s) * CFrame.Angles(spin, 0, 0)
		bar.CFrame = base
		for _, p in plates do
			p.disc.CFrame = base * CFrame.new(p.x, 0, 0)
			p.rim.CFrame = base * CFrame.new(p.x * 1.06, 0, 0)
		end
	end)
	return model
end

-- Javelot d'éclair : dans la main du dieu pendant l'avertissement, puis il file au ras du sol vers le mur.
-- Renvoyé (:Reverse) : il repart, doré, vers la poitrine du dieu.
function Fx.Javelin(message, hand: () -> Vector3)
	local model = Instance.new("Model")
	model.Name = "PumpGodJavelin"
	local shaft = part(Vector3.new(0.45, 0.45, 8), BOLT_COLOR, 0)
	shaft.Parent = model
	local tipPart = part(Vector3.new(1.1, 1.1, 1.6), Color3.new(1, 1, 1), 0)
	tipPart.Parent = model
	local light = Instance.new("PointLight")
	light.Color = BOLT_COLOR
	light.Range = 14
	light.Brightness = 3
	light.Parent = tipPart
	model.Parent = workspace
	local dir = message.dir :: Vector3
	local height = message.height :: number
	local reverse: { from: Vector3, to: () -> Vector3, start: number, arrive: number }? = nil
	local connection
	local function place(tip: Vector3, forward: Vector3)
		local frame = CFrame.lookAt(tip, tip + forward)
		shaft.CFrame = frame * CFrame.new(0, 0, 4)
		tipPart.CFrame = frame * CFrame.new(0, 0, -0.4)
	end
	connection = RunService.RenderStepped:Connect(function()
		local now = Zones.ServerNow()
		if reverse then
			local k = math.clamp((now - reverse.start) / (reverse.arrive - reverse.start), 0, 1)
			local to = reverse.to()
			local pos = reverse.from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * 4, 0)
			place(pos, to - reverse.from)
			if k >= 1 then
				connection:Disconnect()
				model:Destroy()
			end
			return
		end
		if now < message.impact then
			-- Tenu à bout de bras, pointe vers la cible ; il vibre
			local h = hand()
			place(h + Vector3.new(0, 1.5, 0) + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.15, dir)
			return
		end
		local s = (now - message.impact) * message.speed
		if s > message.length + 2 then
			connection:Disconnect()
			model:Destroy()
			return
		end
		-- Part de la main et plonge vite à hauteur de poitrine
		local ground = message.at + dir * s + Vector3.new(0, height, 0)
		local dive = math.clamp(s / 10, 0, 1)
		place(hand():Lerp(ground, dive), dir)
	end)
	return {
		model = model,
		Reverse = function(_, from: Vector3, to: () -> Vector3, start: number, arrive: number)
			reverse = { from = from + Vector3.new(0, height, 0), to = to, start = start, arrive = arrive }
			shaft.Color = GOLD
			tipPart.Color = GOLD
			light.Color = GOLD
		end,
		Destroy = function()
			connection:Disconnect()
			model:Destroy()
		end,
	}
end

-- Disque d'haltère doré posé sur la piste : il tourne sur lui-même sous une colonne de lumière. Porté, il flotte
-- au-dessus de la tête du joueur ; lancé, il file en cloche vers le dieu.
function Fx.Disc(at: Vector3)
	local disc = part(Vector3.new(0.7, 3.2, 3.2), GOLD, 0, Enum.PartType.Cylinder)
	disc.Material = Enum.Material.Metal
	disc.Reflectance = 0.2
	local hole = part(Vector3.new(0.8, 0.9, 0.9), IRON, 0, Enum.PartType.Cylinder)
	-- Fin rayon de lumière au-dessus (repérable de loin, sans éblouir)
	local column = part(Vector3.new(14, 1.4, 1.4), GOLD, 0.6, Enum.PartType.Cylinder)
	column.Material = Enum.Material.SmoothPlastic
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 10
	light.Brightness = 2
	light.Parent = disc
	local mode = "Ground"
	local carrier: (() -> BasePart?)? = nil
	local throw: { from: Vector3, to: () -> Vector3, start: number, arrive: number }? = nil
	local onArrive: (() -> ())? = nil
	local born = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - born
		local frame
		if mode == "Ground" then
			frame = CFrame.new(at + Vector3.new(0, 2 + math.sin(t * 3) * 0.3, 0)) * CFrame.Angles(0, t * 2, 0)
			column.CFrame = CFrame.new(at + Vector3.new(0, 7, 0)) * UPRIGHT
		elseif mode == "Carried" then
			local root = carrier and carrier()
			if not root then
				return
			end
			frame = CFrame.new(root.Position + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, t * 6, 0)
		elseif throw then
			local k = math.clamp((Zones.ServerNow() - throw.start) / (throw.arrive - throw.start), 0, 1)
			local to = throw.to()
			local pos = throw.from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * 8, 0)
			frame = CFrame.lookAt(pos, to) * CFrame.Angles(t * 25, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
			if k >= 1 then
				connection:Disconnect()
				disc:Destroy()
				hole:Destroy()
				column:Destroy()
				if onArrive then
					onArrive()
				end
				return
			end
		end
		if frame then
			disc.CFrame = frame * CFrame.Angles(0, math.pi / 2, 0)
			hole.CFrame = disc.CFrame
		end
	end)
	return {
		Carry = function(_, root: () -> BasePart?)
			mode = "Carried"
			carrier = root
			column.Transparency = 1
		end,
		Throw = function(_, from: Vector3, to: () -> Vector3, start: number, arrive: number, arrived: () -> ())
			mode = "Thrown"
			throw = { from = from + Vector3.new(0, 4.5, 0), to = to, start = start, arrive = arrive }
			onArrive = arrived
			column.Transparency = 1
		end,
		Destroy = function()
			connection:Disconnect()
			disc:Destroy()
			hole:Destroy()
			column:Destroy()
		end,
	}
end

-- Cercle de la pose sacrée : anneau doré qui palpite, colonne de lumière ; pendant la charge, il se remplit
function Fx.Sacred(at: Vector3, radius: number)
	local f = Instance.new("Folder")
	f.Name = "PumpGodSacred"
	f.Parent = workspace
	local base = CFrame.new(at + Vector3.new(0, 0.08, 0)) * UPRIGHT
	local ring = part(Vector3.new(0.12, radius * 2 + 0.8, radius * 2 + 0.8), GOLD, 0.1, Enum.PartType.Cylinder)
	ring.Parent = f
	ring.CFrame = base
	local inner = part(
		Vector3.new(0.14, radius * 2 - 0.4, radius * 2 - 0.4),
		Color3.fromRGB(255, 245, 200),
		0.55,
		Enum.PartType.Cylinder
	)
	inner.Parent = f
	inner.CFrame = base * CFrame.new(0.02, 0, 0)
	local fill = part(Vector3.new(0.16, 0.1, 0.1), GOLD, 0.05, Enum.PartType.Cylinder)
	fill.Parent = f
	-- Colonne de lumière discrète (matière lisse : le néon éblouit), plus dense pendant la charge
	local column =
		part(Vector3.new(30, radius * 1.2, radius * 1.2), Color3.fromRGB(255, 235, 160), 0.85, Enum.PartType.Cylinder)
	column.Material = Enum.Material.SmoothPlastic
	column.Parent = f
	column.CFrame = CFrame.new(at + Vector3.new(0, 15, 0)) * UPRIGHT
	local charge: { start: number, ends: number }? = nil
	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local pulse = 1 + math.sin(t * 5) * 0.05
		ring.Size = Vector3.new(0.12, (radius * 2 + 0.8) * pulse, (radius * 2 + 0.8) * pulse)
		local k = 0
		if charge then
			k = math.clamp((Zones.ServerNow() - charge.start) / (charge.ends - charge.start), 0, 1)
		end
		local d = math.max((radius * 2 - 0.4) * k, 0.1)
		fill.Size = Vector3.new(0.16, d, d)
		fill.CFrame = base * CFrame.new(0.04, 0, 0)
		column.Transparency = 0.85 - 0.4 * k
	end)
	return {
		SetCharge = function(_, start: number?, ends: number?)
			charge = if start and ends then { start = start, ends = ends } else nil
		end,
		Destroy = function()
			connection:Disconnect()
			f:Destroy()
		end,
	}
end

-- Rayon de Mog : colonne dorée du joueur à la poitrine du dieu, qui s'élargit puis s'efface
function Fx.Beam(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local beam = part(Vector3.new(length, 1.5, 1.5), GOLD, 0, Enum.PartType.Cylinder)
	beam.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.pi / 2, 0)
	fadeOut(beam, 0.7, Vector3.new(length, 5, 5))
	local core = part(Vector3.new(length, 0.6, 0.6), Color3.new(1, 1, 1), 0, Enum.PartType.Cylinder)
	core.CFrame = beam.CFrame
	fadeOut(core, 0.5)
	Fx.Impact(to, 2)
end

-- Gerbe d'étincelles dorées (coups portés au dieu) ; power : 1 normal, 2 gros coup
function Fx.Impact(at: Vector3, power: number)
	local ball = part(Vector3.new(2, 2, 2) * power, GOLD, 0.1, Enum.PartType.Ball)
	ball.Position = at
	fadeOut(ball, 0.35, Vector3.new(6, 6, 6) * power)
	for _ = 1, 4 + 4 * power do
		local spark = part(Vector3.new(0.3, 0.3, 1.6), Color3.fromRGB(255, 240, 180), 0)
		local dir = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5).Unit
		spark.CFrame = CFrame.lookAt(at, at + dir)
		TweenService:Create(spark, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(at + dir * 5 * power, at + dir * 6 * power),
			Transparency = 1,
		}):Play()
		Debris:AddItem(spark, 0.4)
	end
end

-- Étoiles qui tournent au-dessus de sa tête tant qu'il est essoufflé
function Fx.Stars(top: () -> Vector3, ends: number)
	local stars = {}
	for k = 1, 4 do
		stars[k] = part(Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(255, 235, 120), 0, Enum.PartType.Ball)
	end
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if Zones.ServerNow() > ends then
			connection:Disconnect()
			for _, s in stars do
				s:Destroy()
			end
			return
		end
		local center = top()
		local t = os.clock()
		for k, s in stars do
			local a = t * 4 + k * math.pi / 2
			s.Position = center + Vector3.new(math.cos(a) * 2.6, math.sin(a * 2) * 0.3, math.sin(a) * 2.6)
		end
	end)
	return {
		Destroy = function()
			connection:Disconnect()
			for _, s in stars do
				s:Destroy()
			end
		end,
	}
end

-- Texte qui monte et s'efface à un endroit du monde (dégâts, « MOG PUNCH! »)
function Fx.Float(at: Vector3, text: string, color: Color3, size: number?)
	local anchor = part(Vector3.new(0.2, 0.2, 0.2), color, 1)
	anchor.Position = at
	local billboard = Ui.create("BillboardGui", {
		Size = UDim2.fromOffset(size or 110, (size or 110) * 0.45),
		StudsOffsetWorldSpace = Vector3.zero,
		AlwaysOnTop = true,
		Adornee = anchor,
		Parent = anchor,
	})
	local label = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
		Parent = billboard,
	})
	TweenService:Create(billboard, TweenInfo.new(0.9), { StudsOffsetWorldSpace = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(anchor, 0.95)
end

return Fx
