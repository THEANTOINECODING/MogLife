-- Sons (étape 7) : musique et effets branchés sur les événements du jeu (répétitions selon leur qualité, aides,
-- achats, transformation, combats de boss, mentor). Les identifiants sont dans Config/Sounds.luau ; un identifiant
-- vide = pas de son (rien n'est inventé).
-- Musique (D54) : trois ambiances qui se relaient en fondu. Ville (douce) ; entraînement pendant ses séries et ses
-- aides (gardée quelques secondes après, pour enchaîner) ; boss pendant un combat et sa présentation. Chaque
-- ambiance reprend où elle s'était arrêtée (sauf le boss, qui repart du début). La musique baisse pendant les jingles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local cache: { [string]: Sound } = {}

local SoundController = {}

-- Joue un effet de Config/Sounds.luau (sans effet si son identifiant est vide).
-- pitch : vitesse de lecture (1 = normal ; le son des répétitions monte avec le combo)
function SoundController.Play(name: string, pitch: number?)
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
	sound.PlaybackSpeed = pitch or 1
	SoundService:PlayLocalSound(sound)
end

-- Musique ------------------------------------------------------------------------------------------------------

type Mood = "Town" | "Workout" | "Boss"

local musicGroup: SoundGroup
local tracks: { [string]: { sound: Sound, index: number, started: boolean } } = {}
local currentMood: string? = nil
local fightActive = false
local runActive = false
local workoutUntil = 0
local bossIntroUntil = 0

local function moodVolume(mood: string): number
	return Sounds.Volume.Music[mood] or 0.2
end

local function playlist(mood: string): { string }
	local list = Sounds.Music[mood]
	local valid = {}
	for _, id in if typeof(list) == "table" then list else {} do
		if typeof(id) == "string" and id ~= "" then
			table.insert(valid, id)
		end
	end
	return valid
end

-- Le lecteur d'une ambiance (créé à la première utilisation) ; enchaîne les morceaux de sa liste
local function track(mood: string)
	local existing = tracks[mood]
	if existing then
		return existing
	end
	local list = playlist(mood)
	if #list == 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = `Music{mood}`
	sound.SoundId = list[1]
	sound.Looped = #list == 1
	sound.Volume = 0
	sound.SoundGroup = musicGroup
	sound.Parent = SoundService
	local entry = { sound = sound, index = 1, started = false }
	sound.Ended:Connect(function()
		entry.index = entry.index % #list + 1
		sound.SoundId = list[entry.index]
		task.wait(Sounds.Timing.TrackGap)
		if currentMood == mood then
			sound:Play()
		end
	end)
	tracks[mood] = entry
	return entry
end

local function fade(sound: Sound, volume: number, onDone: (() -> ())?)
	local tween = TweenService:Create(sound, TweenInfo.new(Sounds.Timing.Fade), { Volume = volume })
	if onDone then
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				onDone()
			end
		end)
	end
	tween:Play()
end

local function wantedMood(): Mood
	local now = os.clock()
	if fightActive or now < bossIntroUntil then
		return "Boss"
	elseif runActive or now < workoutUntil then
		return "Workout"
	end
	return "Town"
end

local function updateMusic()
	local mood = wantedMood()
	if mood == currentMood then
		return
	end
	local previous = currentMood and tracks[currentMood]
	currentMood = mood
	if previous then
		local old = previous.sound
		fade(old, 0, function()
			-- Toujours hors de l'ambiance en cours : on la met en pause (elle reprendra au même endroit)
			if tracks[currentMood :: string] ~= previous then
				old:Pause()
			end
		end)
	end
	local entry = track(mood)
	if not entry then
		return
	end
	local sound = entry.sound
	if mood == "Boss" then
		sound.TimePosition = 0 -- un combat commence toujours sur le début du morceau
	end
	if not entry.started then
		entry.started = true
		sound:Play()
	elseif not sound.IsPlaying then
		sound:Resume()
	end
	fade(sound, moodVolume(mood))
end

-- Baisse la musique le temps d'un jingle
local duckToken = 0
local function duck()
	duckToken += 1
	local token = duckToken
	TweenService:Create(musicGroup, TweenInfo.new(0.25), { Volume = Sounds.Volume.Duck }):Play()
	task.delay(Sounds.Timing.Duck, function()
		if duckToken == token then
			TweenService:Create(musicGroup, TweenInfo.new(1), { Volume = 1 }):Play()
		end
	end)
end

local function startMusic()
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "Music"
	musicGroup.Volume = 1
	musicGroup.Parent = SoundService
	updateMusic()
	-- Les délais (fin de la grâce d'entraînement, fin de la présentation du boss) sont vérifiés en continu
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.25 then
			elapsed = 0
			updateMusic()
		end
	end)
	-- Ses propres exercices et aides (le combat de boss est suivi par BossUpdate)
	Remotes.Activity.OnClientEvent:Connect(function(update)
		if update.player ~= player or update.kind == "Boss" then
			return
		end
		if update.state == "Started" then
			runActive = true
		elseif update.state == "Ended" then
			runActive = false
			workoutUntil = os.clock() + Sounds.Timing.WorkoutGrace
		end
		updateMusic()
	end)
	Remotes.Cutscene.OnClientEvent:Connect(function(request)
		if typeof(request) == "table" and request.kind == "Boss" then
			bossIntroUntil = os.clock() + Sounds.Timing.BossIntro
			updateMusic()
		end
	end)
end

local REP_SOUNDS = { Perfect = "RepPerfect", Good = "RepGood", Auto = "RepGood", Miss = "RepMiss" }

function SoundController.Start()
	startMusic()
	Remotes.SeriesUpdate.OnClientEvent:Connect(function(update)
		if update.state == "Rep" then
			-- Chaque répétition réussie d'affilée joue un peu plus aigu : on entend la série monter (D52)
			local streak = math.min(update.streak or 0, 15)
			SoundController.Play(REP_SOUNDS[update.quality] or "RepGood", 1 + streak * 0.035)
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
			duck()
			SoundController.Play("StageUp")
		end
	end)
	Remotes.BossUpdate.OnClientEvent:Connect(function(update)
		if update.state == "FightStarted" then
			fightActive = true
		elseif update.state == "Victory" then
			fightActive = false
			duck()
			SoundController.Play("BossVictory")
		elseif update.state == "Defeat" or update.state == "Mogged" then
			fightActive = false
			duck()
			SoundController.Play("BossDefeat")
		elseif update.state == "Aborted" then
			fightActive = false
		end
		updateMusic()
	end)
	Remotes.MentorSay.OnClientEvent:Connect(function()
		SoundController.Play("MentorSay")
	end)
end

return SoundController
