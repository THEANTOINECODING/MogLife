-- Social (validé le 16/10) :
-- - Émotes : un joueur prend une pose de culturisme (MogOff.Strike), vue par tout le monde. Hors activité, avec un
--   court délai entre deux poses.
-- - Pareur (« Spot ») : pendant la série d'exercice d'un joueur, un autre joueur proche peut le parer (prompt sur
--   le personnage qui s'entraîne). Le pratiquant gagne +20 % de Mog tant qu'on le pare ; le pareur reçoit une
--   part du Mog de chaque répétition (25 %) et l'encourage en posant. Un seul pareur par série ; la parade
--   s'arrête si le pareur s'éloigne ou lance sa propre activité. Réglages : Balance.Spot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SPOT = Balance.Spot
local PROMPT_NAME = "SpotPrompt"

local StatsService
local MinigameService

local lastEmote: { [Player]: number } = {}
-- Parade en cours : pratiquant -> pareur, et Mog gagné par le pareur pendant cette parade
type Spot = { spotter: Player, earned: number }
local spots: { [Player]: Spot } = {}

local SocialService = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function emote(player: Player, index: number)
	Remotes.EmotePlay:FireAllClients(player, index)
end

local function onEmote(player: Player, index: unknown)
	if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > Balance.Emotes.Count then
		return
	end
	local now = os.clock()
	if MinigameService.IsBusy(player) or now - (lastEmote[player] or 0) < Balance.Emotes.Cooldown then
		return
	end
	lastEmote[player] = now
	emote(player, index)
end

-- ------------------------------------------------------------------ pareur

local function removePrompt(lifter: Player)
	local root = rootOf(lifter)
	local prompt = root and root:FindFirstChild(PROMPT_NAME)
	if prompt then
		prompt:Destroy()
	end
end

local function endSpot(lifter: Player)
	local spot = spots[lifter]
	if not spot then
		return
	end
	spots[lifter] = nil
	if spot.spotter.Parent then
		Remotes.Notify:FireClient(spot.spotter, {
			key = "Spot.Ended",
			args = { name = lifter.DisplayName, mog = math.floor(spot.earned * 10 + 0.5) / 10 },
		})
	end
end

local function startSpot(lifter: Player, spotter: Player)
	if spotter == lifter or spots[lifter] or MinigameService.IsBusy(spotter) then
		return
	end
	for _, other in spots do
		if other.spotter == spotter then
			return -- on ne pare qu'un joueur à la fois
		end
	end
	local a, b = rootOf(lifter), rootOf(spotter)
	if not a or not b or (a.Position - b.Position).Magnitude > SPOT.Distance then
		return
	end
	spots[lifter] = { spotter = spotter, earned = 0 }
	removePrompt(lifter)
	emote(spotter, SPOT.CheerPose)
	Remotes.Notify:FireClient(lifter, {
		key = "Spot.Lifter",
		args = { name = spotter.DisplayName, bonus = math.floor(SPOT.LifterBonus * 100 + 0.5) },
	})
	Remotes.Notify:FireClient(spotter, { key = "Spot.Spotter", args = { name = lifter.DisplayName } })
end

-- Une série d'exercice commence : les autres joueurs peuvent proposer de parer
function SocialService.OfferSpot(lifter: Player)
	local root = rootOf(lifter)
	if not root then
		return
	end
	removePrompt(lifter)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = Texts.Get("Spot.Prompt")
	prompt.ObjectText = lifter.DisplayName
	prompt.MaxActivationDistance = SPOT.Distance
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.3
	prompt.Parent = root
	prompt.Triggered:Connect(function(spotter)
		startSpot(lifter, spotter)
	end)
end

-- Multiplicateur de Mog du pratiquant (1 s'il n'est pas paré)
function SocialService.LifterMultiplier(lifter: Player): number
	return if spots[lifter] then 1 + SPOT.LifterBonus else 1
end

-- Répétition validée du pratiquant : le pareur reçoit sa part s'il est toujours là
function SocialService.OnLifterRep(lifter: Player, gain: number, quality: string)
	local spot = spots[lifter]
	if not spot then
		return
	end
	local a, b = rootOf(lifter), rootOf(spot.spotter)
	if
		not spot.spotter.Parent
		or not a
		or not b
		or (a.Position - b.Position).Magnitude > SPOT.Distance
		or MinigameService.IsBusy(spot.spotter)
	then
		endSpot(lifter)
		return
	end
	local share = gain * SPOT.SpotterShare
	spot.earned += share
	StatsService.Add(spot.spotter, "Mog", share)
	-- Le pareur encourage : il pose à chaque Perfect
	if quality == "Perfect" then
		emote(spot.spotter, SPOT.CheerPose)
	end
end

-- Fin de la série du pratiquant
function SocialService.EndSeries(lifter: Player)
	removePrompt(lifter)
	endSpot(lifter)
end

function SocialService.Init(services)
	StatsService = services.StatsService
	MinigameService = services.MinigameService
end

function SocialService.Start()
	Remotes.Emote.OnServerEvent:Connect(onEmote)
	Players.PlayerRemoving:Connect(function(player)
		lastEmote[player] = nil
		endSpot(player)
		for lifter, spot in spots do
			if spot.spotter == player then
				spots[lifter] = nil
			end
		end
	end)
end

return SocialService
