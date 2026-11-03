-- Stats des joueurs : modification, leaderstats, envoi au client et taille du corps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Throttle = require(script.Parent.Parent.Throttle)

local DataService
local BodyService

local StatsService = {}

-- Apparence provisoire : l'avatar Roblox s'élargit avec le Mog (échelle logarithmique).
-- Sera remplacé par le personnage du jeu (un corps par stade).
local function bodyProgress(mog: number): number
	local max = Balance.BodyScale.MogForMax
	return math.clamp(math.log10(1 + mog) / math.log10(1 + max), 0, 1)
end

local function applyBodyScale(player: Player)
	local data = DataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end
	-- Le stade a son vrai corps : c'est BodyService qui gère les proportions
	if BodyService.BodyFor(player) then
		return
	end

	local t = bodyProgress(data.Mog)
	local scale = Balance.BodyScale
	local width = humanoid:FindFirstChild("BodyWidthScale") :: NumberValue?
	local depth = humanoid:FindFirstChild("BodyDepthScale") :: NumberValue?
	if width then
		width.Value = scale.MinWidth + (scale.MaxWidth - scale.MinWidth) * t
	end
	if depth then
		depth.Value = scale.MinDepth + (scale.MaxDepth - scale.MinDepth) * t
	end
end

local function stageName(stageIndex: number): string
	local stage = Stages.List[stageIndex]
	return Texts.Get(`Stage.{stage.id}`)
end

local function sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats:FindFirstChild("Mog") :: IntValue).Value = math.floor(data.Mog);
		(leaderstats:FindFirstChild("Stage") :: StringValue).Value = stageName(data.Stage)
	end
	-- Stade visible de tous les clients : démarche, poussière des pas, respiration selon le gabarit (D84)
	player:SetAttribute("StageIndex", data.Stage)

	Remotes.StatsChanged:FireClient(player, {
		Mog = data.Mog,
		Cash = data.Cash,
		Stage = data.Stage,
	})
end

local function onPlayerLoaded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local mog = Instance.new("IntValue")
	mog.Name = "Mog"
	mog.Parent = leaderstats

	local stage = Instance.new("StringValue")
	stage.Name = "Stage"
	stage.Parent = leaderstats

	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		applyBodyScale(player)
	end)
	if player.Character then
		applyBodyScale(player)
	end

	sync(player)
end

-- Ajoute (ou retire si négatif) une quantité à une stat numérique. Serveur uniquement.
-- Le Cash ne descend jamais sous 0.
function StatsService.Add(player: Player, stat: "Mog" | "Cash", amount: number)
	local data = DataService.Get(player)
	if not data or typeof(data[stat]) ~= "number" then
		return
	end

	data[stat] += amount
	if stat == "Cash" and data.Cash < 0 then
		data.Cash = 0
	end
	sync(player)

	if stat == "Mog" then
		applyBodyScale(player)
		BodyService.UpdateGrowth(player)
	end
end

-- Renvoie les stats au client et met à jour l'apparence (après une modification directe des données).
function StatsService.Refresh(player: Player)
	sync(player)
	BodyService.Refresh(player)
	applyBodyScale(player)
end

function StatsService.Init(services)
	DataService = services.DataService
	BodyService = services.BodyService
end

function StatsService.Start()
	DataService.PlayerLoaded:Connect(onPlayerLoaded)
	-- Le client redemande ses stats au démarrage, au cas où il aurait raté le premier envoi
	Remotes.RequestStats.OnServerEvent:Connect(Throttle.Wrap(Balance.RemoteThrottle.RequestStats, sync))
end

return StatsService
