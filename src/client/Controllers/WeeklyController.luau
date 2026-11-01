-- Récompenses de la semaine côté client (D67, D96) : la fenêtre s'ouvre d'elle-même à chaque arrivée dans le jeu
-- (une fois le joueur libre : pas pendant le tutoriel, le créateur de personnage ou une scène) : les 3 défis de la
-- semaine (progression, Cash, bouton Réclamer), le bonus des 3 défis (trophée), le coffre de la semaine (7 jours) et
-- le compte à rebours jusqu'aux prochains défis. Plus de bouton dans le menu.
-- Le serveur décide de tout (WeeklyService) ; le client n'envoie que « réclamer ».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local WEEKLY_UI = Balance.WeeklyWindow
local GOLD = Color3.fromRGB(255, 210, 60)
local GREEN = Color3.fromRGB(60, 170, 80)
local DIM = Color3.fromRGB(90, 90, 100)
local ROW = Color3.fromRGB(40, 35, 55)

local player = Players.LocalPlayer

local UIController
local MinigameController
local CreatorController
local CutsceneController

type Row = { frame: Frame, label: TextLabel, fill: Frame, count: TextLabel, button: TextButton }

local state: any = nil
local receivedAt = 0
local panel: Frame
local timerLabel: TextLabel
local rows: { Row } = {}
local bonusLabel: TextLabel
local bonusButton: TextButton
local dayCells: { Frame } = {}
local chestLabel: TextLabel
local chestButton: TextButton
local footerLabel: TextLabel

local WeeklyController = {}
local shownOnArrival = false
local tutorialActive = false

local function layoutWeekly()
	panel.Size = if Ui.isPhonePortrait() then UDim2.new(1, -20, 0, 560) else UDim2.fromOffset(520, 560)
end

local function setButton(button: TextButton, text: string, enabled: boolean, color: Color3)
	button.Text = text
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then color else DIM
end

-- Temps restant jusqu'aux prochains défis, d'après l'heure du serveur reçue avec l'état
local function remainingText(): string
	if not state then
		return ""
	end
	local now = state.now + (os.clock() - receivedAt)
	local seconds = math.max(state.endsAt - now, 0)
	local days = seconds // 86_400
	local hours = (seconds % 86_400) // 3_600
	local minutes = (seconds % 3_600) // 60
	local time = if days > 0
		then Texts.Get("Weekly.TimeDays", { days = days, hours = hours })
		else Texts.Get("Weekly.TimeHours", { hours = hours, minutes = minutes })
	return Texts.Get("Weekly.ResetsIn", { time = time })
end

local function render()
	if not state then
		return
	end
	timerLabel.Text = remainingText()
	for index, row in rows do
		local challenge = state.challenges[index]
		row.frame.Visible = challenge ~= nil
		if challenge then
			row.label.Text = Texts.Get(`Weekly.Challenge.{challenge.id}`, { target = challenge.target })
			row.fill.Size = UDim2.fromScale(math.clamp(challenge.progress / challenge.target, 0, 1), 1)
			row.fill.BackgroundColor3 = if challenge.progress >= challenge.target then GREEN else GOLD
			row.count.Text = Texts.Get("Weekly.Progress", { progress = challenge.progress, target = challenge.target })
			if challenge.claimed then
				setButton(row.button, Texts.Get("Weekly.Claimed"), false, GREEN)
			else
				local done = challenge.progress >= challenge.target
				setButton(row.button, Texts.Get("Weekly.Claim", { cash = Format.Short(challenge.cash) }), done, GREEN)
			end
		end
	end
	bonusLabel.Text = Texts.Get("Weekly.Bonus", { cash = Format.Short(state.bonus.cash) })
	if state.bonus.claimed then
		setButton(bonusButton, Texts.Get("Weekly.Claimed"), false, GOLD)
	else
		setButton(bonusButton, Texts.Get("Weekly.BonusClaim"), state.bonus.ready, GOLD)
	end
	local chest = state.chest
	for day, cell in dayCells do
		local done = chest.days[day] == true
		cell.BackgroundColor3 = if done then GREEN elseif day == state.day then Color3.fromRGB(80, 70, 110) else ROW
		local mark = cell:FindFirstChild("Mark") :: TextLabel
		mark.Text = if done then "✔" else Texts.Get(`Weekly.Day{day}`)
	end
	chestLabel.Text = if chest.todayDone
		then Texts.Get("Weekly.ChestToday", { days = chest.stamps })
		else Texts.Get("Weekly.ChestHint", { minutes = chest.minutes, days = chest.stamps })
	if chest.opened then
		setButton(chestButton, Texts.Get("Weekly.ChestOpened"), false, GOLD)
	elseif chest.canOpen then
		setButton(chestButton, Texts.Get("Weekly.ChestOpen", { cash = Format.Short(chest.cash) }), true, GOLD)
	else
		setButton(chestButton, Texts.Get("Weekly.ChestSunday"), false, GOLD)
	end
	footerLabel.Text = Texts.Get("Weekly.Footer", {
		trophies = state.trophies,
		wins = state.duels.wins,
		losses = state.duels.losses,
		draws = state.duels.draws,
	})
end

local function setOpen(open: boolean)
	panel.Visible = open
	UIController.SetStatsHidden(open, "Weekly")
	MinigameController.SetGameplayLocked(open, "Weekly")
	if open then
		render()
		panel.Position = UDim2.fromScale(0.5, 0.56)
		TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.52),
		}):Play()
	end
end

local function claimButton(parent: GuiObject, onClick: () -> ()): TextButton
	local button = Ui.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(150, 46),
		BackgroundColor3 = DIM,
		Parent = parent,
	})
	button.Activated:Connect(function()
		if button.Active then
			onClick()
		end
	end)
	return button
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "Weekly", ResetOnSpawn = false, DisplayOrder = 1 })

	panel = Ui.panel({
		Name = "WeeklyPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(520, 560),
		Visible = false,
		Parent = gui,
	})
	Ui.create("UISizeConstraint", { MaxSize = Vector2.new(520, 560), Parent = panel })
	-- Téléphone en paysage : la fenêtre rapetisse pour tenir dans la hauteur de l'écran
	local scale = Ui.create("UIScale", { Parent = panel })
	local function fit()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 720
		scale.Scale = math.clamp((height - 60) / 560, 0.55, 1)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	Ui.label({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 40),
		TextColor3 = GOLD,
		Text = Texts.Get("Weekly.Title"),
		Parent = panel,
	})
	timerLabel = Ui.label({
		Position = UDim2.fromOffset(16, 50),
		Size = UDim2.new(1, -32, 0, 22),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(210, 210, 225),
		Parent = panel,
	})

	-- Les 3 défis
	for index = 1, 3 do
		local frame = Ui.create("Frame", {
			Position = UDim2.fromOffset(16, 80 + (index - 1) * 72),
			Size = UDim2.new(1, -32, 0, 64),
			BackgroundColor3 = ROW,
			BackgroundTransparency = 0.15,
			Parent = panel,
		}, { Ui.corner(UDim.new(0, 10)) })
		local label = Ui.label({
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -184, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local bar = Ui.create("Frame", {
			Position = UDim2.fromOffset(12, 40),
			Size = UDim2.new(1, -250, 0, 14),
			BackgroundColor3 = Color3.fromRGB(25, 20, 35),
			Parent = frame,
		}, { Ui.corner(UDim.new(1, 0)) })
		local fill = Ui.create("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = GOLD,
			Parent = bar,
		}, { Ui.corner(UDim.new(1, 0)) })
		local count = Ui.label({
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(1, -232, 0, 47),
			Size = UDim2.fromOffset(60, 20),
			Font = Enum.Font.GothamMedium,
			Parent = frame,
		})
		local button = claimButton(frame, function()
			Remotes.WeeklyClaim:FireServer("Challenge", index)
		end)
		rows[index] = { frame = frame, label = label, fill = fill, count = count, button = button }
	end

	-- Bonus des 3 défis : trophée + Cash
	local bonus = Ui.create("Frame", {
		Position = UDim2.fromOffset(16, 300),
		Size = UDim2.new(1, -32, 0, 60),
		BackgroundColor3 = Color3.fromRGB(70, 55, 20),
		BackgroundTransparency = 0.1,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 10)), Ui.stroke(GOLD, 2, 0.3) })
	bonusLabel = Ui.label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -184, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = bonus,
	})
	bonusButton = claimButton(bonus, function()
		Remotes.WeeklyClaim:FireServer("Bonus")
	end)

	-- Coffre de la semaine : 7 cases (lundi -> dimanche)
	local chest = Ui.create("Frame", {
		Position = UDim2.fromOffset(16, 370),
		Size = UDim2.new(1, -32, 0, 112),
		BackgroundColor3 = ROW,
		BackgroundTransparency = 0.15,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 10)) })
	local days = Ui.create("Frame", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -184, 0, 44),
		BackgroundTransparency = 1,
		Parent = chest,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for day = 1, 7 do
		local cell = Ui.create("Frame", {
			Size = UDim2.new(1 / 7, -5, 1, 0),
			BackgroundColor3 = ROW,
			LayoutOrder = day,
			Parent = days,
		}, { Ui.corner(UDim.new(0, 8)), Ui.stroke(Color3.new(1, 1, 1), 1, 0.6) })
		Ui.label({
			Name = "Mark",
			Position = UDim2.fromScale(0.1, 0.15),
			Size = UDim2.fromScale(0.8, 0.7),
			Parent = cell,
		})
		dayCells[day] = cell
	end
	chestLabel = Ui.label({
		Position = UDim2.fromOffset(12, 58),
		Size = UDim2.new(1, -184, 0, 46),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(215, 215, 230),
		Parent = chest,
	})
	chestButton = claimButton(chest, function()
		Remotes.WeeklyClaim:FireServer("Chest")
	end)

	footerLabel = Ui.label({
		Position = UDim2.fromOffset(16, 488),
		Size = UDim2.new(1, -220, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamMedium,
		Parent = panel,
	})
	local close = Ui.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -12),
		Size = UDim2.fromOffset(170, 48),
		BackgroundColor3 = Color3.fromRGB(90, 90, 90),
		Text = Texts.Get("Shop.Close"),
		Parent = panel,
	})
	close.Activated:Connect(function()
		setOpen(false)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	Ui.watchViewport(layoutWeekly)
end

-- Ouverture du coffre (D84) : il tombe, tremble trois fois, éclate (rayons, pièces), affiche le gain, puis les
-- billets s'envolent vers le compteur de Cash. Un toucher passe la scène.
local function chestScene(cash: number)
	local gui = Ui.create("ScreenGui", { Name = "ChestScene", ResetOnSpawn = false, DisplayOrder = 25 })
	local shade = Ui.create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = gui,
	})
	local rays = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(320, 320),
		Text = "✴️",
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = gui,
	})
	local chest = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, -0.2),
		Size = UDim2.fromOffset(150, 150),
		Text = "🎁",
		TextStrokeTransparency = 1,
		ZIndex = 3,
		Parent = gui,
	})
	local amount = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromOffset(420, 70),
		Text = Texts.Get("Weekly.ChestBurst", { cash = Format.Short(cash) }),
		TextColor3 = GOLD,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 4,
		Parent = gui,
	})
	gui.Parent = player:WaitForChild("PlayerGui")
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		gui:Destroy()
		UIController.FlyToCounter("Cash", 10)
	end
	shade.Activated:Connect(finish)
	task.spawn(function()
		TweenService:Create(shade, TweenInfo.new(0.3), { BackgroundTransparency = 0.45 }):Play()
		local drop = TweenService:Create(chest, TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.45),
		})
		drop:Play()
		drop.Completed:Wait()
		-- Il tremble trois fois, de plus en plus fort
		for shake = 1, 3 do
			for _, angle in { -8 * shake, 8 * shake, 0 } do
				chest.Rotation = angle
				task.wait(0.05)
			end
			task.wait(0.18)
		end
		if finished then
			return
		end
		-- Il éclate
		chest.Text = "💰"
		chest.Size = UDim2.fromOffset(190, 190)
		TweenService:Create(chest, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(150, 150) })
			:Play()
		rays.TextTransparency = 0.2
		TweenService:Create(rays, TweenInfo.new(2.5, Enum.EasingStyle.Linear), { Rotation = 180 }):Play()
		TweenService:Create(amount, TweenInfo.new(0.3), { TextTransparency = 0, TextStrokeTransparency = 0.2 }):Play()
		for index = 1, 12 do
			local coin = Ui.label({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				Size = UDim2.fromOffset(44, 44),
				Text = if index % 2 == 0 then "🪙" else "💵",
				TextStrokeTransparency = 1,
				ZIndex = 2,
				Parent = gui,
			})
			local angle = index / 12 * 2 * math.pi
			TweenService:Create(coin, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, math.cos(angle) * 220, 0.45, math.sin(angle) * 160),
				Rotation = 360,
				TextTransparency = 1,
			}):Play()
		end
		task.wait(2)
		finish()
	end)
end

function WeeklyController.Init(controllers)
	UIController = controllers.UIController
	MinigameController = controllers.MinigameController
	CreatorController = controllers.CreatorController
	CutsceneController = controllers.CutsceneController
end

-- À l'arrivée dans le jeu : la fenêtre s'ouvre dès que le joueur est libre (personnage là, rien d'autre à l'écran),
-- après un court instant pour voir la ville. Pas pendant le tutoriel (trop de choses d'un coup pour un nouveau).
local function openOnArrival()
	local freeSince: number? = nil
	local started = os.clock()
	while os.clock() - started < WEEKLY_UI.ArrivalGiveUp do
		task.wait(0.25)
		local character = player.Character
		local free = state ~= nil
			and not tutorialActive
			and character ~= nil
			and character:FindFirstChild("HumanoidRootPart") ~= nil
			and not CreatorController.IsOpen()
			and not CutsceneController.IsPlaying()
			and not MinigameController.IsGameplayLocked()
		if not free then
			freeSince = nil
		elseif not freeSince then
			freeSince = os.clock()
		elseif os.clock() - freeSince >= WEEKLY_UI.ArrivalDelay then
			setOpen(true)
			return
		end
	end
end

function WeeklyController.Start()
	buildGui()
	Remotes.Tutorial.OnClientEvent:Connect(function(tutorial)
		tutorialActive = tutorial ~= nil and not tutorial.done
	end)
	Remotes.WeeklyState.OnClientEvent:Connect(function(newState)
		if typeof(newState) ~= "table" then
			return
		end
		local wasOpened = state and state.chest and state.chest.opened
		state = newState
		receivedAt = os.clock()
		render()
		if not shownOnArrival then
			shownOnArrival = true
			task.spawn(openOnArrival)
		end
		-- Le coffre vient d'être ouvert : la scène d'ouverture
		if state.chest and state.chest.opened and wasOpened == false then
			chestScene(state.chest.cash or 0)
		end
	end)
	-- Compte à rebours
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.Visible then
				timerLabel.Text = remainingText()
			end
		end
	end)
end

return WeeklyController
