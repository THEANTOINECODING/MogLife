-- La vitesse de déplacement est décidée par le serveur. Les activités bloquent toujours le sprint.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local requested: { [Player]: boolean } = {}
local clientLocked: { [Player]: boolean } = {}

local SprintService = {}

local function apply(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local busy = clientLocked[player] or player:GetAttribute("InRun") == true or player:GetAttribute("InDuel") == true
	humanoid.WalkSpeed = if busy
		then 0
		else if requested[player] then Balance.Movement.SprintSpeed else Balance.Movement.WalkSpeed
end

local function watch(player: Player)
	requested[player] = false
	clientLocked[player] = false
	player.CharacterAdded:Connect(function(character)
		requested[player] = false
		character:WaitForChild("Humanoid", 10)
		apply(player)
	end)
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		requested[player] = false
		apply(player)
	end)
	player:GetAttributeChangedSignal("InDuel"):Connect(function()
		requested[player] = false
		apply(player)
	end)
	if player.Character then
		apply(player)
	end
end

function SprintService.Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		requested[player] = nil
		clientLocked[player] = nil
	end)
	Remotes.SetSprint.OnServerEvent:Connect(function(player, pressed, locked)
		if typeof(pressed) ~= "boolean" or typeof(locked) ~= "boolean" then
			return
		end
		requested[player] = pressed
		clientLocked[player] = locked
		apply(player)
	end)
end

return SprintService
