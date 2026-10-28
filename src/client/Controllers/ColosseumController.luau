-- Le Colisée du Pump (D89, tranche 1) côté client : l'arène vit.
-- - Braseros (tag "ColosseumFire") : feu, braises et lumière orangée ; éteints loin du joueur (téléphone).
-- - Foule des gradins (MapProps « Colosseum_Crowd ») : elle sautille par vagues, chaque secteur à son rythme.
-- - Piliers de lumière (tag "ColosseumPortal") : colonne dorée qui tourne, poussières de lumière qui montent.
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
local GOLD = Color3.fromRGB(255, 214, 110)
local FLAME = Color3.fromRGB(255, 150, 50)

local player = Players.LocalPlayer

local fires: { [BasePart]: { Instance } } = {}
local crowds: { [BasePart]: { base: CFrame, phase: number } } = {}
local portals: { [BasePart]: { spin: BasePart, ring: BasePart } } = {}

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
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 7
	fire.Color = FLAME
	fire.SecondaryColor = Color3.fromRGB(200, 50, 20)
	fire.Parent = anchor
	local light = Instance.new("PointLight")
	light.Color = FLAME
	light.Range = 14
	light.Brightness = 1
	light.Shadows = false
	light.Parent = anchor
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 90, 30))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.18, 0)
	embers.Lifetime = NumberRange.new(1.2, 2)
	embers.Speed = NumberRange.new(3, 6)
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

-- Pilier de lumière : colonne dorée, anneau au sol, poussières qui montent
local function addPortal(anchor: Instance)
	if not anchor:IsA("BasePart") or portals[anchor] then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "PortalFx"
	folder.Parent = anchor
	local foot = anchor.Position - Vector3.new(0, anchor.Size.Y / 2, 0)
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local core = effectPart("Core", Vector3.new(24, 1.6, 1.6), GOLD, 0.6, folder)
	core.Shape = Enum.PartType.Cylinder
	core.CFrame = CFrame.new(foot + Vector3.new(0, 12, 0)) * upright
	local halo = effectPart("Halo", Vector3.new(24, 4.6, 4.6), GOLD, 0.9, folder)
	halo.Shape = Enum.PartType.Cylinder
	halo.CFrame = core.CFrame
	local ring = effectPart("Ring", Vector3.new(0.2, 7, 7), GOLD, 0.25, folder)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(foot + Vector3.new(0, 0.12, 0)) * upright
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 12
	light.Brightness = 1.2
	light.Parent = core
	local motes = Instance.new("ParticleEmitter")
	motes.Color = ColorSequence.new(GOLD)
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Lifetime = NumberRange.new(2, 3)
	motes.Speed = NumberRange.new(4, 7)
	motes.SpreadAngle = Vector2.new(8, 8)
	motes.Rate = 14
	motes.EmissionDirection = Enum.NormalId.Right -- l'axe X du cylindre est vertical
	motes.Parent = ring
	portals[anchor] = { spin = halo, ring = ring }
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
				local on = here ~= nil and (anchor.Position - here).Magnitude < SETTINGS.FireRange
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
			if (anchor.Position - here).Magnitude < 200 then
				fx.spin.CFrame = fx.spin.CFrame * CFrame.Angles(0.02, 0, 0)
				fx.ring.Transparency = 0.45 + 0.2 * math.sin(now * 3)
			end
		end
	end)
end

return ColosseumController
