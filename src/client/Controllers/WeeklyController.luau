-- Récompenses de la semaine côté client (D67, D96, fenêtre « miniature YouTube » en D103) : la fenêtre s'ouvre d'elle-même à chaque arrivée dans le jeu
-- (une fois le joueur libre : pas pendant le tutoriel, le créateur de personnage ou une scène) : les 3 défis de la
-- semaine (progression, Cash, bouton Réclamer), le bonus des 3 défis (trophée), le coffre de la semaine (7 jours) et
-- le compte à rebours jusqu'aux prochains défis. Case « Rewards » dans le menu (D124), avec une pastille rouge quand
-- une récompense attend.
-- Le serveur décide de tout (WeeklyService) ; le client n'envoie que « réclamer ».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

type Row = {
	frame: Frame,
	icon: TextLabel,
	label: TextLabel,
	fill: Frame,
	count: TextLabel,
	button: TextButton,
}

local state: any = nil
local receivedAt = 0
local gui: ScreenGui
local panel: Frame
local panelScale: UIScale
local rays: Frame
local titleLabel: TextLabel
local titleScale: UIScale
local timerLabel: TextLabel
local upToLabel: TextLabel
local goButton: TextButton
local goScale: UIScale
local stickers: { TextLabel } = {}
local header: Frame
local list: ScrollingFrame
local rows: { Row } = {}
local bonusLabel: TextLabel
local bonusButton: TextButton
local dayCells: { Frame } = {}
local chestLabel: TextLabel
local chestButton: TextButton
local footerLabel: TextLabel
local pulsing: { [TextButton]: UIScale } = {} -- boutons « réclamer » prêts : ils battent
local animation: RBXScriptConnection? = nil

local WeeklyController = {}
local shownOnArrival = false
local tutorialActive = false

-- Fenêtre « miniature YouTube » (D103) : rayons jaunes qui tournent, gros titre jaune cerné de noir, autocollants,
-- gain total en énorme, défis en cartes, gros bouton rouge. Taille calculée sur la place réelle de l'écran ;
-- téléphone en paysage (peu de hauteur) : en-tête compact, la liste défile.
local MAX_WIDTH, MAX_HEIGHT = 560, 660
local function layoutWeekly()
	local area = gui.AbsoluteSize
	if area.X < 1 then
		return
	end
	local width = math.min(MAX_WIDTH, area.X - 20)
	local height = math.min(MAX_HEIGHT, area.Y - 16)
	panel.Size = UDim2.fromOffset(width, height)
	local compact = height < 470
	local headerHeight = if compact then 58 else 136
	header.Size = UDim2.new(1, 0, 0, headerHeight)
	titleLabel.AnchorPoint = if compact then Vector2.zero else Vector2.new(0.5, 0)
	titleLabel.Position = if compact then UDim2.fromOffset(14, 6) else UDim2.new(0.5, 0, 0, 12)
	titleLabel.Size = if compact then UDim2.new(0.5, -14, 0, 46) else UDim2.new(0.7, 0, 0, 58)
	upToLabel.AnchorPoint = if compact then Vector2.zero else Vector2.new(0.5, 0)
	upToLabel.Position = if compact then UDim2.new(0.5, 4, 0, 6) else UDim2.new(0.5, 0, 0, 74)
	upToLabel.Size = if compact then UDim2.new(0.5, -18, 0, 24) else UDim2.new(0.86, 0, 0, 30)
	timerLabel.AnchorPoint = if compact then Vector2.zero else Vector2.new(0.5, 0)
	timerLabel.Position = if compact then UDim2.new(0.5, 4, 0, 33) else UDim2.new(0.5, 0, 0, 108)
	timerLabel.Size = if compact then UDim2.new(0.5, -18, 0, 20) else UDim2.new(0.66, 0, 0, 22)
	for _, sticker in stickers do
		sticker.Visible = not compact
	end
	local goHeight = if compact then 44 else 56
	goButton.Size = UDim2.new(0.62, 0, 0, goHeight)
	list.Position = UDim2.fromOffset(0, headerHeight + 4)
	list.Size = UDim2.new(1, 0, 1, -(headerHeight + goHeight + 26))
end

local function setButton(button: TextButton, text: string, enabled: boolean, color: Color3)
	button.Text = text
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then color else DIM
	local scale = button:FindFirstChildOfClass("UIScale")
	pulsing[button] = if enabled then scale else nil
	if scale and not enabled then
		scale.Scale = 1
	end
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

-- Tout ce qu'il reste à gagner cette semaine (défis, trophée, coffre) : le gros chiffre de l'en-tête
local function cashLeft(): number
	local total = 0
	for _, challenge in state.challenges do
		if not challenge.claimed then
			total += challenge.cash
		end
	end
	if not state.bonus.claimed then
		total += state.bonus.cash
	end
	if state.chest and not state.chest.opened then
		total += state.chest.cash or 0
	end
	return total
end

local function render()
	if not state then
		return
	end
	timerLabel.Text = remainingText()
	upToLabel.Text = Texts.Get("Weekly.UpTo", { cash = Format.Short(cashLeft()) })
	for index, row in rows do
		local challenge = state.challenges[index]
		row.frame.Visible = challenge ~= nil
		if challenge then
			row.icon.Text = Texts.Get(`Weekly.Icon.{challenge.id}`)
			row.label.Text = Texts.Get(`Weekly.Challenge.{challenge.id}`, { target = challenge.target })
			row.fill.Size = UDim2.fromScale(math.clamp(challenge.progress / challenge.target, 0, 1), 1)
			row.fill.BackgroundColor3 = if challenge.progress >= challenge.target then GREEN else GOLD
			row.count.Text = Texts.Get("Weekly.Progress", { progress = challenge.progress, target = challenge.target })
			if challenge.claimed then
				setButton(row.button, Texts.Get("Weekly.Claimed"), false, GREEN)
			else
				local done = challenge.progress >= challenge.target
				local key = if done then "Weekly.Claim" else "Weekly.Reward"
				setButton(row.button, Texts.Get(key, { cash = Format.Short(challenge.cash) }), done, GREEN)
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

-- Ce qui bouge pendant que la fenêtre est ouverte : rayons, titre et boutons qui battent, autocollants qui se
-- dandinent (Heartbeat : continue même si l'image n'est pas redessinée)
local function animate()
	if animation then
		return
	end
	local t0 = os.clock()
	animation = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - t0
		rays.Rotation = (t * WEEKLY_UI.RaySpeed) % 360
		-- le titre claque à l'arrivée (grossi), puis respire
		local breathe = 1 + math.sin(t * 4) * 0.035
		titleScale.Scale = breathe + (titleScale.Scale - breathe) * math.max(1 - dt * 10, 0)
		goScale.Scale = 1 + math.max(math.sin(t * 5), 0) * 0.06
		for index, sticker in stickers do
			sticker.Rotation = (sticker:GetAttribute("Tilt") :: number) + math.sin(t * 3 + index * 2) * 6
		end
		for _, scale in pulsing do
			scale.Scale = 1 + math.max(math.sin(t * 6), 0) * 0.07
		end
	end)
end

local function setOpen(open: boolean)
	panel.Visible = open
	UIController.SetStatsHidden(open, "Weekly")
	MinigameController.SetGameplayLocked(open, "Weekly")
	if open then
		layoutWeekly()
		render()
		list.CanvasPosition = Vector2.zero
		animate()
		-- Entrée : la carte jaillit en tournant un peu, le titre claque juste après
		panelScale.Scale = 0.4
		panel.Rotation = -8
		TweenService:Create(panelScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		TweenService:Create(panel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Rotation = 0,
		}):Play()
		titleLabel.Visible = false
		task.delay(0.3, function()
			titleLabel.Visible = true
			titleScale.Scale = 1.7
		end)
	elseif animation then
		animation:Disconnect()
		animation = nil
	end
end

-- Texte « miniature » : gros contour noir
local function shout(props: { [string]: any }, stroke: number?): TextLabel
	local label = Ui.label(props)
	label.TextStrokeTransparency = 1
	Ui.create("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = stroke or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = label,
	})
	return label
end

local function claimButton(parent: GuiObject, onClick: () -> ()): TextButton
	local button = Ui.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.3, 0, 0, 46),
		BackgroundColor3 = DIM,
		Parent = parent,
	})
	Ui.create("UIScale", { Parent = button })
	Ui.stroke(Color3.new(0, 0, 0), 2, 0.3).Parent = button
	button.Activated:Connect(function()
		if button.Active then
			onClick()
		end
	end)
	return button
end

-- Carte d'une ligne de la liste : icône ronde à gauche, contenu au milieu, bouton à droite
local function card(order: number, height: number, color: Color3, iconText: string?): (Frame, TextLabel)
	local frame = Ui.create("Frame", {
		Size = UDim2.new(1, -20, 0, height),
		BackgroundColor3 = color,
		LayoutOrder = order,
		Parent = list,
	}, { Ui.corner(UDim.new(0, 12)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.75) })
	local icon = Ui.label({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		BackgroundTransparency = 0.6,
		BackgroundColor3 = Color3.new(0, 0, 0),
		Text = iconText or "",
		TextStrokeTransparency = 1,
		Parent = frame,
	})
	Ui.corner(UDim.new(1, 0)).Parent = icon
	Ui.create("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = icon,
	})
	return frame, icon
end

local function buildGui()
	gui = Ui.create("ScreenGui", { Name = "Weekly", ResetOnSpawn = false, DisplayOrder = 1 })

	panel = Ui.create("Frame", {
		Name = "WeeklyPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(MAX_WIDTH, MAX_HEIGHT),
		BackgroundColor3 = Color3.fromRGB(30, 18, 50),
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(UDim.new(0, 20)),
		Ui.create("UIStroke", { Color = Color3.fromRGB(255, 230, 0), Thickness = 4 }),
	})
	panelScale = Ui.create("UIScale", { Parent = panel })

	-- Fond : rayons jaunes qui tournent derrière tout (CanvasGroup : ils restent dans les coins ronds)
	local back = Ui.create("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = panel,
	}, {
		Ui.corner(UDim.new(0, 20)),
		Ui.gradient(Color3.fromRGB(120, 40, 170), Color3.fromRGB(20, 10, 35)),
	})
	rays = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromOffset(1500, 1500),
		BackgroundTransparency = 1,
		Parent = back,
	})
	for index = 0, 11 do
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, 120),
			Rotation = index * 15,
			BackgroundColor3 = Color3.fromRGB(255, 220, 40),
			BackgroundTransparency = 0.84,
			BorderSizePixel = 0,
			Parent = rays,
		})
	end

	-- En-tête : titre, gain total, compte à rebours, autocollants
	header = Ui.create("Frame", { BackgroundTransparency = 1, Parent = panel })
	titleLabel = shout({
		Text = Texts.Get("Weekly.Headline"),
		TextColor3 = Color3.fromRGB(255, 230, 0),
		Rotation = -3,
		Parent = header,
	}, 4)
	titleScale = Ui.create("UIScale", { Parent = titleLabel })
	upToLabel = shout({ TextColor3 = Color3.new(1, 1, 1), Parent = header })
	timerLabel = Ui.label({
		BackgroundColor3 = Color3.fromRGB(230, 30, 40),
		BackgroundTransparency = 0,
		Font = Enum.Font.GothamBold,
		TextStrokeTransparency = 1,
		Parent = header,
	})
	Ui.corner(UDim.new(1, 0)).Parent = timerLabel
	Ui.create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		Parent = timerLabel,
	})
	for index, spec in { { "Weekly.StickerLeft", -16, 0 }, { "Weekly.StickerRight", 14, 1 } } do
		local sticker = Ui.label({
			AnchorPoint = Vector2.new(spec[3], 0),
			Position = UDim2.new(spec[3], if spec[3] == 0 then 6 else -6, 0, 6),
			Size = UDim2.fromOffset(58, 58),
			Text = Texts.Get(spec[1]),
			TextStrokeTransparency = 1,
			Rotation = spec[2],
			Parent = header,
		})
		sticker:SetAttribute("Tilt", spec[2])
		stickers[index] = sticker
	end

	-- La liste (elle défile si l'écran est petit)
	list = Ui.create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(255, 230, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel,
	}, {
		Ui.create("UIListLayout", {
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Ui.create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }),
	})

	-- Les 3 défis
	for index = 1, 3 do
		local frame, icon = card(index, 70, ROW)
		local label = Ui.label({
			Position = UDim2.fromOffset(60, 4),
			Size = UDim2.new(0.7, -66, 0, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true, -- deux lignes plutôt qu'un texte minuscule (téléphone, langues longues)
			Parent = frame,
		})
		Ui.create("UITextSizeConstraint", { MaxTextSize = 22, Parent = label })
		local bar = Ui.create("Frame", {
			Position = UDim2.fromOffset(60, 44),
			Size = UDim2.new(0.7, -120, 0, 16),
			BackgroundColor3 = Color3.fromRGB(20, 14, 30),
			Parent = frame,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(0, 0, 0), 2, 0.2) })
		local fill = Ui.create("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = GOLD,
			Parent = bar,
		}, { Ui.corner(UDim.new(1, 0)), Ui.gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)) })
		local count = Ui.label({
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.7, -54, 0, 52),
			Size = UDim2.fromOffset(50, 20),
			Font = Enum.Font.GothamBold,
			Parent = frame,
		})
		local button = claimButton(frame, function()
			Remotes.WeeklyClaim:FireServer("Challenge", index)
		end)
		rows[index] = { frame = frame, icon = icon, label = label, fill = fill, count = count, button = button }
	end

	-- Bonus des 3 défis : trophée + Cash
	local bonus = card(4, 64, Color3.new(1, 1, 1), Texts.Get("Weekly.Icon.Trophy"))
	Ui.gradient(Color3.fromRGB(240, 175, 30), Color3.fromRGB(140, 80, 10)).Parent = bonus
	bonusLabel = shout({
		Position = UDim2.fromOffset(60, 6),
		Size = UDim2.new(0.7, -66, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = bonus,
	}, 2)
	bonusButton = claimButton(bonus, function()
		Remotes.WeeklyClaim:FireServer("Bonus")
	end)

	-- Coffre de la semaine : 7 cases (lundi -> dimanche)
	local chest = card(5, 100, ROW, Texts.Get("Weekly.Icon.Chest"))
	local days = Ui.create("Frame", {
		Position = UDim2.fromOffset(60, 8),
		Size = UDim2.new(0.7, -66, 0, 36),
		BackgroundTransparency = 1,
		Parent = chest,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for day = 1, 7 do
		local cell = Ui.create("Frame", {
			Size = UDim2.new(1 / 7, -4, 1, 0),
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
		Position = UDim2.fromOffset(60, 50),
		Size = UDim2.new(0.7, -66, 0, 42),
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
		Size = UDim2.new(1, -20, 0, 22),
		Font = Enum.Font.GothamMedium,
		LayoutOrder = 6,
		Parent = list,
	})

	-- Gros bouton rouge « LET'S GO! » : ferme la fenêtre
	goButton = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		BackgroundColor3 = Color3.fromRGB(235, 30, 40),
		Text = Texts.Get("Weekly.Go"),
		TextStrokeTransparency = 0.2,
		Parent = panel,
	})
	Ui.create("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = goButton,
	})
	goScale = Ui.create("UIScale", { Parent = goButton })
	Ui.markModal(panel, goButton)
	Ui.onBack(goButton, function()
		setOpen(false)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutWeekly)
	layoutWeekly()
end

-- Ouverture du coffre (D84) : il tombe, tremble trois fois, éclate (rayons, pièces), affiche le gain, puis les
-- billets s'envolent vers le compteur de Cash. Un toucher passe la scène.
local function chestScene(cash: number)
	local sceneGui = Ui.create("ScreenGui", { Name = "ChestScene", ResetOnSpawn = false, DisplayOrder = 25 })
	local shade = Ui.create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = sceneGui,
	})
	local sceneRays = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(320, 320),
		Text = "✴️",
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = sceneGui,
	})
	local chest = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, -0.2),
		Size = UDim2.fromOffset(150, 150),
		Text = "🎁",
		TextStrokeTransparency = 1,
		ZIndex = 3,
		Parent = sceneGui,
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
		Parent = sceneGui,
	})
	sceneGui.Parent = player:WaitForChild("PlayerGui")
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		sceneGui:Destroy()
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
		sceneRays.TextTransparency = 0.2
		TweenService:Create(sceneRays, TweenInfo.new(2.5, Enum.EasingStyle.Linear), { Rotation = 180 }):Play()
		TweenService:Create(amount, TweenInfo.new(0.3), { TextTransparency = 0, TextStrokeTransparency = 0.2 }):Play()
		for index = 1, 12 do
			local coin = Ui.label({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				Size = UDim2.fromOffset(44, 44),
				Text = if index % 2 == 0 then "🪙" else "💵",
				TextStrokeTransparency = 1,
				ZIndex = 2,
				Parent = sceneGui,
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

-- Case « Rewards » du menu (MenuController, D124) : rouvrir la fenêtre quand on veut
function WeeklyController.Open()
	if state and not panel.Visible and not MinigameController.IsGameplayLocked() then
		setOpen(true)
	end
end

-- Une récompense attend-elle d'être réclamée (défi fini, bonus des 3 défis, coffre du dimanche) ? Pastille rouge
function WeeklyController.HasClaim(): boolean
	if not state then
		return false
	end
	for _, challenge in state.challenges do
		if not challenge.claimed and challenge.progress >= challenge.target then
			return true
		end
	end
	if state.bonus and state.bonus.ready and not state.bonus.claimed then
		return true
	end
	return state.chest ~= nil and state.chest.canOpen == true and not state.chest.opened
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
