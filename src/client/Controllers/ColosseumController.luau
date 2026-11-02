-- Le Colisée du Pump (D89, tranche 1) côté client : l'arène vit.
-- - Braseros (tag "ColosseumFire") : feu, braises et lumière orangée ; éteints loin du joueur (téléphone).
--   Attributs optionnels du repère : FireSize (taille des flammes, 3 par défaut) et FireRange (portée d'allumage),
--   pour les torches et braseros géants du Mur des Colosses (D107), visibles de loin.
-- - Foule des gradins (MapProps « Colosseum_Crowd ») : elle sautille par vagues, chaque secteur à son rythme.
-- - Portails (tag "ColosseumPortal" = l'ouverture de l'arche, D105) : tourbillon doré qui tourne dans l'arche,
--   éclats de lumière aspirés vers le centre, cœur qui bat.
-- - Voyage (Remotes.ColosseumTravel) : la colonne s'élargit et monte jusqu'au ciel autour du joueur qui part ; pour
--   soi, l'écran blanchit puis revient à l'arrivée. Tout est local : rien ne part vers le serveur.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local FIRE_TAG = "ColosseumFire"
local PORTAL_TAG = "ColosseumPortal"
local CROWD_NAME = "Colosseum_Crowd"
local SETTINGS = Balance.Colosseum
local VORTEX = SETTINGS.Vortex
local GOLD = Color3.fromRGB(255, 214, 110)
local FLAME = Color3.fromRGB(255, 150, 50)

local player = Players.LocalPlayer

local fires: { [BasePart]: { Instance } } = {}
local crowds: { [BasePart]: { base: CFrame, phase: number } } = {}
type Portal = { core: BasePart, glow: BasePart, dots: { BasePart }, frames: { CFrame } }
local portals: { [BasePart]: Portal } = {}

local ColosseumController = {}

local function effectPart(name: string, size: Vector3, color: Color3, transparency: number, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Size = size
	part.Parent = parent
	return part
end

-- Brasero : flammes, braises qui montent, lumière chaude
local function addFire(anchor: Instance)
	if not anchor:IsA("BasePart") or fires[anchor] then
		return
	end
	local size = anchor:GetAttribute("FireSize")
	local scale = if typeof(size) == "number" then size / 3 else 1
	local fire = Instance.new("Fire")
	fire.Size = 3 * scale
	fire.Heat = 7
	fire.Color = FLAME
	fire.SecondaryColor = Color3.fromRGB(200, 50, 20)
	fire.Parent = anchor
	local light = Instance.new("PointLight")
	light.Color = FLAME
	light.Range = math.min(14 * scale, 60)
	light.Brightness = 1
	light.Shadows = false
	light.Parent = anchor
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 90, 30))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.18 * scale, 0)
	embers.Lifetime = NumberRange.new(1.2, 2)
	embers.Speed = NumberRange.new(3 * scale, 6 * scale)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Acceleration = Vector3.new(0, 2, 0)
	embers.Rate = 6
	embers.Parent = anchor
	fires[anchor] = { fire, light, embers }
end

-- Foule : retient sa place de repos la première fois qu'on la voit
local function trackCrowd(part: Instance)
	if not part:IsA("BasePart") or part.Name ~= CROWD_NAME or crowds[part] then
		return
	end
	local p = part.Position
	crowds[part] = { base = part.CFrame, phase = (math.atan2(p.Z, p.X) * 3) % (2 * math.pi) }
end

-- Portail : le repère a la taille de l'ouverture de l'arche (ovale, face à son axe Z). Fond doré, cœur clair qui
-- bat, bras de lumière en spirale (des éclats posés à chaque image), poussières aspirées vers le centre.
local function addPortal(anchor: Instance)
	if not anchor:IsA("BasePart") or portals[anchor] then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "PortalFx"
	folder.Parent = anchor
	local size = anchor.Size
	-- Cylindre couché : son axe X passe dans l'axe du portail, ses diamètres Y, Z font l'ovale
	local facing = anchor.CFrame * CFrame.Angles(0, math.pi / 2, 0)
	local glow = effectPart("Glow", Vector3.new(0.15, size.Y, size.X), GOLD, 0.35, folder)
	glow.Shape = Enum.PartType.Cylinder
	glow.CFrame = facing
	local core =
		effectPart("Core", Vector3.new(0.3, size.Y * 0.4, size.X * 0.4), Color3.fromRGB(255, 248, 220), 0.1, folder)
	core.Shape = Enum.PartType.Cylinder
	core.CFrame = facing
	local dots = {}
	for i = 1, VORTEX.Arms * VORTEX.Dots do
		local dot = effectPart("Swirl", Vector3.one * 0.3, Color3.fromRGB(255, 236, 160), 0, folder)
		dot.Shape = Enum.PartType.Ball
		dot.CFrame = anchor.CFrame
		dots[i] = dot
	end
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 14
	light.Brightness = 1.4
	light.Parent = core
	-- Poussières : nées sur le bord de l'ovale, aspirées vers le centre
	local motes = Instance.new("ParticleEmitter")
	motes.Shape = Enum.ParticleEmitterShape.Disc
	motes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	motes.EmissionDirection = Enum.NormalId.Right -- l'axe X du cylindre = l'axe du portail
	motes.Color = ColorSequence.new(GOLD)
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Lifetime = NumberRange.new(0.8, 1.2)
	motes.Speed = NumberRange.new(2, 3)
	motes.Rate = 18
	motes.Parent = glow
	portals[anchor] = { core = core, glow = glow, dots = dots, frames = table.create(#dots, anchor.CFrame) }
end

-- Une image du tourbillon : chaque bras part du bord et s'enroule vers le centre ; le tout tourne, le cœur bat
local function spinPortal(anchor: BasePart, fx: Portal, now: number)
	local half = anchor.Size / 2
	local turn = now * VORTEX.Spin
	local i = 0
	for arm = 0, VORTEX.Arms - 1 do
		for k = 1, VORTEX.Dots do
			i += 1
			local r = 1 - (k - 0.5) / VORTEX.Dots -- du bord (1) vers le centre (0)
			local a = turn + arm * 2 * math.pi / VORTEX.Arms + (1 - r) * VORTEX.Twist
			fx.frames[i] = anchor.CFrame
				* CFrame.new(math.cos(a) * half.X * r * 0.92, math.sin(a) * half.Y * r * 0.92, 0)
		end
	end
	workspace:BulkMoveTo(fx.dots, fx.frames, Enum.BulkMoveMode.FireCFrameChanged)
	local beat = 0.5 + 0.5 * math.sin(now * VORTEX.Pulse * 2 * math.pi)
	fx.core.Transparency = 0.05 + 0.3 * beat
	fx.glow.Transparency = 0.3 + 0.1 * beat
end

-- Le voyage : la colonne s'élargit et monte jusqu'au ciel ; pour soi, un flash blanc qui couvre l'arrivée
local flash: Frame? = nil
local function onTravel(update)
	if typeof(update) ~= "table" or typeof(update.from) ~= "Vector3" then
		return
	end
	local who = update.player
	local character = typeof(who) == "Instance" and who:IsA("Player") and who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local at = if root then root.Position else update.from
	local beam = effectPart("TravelBeam", Vector3.new(160, 1, 1), Color3.fromRGB(255, 240, 190), 0.1, workspace)
	beam.Shape = Enum.PartType.Cylinder
	beam.CFrame = CFrame.new(at + Vector3.new(0, 76, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local grow = TweenService:Create(beam, TweenInfo.new(SETTINGS.TravelDelay, Enum.EasingStyle.Quad), {
		Size = Vector3.new(160, 9, 9),
		Transparency = 0.3,
	})
	grow:Play()
	task.delay(SETTINGS.TravelDelay, function()
		TweenService:Create(beam, TweenInfo.new(0.5), { Size = Vector3.new(160, 0.5, 0.5), Transparency = 1 }):Play()
		task.delay(0.55, function()
			beam:Destroy()
		end)
	end)
	if who == player and flash then
		local screen = flash
		screen.BackgroundTransparency = 1
		screen.Visible = true
		TweenService:Create(
			screen,
			TweenInfo.new(SETTINGS.TravelDelay * 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 0 }
		):Play()
		task.delay(SETTINGS.TravelDelay + 0.15, function()
			local fade = TweenService:Create(screen, TweenInfo.new(0.7), { BackgroundTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			screen.Visible = false
		end)
	end
end

local function myPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

function ColosseumController.Start()
	local gui = Ui.create("ScreenGui", {
		Name = "ColosseumFx",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
		Parent = player:WaitForChild("PlayerGui"),
	})
	flash = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 250, 235),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})

	for _, anchor in CollectionService:GetTagged(FIRE_TAG) do
		addFire(anchor)
	end
	CollectionService:GetInstanceAddedSignal(FIRE_TAG):Connect(addFire)
	CollectionService:GetInstanceRemovedSignal(FIRE_TAG):Connect(function(anchor)
		fires[anchor :: BasePart] = nil
	end)
	for _, anchor in CollectionService:GetTagged(PORTAL_TAG) do
		addPortal(anchor)
	end
	CollectionService:GetInstanceAddedSignal(PORTAL_TAG):Connect(addPortal)
	CollectionService:GetInstanceRemovedSignal(PORTAL_TAG):Connect(function(anchor)
		portals[anchor :: BasePart] = nil
	end)

	-- La foule est posée par le serveur dans MapProps (et revient avec le streaming)
	local function watchProps(folder: Instance)
		for _, child in folder:GetChildren() do
			trackCrowd(child)
		end
		folder.ChildAdded:Connect(trackCrowd)
		folder.ChildRemoved:Connect(function(child)
			crowds[child :: BasePart] = nil
		end)
	end
	local props = workspace:FindFirstChild("MapProps")
	if props then
		watchProps(props)
	end
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "MapProps" then
			watchProps(child)
		end
	end)
	Remotes.ColosseumTravel.OnClientEvent:Connect(onTravel)

	-- Braseros allumés seulement près du joueur
	task.spawn(function()
		while true do
			local here = myPosition()
			for anchor, effects in fires do
				local range = anchor:GetAttribute("FireRange")
				local reach = if typeof(range) == "number" then range else SETTINGS.FireRange
				local on = here ~= nil and (anchor.Position - here).Magnitude < reach
				for _, effect in effects do
					(effect :: any).Enabled = on
				end
			end
			task.wait(1)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local here = myPosition()
		if not here then
			return
		end
		for part, crowd in crowds do
			if (crowd.base.Position - here).Magnitude < SETTINGS.FireRange * 1.5 then
				local wave = math.max(math.sin(now * 2 * math.pi * SETTINGS.CrowdSpeed * 0.5 + crowd.phase), 0)
				part.CFrame = crowd.base * CFrame.new(0, SETTINGS.CrowdBounce * wave * wave, 0)
			end
		end
		for anchor, fx in portals do
			if (anchor.Position - here).Magnitude < VORTEX.Range then
				spinPortal(anchor, fx, now)
			end
		end
	end)
end

return ColosseumController
