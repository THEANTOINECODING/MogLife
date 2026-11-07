-- Secrets de la ville (D121), côté client : l'annonce « SECRET FOUND » pour celui qui le trouve
-- (Remotes.SecretFound) et les scènes vues par tous (Remotes.SecretFx) :
-- - GhostLifter : l'haltère fantôme flotte et luit (tag GhostDumbbell) ; soulevé, il s'évapore dans un « booo ».
-- - StatueBeliever : la statue de la place cligne de l'œil et gonfle les biceps.
-- - SewerGains : le rat coach fait ses pompes et donne son conseil.
-- - NeverForget : un reflet du Normie du joueur apparaît devant le miroir du coiffeur et lui fait coucou.
-- Purement visuel : le serveur a déjà tout validé (SecretService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Outfit = require(ReplicatedStorage.Shared.Outfit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local GOLD = Color3.fromRGB(255, 210, 60)
local GHOST_BLUE = Color3.fromRGB(170, 220, 255)
local MAX_DISTANCE = 150

local player = Players.LocalPlayer

local banner: Frame
local bannerTitle: TextLabel
local bannerSub: TextLabel

local SecretController = {}
SecretController.Shown = 0 -- scènes jouées (tests dans Studio)

local function near(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= MAX_DISTANCE
end

-- Point invisible dans le monde (support de bulle ou de particules), détruit après `life` secondes
local function anchorAt(position: Vector3, life: number): Part
	local part = Instance.new("Part")
	part.Name = "SecretFx"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = position
	part.Parent = workspace
	task.delay(life, function()
		part:Destroy()
	end)
	return part
end

local function burst(at: BasePart, texture: string, color: Color3, count: number, size: number, speed: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.5
	emitter.Size = NumberSequence.new(size, size * 1.6)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.Parent = at
	emitter:Emit(count)
end

-- Bulle de parole au-dessus d'une pièce, qui disparaît d'elle-même
local function bubble(adornee: BasePart, text: string, height: number, duration: number)
	local billboard = Ui.create("BillboardGui", {
		Name = "SecretBubble",
		Size = UDim2.fromOffset(240, 64),
		StudsOffsetWorldSpace = Vector3.new(0, height, 0),
		AlwaysOnTop = true,
		MaxDistance = 90,
		Adornee = adornee,
		Parent = adornee,
	})
	local frame = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = billboard,
	}, { Ui.corner(UDim.new(0, 16)), Ui.stroke(Color3.fromRGB(40, 35, 55), 3, 0) })
	Ui.label({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 1, -12),
		TextColor3 = Color3.fromRGB(30, 28, 40),
		TextStrokeTransparency = 1,
		Text = text,
		Parent = frame,
	})
	task.delay(duration, function()
		billboard:Destroy()
	end)
end

-- ------------------------------------------------------------------ haltère fantôme

local ghosts: { [BasePart]: CFrame } = {}

local function watchGhost(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	ghosts[part] = part.CFrame
	local light = Instance.new("PointLight")
	light.Color = GHOST_BLUE
	light.Brightness = 1.2
	light.Range = 10
	light.Parent = part
	part.Color = GHOST_BLUE
	part.Material = Enum.Material.Neon
	part.Transparency = 0.55
	part.Destroying:Connect(function()
		ghosts[part] = nil
	end)
end

local function floatGhosts()
	local t = os.clock()
	for part, base in ghosts do
		if part.Parent then
			part.CFrame = base
				* CFrame.new(0, math.sin(t * 1.6) * 0.5, 0)
				* CFrame.Angles(0, t * 0.6, math.sin(t) * 0.15)
		end
	end
end

local function ghostFx(data)
	if typeof(data.position) ~= "Vector3" or not near(data.position) then
		return
	end
	local at = anchorAt(data.position, 3)
	burst(at, SMOKE, GHOST_BLUE, 24, 1.6, 6)
	bubble(at, Texts.Get("Secret.GhostLifter.Line"), 1.5, 2.6)
end

-- ------------------------------------------------------------------ statue qui cligne

local function statueFx(data)
	local pedestal = data.pedestal
	if typeof(pedestal) ~= "Instance" or not pedestal:IsA("BasePart") or not near(pedestal.Position) then
		return
	end
	local statue = pedestal:FindFirstChild("Statue")
	local top = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0)
	local height = 6
	if statue and statue:IsA("Model") then
		local _, size = statue:GetBoundingBox()
		height = size.Y
		-- Biceps gonflés : la statue grossit d'un coup et revient
		local scale = statue:GetScale()
		task.spawn(function()
			for _, s in { 1.12, 1.18, 1.12, 1 } do
				if not statue.Parent then
					return
				end
				statue:ScaleTo(scale * s)
				task.wait(0.12)
			end
		end)
	end
	local at = anchorAt(top + Vector3.new(0, height * 0.9, 0), 2.5)
	burst(at, SPARKLE, GOLD, 30, 0.8, 8)
	-- Le clin d'œil : un œil qui se ferme au-dessus de la tête
	local billboard = Ui.create("BillboardGui", {
		Size = UDim2.fromOffset(80, 80),
		StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0),
		AlwaysOnTop = true,
		Adornee = at,
		Parent = at,
	})
	local wink = Ui.label({ Size = UDim2.fromScale(1, 1), Text = "😉", Parent = billboard })
	wink.TextTransparency = 1
	TweenService:Create(wink, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
end

-- ------------------------------------------------------------------ rat coach

local function ratFx(data)
	local rat = data.rat
	if typeof(rat) ~= "Instance" or not rat:IsA("BasePart") or not near(rat.Position) then
		return
	end
	local duration = if typeof(data.duration) == "number" then data.duration else 5
	bubble(rat, Texts.Get("Secret.SewerGains.Line"), rat.Size.Y / 2 + 1.4, duration)
	local base = rat.CFrame
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if not rat.Parent or t > duration then
			connection:Disconnect()
			return
		end
		-- Pompes : le corps descend et remonte, le nez vers le sol
		local push = (math.sin(t * 7) + 1) / 2
		rat.CFrame = base * CFrame.new(0, -push * 0.25, 0) * CFrame.Angles(math.rad(push * 8), 0, 0)
	end)
end

-- ------------------------------------------------------------------ miroir du passé

local function setTransparency(model: Model, value: number)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Transparency = math.max(item.Transparency, value)
		end
	end
end

local function mirrorFx(data)
	local mirror = data.mirror
	if
		typeof(mirror) ~= "Instance"
		or not mirror:IsA("BasePart")
		or typeof(data.stage) ~= "string"
		or not near(mirror.Position)
		or not Outfit.Available()
	then
		return
	end
	local look = if typeof(data.look) == "table" then data.look else nil
	local model = Outfit.Build(data.stage, {}, { look = look })
	if not model then
		return
	end
	local duration = if typeof(data.duration) == "number" then data.duration else 5
	-- Debout au pied du miroir, juste devant la glace, tourné vers la salle
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { mirror }
	local front = mirror.CFrame.LookVector
	local probe = mirror.Position + front * 0.8
	local hit = workspace:Raycast(probe, Vector3.new(0, -20, 0), params)
	local floor = if hit then hit.Position.Y else mirror.Position.Y - mirror.Size.Y
	local feet = Vector3.new(probe.X, floor, probe.Z)
	local base = CFrame.lookAt(feet, feet + front)
	model:PivotTo(base)
	setTransparency(model, 0.35)
	model.Parent = workspace
	local _, size = model:GetBoundingBox()
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local light = Instance.new("PointLight")
	light.Color = GHOST_BLUE
	light.Brightness = 1
	light.Range = 8
	if root then
		light.Parent = root
		bubble(root, Texts.Get("Secret.NeverForget.Line"), size.Y * 0.5 + 1.2, duration)
		local wave = Ui.create("BillboardGui", {
			Size = UDim2.fromOffset(60, 60),
			StudsOffsetWorldSpace = Vector3.new(size.X * 0.5 + 0.6, size.Y * 0.2, 0),
			AlwaysOnTop = true,
			Adornee = root,
			Parent = root,
		})
		Ui.label({ Size = UDim2.fromScale(1, 1), Text = "👋", Parent = wave })
	end
	-- Coucou : le reflet se balance de gauche à droite
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if not model.Parent or t > duration then
			connection:Disconnect()
			model:Destroy()
			return
		end
		model:PivotTo(base * CFrame.Angles(0, 0, math.sin(t * 6) * math.rad(6)))
	end)
end

-- ------------------------------------------------------------------ annonce

local function announce(secretId: string)
	bannerTitle.Text = Texts.Get("Secret.Found")
	bannerSub.Text = Texts.Get("Secret.FoundTitle", { title = Texts.Get(`Nick.Title.{secretId}`) })
	banner.Visible = true
	banner.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(
		banner,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0.86, 0, 0, 110) }
	):Play()
	task.delay(4, function()
		TweenService:Create(banner, TweenInfo.new(0.3), { Size = UDim2.fromOffset(0, 0) }):Play()
		task.wait(0.3)
		banner.Visible = false
	end)
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "Secrets", ResetOnSpawn = false, DisplayOrder = 25 })
	banner = Ui.create("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Color3.fromRGB(28, 22, 44),
		BackgroundTransparency = 0.1,
		ClipsDescendants = true,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(UDim.new(0, 18)),
		Ui.stroke(GOLD, 3, 0),
		Ui.create("UISizeConstraint", { MaxSize = Vector2.new(520, 110) }),
	})
	bannerTitle = Ui.label({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0.55, -8),
		TextColor3 = GOLD,
		Parent = banner,
	})
	bannerSub = Ui.label({
		Position = UDim2.new(0, 12, 0.55, 0),
		Size = UDim2.new(1, -24, 0.45, -10),
		Parent = banner,
	})
	gui.Parent = player:WaitForChild("PlayerGui")
end

function SecretController.Start()
	buildGui()
	for _, part in CollectionService:GetTagged("GhostDumbbell") do
		watchGhost(part)
	end
	CollectionService:GetInstanceAddedSignal("GhostDumbbell"):Connect(watchGhost)
	RunService.RenderStepped:Connect(floatGhosts)
	Remotes.SecretFound.OnClientEvent:Connect(function(secretId)
		if typeof(secretId) == "string" then
			announce(secretId)
		end
	end)
	Remotes.SecretFx.OnClientEvent:Connect(function(secretId, data)
		if typeof(secretId) ~= "string" or typeof(data) ~= "table" then
			return
		end
		SecretController.Shown += 1
		if secretId == "GhostLifter" then
			ghostFx(data)
		elseif secretId == "StatueBeliever" then
			statueFx(data)
		elseif secretId == "SewerGains" then
			ratFx(data)
		elseif secretId == "NeverForget" then
			mirrorFx(data)
		end
	end)
end

return SecretController
