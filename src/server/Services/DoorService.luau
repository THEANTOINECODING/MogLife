-- Portes automatiques (emplacements de décor avec l'attribut AutoDoor : entrée des maisons, garage → maison,
-- magasins) : la porte pivote sur sa charnière quand un joueur s'approche, à l'opposé de lui (comme une porte
-- qu'on pousse), et se referme quand plus personne n'est à côté. Elle n'a pas de collision : on ne reste
-- jamais coincé derrière.
-- Attribut DoorHinge : côté de la charnière dans le repère du modèle (-1 = côté -X, 1 = côté +X).
-- Attribut DoorSwing (optionnel) : 1 = s'ouvre toujours vers le +Z du repère (-1 : vers le -Z), pour un passage
-- trop étroit d'un côté.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local SLOT_TAG = "PropSlot"
local DOORS = Balance.Doors

type Door = {
	part: BasePart,
	closed: CFrame,
	openA: CFrame,
	openB: CFrame,
	value: CFrameValue,
	isOpen: boolean,
	fixed: CFrame?,
}

local PropService

local doors: { Door } = {}

local DoorService = {}

-- Position du joueur le plus proche à portée de la porte, ou nil
local function nearestPlayer(position: Vector3): Vector3?
	local best, bestDistance = nil, DOORS.OpenDistance
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local distance = (root.Position - position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = root.Position, distance
			end
		end
	end
	return best
end

local function register(slot: Instance)
	if slot:GetAttribute("AutoDoor") ~= true then
		return
	end
	local part = PropService.GetVisual(slot)
	if not part then
		return
	end
	local side = if slot:GetAttribute("DoorHinge") == 1 then 1 else -1
	local hingeX = side * part.Size.X / 2
	local closed = part.CFrame
	local pivot = closed * CFrame.new(hingeX, 0, 0)
	local angle = math.rad(DOORS.OpenAngle)
	local value = Instance.new("CFrameValue")
	value.Value = closed
	value.Changed:Connect(function(cframe)
		part.CFrame = cframe
	end)
	local openA = pivot * CFrame.Angles(0, angle, 0) * CFrame.new(-hingeX, 0, 0)
	local openB = pivot * CFrame.Angles(0, -angle, 0) * CFrame.new(-hingeX, 0, 0)
	local swing = slot:GetAttribute("DoorSwing")
	local fixed = nil
	if typeof(swing) == "number" and swing ~= 0 then
		local toward = closed.Position + closed.LookVector * -swing -- +Z du repère = -LookVector
		fixed = if (openA.Position - toward).Magnitude <= (openB.Position - toward).Magnitude then openA else openB
	end
	table.insert(doors, {
		part = part,
		closed = closed,
		openA = openA,
		openB = openB,
		value = value,
		isOpen = false,
		fixed = fixed,
	})
end

function DoorService.Init(services)
	PropService = services.PropService
end

function DoorService.Start()
	for _, slot in CollectionService:GetTagged(SLOT_TAG) do
		register(slot)
	end
	local info = TweenInfo.new(DOORS.SwingTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.spawn(function()
		while true do
			for _, door in doors do
				local player = nearestPlayer(door.closed.Position)
				local wantOpen = player ~= nil
				if wantOpen ~= door.isOpen then
					door.isOpen = wantOpen
					local target = door.closed
					if player and door.fixed then
						target = door.fixed
					elseif player then
						-- Le battant s'ouvre du côté opposé au joueur
						local awayA = (door.openA.Position - player).Magnitude
						local awayB = (door.openB.Position - player).Magnitude
						target = if awayA >= awayB then door.openA else door.openB
					end
					TweenService:Create(door.value, info, { Value = target }):Play()
				end
			end
			task.wait(DOORS.CheckInterval)
		end
	end)
end

return DoorService
