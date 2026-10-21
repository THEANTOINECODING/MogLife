local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Activity = require(script.Parent.Activities.Playground)
local GuiService = game:GetService("GuiService")
local Shared = ReplicatedStorage.Shared
local Game = require(Shared.Playground)
local Config = require(Shared.Config.Playground)
local Art = require(Shared.Config.PlaygroundArt)
local Budget = require(Shared.Playground.Status)
local Common = require(Shared.Playground.Common)
local Texts = require(Shared.Config.Texts)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Kit = require(script.Parent.MinigameKit)
local View = require(script.Parent.PlaygroundView)
local Ui = require(script.Parent.Ui)
local Sound = require(script.Parent.Controllers.SoundController)
local Settings = require(script.Parent.Controllers.SettingsController)

local Client = {}

function Client.new(name, parent, interval, onRep, options)
	local self = Kit.new(parent, interval, onRep, options)
	options = options or {}
	local duel = name == "ReadRip"
	local theme = Art.Themes[Art.Groups[name] or "Gym"]
	local state = options.state or options.playground or (if not duel then Game.New(name, options.seed) else nil)
	local sequence, x, y, pressed, touch = 0, 0.5, 0.5, false, nil
	local elapsed, lastMove, lastPulse, lastMiss = 0, 0, 0, 0
	local pending = {}
	local celebrated = false
	local gridClock = 0
	if state and state.rules.size then
		x, y = Common.xy(if state.path then state.path[1] or 1 else 1, state.rules.size)
	end
	local arm = { stamina = 1, opponentStamina = 1, lean = 0, limit = 12, time = Config.Arm.Duration, held = false }
	local root = Ui.create("Frame", {
		Name = "Playground",
		BackgroundColor3 = Color3.fromRGB(17, 26, 42),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	self.root = root
	local panel = Ui.create("Frame", {
		Name = "GamePanel",
		BackgroundTransparency = 0.03,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, -8),
		Parent = root,
	}, {
		Ui.corner(UDim.new(0, 24)),
		Ui.gradient(Color3.fromRGB(57, 38, 87), Color3.fromRGB(22, 17, 39)),
		Ui.stroke(theme.accent, 2, 0.12),
	})
	local title = Ui.label({
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 0, 32),
		Text = Texts.Get("Playground." .. name .. ".Title"),
		TextColor3 = theme.accent,
		Parent = panel,
	})
	title.TextSize = 25
	local hint = Ui.label({
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24, 0, 44),
		Text = Texts.Get("Playground." .. name .. ".Hint"),
		Parent = panel,
	})
	hint.TextSize, hint.TextWrapped = 17, true
	local stage = Ui.create("ViewportFrame", {
		Name = "Stage",
		Position = UDim2.fromOffset(0, 82),
		BackgroundColor3 = theme.sky,
		Ambient = Color3.fromRGB(180, 195, 220),
		LightColor = Color3.fromRGB(255, 236, 205),
		LightDirection = Vector3.new(-1, -2, -3),
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 18)), Ui.stroke(theme.accent, 2, 0.5) })
	local camera = Instance.new("Camera")
	camera.FieldOfView = 2.864
	camera.CFrame = CFrame.new(0, 0, 200)
	camera.Parent = stage
	stage.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = stage
	local view = View.new(world, nil, nil, name)
	local inputZone = Ui.create("TextButton", {
		Name = "Input",
		Selectable = false,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Position = stage.Position,
		ZIndex = 5,
		Parent = panel,
	})
	local cursor = Ui.create("Frame", {
		Size = UDim2.fromOffset(14, 14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = inputZone,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.fromRGB(255, 255, 240), 2, 0.05) })
	local cue = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.15),
		Size = UDim2.fromScale(0.8, 0.12),
		Text = "",
		TextTransparency = 1,
		ZIndex = 8,
		Parent = inputZone,
	})
	local cueTween
	local status = Ui.label({ TextColor3 = Color3.fromRGB(128, 244, 190), Parent = panel })
	local budget = Ui.label({
		Name = "Budget",
		TextColor3 = theme.accent,
		TextWrapped = true,
		TextStrokeTransparency = 1,
		Parent = panel,
	})
	local mastery = Ui.label({
		Name = "Mastery",
		TextColor3 = Color3.fromRGB(218, 206, 239),
		TextStrokeTransparency = 1,
		Parent = panel,
	})
	local track = Ui.create(
		"Frame",
		{ Name = "Progress", BackgroundColor3 = Color3.fromRGB(15, 12, 27), BorderSizePixel = 0, Parent = panel },
		{ Ui.corner(UDim.new(1, 0)) }
	)
	local fill = Ui.create(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = theme.accent, BorderSizePixel = 0, Parent = track },
		{ Ui.corner(UDim.new(1, 0)) }
	)
	local undo = Ui.button({
		Name = "Undo",
		Text = Texts.Get("Playground.Undo"),
		BackgroundColor3 = Color3.fromRGB(82, 62, 116),
		Visible = name == "ParkingKnot" or name == "AirwayExpress",
		Parent = panel,
		ZIndex = 9,
	})
	local controls = Ui.label({
		Text = Texts.Get("Playground.Controls"),
		TextColor3 = Color3.fromRGB(174, 191, 212),
		Parent = panel,
	})
	controls.TextSize = 13
	controls.TextWrapped = true
	local function updateControls(inputType)
		local platform = if inputType == Enum.UserInputType.Touch
			then "Touch"
			elseif string.find(inputType.Name, "Gamepad") then "Gamepad"
			else "Keyboard"
		controls.Text = Texts.Get("Playground.Controls." .. platform)
	end
	updateControls(UserInputService:GetLastInputType())
	self:Connect(UserInputService.LastInputTypeChanged, updateControls)
	local function fit()
		local size = parent.AbsoluteSize
		local portrait = size.Y > size.X
		local compact = not portrait and size.Y < 540
		local side = math.max(
			100,
			math.min(
				560,
				if portrait then size.X - 40 elseif compact then size.X - 230 else size.X * 0.52 - 32,
				size.Y - (if compact then 100 else 290)
			)
		)
		panel.AnchorPoint = if portrait then Vector2.new(0.5, 1) else Vector2.new(1, 0.5)
		panel.Position = if portrait then UDim2.new(0.5, 0, 1, -70) else UDim2.new(1, -12, 0.5, -28)
		panel.Size = UDim2.fromOffset(side + (if compact then 192 else 24), if compact then side + 24 else side + 224)
		title.Position, title.Size =
			UDim2.fromOffset(12, 10), if compact then UDim2.fromOffset(158, 38) else UDim2.new(1, -24, 0, 32)
		hint.Position, hint.Size =
			UDim2.fromOffset(12, 50), if compact then UDim2.fromOffset(158, 64) else UDim2.new(1, -24, 0, 42)
		stage.Position = if compact then UDim2.fromOffset(180, 12) else UDim2.fromOffset(12, 106)
		stage.Size = UDim2.fromOffset(side, side)
		inputZone.Position, inputZone.Size = stage.Position, stage.Size
		budget.Position, budget.Size =
			if compact then UDim2.fromOffset(12, 120) else UDim2.fromOffset(12, side + 116),
			if compact then UDim2.fromOffset(158, 36) else UDim2.new(1, if undo.Visible then -126 else -24, 0, 28)
		undo.Position, undo.Size =
			if compact then UDim2.fromOffset(18, side - 40) else UDim2.new(1, -108, 0, side + 110),
			UDim2.fromOffset(96, 44)
		status.Position, status.Size =
			if compact then UDim2.fromOffset(12, 160) else UDim2.fromOffset(12, side + 148),
			if compact then UDim2.fromOffset(158, 26) else UDim2.new(1, -24, 0, 22)
		mastery.Position, mastery.Size =
			if compact then UDim2.fromOffset(12, 190) else UDim2.fromOffset(12, side + 174),
			if compact then UDim2.fromOffset(158, 24) else UDim2.new(1, -24, 0, 20)
		controls.Position, controls.Size =
			if compact then UDim2.fromOffset(12, 220) else UDim2.fromOffset(12, side + 198),
			if compact then UDim2.fromOffset(158, 32) else UDim2.new(1, -24, 0, 18)
		track.Position, track.Size =
			if compact then UDim2.fromOffset(180, side + 16) else UDim2.fromOffset(12, 97),
			if compact then UDim2.fromOffset(side, 4) else UDim2.new(1, -24, 0, 4)
	end
	fit()
	self:Connect(parent:GetPropertyChangedSignal("AbsoluteSize"), fit)
	local function send(kind)
		sequence += 1
		if options.token then
			Remotes.PlaygroundInput:FireServer(options.token, sequence, kind, x, y, workspace:GetServerTimeNow())
		end
		if state then
			if options.token and #pending < Config.InputRate then
				table.insert(pending, { sequence = sequence, kind = kind, x = x, y = y, time = state.t })
			end
			Game.Input(state, kind, x, y)
		end
	end
	self:Connect(undo.Activated, function()
		send("undo")
	end)
	local function position(input)
		local p = Vector2.new(input.Position.X, input.Position.Y)
		local rel = (p - inputZone.AbsolutePosition) / inputZone.AbsoluteSize
		x, y = math.clamp(rel.X, 0, 1), math.clamp(rel.Y, 0, 1)
	end
	local function release()
		if pressed then
			pressed = false
			send("up")
		end
		touch = nil
	end
	self:Connect(inputZone.InputBegan, function(input)
		if pressed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			if input.UserInputType == Enum.UserInputType.Touch then
				touch = input
			end
			position(input)
			pressed = true
			send("down")
		end
	end)
	self:Connect(UserInputService.InputBegan, function(input)
		if GuiService.MenuIsOpen or pressed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			pressed = true
			send("down")
		elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.ButtonX then
			send("undo")
		end
	end)
	self:Connect(UserInputService.InputChanged, function(input)
		if input == touch then
			position(input)
		elseif not touch and input.UserInputType == Enum.UserInputType.MouseMovement then
			local point = Vector2.new(input.Position.X, input.Position.Y) - inputZone.AbsolutePosition
			local size = inputZone.AbsoluteSize
			if pressed or (point.X >= 0 and point.Y >= 0 and point.X <= size.X and point.Y <= size.Y) then
				position(input)
			end
		end
	end)
	self:Connect(UserInputService.InputEnded, function(input)
		if
			input == touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			if input == touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				position(input)
			end
			release()
		end
	end)
	self:Connect(UserInputService.WindowFocusReleased, release)
	self:Connect(GuiService.MenuOpened, release)
	self:Connect(Remotes.PlaygroundState.OnClientEvent, function(update)
		if update.token ~= options.token then
			return
		end
		if update.state then
			local predictedTime = if state then state.t else update.state.t
			state = update.state
			while pending[1] and pending[1].sequence <= (update.sequence or sequence) do
				table.remove(pending, 1)
			end
			local limit = state.t + Config.PredictionLimit
			for _, action in pending do
				local ahead = math.max(0, math.min(action.time, limit) - state.t)
				while ahead > 0 do
					local step = math.min(ahead, Config.Step)
					Game.Step(state, step)
					ahead -= step
				end
				Game.Input(state, action.kind, action.x, action.y)
			end
			state.x, state.y = x, y
			local ahead = math.clamp(predictedTime - state.t, 0, Config.PredictionLimit)
			while ahead > 0 do
				local step = math.min(ahead, Config.Step)
				Game.Step(state, step)
				ahead -= step
			end
		end
		if update.duel then
			arm = update.duel
		end
	end)
	self:OnStep(function(dt)
		elapsed += dt
		local direction = self:HeldDirection()
		if direction.Magnitude > 0 then
			if state and state.rules.size then
				if elapsed >= gridClock then
					gridClock = elapsed + Config.GridRepeat
					local size = state.rules.size
					local cell = Common.cell(x, y, size)
					local col, row = (cell - 1) % size, math.floor((cell - 1) / size)
					if math.abs(direction.X) > math.abs(direction.Y) then
						col = math.clamp(col + math.sign(direction.X), 0, size - 1)
					else
						row = math.clamp(row + math.sign(direction.Y), 0, size - 1)
					end
					x, y = Common.xy(row * size + col + 1, size)
					send("move")
				end
			else
				x, y =
					math.clamp(x + direction.X * dt * Config.CursorSpeed, 0, 1),
					math.clamp(y + direction.Y * dt * Config.CursorSpeed, 0, 1)
			end
		else
			gridClock = elapsed
		end
		if elapsed - lastMove >= Config.InputInterval then
			lastMove = elapsed
			send("move")
		end
		cursor.Position = UDim2.fromScale(x, y)
		cursor.Visible = not duel
		if state then
			Game.Step(state, math.min(dt, 0.1))
			Activity.LocalState = state
			view:Draw(Game.Draw(state))
			if state.finished and state.won and not celebrated then
				celebrated = true
				Sound.Play("SceneImpact")
				if Settings.Get("ScreenFx") then
					for i = 1, 12 do
						local shard = Ui.create("Frame", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromOffset(7, 12),
							BackgroundColor3 = if i % 2 == 0 then theme.accent else Color3.fromRGB(130, 244, 190),
							BorderSizePixel = 0,
							Rotation = i * 31,
							ZIndex = 12,
							Parent = inputZone,
						})
						TweenService
							:Create(shard, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								Position = UDim2.fromScale(
									0.5 + math.cos(i * 2.4) * 0.43,
									0.5 + math.sin(i * 2.4) * 0.36
								),
								Rotation = i * 61,
								BackgroundTransparency = 1,
							})
							:Play()
						task.delay(0.7, function()
							shard:Destroy()
						end)
					end
				end
			end
			if state.pulse > lastPulse then
				local missed = state.misses > lastMiss
				local feedback = state.feedback or (if missed then "Miss" else "Good")
				cue.Text = Texts.Get("Playground.Feedback." .. feedback)
				cue.TextColor3 = if missed
					then Color3.fromRGB(255, 120, 125)
					elseif feedback == "Perfect" then theme.accent
					else Color3.fromRGB(128, 244, 190)
				if cueTween then
					cueTween:Cancel()
				end
				cue.TextTransparency = 0
				cueTween = TweenService:Create(
					cue,
					TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.25),
					{ TextTransparency = 1 }
				)
				cueTween:Play()
				if missed or feedback == "Good" or feedback == "Perfect" then
					Sound.Play(if missed then "RepMiss" elseif feedback == "Perfect" then "RepPerfect" else "RepGood")
				end
				lastPulse, lastMiss = state.pulse, state.misses
			end
			local key = if state.t < 0
				then "Ready"
				elseif state.finished then (if state.won then "Won" else "Practice")
				else "Progress"
			status.Text = Texts.Get("Playground." .. key, {
				time = Format.Short(math.ceil(math.max(0, Config.Games[name].duration - state.t))),
				score = Format.Short(math.floor(Game.Completion(state) * 100)),
				count = Format.Short(math.ceil(-state.t)),
			})
			local budgetKey, args = Budget(state)
			for k, v in args do
				args[k] = Format.Short(v)
			end
			budget.Text = Texts.Get("Playground.Budget." .. budgetKey, args)
			if state.notice then
				budget.Text = Texts.Get("Playground.Feedback." .. state.notice)
			end
			mastery.Text = Texts.Get("Playground.Mastery", {
				accuracy = Format.Short(Game.Accuracy(state)),
				streak = Format.Short(state.streak or 0),
				bonus = Format.Short((Game.Combo(state) - 1) * 100),
			})
			fill.Size = UDim2.fromScale(Game.Completion(state), 1)
		else
			local nodes = {
				{ id = "table", x = 0.5, y = 0.65, w = 0.88, h = 0.12, style = "wood", angle = 0 },
				{
					id = "you",
					x = 0.26,
					y = 0.49,
					w = 0.18,
					h = 0.36,
					style = "athlete",
					angle = -arm.lean / arm.limit * 30,
				},
				{
					id = "them",
					x = 0.74,
					y = 0.49,
					w = 0.18,
					h = 0.36,
					style = "rival",
					angle = -arm.lean / arm.limit * 30,
				},
				{
					id = "grip",
					x = 0.5 + arm.lean / arm.limit * 0.22,
					y = 0.45,
					w = 0.13,
					h = 0.13,
					style = "gold",
					angle = -arm.lean / arm.limit * 60,
				},
				{
					id = "stamina",
					x = 0.26,
					y = 0.81,
					w = 0.32 * math.max(0.02, arm.stamina),
					h = 0.045,
					style = "goal",
					angle = 0,
				},
				{
					id = "opponent",
					x = 0.74,
					y = 0.81,
					w = 0.32 * math.max(0.02, arm.opponentStamina),
					h = 0.045,
					style = "danger",
					angle = 0,
				},
			}
			view:Draw(nodes)
			status.Text = Texts.Get("Playground.Arm", {
				stamina = Format.Short(arm.stamina * 100),
				opponent = Format.Short(arm.opponentStamina * 100),
				time = Format.Short(math.ceil(arm.time)),
			})
			budget.Text = Texts.Get(
				if arm.exhausted
					then "Playground.Exhausted"
					elseif arm.opponentExhausted then "Playground.Attack"
					elseif arm.held then "Playground.Pushing"
					else "Playground.Recovering"
			)
			mastery.Text = Texts.Get("Playground.DuelGoal")
			fill.Size = UDim2.fromScale(math.clamp(0.5 + arm.lean / arm.limit * 0.5, 0, 1), 1)
		end
	end)
	local destroy = self.Destroy
	self.Destroy = function()
		Activity.LocalState = nil
		if cueTween then
			cueTween:Cancel()
		end
		release()
		view:Destroy()
		destroy(self)
	end
	send("ready")
	return self
end

return Client
