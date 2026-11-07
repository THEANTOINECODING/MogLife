-- Repas de boost (D114), vu par tous les joueurs proches : le serveur annonce qu'un joueur mange (Remotes.BoostEaten)
-- et chaque client joue la même scène courte (Balance.BoostShop.EatDuration, ~1,4 s) :
-- 1. l'aliment apparaît dans la main droite, qui le porte à la bouche ;
-- 2. deux bouchées (ou une grosse gorgée, bouteille renversée, tête en arrière) avec miettes et son ;
-- 3. l'aliment disparaît d'un coup, étincelles de la couleur du boost autour du joueur et petit scintillement sonore.
-- Seuls le bras droit et le cou sont animés : le joueur peut marcher en mangeant. Un personnage déjà animé ailleurs
-- (série, combat, émote) n'a que les effets et les sons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rig = require(script.Parent.Parent.Activities.Rig)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local MAX_DISTANCE = 120 -- au-delà, rien n'est joué (personne ne le verrait)
local ARM_JOINTS = { "RightShoulder", "RightElbow", "RightWrist" }

local ActivityController
local SoundController

local SnackController = {}
SnackController.Played = 0 -- repas joués (tests dans Studio)

type Meal = {
	who: Player,
	character: Model,
	head: BasePart,
	rig: Rig.Rig?,
	food: Model,
	foodScale: number,
	boostId: string,
	drink: boolean,
	start: number,
	bites: { number },
	nextBite: number,
	popped: boolean,
}

local meals: { [Player]: Meal } = {}

-- ------------------------------------------------------------------ aliments (petits modèles, côté client)

local function part(model: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = model
	return p
end

-- Cylindre debout (l'axe des cylindres Roblox est X : on le tourne)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- Chaque modèle est construit autour de son point de prise (0, 0, 0) : la main
local builders: { [string]: (Model) -> () } = {
	-- Shaker rose : gobelet, couvercle blanc, bec
	ProteinShake = function(m)
		part(m, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.9, 0.55, 0.55),
			CFrame = CFrame.new(0, 0.2, 0) * UPRIGHT,
			Color = Color3.fromRGB(240, 170, 215),
		})
		part(m, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.16, 0.6, 0.6),
			CFrame = CFrame.new(0, 0.7, 0) * UPRIGHT,
			Color = Color3.fromRGB(250, 250, 250),
		})
		part(m, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.18, 0.16, 0.16),
			CFrame = CFrame.new(0, 0.85, -0.12) * UPRIGHT,
			Color = Color3.fromRGB(60, 60, 70),
		})
	end,
	-- Jus de kale : bouteille verte fluo, paille rayée, feuille
	TurboJuice = function(m)
		part(m, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.95, 0.48, 0.48),
			CFrame = CFrame.new(0, 0.22, 0) * UPRIGHT,
			Color = Color3.fromRGB(110, 230, 80),
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
		part(m, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 0.5, 0.5),
			CFrame = CFrame.new(0, 0.74, 0) * UPRIGHT,
			Color = Color3.fromRGB(240, 240, 240),
		})
		part(m, {
			Size = Vector3.new(0.07, 0.6, 0.07),
			CFrame = CFrame.new(0.08, 1.0, 0) * CFrame.Angles(0, 0, math.rad(-12)),
			Color = Color3.fromRGB(255, 80, 90),
		})
		part(m, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.35, 0.08, 0.22),
			CFrame = CFrame.new(-0.2, 0.82, 0.05) * CFrame.Angles(0, 0, math.rad(30)),
			Color = Color3.fromRGB(40, 130, 50),
		})
	end,
	-- Steak démesuré : une tranche épaisse et son os
	GiantSteak = function(m)
		part(m, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.5, 0.45, 1.05),
			CFrame = CFrame.new(0, 0.35, -0.2) * CFrame.Angles(math.rad(70), 0, 0),
			Color = Color3.fromRGB(150, 70, 45),
		})
		part(m, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.2, 0.47, 0.75),
			CFrame = CFrame.new(0, 0.38, -0.2) * CFrame.Angles(math.rad(70), 0, 0),
			Color = Color3.fromRGB(205, 95, 70),
		})
		part(m, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 0.14, 0.14),
			CFrame = CFrame.new(0, -0.15, 0) * UPRIGHT,
			Color = Color3.fromRGB(245, 240, 225),
		})
		for _, x in { -0.07, 0.07 } do
			part(m, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.17, 0.17, 0.17),
				CFrame = CFrame.new(x, -0.46, 0),
				Color = Color3.fromRGB(245, 240, 225),
			})
		end
	end,
	-- Petit-déjeuner d'œufs dorés : une assiette et deux œufs au plat aux jaunes d'or
	GoldenEggs = function(m)
		part(m, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.08, 1.1, 1.1),
			CFrame = CFrame.new(0, 0.05, -0.35) * UPRIGHT,
			Color = Color3.fromRGB(245, 245, 250),
		})
		for _, offset in { Vector3.new(-0.2, 0.1, -0.25), Vector3.new(0.22, 0.1, -0.45) } do
			part(m, {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.05, 0.45, 0.42),
				CFrame = CFrame.new(offset) * UPRIGHT,
				Color = Color3.fromRGB(255, 252, 240),
			})
			part(m, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.2, 0.13, 0.2),
				CFrame = CFrame.new(offset + Vector3.new(0, 0.06, 0)),
				Color = Color3.fromRGB(255, 200, 40),
				Material = Enum.Material.Neon,
			})
		end
	end,
}

local DRINKS = { ProteinShake = true, TurboJuice = true }

local function buildFood(boostId: string): Model
	local model = Instance.new("Model")
	model.Name = "Snack_" .. boostId
	local grip = part(model, { Name = "Grip", Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1 })
	model.PrimaryPart = grip
	local builder = builders[boostId]
	if builder then
		builder(model)
	end
	return model
end

-- Modèle de l'aliment (aperçu 3D de la boutique et du sac, D121)
function SnackController.BuildFood(boostId: string): Model
	return buildFood(boostId)
end

-- ------------------------------------------------------------------ effets

local function burst(at: BasePart, color: Color3, count: number, speed: number, size: number, lifetime: number)
	local attachment = Instance.new("Attachment")
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = attachment
	attachment.Parent = at
	emitter:Emit(count)
	task.delay(lifetime + 0.2, function()
		attachment:Destroy()
	end)
end

-- Miettes (ou gouttes) qui tombent de la bouche
local function crumbs(head: BasePart, color: Color3, scale: number)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, -head.Size.Y * 0.25, -head.Size.Z * 0.5)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(0.12 * scale, 0.05 * scale)
	emitter.Lifetime = NumberRange.new(0.35, 0.55)
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Rate = 0
	emitter.Parent = attachment
	attachment.Parent = head
	emitter:Emit(8)
	task.delay(0.8, function()
		attachment:Destroy()
	end)
end

-- ------------------------------------------------------------------ scène

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function finish(who: Player)
	local meal = meals[who]
	if not meal then
		return
	end
	meals[who] = nil
	meal.food:Destroy()
	if meal.rig then
		-- Rend la main à l'animation de Roblox (elle réécrit ces articulations à l'image suivante)
		for _, joint in ARM_JOINTS do
			meal.rig.joints[joint].instance.Transform = CFrame.identity
		end
		meal.rig.joints.Neck.instance.Transform = CFrame.identity
		ActivityController.SetBusy(who, false)
	end
end

local function play(who: Player, boostId: string)
	local boost = Boosts[boostId]
	local character = who.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local hand = character and character:FindFirstChild("RightHand") :: BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not boost or not character or not head or not hand or not root then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - root.Position).Magnitude > MAX_DISTANCE then
		return
	end
	finish(who)
	SnackController.Played += 1
	-- Animer le bras seulement si personne d'autre n'anime ce personnage
	local rig = if ActivityController.IsBusy(who) then nil else Rig.new(character)
	if rig then
		ActivityController.SetBusy(who, true)
	end
	-- Taille de l'aliment selon la tête (les corps de stade ont des têtes de tailles très différentes)
	local scale = math.clamp(head.Size.Y / 1.2, 0.6, 3)
	local food = buildFood(boostId)
	food:ScaleTo(scale)
	food:PivotTo(hand.CFrame)
	food.Parent = workspace
	local drink = DRINKS[boostId] == true
	local duration = Balance.BoostShop.EatDuration
	meals[who] = {
		who = who,
		character = character,
		head = head,
		rig = rig,
		food = food,
		foodScale = scale,
		boostId = boostId,
		drink = drink,
		start = os.clock(),
		-- Moments des bouchées (part de la durée) : deux croquées, ou une longue gorgée
		bites = if drink then { 0.3 } else { 0.32, 0.56 },
		nextBite = 1,
		popped = false,
	}
	-- L'aliment apparaît avec un petit rebond
	local size = food:GetScale()
	food:ScaleTo(size * 0.3)
	local grow = Instance.new("NumberValue")
	grow.Value = 0.3
	grow.Changed:Connect(function(value)
		if food.Parent then
			food:ScaleTo(size * value)
		end
	end)
	local tween = TweenService:Create(grow, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Value = 1 })
	tween.Completed:Once(function()
		grow:Destroy()
	end)
	tween:Play()
	task.delay(duration + 0.1, function()
		if meals[who] and meals[who].food == food then
			finish(who)
		end
	end)
end

local function step()
	local now = os.clock()
	local duration = Balance.BoostShop.EatDuration
	for who, meal in meals do
		local character = meal.character
		local head = meal.head
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hand = character:FindFirstChild("RightHand") :: BasePart?
		if not character.Parent or not head.Parent or not root or not hand then
			finish(who)
			continue
		end
		local t = (now - meal.start) / duration
		local boost = Boosts[meal.boostId]
		-- Bouchées : son et miettes
		local biteAt = meal.bites[meal.nextBite]
		if biteAt and t >= biteAt then
			meal.nextBite += 1
			SoundController.PlayAt(if meal.drink then "SnackGulp" else "SnackBite", head, 0.95 + math.random() * 0.1)
			if not meal.drink then
				crumbs(head, boost.color, meal.foodScale)
				-- L'aliment rapetisse à chaque bouchée
				meal.food:ScaleTo(meal.food:GetScale() * 0.8)
			end
		end
		-- Fin : l'aliment disparaît, le boost s'allume
		if not meal.popped and t >= 0.72 then
			meal.popped = true
			meal.food.Parent = nil
			SoundController.PlayAt("SnackPower", head)
			burst(root, boost.color, 26, 14 * meal.foodScale, 0.5 * meal.foodScale, 0.7)
			burst(head, Color3.new(1, 1, 1), 10, 6 * meal.foodScale, 0.35 * meal.foodScale, 0.45)
		end

		-- Montée vers la bouche (0 -> 0,2), maintien, descente (0,78 -> 1)
		local lift = math.min(smooth(t / 0.2), smooth((1 - t) / 0.22))
		-- Petit va-et-vient à chaque bouchée
		local chew = 0
		for _, at in meal.bites do
			local d = (t - at) / 0.12
			if d > -1 and d < 1 then
				chew = math.max(chew, 1 - math.abs(d))
			end
		end
		local up = root.CFrame.UpVector
		local forward = root.CFrame.LookVector
		local right = root.CFrame.RightVector
		local mouth = (head.CFrame * CFrame.new(0, -head.Size.Y * 0.2, -head.Size.Z * 0.5)).Position
		local rig = meal.rig
		if rig then
			rig:Clear()
			local rest = rig:PartCFrame("RightHand").Position
			local nearMouth = mouth + forward * (0.55 - 0.25 * chew) * meal.foodScale - up * 0.35 * meal.foodScale
			rig:Grip("RightArm", rest:Lerp(nearMouth, lift), (right * 0.7 - up).Unit)
			local tilt = if meal.drink then 18 * lift else 6 * chew
			rig:Set("Neck", CFrame.Angles(math.rad(tilt), 0, 0))
			for _, joint in ARM_JOINTS do
				rig.joints[joint].instance.Transform = rig.pose[joint] or CFrame.identity
			end
			rig.joints.Neck.instance.Transform = rig.pose.Neck
		end
		-- L'aliment suit la paume ; une boisson se renverse vers la bouche
		if meal.food.Parent then
			local palm = if rig then rig:PartCFrame("RightHand").Position else hand.Position
			local pour = if meal.drink then math.rad(-75) * lift else math.rad(-20) * lift
			local facing = CFrame.lookAt(palm, palm + forward) * CFrame.Angles(pour, 0, 0)
			meal.food:PivotTo(facing)
		end
	end
end

function SnackController.Init(controllers)
	ActivityController = controllers.ActivityController
	SoundController = controllers.SoundController
end

function SnackController.Start()
	Remotes.BoostEaten.OnClientEvent:Connect(function(who, boostId)
		if typeof(who) == "Instance" and who:IsA("Player") and typeof(boostId) == "string" then
			play(who, boostId)
		end
	end)
	Players.PlayerRemoving:Connect(finish)
	-- Après l'Animator (comme les activités) : la pose écrase l'animation de Roblox pour ces articulations
	RunService.PreSimulation:Connect(step)
end

return SnackController
