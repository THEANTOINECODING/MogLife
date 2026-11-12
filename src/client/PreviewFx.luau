-- D127 : effets imités dans un aperçu 3D (ViewportFrame de la boutique). Un ViewportFrame n'affiche ni
-- ParticleEmitter, ni Trail, ni Beam : chaque particule est ici une petite pièce invisible portant une image
-- (Decal) tournée vers la caméra, déplacée et estompée à chaque image.
-- Sources : articles de luxe (Config/Luxury : Aura, Trail, Entrance) et aura des tenues Robux (StyleSets.Auras).
-- Usage : local fx = PreviewFx.new(world, camera) ; fx:Set(items, model) ; fx:Step(dt) chaque image ; fx:Destroy().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Feel = require(ReplicatedStorage.Shared.Config.Feel)
local Luxury = require(ReplicatedStorage.Shared.Config.Luxury)
local StyleItems = require(ReplicatedStorage.Shared.Config.StyleItems)
local StyleSets = require(ReplicatedStorage.Shared.Config.StyleSets)

local TUNING = Feel.ShopFx
local TEXTURE_ROOT = "rbxasset://textures/particles/"
local DEFAULT_TEXTURE = TEXTURE_ROOT .. "sparkles_main.dds"

type Emitter = {
	kind: "Aura" | "Trail" | "Entrance",
	texture: string,
	colors: { Color3 },
	alpha: { number }, -- opacité au début, au milieu, à la fin
	size: { number }, -- taille au début, au milieu, à la fin
	rate: number,
	life: { number },
	speed: { number },
	accel: Vector3,
	anchor: string, -- "Body", "UpperTorso", "LowerTorso", "Head", "Feet"
	flat: boolean,
	width: number,
	budget: number, -- particules en attente d'émission (fraction)
	clock: number,
}

type Particle = {
	part: BasePart,
	decal: Decal,
	position: Vector3,
	velocity: Vector3,
	accel: Vector3,
	age: number,
	life: number,
	emitter: Emitter,
	flat: boolean,
	turn: number,
}

local PreviewFx = {}
PreviewFx.__index = PreviewFx

local function texture(name: string?): string
	if not name or name == "" then
		return DEFAULT_TEXTURE
	end
	return if string.find(name, "://", 1, true) then name else TEXTURE_ROOT .. name
end

local function curve(values: { number }, t: number): number
	local a, b, c = values[1] or 1, values[2] or values[1] or 1, values[3] or values[2] or values[1] or 1
	return if t < 0.5 then a + (b - a) * t * 2 else b + (c - b) * (t - 0.5) * 2
end

local function between(range: { number }, rng: Random): number
	local low = range[1] or 0
	return low + ((range[2] or low) - low) * rng:NextNumber()
end

-- Émetteurs d'un article de luxe
local function luxuryEmitter(entry: Luxury.Entry): Emitter
	local fx = entry.fx
	local kind = entry.category
	local size = if kind == "Trail" then (fx.width or 1) else fx.size
	return {
		kind = kind,
		texture = texture(if kind == "Trail" then "" else fx.texture),
		colors = fx.colors,
		alpha = if kind == "Trail" then { 0.9, 0.7, 0 } else { 0.2, 1, 0 },
		size = if kind == "Entrance" then { size * 0.5, size * 0.9, size * 1.2 } else { size * 0.8, size, size * 0.6 },
		rate = fx.rate,
		life = { fx.lifetime * 0.8, fx.lifetime * 1.2 },
		speed = { fx.speed * 0.5, fx.speed },
		accel = Vector3.zero,
		anchor = if kind == "Aura" then "Body" else "Feet",
		flat = false,
		width = fx.width or 1,
		budget = 0,
		clock = TUNING.BurstEvery * 0.6,
	}
end

-- Émetteurs de l'aura d'une tenue Robux
local function setEmitters(setId: string, into: { Emitter })
	local aura = StyleSets.Auras[setId]
	for _, layer in (aura and aura.layers) or {} do
		table.insert(into, {
			kind = "Aura",
			texture = texture(layer.texture),
			colors = layer.colors,
			alpha = layer.alpha or { 0, 1, 0 },
			size = layer.size or { 0.3, 0.3, 0 },
			rate = layer.rate or 4,
			life = layer.life or { 1, 1 },
			speed = layer.speed or { 0.3, 0.6 },
			accel = layer.accel or Vector3.zero,
			anchor = layer.anchor or "UpperTorso",
			flat = layer.flat == true,
			width = 1,
			budget = 0,
			clock = 0,
		})
	end
end

function PreviewFx.new(world: Instance, camera: Camera)
	local self = setmetatable({}, PreviewFx)
	self.world = world
	self.camera = camera
	self.emitters = {} :: { Emitter }
	self.particles = {} :: { Particle }
	self.pool = {} :: { Particle }
	self.model = nil :: Model?
	self.anchors = {} :: { [string]: BasePart | false }
	self.box = nil :: { cf: CFrame, size: Vector3 }?
	self.rng = Random.new()
	self.folder = Instance.new("Folder")
	self.folder.Name = "PreviewFx"
	self.folder.Parent = world
	return self
end

-- Articles portés ou essayés : leurs effets remplacent les précédents
function PreviewFx:Set(items: { string }, model: Model?)
	self.model = model
	local emitters: { Emitter } = {}
	local sets: { [string]: boolean } = {}
	for _, itemId in items do
		local entry = Luxury.ById[itemId]
		if entry then
			table.insert(emitters, luxuryEmitter(entry))
		end
		local item = StyleItems[itemId]
		local setId = item and item.setId
		if setId and item.category == "Top" and not sets[setId] then
			sets[setId] = true
			setEmitters(setId, emitters)
		end
	end
	self.emitters = emitters
	self.anchors = {}
	self.box = nil
	for _, particle in self.particles do
		particle.age = particle.life
	end
end

-- Zone d'émission, dans le repère du modèle (il tourne sur lui-même autour de l'origine)
function PreviewFx:_origin(anchor: string): (Vector3, Vector3)
	local model = self.model :: Model
	if anchor ~= "Body" and anchor ~= "Feet" then
		local found = self.anchors[anchor]
		if found == nil then
			found = false
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and string.find(part.Name, anchor, 1, true) then
					found = part
					break
				end
			end
			self.anchors[anchor] = found
		end
		if found then
			return found.Position, found.Size * 0.5
		end
	end
	-- Le modèle tourne autour de l'axe vertical : sa boîte, mesurée une fois, reste valable
	if not self.box then
		local cf, size = model:GetBoundingBox()
		self.box = { cf = cf, size = size }
	end
	local cf, size = self.box.cf, self.box.size
	if anchor == "Feet" then
		return Vector3.new(cf.Position.X, cf.Position.Y - size.Y * 0.5 + 0.1, cf.Position.Z), Vector3.new(0.2, 0, 0.2)
	end
	return cf.Position, Vector3.new(size.X * 0.4, size.Y * 0.45, size.Z * 0.4)
end

function PreviewFx:_spawn(emitter: Emitter, position: Vector3, velocity: Vector3, accel: Vector3, life: number)
	if #self.particles >= TUNING.MaxParticles then
		return
	end
	local particle = table.remove(self.pool)
	if not particle then
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Size = Vector3.new(1, 1, 0.05)
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Front
		decal.Parent = part
		particle = {
			part = part,
			decal = decal,
			position = position,
			velocity = velocity,
			accel = accel,
			age = 0,
			life = life,
			emitter = emitter,
			flat = false,
			turn = 0,
		}
	end
	local p = particle :: Particle
	p.position, p.velocity, p.accel, p.age, p.life, p.emitter = position, velocity, accel, 0, life, emitter
	p.flat = emitter.flat
	p.turn = self.rng:NextNumber() * math.pi * 2
	p.decal.Texture = emitter.texture
	p.part.Parent = self.folder
	table.insert(self.particles, p)
end

function PreviewFx:_emit(emitter: Emitter, dt: number)
	local rng = self.rng
	local model = self.model :: Model
	if emitter.kind == "Entrance" then
		emitter.clock += dt
		if emitter.clock < TUNING.BurstEvery then
			return
		end
		emitter.clock = 0
		local origin = self:_origin("Feet")
		for _ = 1, math.min(emitter.rate, TUNING.BurstMax) do
			local dir = Vector3.new(rng:NextNumber() - 0.5, rng:NextNumber() * 0.9 + 0.3, rng:NextNumber() - 0.5).Unit
			local speed = between(emitter.speed, rng) * TUNING.BurstSpeedScale
			self:_spawn(
				emitter,
				origin + Vector3.new(0, 0.5, 0),
				dir * speed,
				Vector3.new(0, -TUNING.BurstGravity, 0),
				between(emitter.life, rng)
			)
		end
		return
	end
	local rate = if emitter.kind == "Trail" then TUNING.TrailRate else emitter.rate * TUNING.RateScale
	emitter.budget += rate * dt
	while emitter.budget >= 1 do
		emitter.budget -= 1
		local life = between(emitter.life, rng)
		if emitter.kind == "Trail" then
			-- Derrière les hanches : le modèle tourne, la traînée reste en place et dessine un arc
			local pivot = model:GetPivot()
			local hips = self:_origin("LowerTorso")
			local back = -pivot.LookVector
			local side = pivot.RightVector * (rng:NextNumber() - 0.5) * emitter.width * 0.5
			self:_spawn(emitter, hips + back * 0.8 + side, back * TUNING.TrailDrift, Vector3.zero, life)
		else
			local center, half = self:_origin(emitter.anchor)
			local offset = Vector3.new(
				(rng:NextNumber() * 2 - 1) * half.X,
				(rng:NextNumber() * 2 - 1) * half.Y,
				(rng:NextNumber() * 2 - 1) * half.Z
			)
			local dir = if emitter.flat
				then Vector3.zero
				else Vector3.new(rng:NextNumber() - 0.5, rng:NextNumber() - 0.3, rng:NextNumber() - 0.5).Unit
			self:_spawn(emitter, center + offset, dir * between(emitter.speed, rng), emitter.accel, life)
		end
	end
end

function PreviewFx:Step(dt: number)
	if not self.model or not self.model.Parent then
		for _, particle in self.particles do
			particle.age = particle.life
		end
	else
		for _, emitter in self.emitters do
			self:_emit(emitter, dt)
		end
	end
	local eye = self.camera.CFrame.Position
	local index = 1
	while index <= #self.particles do
		local p = self.particles[index]
		p.age += dt
		if p.age >= p.life then
			p.part.Parent = nil
			table.insert(self.pool, p)
			self.particles[index] = self.particles[#self.particles]
			self.particles[#self.particles] = nil
			continue
		end
		p.velocity += p.accel * dt
		p.position += p.velocity * dt
		local t = p.age / p.life
		local emitter = p.emitter
		local size = math.max(0.02, curve(emitter.size, t))
		local colors = emitter.colors
		p.decal.Color3 = if #colors > 1 then colors[1]:Lerp(colors[#colors], t) else colors[1]
		p.decal.Transparency = 1 - math.clamp(curve(emitter.alpha, t), 0, 1)
		p.part.Size = Vector3.new(size, size, 0.05)
		p.turn += dt
		p.part.CFrame = if p.flat
			then CFrame.new(p.position) * CFrame.Angles(math.pi / 2, 0, p.turn)
			else CFrame.lookAt(p.position, eye) * CFrame.Angles(0, 0, p.turn)
		index += 1
	end
end

function PreviewFx:Destroy()
	self.folder:Destroy()
	self.particles = {}
	self.pool = {}
end

return PreviewFx
