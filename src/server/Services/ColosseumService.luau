-- Le Colisée du Pump (D89, tranche 1) : l'arène du dernier boss, au-delà du coin sud-ouest de la ville.
-- - Piliers de lumière (tag "ColosseumPortal", attribut Target = "Colosseum" ou "Temple") : un au temple du Dieu du
--   Pump, un sur le parvis du colisée. Le joueur demande (ProximityPrompt), le serveur vérifie (distance, délai, pas en
--   pleine série ni en combat), tout le monde voit la lumière monter (Remotes.ColosseumTravel), puis il arrive.
-- - Sécurité de la piste : seul le combattant du dernier boss a le droit d'y être (défi accepté au temple, D94). Un
--   joueur qui s'y retrouve (bug, glitch) remonte dans les gradins.
-- Points de jeu de la carte (tag "ColosseumSpot", attribut Role) : Arrival, Stands, Center, Fighter, Boss.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PORTAL_TAG = "ColosseumPortal"
local SPOT_TAG = "ColosseumSpot"
local SETTINGS = Balance.Colosseum

local MinigameService
local BossService

local lastTrip: { [Player]: number } = {}
local traveling: { [Player]: boolean } = {}
local fighters: { [Player]: boolean } = {}

local ColosseumService = {}

local function findSpot(role: string): BasePart?
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		if spot:IsA("BasePart") and spot:GetAttribute("Role") == role then
			return spot
		end
	end
	return nil
end

local function findPortal(target: string): BasePart?
	for _, portal in CollectionService:GetTagged(PORTAL_TAG) do
		if portal:IsA("BasePart") and portal:GetAttribute("Target") == target then
			return portal
		end
	end
	return nil
end

-- Où l'on arrive : sur le parvis du colisée, tourné vers son entrée ; ou à côté du pilier du temple
local function destination(target: string): CFrame?
	if target == "Colosseum" then
		local arrival, center = findSpot("Arrival"), findSpot("Center")
		if not arrival or not center then
			return nil
		end
		local from = arrival.Position + Vector3.new(0, 3, 0)
		local look = Vector3.new(center.Position.X, from.Y, center.Position.Z)
		return CFrame.lookAt(from, look)
	end
	local portal = findPortal("Colosseum")
	if not portal then
		return nil
	end
	-- Devant le pilier du temple, côté ville, tourné vers la ville
	return portal.CFrame * CFrame.new(0, 0, -6)
end

local function travel(player: Player, portal: BasePart)
	local target = portal:GetAttribute("Target")
	if typeof(target) ~= "string" or traveling[player] then
		return
	end
	if MinigameService.IsBusy(player) or BossService.IsFighting(player) then
		return
	end
	if not MinigameService.IsNear(player, portal, SETTINGS.PortalDistance) then
		return
	end
	local now = os.clock()
	if now - (lastTrip[player] or -math.huge) < SETTINGS.PortalCooldown then
		return
	end
	local arrive = destination(target)
	if not arrive then
		return
	end
	lastTrip[player] = now
	traveling[player] = true
	-- Tout le monde voit la colonne de lumière monter autour du joueur
	Remotes.ColosseumTravel:FireAllClients({ player = player, from = portal.Position })
	task.delay(SETTINGS.TravelDelay, function()
		traveling[player] = nil
		local character = player.Character
		if player.Parent and character and character:FindFirstChild("HumanoidRootPart") then
			character:PivotTo(arrive)
		end
	end)
end

local function setupPortal(portal: Instance)
	if not portal:IsA("BasePart") or portal:FindFirstChild("PortalPrompt") then
		return
	end
	local target = portal:GetAttribute("Target")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PortalPrompt"
	prompt.ActionText = Texts.Get(if target == "Temple" then "Colosseum.PortalBack" else "Colosseum.PortalTo")
	prompt.ObjectText = Texts.Get("Colosseum.PortalName")
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal
	prompt.Triggered:Connect(function(player)
		travel(player, portal)
	end)
end

-- Le combattant du Dieu du Pump (PumpGodService) : il a le droit d'être sur la piste
function ColosseumService.SetFighter(player: Player, fighting: boolean)
	fighters[player] = if fighting then true else nil
	player:SetAttribute("InFight", if fighting then true else nil)
end

-- Renvoie un joueur au temple, avec la colonne de lumière (défaite contre le Dieu du Pump)
function ColosseumService.SendToTemple(player: Player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local arrive = destination("Temple")
	if not root or not arrive or traveling[player] then
		return
	end
	traveling[player] = true
	Remotes.ColosseumTravel:FireAllClients({ player = player, from = root.Position })
	task.delay(SETTINGS.TravelDelay, function()
		traveling[player] = nil
		local character = player.Character
		if player.Parent and character and character:FindFirstChild("HumanoidRootPart") then
			character:PivotTo(arrive)
		end
	end)
end

-- Personne d'autre que le combattant sur la piste : un joueur qui s'y retrouve remonte dans les gradins
local function checkPit()
	local center = findSpot("Center")
	local stands = findSpot("Stands")
	if not center or not stands then
		return
	end
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and not fighters[player] and not traveling[player] then
			local offset = root.Position - center.Position
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if flat < SETTINGS.PitRadius and offset.Y < SETTINGS.PitHeight and offset.Y > -4 then
				local look = Vector3.new(center.Position.X, stands.Position.Y + 3, center.Position.Z)
				player.Character:PivotTo(CFrame.lookAt(stands.Position + Vector3.new(0, 3, 0), look))
			end
		end
	end
end

function ColosseumService.Init(services)
	MinigameService = services.MinigameService
	BossService = services.BossService
end

function ColosseumService.Start()
	for _, portal in CollectionService:GetTagged(PORTAL_TAG) do
		setupPortal(portal)
	end
	CollectionService:GetInstanceAddedSignal(PORTAL_TAG):Connect(setupPortal)
	Players.PlayerRemoving:Connect(function(player)
		lastTrip[player] = nil
		traveling[player] = nil
		fighters[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(SETTINGS.PitCheckEvery)
			checkPit()
		end
	end)
end

return ColosseumService
