-- Le mentor mystérieux (décision D29) : lunettes noires, barbe blanche, proverbes absurdes de salle de sport.
-- Pour l'instant il attend près du podium de la place (tag MentorSpot) et livre un proverbe à qui l'écoute.
-- Le guide et le tutoriel (étape 5) lui donneront ses vraies missions.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Npc = require(ServerScriptService.Server.Npc)

local SPOT_TAG = "MentorSpot"
local LOOK = "Mentor"

local MentorService = {}

-- Proverbes Mentor.Proverb1, Proverb2… (on les compte dans Texts : en ajouter n'exige pas de toucher au code)
local function proverbCount(): number
	local count = 0
	while Texts.Has(`Mentor.Proverb{count + 1}`) do
		count += 1
	end
	return count
end

local function spawnMentor(spot: Instance)
	if not spot:IsA("BasePart") then
		return
	end
	local facing = (spot.CFrame * CFrame.new(0, 0, -10)).Position
	local _, body = Npc.Spawn(LOOK, Texts.Get(`Npc.{LOOK}`), spot, facing)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.Get("Mentor.Prompt")
	prompt.ObjectText = Texts.Get(`Npc.{LOOK}`)
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	local count = proverbCount()
	local last: { [Player]: number } = {}
	prompt.Triggered:Connect(function(player)
		if count == 0 then
			return
		end
		-- Jamais deux fois le même proverbe d'affilée
		local index = math.random(1, count)
		if count > 1 and index == last[player] then
			index = index % count + 1
		end
		last[player] = index
		Remotes.Notify:FireClient(player, { key = `Mentor.Proverb{index}` })
	end)
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
end

function MentorService.Start()
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		spawnMentor(spot)
	end
end

return MentorService
