-- Portes automatiques (emplacements de décor avec l'attribut AutoDoor, ex. entre le garage et la maison) :
-- la porte pivote quand un joueur s'approche, et se referme quand plus personne n'est à côté.
-- Attribut DoorHingeX : position de la charnière le long de la largeur de la porte (repère de la porte).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local SLOT_TAG = "PropSlot"
local DOORS = Balance.Doors

type Door = { part: BasePart, closed: CFrame, opened: CFrame, value: CFrameValue, isOpen: boolean }

local PropService

local doors: { Door } = {}

local DoorService = {}

local function anyoneNear(position: Vector3): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - position).Magnitude <= DOORS.OpenDistance then
			return true
		end
	end
	return false
end

local function register(slot: Instance)
	if slot:GetAttribute("AutoDoor") ~= true then
		return
	end
	local part = PropService.GetVisual(slot)
	if not part then
		return
	end
	local hinge = slot:GetAttribute("DoorHingeX")
	local hingeX = if typeof(hinge) == "number" then hinge else -part.Size.X / 2
	local closed = part.CFrame
	local pivot = closed * CFrame.new(hingeX, 0, 0)
	local opened = pivot * CFrame.Angles(0, math.rad(DOORS.OpenAngle), 0) * CFrame.new(-hingeX, 0, 0)
	local value = Instance.new("CFrameValue")
	value.Value = closed
	value.Changed:Connect(function(cframe)
		part.CFrame = cframe
	end)
	table.insert(doors, { part = part, closed = closed, opened = opened, value = value, isOpen = false })
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
				local wantOpen = anyoneNear(door.closed.Position)
				if wantOpen ~= door.isOpen then
					door.isOpen = wantOpen
					TweenService:Create(door.value, info, { Value = if wantOpen then door.opened else door.closed })
						:Play()
				end
			end
			task.wait(DOORS.CheckInterval)
		end
	end)
end

return DoorService
