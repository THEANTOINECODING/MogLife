-- Sons (étape 7) : musique de fond en boucle et effets branchés sur les événements du jeu (répétitions selon leur
-- qualité, aides, achats, transformation, combats de boss, mentor). Les identifiants sont dans Config/Sounds.luau ;
-- un identifiant vide = pas de son (rien n'est inventé).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local cache: { [string]: Sound } = {}

local SoundController = {}

-- Joue un effet de Config/Sounds.luau (sans effet si son identifiant est vide)
function SoundController.Play(name: string)
	local id = Sounds.Sfx[name]
	if typeof(id) ~= "string" or id == "" then
		return
	end
	local sound = cache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Volume = Sounds.Volume.Sfx
		sound.Parent = SoundService
		cache[name] = sound
	end
	SoundService:PlayLocalSound(sound)
end

local function startMusic()
	local id = Sounds.Music.Town
	if typeof(id) ~= "string" or id == "" then
		return
	end
	local music = Instance.new("Sound")
	music.Name = "Music"
	music.SoundId = id
	music.Looped = true
	music.Volume = Sounds.Volume.Music
	music.Parent = SoundService
	music:Play()
end

local REP_SOUNDS = { Perfect = "RepPerfect", Good = "RepGood", Auto = "RepGood", Miss = "RepMiss" }

function SoundController.Start()
	startMusic()
	Remotes.SeriesUpdate.OnClientEvent:Connect(function(update)
		if update.state == "Rep" then
			SoundController.Play(REP_SOUNDS[update.quality] or "RepGood")
		elseif update.state == "Ended" and update.reason == "Completed" and update.kind == "Exercise" then
			SoundController.Play("SeriesEnd")
		end
	end)
	Remotes.Notify.OnClientEvent:Connect(function(message)
		local key = message and message.key
		if key == "Help.Done" or key == "Help.Thanks" then
			SoundController.Play("HelpDone")
		elseif key == "Shop.Bought" or key == "Furniture.Bought" then
			SoundController.Play("Purchase")
		end
	end)
	Remotes.BodyTransform.OnClientEvent:Connect(function(who)
		if who == player then
			SoundController.Play("StageUp")
		end
	end)
	Remotes.BossUpdate.OnClientEvent:Connect(function(update)
		if update.state == "Victory" then
			SoundController.Play("BossVictory")
		elseif update.state == "Defeat" or update.state == "Mogged" then
			SoundController.Play("BossDefeat")
		end
	end)
	Remotes.MentorSay.OnClientEvent:Connect(function()
		SoundController.Play("MentorSay")
	end)
end

return SoundController
