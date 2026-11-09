-- Ressenti des coups (D126, design/REVIEW_2026-11-10.md, réglages dans Config/Feel.luau).
-- Un coup se sent par plusieurs canaux en même temps : son en couches, caméra (figée un instant, zoom, secousse),
-- flash, voile rouge, vibration. La force suit l'importance du coup.
-- - LocalRep : chaque geste noté du joueur (tous les mini-jeux) joue son son tout de suite, au lieu d'attendre la
--   confirmation du serveur ; en combat de boss, couches d'impact, hit-stop et flash sur un Perfect.
-- - BossRep : le boss marque contre le joueur (son de coup, secousse latérale, voile rouge sur les bords).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Feel = require(ReplicatedStorage.Shared.Config.Feel)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local CameraFraming = require(script.Parent.CameraFraming)
local Kit = require(script.Parent.MinigameKit)
local Ui = require(script.Parent.Ui)

local ImpactFx = {}

local REP_SOUNDS = { Perfect = "RepPerfect", Good = "RepGood", Miss = "RepMiss" }

local lastLocalRep = -math.huge
local streak = 0
local flash: ColorCorrectionEffect? = nil
local vignette: ScreenGui? = nil
local edges: { Frame } = {}

-- Instant du dernier geste noté (SoundController : la confirmation du serveur ne rejoue pas le son)
function ImpactFx.LastLocalRep(): number
	return lastLocalRep
end

-- Nouvelle série : le son repart de sa hauteur de base
function ImpactFx.ResetStreak()
	streak = 0
end

local function layers(list: { string }?, pitch: number?)
	for _, name in list or {} do
		Kit.Sound(name, pitch)
	end
end

local function flashImage(amount: number, duration: number)
	if not Kit.Setting("ScreenFx") then
		return
	end
	if not flash or not flash.Parent then
		local effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "ImpactFlash"
		effect.Parent = Lighting
		flash = effect
	end
	local effect = flash :: ColorCorrectionEffect
	effect.Brightness = amount
	TweenService:Create(effect, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
	}):Play()
end

-- Voile coloré sur les 4 bords de l'écran (dégradés), qui s'efface
local function buildVignette(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "ImpactVignette"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	local depth = Feel.BossHit.VignetteDepth
	-- position, taille, rotation du dégradé (le bord opaque vers l'extérieur)
	local sides = {
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, depth), 90 },
		{ UDim2.fromScale(0, 1 - depth), UDim2.fromScale(1, depth), -90 },
		{ UDim2.fromScale(0, 0), UDim2.fromScale(depth, 1), 0 },
		{ UDim2.fromScale(1 - depth, 0), UDim2.fromScale(depth, 1), 180 },
	}
	for _, side in sides do
		local frame = Ui.create("Frame", {
			Position = side[1],
			Size = side[2],
			BorderSizePixel = 0,
			BackgroundColor3 = Feel.BossHit.VignetteColor,
			BackgroundTransparency = 1,
			Parent = gui,
		}, {
			Ui.create("UIGradient", {
				Rotation = side[3],
				Transparency = NumberSequence.new(0, 1),
			}),
		})
		table.insert(edges, frame)
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

local function showVignette(strongest: number)
	if not Kit.Setting("ScreenFx") then
		return
	end
	if not vignette or not vignette.Parent then
		edges = {}
		vignette = buildVignette()
	end
	for _, frame in edges do
		frame.BackgroundTransparency = strongest
		TweenService:Create(frame, TweenInfo.new(Feel.BossHit.VignetteTime, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1,
		}):Play()
	end
end

-- Geste noté du joueur. inBoss : combat de boss (couches d'impact, hit-stop, flash)
function ImpactFx.LocalRep(quality: string, inBoss: boolean)
	lastLocalRep = os.clock()
	streak = if quality == "Miss" then 0 else streak + 1
	local pitch = 1 + math.min(streak, Sounds.ComboPitch.MaxStreak) * Sounds.ComboPitch.Step
	Kit.Sound(REP_SOUNDS[quality] or "RepGood", pitch)
	if not inBoss then
		return
	end
	local hit = Feel.PlayerHit
	layers(hit.Layers[quality])
	if quality == "Perfect" then
		if Kit.Setting("ScreenFx") then
			CameraFraming.Freeze(hit.FreezePerfect)
		end
		flashImage(hit.FlashPerfect, hit.FlashTime)
	end
end

-- Le boss marque contre le joueur (son propre combat)
function ImpactFx.BossRep(quality: string)
	local hit = Feel.BossHit
	task.delay(hit.Delay, function()
		layers(hit.Layers[quality])
		if quality == "Miss" then
			return
		end
		if Kit.Setting("ScreenFx") then
			CameraFraming.Jolt(hit.Jolt[quality] or hit.Jolt.Good)
		end
		showVignette(hit.Vignette[quality] or hit.Vignette.Good)
		Kit.Haptic(if quality == "Perfect" then "Strong" else "Light")
	end)
end

return ImpactFx
