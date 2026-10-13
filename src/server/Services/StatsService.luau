-- Stats des joueurs : modification, leaderstats, envoi au client et taille du corps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Ranks = require(ReplicatedStorage.Shared.Config.Ranks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService

local StatsService = {}

local function bodyProgress(strength: number): number
	local max = Balance.BodyScale.StrengthForMax
	return math.clamp(math.log10(1 + strength) / math.log10(1 + max), 0, 1)
end

local function applyBodyScale(player: Player)
	local data = DataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end

	local t = bodyProgress(data.Strength)
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

local function sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end

	local rank = Ranks.FromStrength(data.Strength)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats:FindFirstChild("Force") :: IntValue).Value = data.Strength;
		(leaderstats:FindFirstChild("Rang") :: StringValue).Value = rank
	end

	Remotes.StatsChanged:FireClient(player, {
		Strength = data.Strength,
		Cash = data.Cash,
		Mog = data.Mog,
		Rank = rank,
	})
end

local function onPlayerLoaded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local strength = Instance.new("IntValue")
	strength.Name = "Force"
	strength.Parent = leaderstats

	local rank = Instance.new("StringValue")
	rank.Name = "Rang"
	rank.Parent = leaderstats

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

-- Ajoute (ou retire si négatif) une quantité à une stat. Serveur uniquement.
function StatsService.Add(player: Player, stat: string, amount: number)
	local data = DataService.Get(player)
	if not data or data[stat] == nil then
		return
	end

	local previousRank = Ranks.FromStrength(data.Strength)
	data[stat] += amount
	sync(player)

	if stat == "Strength" then
		applyBodyScale(player)
		local newRank = Ranks.FromStrength(data.Strength)
		if newRank ~= previousRank then
			print(`[MOG LIFE] {player.Name} passe au rang {newRank}`)
		end
	end
end

function StatsService.Init(services)
	DataService = services.DataService
end

function StatsService.Start()
	DataService.PlayerLoaded:Connect(onPlayerLoaded)
	-- Le client redemande ses stats au démarrage, au cas où il aurait raté le premier envoi
	Remotes.RequestStats.OnServerEvent:Connect(sync)
end

return StatsService
