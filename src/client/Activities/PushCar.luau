-- Aide « Pousser la voiture du voisin » : le joueur se met derrière la voiture en panne et la pousse vraiment ;
-- elle avance un peu à chaque répétition (une ratée patine sur place) et revient à sa place à la fin. D37.

local PushCar = {}
PushCar.__index = PushCar

local SEARCH_RADIUS = 30 -- la voiture est garée sur la route, à quelques mètres du voisin
local STEP = 0.6 -- distance parcourue par répétition réussie

function PushCar.Stand(top: CFrame): CFrame
	return top * CFrame.new(0, 0, -3.6) * CFrame.Angles(0, math.pi, 0)
end

-- La voiture : le modèle de voiture (Car…) le plus proche du voisin
local function findCar(anchor: BasePart): BasePart?
	local folder = workspace:FindFirstChild("MapProps")
	local best, bestDistance = nil, SEARCH_RADIUS
	for _, part in if folder then folder:GetChildren() else {} do
		if part:IsA("BasePart") and string.sub(part.Name, 1, 3) == "Car" then
			local distance = (part.Position - anchor.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = part, distance
			end
		end
	end
	return best
end

function PushCar.new(ctx)
	local self = setmetatable({ ctx = ctx }, PushCar)
	local car = findCar(ctx.anchor)
	if car then
		self.car = ctx.borrow(car.Name, false, SEARCH_RADIUS)
	end
	if self.car then
		self.carStart = self.car.CFrame
		-- Le long de la voiture = son plus grand côté horizontal ; on pousse depuis l'arrière, côté joueur
		local size = self.car.Size
		local axis = if size.X > size.Z then self.carStart.RightVector else self.carStart.LookVector
		local toPlayer = ctx.rig.root.Position - self.carStart.Position
		if axis:Dot(toPlayer) > 0 then
			axis = -axis
		end
		self.forward = Vector3.new(axis.X, 0, axis.Z).Unit
		self.halfLength = math.max(size.X, size.Z) / 2
		self.height = size.Y
		-- Son propre personnage va se placer derrière la voiture (la caméra suit la scène)
		if ctx.isLocal then
			local root = ctx.rig.root
			local rear = self.carStart.Position - self.forward * (self.halfLength + 2)
			root.CFrame = CFrame.lookAt(
				Vector3.new(rear.X, root.Position.Y, rear.Z),
				Vector3.new(self.carStart.Position.X, root.Position.Y, self.carStart.Position.Z)
			)
		end
	end
	local rig = ctx.rig
	local saved = table.clone(rig.pose)
	rig:Clear()
	self.lower = rig.root.CFrame:ToObjectSpace(rig:PartCFrame("LowerTorso"))
	rig.pose = saved
	return self
end

function PushCar:Pose(p: number, shake: number, _u: number, time: number, count: number)
	local rig, m = self.ctx.rig, self.ctx.measures
	local root = rig.root.CFrame
	if not self.car then
		return
	end
	-- La voiture avance d'un pas à chaque poussée réussie (une ratée ne fait que trembler)
	local progress = (math.max(count - 1, 0) + p * (1 - shake * 0.8)) * STEP
	local wobble = shake * math.sin(time * 35) * 0.04
	self.car.CFrame = self.carStart + self.forward * (progress + wobble)

	-- Le joueur colle à l'arrière de la voiture, penché, bras tendus, et marche avec elle
	local rear = self.car.Position - self.forward * (self.halfLength + m.armLength * 0.75)
	local stand = CFrame.lookAt(
		Vector3.new(rear.X, root.Position.Y, rear.Z),
		Vector3.new(self.car.Position.X, root.Position.Y, self.car.Position.Z)
	)
	local lean = 0.55 + 0.15 * p
	local stride = math.sin(time * 6) * 0.35 * (0.3 + p)
	rig:Place("LowerTorso", stand * self.lower * CFrame.Angles(-lean, 0, 0))
	rig:Set("LeftHip", CFrame.Angles(0.3 + stride, 0, 0))
	rig:Set("RightHip", CFrame.Angles(0.3 - stride, 0, 0))
	rig:Set("LeftKnee", CFrame.Angles(-0.4 - math.max(stride, 0), 0, 0))
	rig:Set("RightKnee", CFrame.Angles(-0.4 - math.max(-stride, 0), 0, 0))
	local contact = self.car.Position - self.forward * (self.halfLength + 0.1) + Vector3.new(0, self.height * 0.15, 0)
	for _, sx in { -1, 1 } do
		local grip = contact + stand.RightVector * sx * m.handSpread
		rig:Reach(if sx < 0 then "LeftArm" else "RightArm", grip, -Vector3.yAxis + stand.RightVector * sx * 0.5)
	end
end

function PushCar:Destroy() end

return PushCar
