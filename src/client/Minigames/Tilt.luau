-- Mini-jeu « Tilt » (exercice : squat, D81) : glisser le pouce vers le bas (n'importe où sur l'écran) pour
-- descendre jusqu'à la ligne verte, puis lever le doigt (ou remonter) pour se relever. La répétition est notée
-- à la remontée, selon l'écart entre le point le plus bas et la ligne. La ligne change à chaque répétition.
-- Surprise (niveau Tilt.PauseLevel) : squat avec pause, rester dans la zone le temps que le cercle se remplisse.
-- Clavier : maintenir flèche bas / S / Espace ; manette : maintenir A ou stick vers le bas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Tilt
local GREEN = Color3.fromRGB(90, 220, 100)
local GOLD = Color3.fromRGB(255, 210, 60)
local TOP = 0.1 -- position de la barre debout (fraction de la piste)
local BOTTOM = 0.92 -- position tout en bas
local DOWN_KEYS = { Enum.KeyCode.Down, Enum.KeyCode.S, Enum.KeyCode.Space, Enum.KeyCode.ButtonA }

local Tilt = {}

function Tilt.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(280, 420))
	local rng = self:Random()
	self:TrackDrag()

	local track = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(1, -40, 1, -28),
		BackgroundColor3 = Color3.fromRGB(25, 20, 40),
		BackgroundTransparency = 0.2,
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 16)) })
	local band = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromScale(1, 0.1),
		BackgroundColor3 = GREEN,
		BackgroundTransparency = 0.35,
		ZIndex = 2,
		Parent = track,
	})
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = GOLD,
		ZIndex = 3,
		Parent = band,
	})
	local pause = Ui.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		ZIndex = 4,
		Visible = false,
		Parent = band,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(GOLD, 3, 0) })
	local pauseFill = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0, 0),
		BackgroundColor3 = GOLD,
		ZIndex = 5,
		Parent = pause,
	}, { Ui.corner(UDim.new(1, 0)) })
	-- La barre chargée, sur les épaules
	local bar = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, -24, 0, 12),
		BackgroundColor3 = Color3.fromRGB(220, 220, 230),
		ZIndex = 6,
		Parent = track,
	}, { Ui.corner(UDim.new(1, 0)) })
	for _, x in { 0.04, 0.96 } do
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.fromOffset(20, 46),
			BackgroundColor3 = Color3.fromRGB(60, 60, 70),
			ZIndex = 7,
			Parent = bar,
		}, { Ui.corner(UDim.new(0, 5)) })
	end
	local face = self:Emoji(bar, "😤", 40, 8)
	face.Position = UDim2.new(0.5, 0, 0.5, 22)

	local depth = 0 -- 0 = debout, 1 = tout en bas
	local deepest = 0
	local descending = false
	local target = 0.7
	local needsPause = false
	local pausedFor = 0

	local function newTarget()
		target = SETTINGS.TargetMin + rng:NextNumber() * (SETTINGS.TargetMax - SETTINGS.TargetMin)
		needsPause = self.level >= SETTINGS.PauseLevel and rng:NextNumber() < SETTINGS.PauseChance
		if needsPause then
			self:Announce("Minigame.Twist.Tilt.Pause")
		end
		pausedFor = 0
	end
	newTarget()

	local function keyDown(): boolean
		for _, key in DOWN_KEYS do
			if UserInputService:IsKeyDown(key) then
				return true
			end
		end
		for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if state.KeyCode == Enum.KeyCode.ButtonA and state.UserInputState == Enum.UserInputState.Begin then
				return true
			end
			if state.KeyCode == Enum.KeyCode.Thumbstick1 and state.Position.Y < -0.5 then
				return true
			end
		end
		return false
	end

	self:Guide(panel, "SwipeDown")

	self:OnStep(function(dt)
		local ready = self:RepReady()
		local drag = self:ConsumeDrag()
		local camera = workspace.CurrentCamera
		local range = (if camera then camera.ViewportSize.Y else 600) * SETTINGS.RangeFraction
		local pushing = self.dragging or keyDown()
		if self.dragging then
			depth += drag.Y * Balance.Minigames.DragSensitivity / range
		elseif keyDown() then
			depth += SETTINGS.KeySpeed * dt
		else
			depth -= SETTINGS.RiseSpeed * dt
		end
		-- Pas encore prêt (cadence) : on ne peut pas redescendre, la barre reste en haut
		if not ready and not descending then
			depth = math.min(depth, SETTINGS.StartAbove * 0.9)
		end
		depth = math.clamp(depth, 0, 1)

		local half = SETTINGS.GoodMax * self.timingScale
		if depth > SETTINGS.StartAbove and ready then
			descending = true
		end
		if descending then
			deepest = math.max(deepest, depth)
			if math.abs(depth - target) <= half then
				pausedFor += dt
			end
			-- Remonté : la répétition est notée
			if depth < SETTINGS.StandBelow or (not pushing and depth < SETTINGS.StartAbove) then
				local quality = self:GradeError(math.abs(deepest - target), SETTINGS.PerfectMax, SETTINGS.GoodMax)
				if needsPause and pausedFor < SETTINGS.PauseTime then
					quality = "Miss"
				end
				self:Rep(quality, band)
				descending = false
				deepest = 0
				newTarget()
			end
		end

		local y = TOP + (BOTTOM - TOP) * depth
		bar.Position = UDim2.fromScale(0.5, y)
		band.Position = UDim2.fromScale(0, TOP + (BOTTOM - TOP) * target)
		band.Size = UDim2.fromScale(1, (BOTTOM - TOP) * half * 2)
		band.BackgroundTransparency = if ready then 0.35 else 0.8
		pause.Visible = needsPause
		local pauseProgress = math.clamp(pausedFor / SETTINGS.PauseTime, 0, 1)
		pauseFill.Size = UDim2.fromScale(pauseProgress, pauseProgress)
		-- Trop bas : la barre devient rouge
		local tooDeep = depth > target + half
		bar.BackgroundColor3 = if tooDeep then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(220, 220, 230)
		face.Text = if tooDeep then "😵" elseif depth > 0.3 then "😤" else "🙂"
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return {
			depth = depth,
			target = target,
			needsPause = needsPause,
			pausedFor = pausedFor,
			descending = descending,
			ready = self:RepReady(),
		}
	end

	return self
end

return Tilt
