-- Badges Roblox (D126, Config/Badges.luau) : donnés d'après la sauvegarde du joueur (stade, boss battus, meilleure
-- note). Vérifié toutes les quelques secondes ; chaque badge n'est demandé qu'une fois par session.
-- (Nommé BadgeAwardService pour ne pas se confondre avec le service Roblox BadgeService.)

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Badges = require(ReplicatedStorage.Shared.Config.Badges)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)

local BadgeAwardService = {}

local DataService
local asked: { [Player]: { [number]: boolean } } = {}

local function give(player: Player, badgeId: number)
	if badgeId == 0 then
		return
	end
	local done = asked[player]
	if not done or done[badgeId] then
		return
	end
	done[badgeId] = true
	task.spawn(function()
		local okHas, has = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
		end)
		if okHas and has then
			return
		end
		local ok, err = pcall(function()
			BadgeService:AwardBadge(player.UserId, badgeId)
		end)
		if not ok then
			done[badgeId] = nil -- nouvel essai à la prochaine vérification
			warn(`[BadgeAwardService] badge {badgeId} non donné : {err}`)
		end
	end)
end

local function check(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	for index, stage in Stages.List do
		if index > 1 and data.Stage >= index then
			give(player, Badges.Stages[stage.id] or 0)
		end
	end
	for bossId, badgeId in Badges.Bosses do
		if data.BossesBeaten[bossId] == true or (bossId == "PumpGod" and (data.PumpGodWins or 0) > 0) then
			give(player, badgeId)
		end
	end
	for _, score in data.Records or {} do
		if typeof(score) == "number" and score >= Badges.FirstS.score then
			give(player, Badges.FirstS.id)
			break
		end
	end
end

function BadgeAwardService.Init(services)
	DataService = services.DataService
end

function BadgeAwardService.Start()
	Players.PlayerAdded:Connect(function(player)
		asked[player] = {}
	end)
	for _, player in Players:GetPlayers() do
		asked[player] = {}
	end
	Players.PlayerRemoving:Connect(function(player)
		asked[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Badges.CheckEvery)
			for player in asked do
				if player.Parent then
					check(player)
				end
			end
		end
	end)
end

return BadgeAwardService
