-- Mur des Colosses (D107) côté client : les statues qui ferment le monde s'animent.
-- - Yeux (tag "ColossusGlow", Kind = "Eye", attribut Gaze = direction du regard) : un rayon doré sort de chaque œil,
--   s'élargit et s'efface, son intensité ondule doucement.
-- - Sceptres-haltères (Kind = "Scepter") : lumière dorée qui pulse et étincelles.
-- Les flammes des torches et des braseros du mur sont celles du Colisée (tag "ColosseumFire", ColosseumController).
-- Tout est coupé loin du joueur (téléphone). Rien ne part vers le serveur.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local TAG = "ColossusGlow"
local SETTINGS = Balance.StatueWall
local GOLD = Color3.fromRGB(255, 214, 110)

local player = Players.LocalPlayer

type Glow = { kind: string, effects: { Instance }, beam: Beam?, light: PointLight?, phase: number, on: boolean }
local glows: { [BasePart]: Glow } = {}

local StatueWallController = {}

local function addEye(anchor: BasePart, glow: Glow)
	local gaze = anchor:GetAttribute("Gaze")
	if typeof(gaze) ~= "Vector3" or gaze.Magnitude < 0.01 then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.Position = anchor.CFrame:VectorToObjectSpace(gaze.Unit * SETTINGS.EyeBeamLength)
	a1.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(GOLD, Color3.fromRGB(255, 240, 190))
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = SETTINGS.EyeBeamWidth[1]
	beam.Width1 = SETTINGS.EyeBeamWidth[2]
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.4, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Segments = 4
	beam.Parent = anchor
	glow.beam = beam
	table.insert(glow.effects, beam)
end

local function addScepter(anchor: BasePart, glow: Glow)
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = SETTINGS.ScepterLight.Range
	light.Shadows = false
	light.Parent = anchor
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(GOLD)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.6, 0)
	sparks.Lifetime = NumberRange.new(1, 1.8)
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 8
	sparks.Parent = anchor
	glow.light = light
	table.insert(glow.effects, light)
	table.insert(glow.effects, sparks)
end

local function add(anchor: Instance)
	if not anchor:IsA("BasePart") or glows[anchor] then
		return
	end
	local kind = anchor:GetAttribute("Kind")
	local p = anchor.Position
	local glow: Glow = { kind = tostring(kind), effects = {}, phase = (p.X + p.Z) * 0.05, on = true }
	if kind == "Eye" then
		addEye(anchor, glow)
	elseif kind == "Scepter" then
		addScepter(anchor, glow)
	end
	glows[anchor] = glow
end

local function myPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

function StatueWallController.Start()
	for _, anchor in CollectionService:GetTagged(TAG) do
		add(anchor)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(anchor)
		glows[anchor :: BasePart] = nil
	end)

	-- Effets allumés seulement à portée
	task.spawn(function()
		while true do
			local here = myPosition()
			for anchor, glow in glows do
				local on = here ~= nil and (anchor.Position - here).Magnitude < SETTINGS.Range
				if on ~= glow.on then
					glow.on = on
					for _, effect in glow.effects do
						(effect :: any).Enabled = on
					end
				end
			end
			task.wait(1)
		end
	end)

	local brightness = SETTINGS.ScepterLight.Brightness
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, glow in glows do
			if not glow.on then
				continue
			end
			if glow.beam then
				local wave = 0.5 + 0.5 * math.sin(now * 2 * math.pi * SETTINGS.EyeFlicker + glow.phase)
				glow.beam.Brightness = 1 + wave * 1.5
			elseif glow.light then
				local wave = 0.5 + 0.5 * math.sin(now * 2 * math.pi * SETTINGS.ScepterPulse + glow.phase)
				glow.light.Brightness = brightness[1] + (brightness[2] - brightness[1]) * wave
			end
		end
	end)
end

return StatueWallController
