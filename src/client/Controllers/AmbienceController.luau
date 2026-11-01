-- Ambiance : les lampadaires (tag "StreetLight") s'allument la nuit et s'éteignent le jour.
-- L'heure vient du serveur (DayNightService) via Lighting.ClockTime ; ce changement est local à chaque joueur.
-- Jets d'eau (D97) : chaque point de la carte tagué "FountainJet" reçoit les particules de son type
-- (attribut Jet, réglages dans Config/Ambience.luau), dirigées selon l'attribut JetDir.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambience = require(ReplicatedStorage.Shared.Config.Ambience)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local STREET_LIGHT_TAG = "StreetLight"
local JET_TAG = "FountainJet"
local SPINNER_TAG = "Spinner"
local SPIN_DISTANCE = 120 -- au-delà, les ventilateurs ne tournent pas (téléphone)
local TEXTURES = {
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}
local UP = Vector3.new(0, 1, 0)
local CYCLE = Balance.DayNight
local OFF_COLOR = Color3.fromRGB(150, 150, 140)

local isOn: boolean? = nil
local onColors: { [BasePart]: Color3 } = {}

local AmbienceController = {}

local function apply(part: Instance, on: boolean)
	if not part:IsA("BasePart") then
		return
	end
	onColors[part] = onColors[part] or part.Color
	part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Color = if on then onColors[part] else OFF_COLOR
	for _, child in part:GetChildren() do
		if child:IsA("Light") then
			child.Enabled = on
		end
	end
end

local function update()
	local clock = Lighting.ClockTime
	local on = clock >= CYCLE.LightsOn or clock < CYCLE.LightsOff
	if on == isOn then
		return
	end
	isOn = on
	for _, part in CollectionService:GetTagged(STREET_LIGHT_TAG) do
		apply(part, on)
	end
end

-- Rotation qui amène le haut (Y) sur `direction`
local function aimUp(direction: Vector3): CFrame
	local dir = if direction.Magnitude > 1e-3 then direction.Unit else UP
	local axis = UP:Cross(dir)
	if axis.Magnitude < 1e-4 then
		return if dir.Y >= 0 then CFrame.identity else CFrame.Angles(math.pi, 0, 0)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(UP:Dot(dir), -1, 1)))
end

local function addJet(point: Instance)
	local settings = Ambience.Jets[point:GetAttribute("Jet") :: string]
	if not settings or not point:IsA("BasePart") or point:FindFirstChild("Jet") then
		return
	end
	local direction = point:GetAttribute("JetDir")
	local attachment = Instance.new("Attachment")
	attachment.Name = "Jet"
	attachment.Parent = point
	attachment.WorldCFrame = CFrame.new(point.Position)
		* aimUp(if typeof(direction) == "Vector3" then direction else UP)
	local emitter = Instance.new("ParticleEmitter")
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Texture = TEXTURES[settings.texture]
	emitter.Rate = settings.rate
	emitter.Speed = settings.speed
	emitter.Lifetime = settings.lifetime
	emitter.SpreadAngle = Vector2.new(settings.spread, settings.spread)
	emitter.Acceleration = Vector3.new(0, -settings.gravity, 0)
	emitter.Size = NumberSequence.new(settings.size[1], settings.size[2])
	emitter.Transparency = NumberSequence.new(settings.transparency[1], settings.transparency[2])
	emitter.Color = ColorSequence.new(settings.color)
	emitter.Drag = settings.drag or 0
	emitter.LightEmission = settings.glow or 0.3
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Parent = attachment
end

-- Pièces qui tournent sur place (pales des ventilateurs de la salle, D101) : autour de leur attribut SpinCenter,
-- à SpinSpeed radians par seconde. Rotation locale, purement décorative.
local spinners: { [BasePart]: { center: Vector3, offset: CFrame, speed: number } } = {}

local function addSpinner(part: Instance)
	local center, speed = part:GetAttribute("SpinCenter"), part:GetAttribute("SpinSpeed")
	if not part:IsA("BasePart") or typeof(center) ~= "Vector3" or typeof(speed) ~= "number" then
		return
	end
	spinners[part] = { center = center, offset = CFrame.new(center):ToObjectSpace(part.CFrame), speed = speed }
end

local function spin()
	local camera = workspace.CurrentCamera
	if not camera or not next(spinners) then
		return
	end
	local now = os.clock()
	local parts, cframes = {}, {}
	for part, entry in spinners do
		if not part.Parent then
			spinners[part] = nil
		elseif (camera.CFrame.Position - entry.center).Magnitude < SPIN_DISTANCE then
			table.insert(parts, part)
			table.insert(cframes, CFrame.new(entry.center) * CFrame.Angles(0, now * entry.speed, 0) * entry.offset)
		end
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function AmbienceController.Start()
	CollectionService:GetInstanceAddedSignal(SPINNER_TAG):Connect(addSpinner)
	for _, part in CollectionService:GetTagged(SPINNER_TAG) do
		addSpinner(part)
	end
	RunService.Heartbeat:Connect(spin)
	CollectionService:GetInstanceAddedSignal(JET_TAG):Connect(addJet)
	for _, point in CollectionService:GetTagged(JET_TAG) do
		addJet(point)
	end
	CollectionService:GetInstanceAddedSignal(STREET_LIGHT_TAG):Connect(function(part)
		apply(part, isOn == true)
	end)
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(update)
	update()
end

return AmbienceController
