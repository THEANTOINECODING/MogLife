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
local sfxGroup: SoundGroup? = nil
local musicOn = true -- réglages du joueur (SettingsController)
local soundsOn = true

function SoundController.Play(name: string, pitch: number?)
	local entry = Sounds.Sfx[name]
	if typeof(entry) ~= "table" or typeof(entry.id) ~= "string" or entry.id == "" then
		return
	end
	local sound = cache[name]
	if not sound then
		if not sfxGroup then
			sfxGroup = Instance.new("SoundGroup")
			sfxGroup.Name = "Effects"
			sfxGroup.Volume = if soundsOn then Sounds.Volume.Sfx else 0
			sfxGroup.Parent = SoundService
		end
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = entry.id
		sound.Volume = entry.volume or 0.5
		sound.SoundGroup = sfxGroup
		sound.Parent = SoundService
		cache[name] = sound
	end
	sound.PlaybackSpeed = pitch or entry.pitch or 1 -- un effet peut avoir sa propre hauteur (Config/Sounds.luau)
	SoundService:PlayLocalSound(sound)
end

-- Joue un effet dans le monde, sur une pièce (on l'entend de près, moins de loin) ; même réglage « Sons »
function SoundController.PlayAt(name: string, part: BasePart, pitch: number?)
	local entry = Sounds.Sfx[name]
	if typeof(entry) ~= "table" or typeof(entry.id) ~= "string" or entry.id == "" or not part.Parent then
		return
	end
	if not sfxGroup then
		sfxGroup = Instance.new("SoundGroup")
		sfxGroup.Name = "Effects"
		sfxGroup.Volume = if soundsOn then Sounds.Volume.Sfx else 0
		sfxGroup.Parent = SoundService
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = entry.id
	sound.Volume = entry.volume or 0.5
	sound.PlaybackSpeed = pitch or entry.pitch or 1
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 70
	sound.SoundGroup = sfxGroup
	sound.Parent = part
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(6, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Musique ------------------------------------------------------------------------------------------------------

type Mood = "Town" | "Workout" | "Boss"

local musicGroup: SoundGroup
type Track = { id: string, volume: number }
local tracks: { [string]: { sound: Sound, index: number, started: boolean, list: { Track } } } = {}
local currentMood: string? = nil
local fightActive = false
local arenaActive = false -- combat du Dieu du Pump (D93)
local runActive = false
local workoutUntil = 0
local bossIntroUntil = 0

local function playlist(mood: string): { Track }
	local list = Sounds.Music[mood]
	local valid = {}
	for _, item in if typeof(list) == "table" then list else {} do
		if typeof(item) == "table" and typeof(item.id) == "string" and item.id ~= "" then
			table.insert(valid, { id = item.id, volume = item.volume or 0.3 })
		end
	end
	return valid
end

-- Volume du morceau en cours de cette ambiance (chaque morceau a le sien, voir Config/Sounds.luau)
local function moodVolume(mood: string): number
	local entry = tracks[mood]
	return if entry then entry.list[entry.index].volume else 0
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
	sound.SoundId = list[1].id
	sound.Looped = #list == 1
	sound.Volume = 0
	sound.SoundGroup = musicGroup
	sound.Parent = SoundService
	local entry = { sound = sound, index = 1, started = false, list = list }
	sound.Ended:Connect(function()
		entry.index = entry.index % #list + 1
		sound.SoundId = list[entry.index].id
		if currentMood == mood then
			sound.Volume = list[entry.index].volume
		end
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
	if fightActive or arenaActive or now < bossIntroUntil then
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
	if not musicOn then
		return
	end
	TweenService:Create(musicGroup, TweenInfo.new(0.4), { Volume = Sounds.Volume.Music * Sounds.Volume.Duck }):Play()
	task.delay(Sounds.Timing.Duck, function()
		if duckToken == token then
			TweenService:Create(musicGroup, TweenInfo.new(1.5), { Volume = if musicOn then Sounds.Volume.Music else 0 })
				:Play()
		end
	end)
end

local function startMusic()
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "Music"
	musicGroup.Volume = if musicOn then Sounds.Volume.Music else 0
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

-- Combat du Dieu du Pump (combattant et spectateurs proches) : musique de boss (PumpGodController)
function SoundController.SetArena(on: boolean)
	arenaActive = on
	if musicGroup then
		updateMusic()
	end
end

-- Réglages du joueur : couper / remettre la musique ou les effets (en fondu pour la musique)
function SoundController.SetMusicEnabled(on: boolean)
	musicOn = on
	if musicGroup then
		TweenService:Create(musicGroup, TweenInfo.new(0.5), { Volume = if on then Sounds.Volume.Music else 0 }):Play()
	end
end

function SoundController.SetSoundsEnabled(on: boolean)
	soundsOn = on
	if sfxGroup then
		sfxGroup.Volume = if on then Sounds.Volume.Sfx else 0
	end
end

local REP_SOUNDS = { Perfect = "RepPerfect", Good = "RepGood", Miss = "RepMiss" }

function SoundController.Start()
	startMusic()
	Remotes.SeriesUpdate.OnClientEvent:Connect(function(update)
		if update.state == "Rep" then
			-- Chaque répétition réussie d'affilée joue un peu plus aigu : on entend la série monter (D52)
			local streak = math.min(update.streak or 0, Sounds.ComboPitch.MaxStreak)
			SoundController.Play(REP_SOUNDS[update.quality] or "RepGood", 1 + streak * Sounds.ComboPitch.Step)
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
	Remotes.DuelUpdate.OnClientEvent:Connect(function(update)
		if typeof(update) ~= "table" then
			return
		end
		if update.state == "Started" then
			fightActive = true
		elseif update.state == "Result" then
			duck()
			if update.result == "Won" then
				SoundController.Play("BossVictory")
			elseif update.result == "Lost" or update.result == "Forfeit" then
				SoundController.Play("BossDefeat")
			else
				SoundController.Play("SeriesEnd")
			end
		elseif update.state == "Finished" then
			fightActive = false
		end
		updateMusic()
	end)
	Remotes.MentorSay.OnClientEvent:Connect(function()
		SoundController.Play("MentorSay")
	end)
end

return SoundController
