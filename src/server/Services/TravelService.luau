-- Déplacements rapides : bouton « Maison » (n'importe où) et bus entre les arrêts (tag "BusStop" + attribut Stop).
-- Le client demande, le serveur vérifie (pas en pleine série ni en combat, délai, distance à l'arrêt).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local STOP_TAG = "BusStop"
local TRAVEL = Balance.Travel

local MinigameService
local BossService
local PlotService

local lastTrip: { [Player]: number } = {}

local TravelService = {}

local function canTravel(player: Player, cooldown: number): boolean
	if MinigameService.IsBusy(player) or BossService.IsFighting(player) then
		return false
	end
	local now = os.clock()
	if now - (lastTrip[player] or 0) < cooldown then
		return false
	end
	lastTrip[player] = now
	return true
end

local function teleport(player: Player, target: CFrame)
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(target)
	end
end

local function findStop(stopId: string): BasePart?
	for _, stop in CollectionService:GetTagged(STOP_TAG) do
		if stop:IsA("BasePart") and stop:GetAttribute("Stop") == stopId then
			return stop
		end
	end
	return nil
end

local function nearAnyStop(player: Player): boolean
	for _, stop in CollectionService:GetTagged(STOP_TAG) do
		if stop:IsA("BasePart") and MinigameService.IsNear(player, stop, TRAVEL.BusStopDistance) then
			return true
		end
	end
	return false
end

local function onGoHome(player: Player)
	local home = PlotService.GetHomeCFrame(player)
	if home and canTravel(player, TRAVEL.HomeCooldown) then
		teleport(player, home)
	end
end

local function onTakeBus(player: Player, stopId: unknown)
	if typeof(stopId) ~= "string" then
		return
	end
	local stop = findStop(stopId)
	if not stop or not nearAnyStop(player) or not canTravel(player, TRAVEL.BusCooldown) then
		return
	end
	-- On descend devant l'abri, sur le trottoir, tourné vers la route
	teleport(player, stop.CFrame * CFrame.new(0, 3, -2.5))
end

function TravelService.Init(services)
	MinigameService = services.MinigameService
	BossService = services.BossService
	PlotService = services.PlotService
end

function TravelService.Start()
	for _, stop in CollectionService:GetTagged(STOP_TAG) do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BusPrompt"
		prompt.ActionText = Texts.Get("Bus.Prompt")
		prompt.ObjectText = Texts.Get(`Bus.Stop.{stop:GetAttribute("Stop")}`)
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = stop
	end
	Remotes.GoHome.OnServerEvent:Connect(onGoHome)
	Remotes.TakeBus.OnServerEvent:Connect(onTakeBus)
	Players.PlayerRemoving:Connect(function(player)
		lastTrip[player] = nil
	end)
end

return TravelService
