-- Aperçus 3D des magasins (D121) : une vignette ViewportFrame qui montre un objet (meuble, aliment) en train de
-- tourner lentement sur lui-même, cadré automatiquement d'après sa boîte englobante.
-- Utilisé par FurnitureController (meubles) et BoostController (aliments). Purement visuel.
--   local view = Preview3D.new(parent, { Size = ..., Position = ... })
--   Preview3D.Show(view, modelOrPart)  -- l'objet est copié ; l'original n'est pas touché
-- Une vignette dont l'interface est détruite sort toute seule de la boucle d'animation.

local RunService = game:GetService("RunService")

local Ui = require(script.Parent.Ui)

local SPIN_SPEED = math.rad(28) -- degrés par seconde
local PITCH = math.rad(-18) -- regard légèrement plongeant
local YAW_START = math.rad(-30) -- trois-quarts face au départ
local FOV = 30

type View = { frame: ViewportFrame, camera: Camera, center: Vector3, distance: number, spin: boolean }

local views: { View } = {}
local loop: RBXScriptConnection? = nil

local Preview3D = {}

local function place(view: View, angle: number)
	local look = CFrame.new(view.center) * CFrame.Angles(0, YAW_START + angle, 0) * CFrame.Angles(PITCH, 0, 0)
	view.camera.CFrame = look * CFrame.new(0, 0, view.distance)
end

local function step()
	local angle = os.clock() * SPIN_SPEED
	for i = #views, 1, -1 do
		local view = views[i]
		if not view.frame.Parent or not view.frame:IsDescendantOf(game) then
			table.remove(views, i)
		elseif view.spin and view.frame.Visible then
			place(view, angle)
		end
	end
	if #views == 0 and loop then
		loop:Disconnect()
		loop = nil
	end
end

-- Vignette vide ; `props` est passé à la ViewportFrame (Size, Position, AnchorPoint, LayoutOrder…)
function Preview3D.new(parent: Instance, props: { [string]: any }): View
	local frame = Ui.create("ViewportFrame", {
		BackgroundColor3 = Color3.fromRGB(28, 24, 40),
		BackgroundTransparency = 0.1,
		Ambient = Color3.fromRGB(170, 165, 180),
		LightColor = Color3.fromRGB(255, 248, 235),
		LightDirection = Vector3.new(-0.6, -1, -0.4),
	}, { Ui.corner(UDim.new(0, 10)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.6) }) :: ViewportFrame
	for key, value in props do
		(frame :: any)[key] = value
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = frame
	frame.CurrentCamera = camera
	frame.Parent = parent
	return { frame = frame, camera = camera, center = Vector3.zero, distance = 10, spin = true }
end

-- Montre une copie de `source` (Model ou BasePart) dans la vignette, à la place de l'objet précédent
function Preview3D.Show(view: View, source: Instance)
	for _, child in view.frame:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") then
			child:Destroy()
		end
	end
	local copy = source:Clone()
	local holder: Model
	if copy:IsA("Model") then
		holder = copy
	else
		holder = Instance.new("Model")
		copy.Parent = holder
	end
	for _, item in holder:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
		elseif item:IsA("Script") or item:IsA("LocalScript") or item:IsA("Sound") then
			item:Destroy()
		end
	end
	if copy:IsA("BasePart") then
		copy.CFrame = CFrame.new()
	end
	holder.Parent = view.frame
	local box, size = holder:GetBoundingBox()
	view.center = box.Position
	-- Distance pour que la plus grande dimension remplisse ~80 % de la vignette
	local radius = size.Magnitude / 2
	view.distance = radius / math.tan(math.rad(FOV / 2)) * 1.05
	place(view, os.clock() * SPIN_SPEED)
	if not table.find(views, view) then
		table.insert(views, view)
	end
	if not loop then
		loop = RunService.RenderStepped:Connect(step)
	end
end

-- Nombre de vignettes animées (tests dans Studio)
function Preview3D.Count(): number
	return #views
end

return Preview3D
