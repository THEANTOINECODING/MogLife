-- Scènes tactiles de la refonte. Les gestes sont mesurés en fractions du panneau, jamais en pixels.
-- Chaque activité fournit son propre objectif et sa propre règle dans Config/SceneGames.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local SceneGames = require(ReplicatedStorage.Shared.Config.SceneGames)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Kit = require(script.Parent.MinigameKit)
local SceneArt = require(script.Parent.SceneArt)
local Ui = require(script.Parent.Ui)
local SoundController = require(script.Parent.Controllers.SoundController)

local C = SceneGames.Common
local LANES = { 0.2, 0.5, 0.8 }
local ARROWS = { "◀", "●", "▶" }
local WHITE = Color3.fromRGB(250, 248, 240)
local GOLD = Color3.fromRGB(255, 216, 103)
local INK = Color3.fromRGB(24, 19, 39)
local MISS = Color3.fromRGB(255, 110, 110)

local SceneChallenge = {}

local function laneAt(x: number): number
	return math.clamp(math.floor(x * 3) + 1, 1, 3)
end

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function isAction(input: InputObject): boolean
	return input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA
end

local function keyLane(input: InputObject): number?
	local key = input.KeyCode
	if key == Enum.KeyCode.Left or key == Enum.KeyCode.A or key == Enum.KeyCode.Q or key == Enum.KeyCode.DPadLeft then
		return 1
	elseif key == Enum.KeyCode.Up or key == Enum.KeyCode.W or key == Enum.KeyCode.Z or key == Enum.KeyCode.DPadUp then
		return 2
	elseif key == Enum.KeyCode.Right or key == Enum.KeyCode.D or key == Enum.KeyCode.DPadRight then
		return 3
	end
	return nil
end

local function controlKey(mechanic: string): string
	if mechanic == "trace" or mechanic == "balance" then
		return "Steer"
	elseif mechanic == "aim" or mechanic == "pan" then
		return "Aim"
	elseif mechanic == "hold" or mechanic == "catchLift" then
		return "Hold"
	elseif mechanic == "findPull" then
		return "FindPull"
	elseif mechanic == "findHold" then
		return "FindHold"
	elseif mechanic == "flick" then
		return "Flick"
	end
	return "Choose"
end

local function make(name: string, parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local spec = SceneGames.Games[name]
	assert(spec, `Unknown scene game: {name}`)
	local self = Kit.new(parent, interval, onRep, options)
	local rng = Random.new((options and options.seed) or math.floor(os.clock() * 1000))
	local panel = self:Panel(UDim2.fromOffset(410, 350))
	panel.Name = name
	local header = Ui.create("Frame", {
		Name = "Instruction",
		Position = UDim2.fromOffset(10, 9),
		Size = UDim2.new(1, -20, 0, 55),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.1,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	Ui.label({
		Position = UDim2.fromOffset(10, 2),
		Size = UDim2.new(1, -20, 0, 20),
		Text = Texts.Get(`Minigame.Title.{name}`),
		TextColor3 = spec.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 1,
		Parent = header,
	})
	local arena = Ui.create("Frame", {
		Name = "Scene",
		Position = UDim2.fromOffset(10, 70),
		Size = UDim2.new(1, -20, 1, -128),
		BackgroundColor3 = Color3.fromRGB(31, 27, 49),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 15)), Ui.stroke(spec.accent, 2, 0.5) })
	SceneArt.Build(arena, name, spec.accent)
	local prompt = Ui.label({
		Name = "Cue",
		Position = UDim2.fromOffset(10, 22),
		Size = UDim2.new(1, -20, 0, 31),
		Text = Texts.Get(`Minigame.Hint.{name}`),
		TextWrapped = true,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 1,
		Parent = header,
	})
	local glow = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromScale(0.7, 1.1),
		BackgroundColor3 = spec.accent,
		BackgroundTransparency = 0.88,
		Parent = arena,
	}, { Ui.corner(UDim.new(1, 0)) })
	Ui.create("Frame", {
		Position = UDim2.fromScale(0, 0.78),
		Size = UDim2.fromScale(1, 0.22),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.25,
		Parent = arena,
	})
	local objectShadow = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(106, 106),
		BackgroundColor3 = spec.accent,
		BackgroundTransparency = 0.63,
		Parent = arena,
	}, { Ui.corner(UDim.new(1, 0)) })
	local object = self:Emoji(arena, spec.icon, 98, 3)
	object.Position = UDim2.fromScale(0.5, 0.48)
	object.TextStrokeTransparency = 1
	local targetRing = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(72, 72),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = arena,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(GOLD, 5, 0) })
	local target = self:Emoji(arena, "✦", 48, 4)
	target.TextColor3 = GOLD
	local marker = self:Emoji(arena, "●", 40, 5)
	marker.TextColor3 = WHITE
	local laneLabels = {}
	for index, x in LANES do
		local tile = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(x, 0.97),
			Size = UDim2.fromScale(0.27, 0.2),
			BackgroundColor3 = Color3.fromRGB(64, 51, 82),
			Parent = arena,
		}, { Ui.corner(UDim.new(0, 11)), Ui.stroke(WHITE, 2, 0.72) })
		local label = self:Emoji(tile, ARROWS[index], 42, 4)
		label.Position = UDim2.fromScale(0.5, 0.5)
		laneLabels[index] = { tile = tile, label = label }
	end
	local meterTarget = if spec.mechanic == "findPull" then C.SwipeShort else spec.target or 0.68
	local meterBack = Ui.create("Frame", {
		Name = "ChargeTrack",
		Position = UDim2.fromScale(0.1, 0.72),
		Size = UDim2.fromScale(0.8, 0.045),
		BackgroundColor3 = INK,
		ZIndex = 3,
		Parent = arena,
	}, { Ui.corner(UDim.new(1, 0)) })
	local chargeZone = Ui.create("Frame", {
		Name = "GoodZone",
		Position = UDim2.fromScale(0.1 + (meterTarget - C.HoldGood * self.timingScale) * 0.8, 0.72),
		Size = UDim2.fromScale(C.HoldGood * 2 * self.timingScale * 0.8, 0.045),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0.45,
		ZIndex = 4,
		Parent = arena,
	}, { Ui.corner(UDim.new(1, 0)) })
	local progress = Ui.create("Frame", {
		Name = "Charge",
		Position = UDim2.fromScale(0.1, 0.72),
		Size = UDim2.fromScale(0, 0.045),
		BackgroundColor3 = spec.accent,
		ZIndex = 5,
		Parent = arena,
	}, { Ui.corner(UDim.new(1, 0)) })
	local chargeGoal = Ui.create("Frame", {
		Name = "ChargeGoal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.1 + meterTarget * 0.8, 0.742),
		Size = UDim2.fromScale(0.018, 0.1),
		BackgroundColor3 = WHITE,
		ZIndex = 6,
		Parent = arena,
	}, { Ui.corner(UDim.new(1, 0)) })
	local inputSurface = Ui.create("TextButton", {
		Name = "TouchArea",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		ZIndex = 10,
		Parent = arena,
	})
	local cycleTrack = Ui.create("Frame", {
		Name = "TimeTrack",
		Position = UDim2.new(0, 12, 1, -48),
		Size = UDim2.new(1, -24, 0, 6),
		BackgroundColor3 = INK,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })
	local cycleFill = Ui.create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = GOLD,
		Parent = cycleTrack,
	}, { Ui.corner(UDim.new(1, 0)) })
	local controls = Ui.label({
		Name = "Controls",
		Position = UDim2.new(0, 12, 1, -39),
		Size = UDim2.new(1, -24, 0, 30),
		Text = "",
		TextWrapped = true,
		TextColor3 = WHITE,
		TextStrokeTransparency = 1,
		Parent = panel,
	})
	local function updateControls(inputType: Enum.UserInputType)
		local platform = if inputType == Enum.UserInputType.Touch
			then "Touch"
			elseif string.find(inputType.Name, "Gamepad") then "Gamepad"
			else "Keyboard"
		controls.Text = Texts.Get(`Minigame.Control.{controlKey(spec.mechanic)}.{platform}`)
	end
	updateControls(UserInputService:GetLastInputType())
	self:Connect(UserInputService.LastInputTypeChanged, updateControls)

	local cycle = -1
	local choice = 2
	local goal = Vector2.new(0.5, 0.48)
	local cursor = Vector2.new(0.5, 0.48)
	local desired = cursor
	local held: InputObject? = nil
	local keyHeld = false
	local downAt = 0
	local downPoint = Vector2.zero
	local point = Vector2.zero
	local phase = 0
	local used = false
	local resolved = false
	local quality = "Miss"
	local errorSum = 0
	local sampled = 0
	local drift = 0
	local flashToken = 0

	local function relative(screen: Vector2): Vector2
		local size = arena.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return Vector2.new(0.5, 0.5)
		end
		local p = (screen - arena.AbsolutePosition) / size
		return Vector2.new(math.clamp(p.X, 0, 1), math.clamp(p.Y, 0, 1))
	end

	local function flash(result: string)
		flashToken += 1
		local token = flashToken
		local color = if result == "Miss" then MISS else spec.accent
		arena.BackgroundColor3 = color
		object.Text = if result == "Miss" then spec.icon else spec.success
		object.Size = UDim2.fromOffset(126, 126)
		TweenService:Create(object, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(98, 98),
		}):Play()
		if result ~= "Miss" then
			SoundController.Play("SceneImpact", if result == "Perfect" then 1.15 else 0.95)
		end
		task.delay(0.18, function()
			if token == flashToken and arena.Parent then
				arena.BackgroundColor3 = Color3.fromRGB(31, 27, 49)
			end
		end)
	end

	local function resolve(result: string)
		if resolved or self.auto then
			return
		end
		quality = result
		resolved = true
		flash(result)
		self:Rep(result)
	end

	local function reactionQuality(t: number): string
		return self:GradeError((t % interval) / interval, C.ChoicePerfectShare, C.ChoiceGoodShare)
	end

	local function selectLane(index: number, t: number)
		if spec.mechanic == "choice" then
			local wanted = if spec.variant == "pivot" then 4 - choice else choice
			resolve(if index == wanted then reactionQuality(t) else "Miss")
		elseif spec.mechanic == "flick" then
			local phaseTime = (t % interval) / interval
			local wanted = if choice == 1 then 1 else 3
			resolve(
				if index == wanted
					then self:GradeError(math.abs(phaseTime - C.FlickCenter), C.FlickPerfect, C.FlickGood)
					else "Miss"
			)
		elseif spec.mechanic == "findPull" or spec.mechanic == "findHold" then
			phase = if index == choice then 2 else -1
			if phase < 0 then
				resolve("Miss")
			else
				SoundController.Play("SceneTouch", 1)
				laneLabels[index].tile.BackgroundColor3 = spec.accent
			end
		end
	end

	local function begin(t: number, p: Vector2, keyboard: boolean)
		if resolved or self.auto then
			return
		end
		downAt = t
		downPoint = p
		point = p
		used = true
		local mechanic = spec.mechanic
		if mechanic == "flick" then
			selectLane(if p.X < 0.5 then 1 else 3, t)
		elseif mechanic == "choice" or mechanic == "findPull" or mechanic == "findHold" then
			selectLane(laneAt(p.X), t)
		elseif mechanic == "hold" or mechanic == "catchLift" then
			SoundController.Play("SceneTouch", 0.9)
		elseif mechanic == "trace" then
			desired = p
		end
		keyHeld = keyboard
	end

	local function finish(t: number)
		if resolved or self.auto then
			return
		end
		local mechanic = spec.mechanic
		local duration = math.max(0, t - downAt)
		if mechanic == "hold" or mechanic == "findHold" then
			if mechanic == "findHold" and phase ~= 2 then
				return
			end
			local targetCharge = spec.target or 0.68
			local measured = if spec.variant == "wave" then (t % interval) / interval else duration / interval
			resolve(
				if spec.variant == "wave" and duration / interval < C.SwipeShort
					then "Miss"
					else self:GradeError(math.abs(measured - targetCharge), C.HoldPerfect, C.HoldGood)
			)
		elseif mechanic == "catchLift" then
			local catchError = math.abs((downAt % interval) / interval - spec.target)
			local lift = duration / interval
			local grade = self:GradeError(catchError, C.HoldPerfect, C.HoldGood)
			resolve(if lift >= C.SwipeShort then grade else "Miss")
		elseif mechanic == "findPull" then
			if phase ~= 2 then
				return
			end
			local pull = duration / interval
			resolve(if pull >= C.SwipeShort then reactionQuality(downAt) else "Miss")
		elseif mechanic == "aim" or mechanic == "pan" then
			local scoredGoal = if spec.variant == "reverse" then Vector2.new(1 - goal.X, 1 - goal.Y) else goal
			local distance = if mechanic == "pan" then math.abs(cursor.X - goal.X) else (cursor - scoredGoal).Magnitude
			resolve(self:GradeError(distance, C.AimPerfect, C.AimGood))
		end
		keyHeld = false
	end

	local function nextCycle(index: number)
		if cycle >= 0 and not self.auto then
			if spec.mechanic == "trace" or spec.mechanic == "balance" then
				local average = if sampled > 0 and used then errorSum / sampled else 1
				quality = self:GradeError(average, C.TracePerfect, C.TraceGood)
				flash(quality)
				self:Rep(quality)
			elseif not resolved then
				flash("Miss")
				self:Rep("Miss")
			end
		end
		cycle = index
		choice = rng:NextInteger(1, 3)
		if spec.mechanic == "flick" or spec.variant == "pivot" then
			choice = if rng:NextInteger(1, 2) == 1 then 1 else 3
		end
		goal = Vector2.new(
			LANES[choice],
			if spec.mechanic == "aim" then ({ 0.34, 0.48, 0.62 })[rng:NextInteger(1, 3)] else 0.48
		)
		cursor = if spec.mechanic == "trace"
			then (if spec.axis == "Y" then Vector2.new(0.5, 0.78) else Vector2.new(0.2, LANES[choice] * 0.4 + 0.24))
			else Vector2.new(0.5, 0.48)
		desired = cursor
		phase = 0
		used = false
		resolved = false
		quality = "Miss"
		errorSum = 0
		sampled = 0
		drift = 0
		held = nil
		keyHeld = false
		for lane, info in laneLabels do
			info.tile.Position = UDim2.fromScale(
				if spec.mechanic == "flick" then (if lane == 1 then 0.25 else 0.75) else LANES[lane],
				0.97
			)
			info.tile.Size = UDim2.fromScale(if spec.mechanic == "flick" then 0.46 else 0.27, 0.2)
			local hiddenAnswer = spec.variant == "escape"
				or spec.variant == "pivot"
				or spec.variant == "bubble"
				or spec.variant == "leak"
				or spec.variant == "leg"
				or spec.variant == "weight"
			info.tile.BackgroundColor3 = if lane == choice and not hiddenAnswer
				then spec.accent
				else Color3.fromRGB(64, 51, 82)
			info.label.Text = if spec.variant == "escape"
				then ({ "🧊", "📺", "🛋️" })[lane]
				elseif spec.variant == "pivot" then (if lane == choice then "🚪" else ARROWS[lane])
				elseif spec.variant == "bubble" then (if lane == choice then "🫧" else "●")
				elseif spec.variant == "leak" then (if lane == choice then "💧" else "●")
				elseif spec.variant == "leg" then (if lane == choice then "〰" else "🦵")
				elseif spec.variant == "weight" then (if lane == choice
					then "🧱"
					elseif lane == 1 then "🥚"
					else "🍓")
				elseif spec.variant == "safeTile" then (if lane == choice then "✓" else "╳")
				elseif spec.mechanic == "flick" then (if lane == 1 then "↑" elseif lane == 3 then "⇈" else "•")
				else ARROWS[lane]
			info.tile.Visible = spec.mechanic == "choice"
				or spec.mechanic == "findPull"
				or spec.mechanic == "findHold"
				or (spec.mechanic == "flick" and lane ~= 2)
		end
		prompt.Text = Texts.Get(`Minigame.Hint.{name}`)
		object.Text = spec.icon
		object.Size = UDim2.fromOffset(98, 98)
		object.Position = UDim2.fromScale(0.5, 0.48)
		target.Visible = spec.mechanic ~= "hold" and spec.mechanic ~= "catchLift"
		targetRing.Visible = target.Visible
		marker.Visible = spec.mechanic == "trace"
			or spec.mechanic == "aim"
			or spec.mechanic == "pan"
			or spec.mechanic == "balance"
		progress.Visible = spec.mechanic == "hold"
			or spec.mechanic == "catchLift"
			or spec.mechanic == "findHold"
			or spec.mechanic == "findPull"
		meterBack.Visible = progress.Visible
		chargeZone.Visible = progress.Visible and spec.mechanic ~= "findPull"
		chargeGoal.Visible = progress.Visible
		if spec.mechanic == "flick" then
			target.Text = if choice == 3 then "⇈" else "↑"
		elseif spec.variant == "escape" then
			target.Text = ({ "🧊", "📺", "🛋️" })[choice]
		elseif spec.variant == "bubble" then
			target.Text = "🫧"
		elseif spec.variant == "leak" then
			target.Text = "💧"
		elseif spec.variant == "leg" then
			target.Text = "〰"
		elseif spec.variant == "weight" then
			target.Text = "🧱"
		elseif spec.variant == "pivot" then
			target.Text = "✓"
		elseif spec.variant == "hammer" then
			target.Text = "📌"
		elseif spec.variant == "reverse" then
			target.Text = "✦"
		elseif spec.variant == "shade" then
			target.Text = if choice == 1 then "🌴" else "☀️"
		elseif spec.variant == "mirror" then
			target.Text = "☀️"
		elseif spec.mechanic == "pan" then
			target.Text = "📍"
		else
			target.Text = if spec.mechanic == "choice"
					or spec.mechanic == "findPull"
					or spec.mechanic == "findHold"
				then ARROWS[choice]
				else "✦"
		end
		if
			spec.mechanic == "choice"
			or spec.mechanic == "findPull"
			or spec.mechanic == "findHold"
			or spec.mechanic == "flick"
		then
			goal = Vector2.new(LANES[choice], 0.45)
		end
		if
			spec.variant == "escape"
			or spec.variant == "bubble"
			or spec.variant == "leak"
			or spec.variant == "leg"
			or spec.variant == "weight"
		then
			goal = Vector2.new(0.5, 0.45)
		elseif spec.variant == "pivot" then
			goal = Vector2.new(LANES[4 - choice], 0.45)
		elseif spec.mechanic == "balance" then
			goal = Vector2.new(0.5, 0.48)
		end
		marker.Text = if spec.variant == "hammer"
			then "🔨"
			elseif spec.variant == "reverse" then "🪢"
			elseif spec.variant == "shade" then "🏖️"
			elseif spec.variant == "mirror" then "🪞"
			elseif spec.mechanic == "pan" then "🏙️"
			else "●"
	end

	self:Connect(inputSurface.InputBegan, function(input)
		if not isPointer(input) or held or self.auto then
			return
		end
		held = input
		local t = os.clock() - self.startTime
		begin(t, relative(Vector2.new(input.Position.X, input.Position.Y)), false)
	end)
	self:Connect(UserInputService.InputChanged, function(input)
		if
			held
			and (
				input == held
				or (
					held.UserInputType == Enum.UserInputType.MouseButton1
					and input.UserInputType == Enum.UserInputType.MouseMovement
				)
			)
		then
			point = relative(Vector2.new(input.Position.X, input.Position.Y))
			if spec.mechanic == "trace" then
				desired = point
			elseif spec.mechanic == "aim" or spec.mechanic == "pan" then
				desired = Vector2.new(0.5, 0.48) + point - downPoint
			end
		end
	end)
	self:Connect(UserInputService.InputEnded, function(input)
		if
			held
			and (
				input == held
				or (
					held.UserInputType == Enum.UserInputType.MouseButton1
					and input.UserInputType == Enum.UserInputType.MouseButton1
				)
			)
		then
			finish(os.clock() - self.startTime)
			held = nil
		end
	end)
	self:Connect(UserInputService.InputBegan, function(input)
		if UserInputService:GetFocusedTextBox() or self.auto or resolved then
			return
		end
		local t = os.clock() - self.startTime
		local lane = keyLane(input)
		if
			lane
			and (
				spec.mechanic == "choice"
				or spec.mechanic == "findPull"
				or spec.mechanic == "findHold"
				or spec.mechanic == "flick"
			)
		then
			if spec.mechanic ~= "flick" or lane ~= 2 then
				begin(t, Vector2.new(LANES[lane], 0.48), true)
			end
		elseif isAction(input) then
			if spec.mechanic == "hold" or spec.mechanic == "catchLift" then
				begin(t, cursor, true)
			elseif spec.mechanic == "aim" or spec.mechanic == "pan" then
				finish(t)
			end
		end
	end)
	self:Connect(UserInputService.InputEnded, function(input)
		if keyHeld and (isAction(input) or keyLane(input) ~= nil) then
			finish(os.clock() - self.startTime)
		end
	end)

	self:OnStep(function(dt, t)
		local index = math.floor(t / interval)
		if index > cycle then
			nextCycle(index)
		end
		local phaseTime = (t / interval) % 1
		cycleFill.Size = UDim2.fromScale(phaseTime, 1)
		if spec.mechanic == "trace" then
			local lane = LANES[choice]
			local wobble = if spec.variant == "resistance"
				then 0.08 * math.sin(phaseTime * math.pi * 3)
				else 0.06 * math.sin(phaseTime * math.pi * 2)
			goal = if spec.axis == "Y"
				then Vector2.new(0.5 + wobble, 0.78 - phaseTime * 0.55)
				else Vector2.new(0.2 + phaseTime * 0.6, lane * 0.4 + 0.24 + wobble)
			if self.auto then
				cursor = goal
			else
				local direction = self:HeldDirection()
				if direction.Magnitude > 0 then
					cursor += direction * C.KeyboardSpeed * dt
					used = true
				elseif held then
					local difference = desired - cursor
					local step = C.KeyboardSpeed * dt
					cursor += if difference.Magnitude > step then difference.Unit * step else difference
				end
				if held or direction.Magnitude > 0 then
					errorSum += (cursor - goal).Magnitude * dt
				else
					errorSum += dt
				end
				sampled += dt
			end
		elseif spec.mechanic == "balance" then
			local wind = math.sin(t * 2.4) * C.BalanceDrift * (if choice == 1 then -1 else 1)
			local direction = self:HeldDirection().X
			direction = if math.abs(direction) <= C.BalanceDeadzone then 0 else if direction < 0 then -1 else 1
			if held then
				direction = if point.X < C.BalanceTouchLeft then -1 elseif point.X > C.BalanceTouchRight then 1 else 0
			end
			if self.auto then
				cursor = Vector2.new(0.5, 0.48)
			else
				drift = math.clamp(drift + (wind + direction * C.BalanceControl) * dt, -0.45, 0.45)
				cursor = Vector2.new(0.5 + drift, 0.48)
				used = used or held ~= nil or direction ~= 0
				errorSum += math.abs(drift) * dt
				sampled += dt
			end
		elseif spec.mechanic == "aim" or spec.mechanic == "pan" then
			if spec.variant == "mirror" then
				goal = Vector2.new(LANES[choice] + 0.08 * math.sin(phaseTime * math.pi * 2), goal.Y)
			end
			local direction = self:HeldDirection()
			if direction.Magnitude > 0 then
				cursor += direction * C.KeyboardSpeed * dt
				used = true
			elseif held then
				local difference = desired - cursor
				local step = C.KeyboardSpeed * dt
				cursor += if difference.Magnitude > step then difference.Unit * step else difference
			end
		elseif
			spec.mechanic == "hold"
			or spec.mechanic == "catchLift"
			or spec.mechanic == "findHold"
			or spec.mechanic == "findPull"
		then
			local charging = held ~= nil or keyHeld
			local amount = if spec.variant == "wave" or spec.mechanic == "catchLift"
				then phaseTime
				else if charging then math.clamp((t - downAt) / interval, 0, 1) else 0
			progress.Size = UDim2.fromScale(amount * 0.8, 0.045)
			progress.BackgroundColor3 = if spec.mechanic == "findPull" and amount >= C.SwipeShort
				then GOLD
				elseif math.abs(amount - meterTarget) <= C.HoldGood * self.timingScale then GOLD
				else spec.accent
		end
		cursor = Vector2.new(
			math.clamp(cursor.X, C.MinTargetMargin, 1 - C.MinTargetMargin),
			math.clamp(cursor.Y, C.MinTargetMargin, 1 - C.MinTargetMargin)
		)
		local shownGoal = if spec.variant == "reverse" then Vector2.new(1 - goal.X, 1 - goal.Y) else goal
		target.Position = UDim2.fromScale(shownGoal.X, shownGoal.Y)
		targetRing.Position = target.Position
		glow.Position = UDim2.fromScale(goal.X, 0.48)
		marker.Position = UDim2.fromScale(cursor.X, cursor.Y)
		objectShadow.Position = object.Position
		if not resolved then
			if spec.mechanic == "trace" then
				object.Position = UDim2.fromScale(0.5 + (cursor.X - 0.5) * 0.3, 0.48 + (cursor.Y - 0.48) * 0.3)
			elseif spec.mechanic == "catchLift" then
				object.Position = UDim2.fromScale(0.5, 0.24 + phaseTime * 0.38)
			elseif spec.mechanic == "hold" then
				local compression = if held or keyHeld then math.clamp((t - downAt) / interval, 0, 1) else 0
				object.Position = UDim2.fromScale(0.5, 0.48 + compression * 0.1)
			elseif spec.mechanic == "aim" then
				object.Position = UDim2.fromScale(0.5 + (cursor.X - 0.5) * 0.12, 0.48 + (cursor.Y - 0.48) * 0.12)
			elseif spec.mechanic == "findPull" or spec.mechanic == "findHold" then
				object.Position = UDim2.fromScale(0.5, if phase > 0 then 0.39 else 0.48)
			end
		end
		object.Rotation = if spec.mechanic == "balance"
			then drift * 35
			elseif spec.mechanic == "flick" then phaseTime * 180
			elseif spec.variant == "wave" then math.sin(phaseTime * math.pi * 6) * 9
			elseif spec.mechanic == "trace" then math.sin(phaseTime * math.pi) * 10
			else 0
	end)

	return self
end

function SceneChallenge.For(name: string)
	return {
		new = function(parent: GuiObject, interval: number, onRep: (string) -> (), options)
			return make(name, parent, interval, onRep, options)
		end,
	}
end

return SceneChallenge
