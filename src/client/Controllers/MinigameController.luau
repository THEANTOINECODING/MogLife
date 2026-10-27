-- Runs de mini-jeu côté client (série d'exercice, aide, manche de boss) : ouvre le bon mini-jeu,
-- envoie les répétitions au serveur, affiche le feedback et l'écran de fin de série.
-- Le client ne calcule aucun gain : il affiche ce que le serveur confirme.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CameraFraming = require(script.Parent.Parent.CameraFraming)
local MinigameKit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local Minigames = script.Parent.Parent.Minigames

local QUALITY_COLORS = {
	Perfect = Color3.fromRGB(255, 215, 40),
	Good = Color3.fromRGB(90, 230, 90),
	Miss = Color3.fromRGB(170, 170, 170),
}

-- Couleur du combo selon son multiplicateur (x1.2, x1.5, x2)
local COMBO_COLORS = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(120, 220, 255),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(255, 90, 40),
}

local player = Players.LocalPlayer

local UIController
-- Vitesse et saut d'origine, mémorisés pendant qu'un run bloque le personnage
local savedMovement: { walkSpeed: number, jumpHeight: number, jumpPower: number }? = nil

local gui: ScreenGui
local endPanel: Frame
local endLabel: TextLabel
local gradeLabel: TextLabel
local starsLabel: TextLabel
local accuracyLabel: TextLabel
local recordLabel: TextLabel
local continueButton: TextButton
local doneButton: TextButton

-- Couleur de chaque note
local GRADE_COLORS = {
	S = Color3.fromRGB(255, 210, 60),
	A = Color3.fromRGB(90, 220, 90),
	B = Color3.fromRGB(110, 180, 255),
	C = Color3.fromRGB(200, 200, 200),
}
local GRADE_STARS = { S = 3, A = 2, B = 1, C = 0 }
local lastExerciseId: string? = nil
local pendingContinue = false

type Current = {
	kind: string,
	id: string,
	total: number,
	interval: number,
	minigame: any,
	root: Frame,
	counter: TextLabel,
	feedback: TextLabel,
	gainLabel: TextLabel,
	comboLabel: TextLabel,
	fire: Frame,
	streak: number,
	lastLocalRep: number,
	startedAt: number,
	sent: number, -- répétitions envoyées au serveur
	gained: number, -- somme des gains confirmés par le serveur
	connections: { RBXScriptConnection },
}

local current: Current? = nil
local SettingsController
local SprintController

local MinigameController = {}
MinigameController.LastCombo = 1

-- Bloque le personnage sur place (le client contrôle son propre personnage).
-- On n'utilise pas PlayerModule : les versions récentes de Roblox ne le fournissent plus.
-- Pendant un mini-jeu ou une fenêtre, les étiquettes flottantes du décor (noms des PNJ, icônes des lieux, repères)
-- sont masquées : elles passaient devant les textes du mini-jeu
local hiddenTags: { BillboardGui } = {}
local TAG_NAMES = { NameTag = true, LandmarkIcon = true, EventMarker = true }
local function setWorldTagsHidden(hidden: boolean)
	if hidden then
		if #hiddenTags > 0 then
			return
		end
		for _, tag in workspace:GetDescendants() do
			if tag:IsA("BillboardGui") and TAG_NAMES[tag.Name] and tag.Enabled then
				tag.Enabled = false
				table.insert(hiddenTags, tag)
			end
		end
	else
		for _, tag in hiddenTags do
			tag.Enabled = true
		end
		table.clear(hiddenTags)
	end
end

local lockReasons: { [string]: boolean } = {}
local savedTouchGuiEnabled: boolean? = nil
function MinigameController.SetGameplayLocked(locked: boolean, reason: string?)
	lockReasons[reason or "Series"] = if locked then true else nil
	local active = next(lockReasons) ~= nil
	local touchGui = player:FindFirstChildOfClass("PlayerGui")
		and player.PlayerGui:FindFirstChild("TouchGui") :: ScreenGui?
	if touchGui then
		if active then
			if savedTouchGuiEnabled == nil then
				savedTouchGuiEnabled = touchGui.Enabled
			end
			touchGui.Enabled = false
		elseif savedTouchGuiEnabled ~= nil then
			touchGui.Enabled = savedTouchGuiEnabled
			savedTouchGuiEnabled = nil
		end
	end
	if active then
		SprintController.SetLocked(true)
	end
	ProximityPromptService.Enabled = not active
	setWorldTagsHidden(active)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if active then
		if humanoid and not savedMovement then
			savedMovement = {
				walkSpeed = humanoid.WalkSpeed,
				jumpHeight = humanoid.JumpHeight,
				jumpPower = humanoid.JumpPower,
			}
			humanoid.WalkSpeed = 0
			humanoid.JumpHeight = 0
			humanoid.JumpPower = 0
		end
	elseif savedMovement then
		if humanoid then
			humanoid.WalkSpeed = savedMovement.walkSpeed
			humanoid.JumpHeight = savedMovement.jumpHeight
			humanoid.JumpPower = savedMovement.jumpPower
		end
		savedMovement = nil
	end
	if not active then
		SprintController.SetLocked(false)
	end
end

local function pop(label: TextLabel, text: string, color: Color3)
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.3
	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.3), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
end

-- Le gain confirmé par le serveur s'envole vers le haut (une copie par répétition : ils peuvent se suivre)
local function flyGain(label: TextLabel, text: string, color: Color3)
	local copy = label:Clone()
	copy.Text = text
	copy.TextColor3 = color
	copy.TextTransparency = 0
	copy.TextStrokeTransparency = 0.3
	copy.Parent = label.Parent
	TweenService:Create(copy, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.fromOffset(0, 70),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(0.75, function()
		copy:Destroy()
	end)
end

-- Envoie une répétition si la cadence locale le permet. Renvoie true si elle a été envoyée.
local function sendRep(quality: string): boolean
	if not current then
		return false
	end
	local now = os.clock()
	-- Même quota que le serveur, avec une marge pour absorber la latence
	local tolerance = Balance.RepIntervalTolerance + 0.05
	local allowed = math.floor((now - current.startedAt) / (current.interval * tolerance)) + 1
	if current.sent >= allowed or now - current.lastLocalRep < 0.2 then
		return false
	end
	current.lastLocalRep = now
	current.sent += 1
	Remotes.Rep:FireServer(quality)
	pop(current.feedback, Texts.Get(`Minigame.{quality}`), QUALITY_COLORS[quality])
	return true
end

-- Pendant une série, la colonne de gauche (Maison, Flex, Style, Settings) se range : elle ne sert à rien et
-- cachait le personnage (le bouton Stop reste)
-- Plusieurs raisons peuvent se cumuler (série en cours, combat de boss entre deux manches) : la colonne ne revient
-- que quand il n'y en a plus aucune
local SIDE_GUIS = { "Travel", "Emotes", "Menu", "Weekly" }
local sideReasons: { [string]: boolean } = {}
local function setSideButtonsHidden(hidden: boolean, reason: string?)
	sideReasons[reason or "Run"] = if hidden then true else nil
	local anyReason = next(sideReasons) ~= nil
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	for _, name in SIDE_GUIS do
		local sideGui = playerGui and playerGui:FindFirstChild(name)
		if sideGui and sideGui:IsA("ScreenGui") then
			sideGui.Enabled = not anyReason
		end
	end
end

function MinigameController.SetSideButtonsHidden(hidden: boolean, reason: string)
	setSideButtonsHidden(hidden, reason)
end

local function closeRun()
	if not current then
		return
	end
	setSideButtonsHidden(false)
	UIController.SetStatsHidden(false, "Run")
	for _, connection in current.connections do
		connection:Disconnect()
	end
	current.minigame:Destroy()
	current.root:Destroy()
	current = nil
end

local function openRun(update)
	closeRun()
	pendingContinue = false
	endPanel.Visible = false

	local module = Minigames:FindFirstChild(update.minigame)
	if not module then
		warn(`[MinigameController] No minigame module named {update.minigame}`)
		Remotes.StopSeries:FireServer()
		return
	end

	if update.kind == "Exercise" then
		lastExerciseId = update.id
	end
	MinigameController.SetGameplayLocked(true)
	setSideButtonsHidden(true)
	UIController.SetStatsHidden(true, "Run")

	-- Le cadre plein écran capte les touches : la caméra ne tourne pas pendant le mini-jeu
	local root = Ui.create("Frame", {
		Name = "Series",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = true,
		Parent = gui,
	})
	local compact = Ui.isPhonePortrait()
	local touchLandscape = UserInputService.TouchEnabled and not compact
	local railWidth = math.min(260, math.floor(root.AbsoluteSize.X * 0.28))
	local railButtonWidth = math.floor((railWidth - 8) / 2)

	if update.titleKey then
		Ui.label({
			Name = "Title",
			AnchorPoint = if touchLandscape then Vector2.zero else Vector2.new(0.5, 0),
			Position = if touchLandscape
				then UDim2.fromOffset(16, 8)
				else UDim2.new(0.5, 0, 0, if compact then 88 else 156),
			Size = if touchLandscape
				then UDim2.fromOffset(railWidth, 32)
				else if compact then UDim2.new(1, -24, 0, 36) else UDim2.fromOffset(520, 40),
			TextColor3 = Color3.fromRGB(255, 220, 120),
			Text = UIController.Resolve({ key = update.titleKey, args = update.titleArgs }),
			Parent = root,
		})
	end
	local counter = Ui.label({
		Name = "Counter",
		AnchorPoint = if touchLandscape then Vector2.zero else Vector2.new(0.5, 0),
		Position = if touchLandscape
			then UDim2.fromOffset(16, 44)
			else UDim2.new(0.5, 0, 0, if compact then 126 else 198),
		Size = if touchLandscape then UDim2.fromOffset(railWidth, 32) else UDim2.fromOffset(200, 40),
		Text = Texts.Get("Minigame.RepCounter", { reps = 0, total = update.total }),
		Parent = root,
	})
	local feedback = Ui.label({
		Name = "Feedback",
		AnchorPoint = if touchLandscape then Vector2.zero else Vector2.new(0.5, 0.5),
		Position = if touchLandscape
			then UDim2.fromOffset(16, 82)
			else UDim2.fromScale(if compact then 0.5 else 0.42, if compact then 0.25 else 0.45),
		Size = if touchLandscape
			then UDim2.fromOffset(railWidth, 44)
			else if compact then UDim2.new(1, -24, 0, 54) else UDim2.fromOffset(420, 80),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = root,
	})
	-- Combo (D49) : grossit et change de couleur à chaque palier, « ON FIRE » au dernier
	local comboLabel = Ui.label({
		Name = "Combo",
		AnchorPoint = if touchLandscape then Vector2.zero else Vector2.new(0.5, 0),
		Position = if touchLandscape
			then UDim2.fromOffset(16, 163)
			else UDim2.new(0.5, 0, 0, if compact then 162 else 240),
		Size = if touchLandscape then UDim2.fromOffset(railWidth, 28) else UDim2.fromOffset(320, 34),
		TextColor3 = COMBO_COLORS[1],
		Text = "",
		Parent = root,
	})
	local gainLabel = Ui.label({
		Name = "Gain",
		AnchorPoint = if touchLandscape then Vector2.zero else Vector2.new(0.5, 0.5),
		Position = if touchLandscape
			then UDim2.fromOffset(16, 128)
			else UDim2.fromScale(if compact then 0.5 else 0.42, if compact then 0.31 else 0.55),
		Size = if touchLandscape then UDim2.fromOffset(railWidth, 32) else UDim2.fromOffset(260, 40),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = root,
	})
	-- Consigne du mini-jeu, toujours visible (une phrase)
	local hint = Ui.label({
		Name = "Hint",
		AnchorPoint = if touchLandscape or compact then Vector2.zero else Vector2.new(0.5, 1),
		Position = if touchLandscape
			then UDim2.fromOffset(16, 196)
			elseif compact then UDim2.fromOffset(12, 198)
			else UDim2.new(0.5, 0, 1, -84),
		Size = if touchLandscape
			then UDim2.fromOffset(railWidth, 56)
			elseif compact then UDim2.new(1, -24, 0, 30)
			else UDim2.fromOffset(600, 34),
		TextWrapped = true,
		Text = Texts.Get(`Minigame.Hint.{update.minigame}`),
		Parent = root,
	})
	hint.TextXAlignment = if touchLandscape then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	local stopButton = Ui.button({
		Name = "Stop",
		AnchorPoint = if touchLandscape
			then Vector2.zero
			else if UserInputService.TouchEnabled then Vector2.new(1, 0) else Vector2.new(0, 1),
		Position = if touchLandscape
			then UDim2.fromOffset(16, 260)
			else if UserInputService.TouchEnabled
				then UDim2.new(1, -16, 0, if compact then 208 else 80)
				else UDim2.new(0, 16, 1, -16),
		Size = if touchLandscape then UDim2.fromOffset(railButtonWidth, 50) else UDim2.fromOffset(130, 56),
		BackgroundColor3 = Color3.fromRGB(200, 60, 60),
		Text = Texts.Get("Minigame.Stop"),
		Selectable = false,
		Parent = root,
	})

	-- La série se corse : les fenêtres de notation se resserrent à chaque répétition (D80)
	local baseScale = update.timingScale or 1
	local total = math.max(1, tonumber(update.total) or 1)
	local played = 0
	local minigame
	minigame = require(module :: ModuleScript).new(root, update.interval, function(quality: string)
		if current then
			sendRep(quality)
		end
		played += 1
		if minigame then
			minigame.timingScale = baseScale
				* (1 - Balance.Minigames.SeriesTightening * math.min(played, total - 1) / math.max(1, total - 1))
		end
	end, {
		timingScale = update.timingScale,
		seed = update.seed,
		level = update.level,
		name = update.minigame,
		total = update.total,
	})

	-- Au départ, la consigne s'affiche en grand au milieu de l'écran, puis s'efface (elle reste dans la colonne)
	local intro = Ui.label({
		Name = "Intro",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, if compact then 0.2 else 0.16),
		Size = if compact then UDim2.new(1, -24, 0, 60) else UDim2.new(0.7, 0, 0, 64),
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(255, 230, 140),
		TextStrokeTransparency = 0,
		Text = hint.Text,
		ZIndex = 50,
		Parent = root,
	})
	task.delay(Balance.Minigames.AnnounceTime, function()
		if intro.Parent then
			TweenService:Create(intro, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.delay(0.45, function()
				intro:Destroy()
			end)
		end
	end)

	-- Cadre « EN FEU » : les bords de l'écran rougeoient tant que le combo est au maximum
	local fire = Ui.create("Frame", {
		Name = "OnFire",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 0,
		Parent = root,
	})
	for _, edge in { { 0, 90 }, { 1, -90 } } do
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0, edge[1]),
			Position = UDim2.fromScale(0, edge[1]),
			Size = UDim2.fromScale(1, 0.18),
			BackgroundColor3 = Color3.fromRGB(255, 110, 30),
			BorderSizePixel = 0,
			Parent = fire,
		}, {
			Ui.create("UIGradient", {
				Rotation = edge[2],
				Transparency = NumberSequence.new(0.35, 1),
			}),
		})
	end

	local session: Current = {
		kind = update.kind,
		id = update.id,
		total = update.total,
		interval = update.interval,
		minigame = minigame,
		root = root,
		counter = counter,
		feedback = feedback,
		gainLabel = gainLabel,
		comboLabel = comboLabel,
		fire = fire,
		streak = 0,
		lastLocalRep = 0,
		startedAt = os.clock(),
		sent = 0,
		gained = 0,
		connections = {},
	}
	current = session

	table.insert(
		session.connections,
		stopButton.Activated:Connect(function()
			Remotes.StopSeries:FireServer()
		end)
	)
	table.insert(
		session.connections,
		UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.ButtonB then
				Remotes.StopSeries:FireServer()
			end
		end)
	)
end

-- Petit coup de zoom de la caméra (répétition parfaite, palier de combo)
local function punch(strength: number)
	local camera = workspace.CurrentCamera
	if not camera or (SettingsController and not SettingsController.Get("ScreenFx")) then
		return
	end
	-- Toujours depuis le même zoom de référence : plusieurs Perfect rapprochés ne zooment pas de plus en plus
	local base = CameraFraming.Fov
	camera.FieldOfView = base - math.min(strength, 4)
	TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = base,
	}):Play()
end

local function showCombo(session: Current, streak: number, combo: number)
	local label = session.comboLabel
	local previous = session.streak
	session.streak = streak
	if streak == 0 then
		session.fire.Visible = false
		if previous >= 5 then
			pop(label, Texts.Get("Minigame.ComboBroken"), Color3.fromRGB(200, 200, 200))
		else
			label.Text = ""
		end
		return
	end
	local tier = if combo >= 2 then 4 elseif combo >= 1.5 then 3 elseif combo > 1 then 2 else 1
	session.fire.Visible = tier == 4
	-- Un nouveau tween annule le fondu de « Combo broken » encore en cours
	TweenService:Create(label, TweenInfo.new(0), { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	label.TextColor3 = COMBO_COLORS[tier]
	label.Text = if tier == 4
		then `{Texts.Get("Minigame.OnFire")}  {Texts.Get("Minigame.Combo", { multiplier = combo })}`
		elseif combo > 1 then Texts.Get("Minigame.Combo", { multiplier = combo })
		else Texts.Get("Minigame.Streak", { streak = streak })
	-- Le label « saute » à chaque répétition, plus fort quand on passe un palier
	local tierUp = combo > MinigameController.LastCombo
	local grow = if tierUp then 1.5 else 1.15
	label.Size = UDim2.fromOffset(320 * grow, 34 * grow)
	TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(320, 34),
	}):Play()
	if tierUp then
		punch(6)
	end
end

local function onRepConfirmed(update)
	if not current then
		return
	end
	current.counter.Text = Texts.Get("Minigame.RepCounter", { reps = update.reps, total = current.total })
	if update.streak then
		showCombo(current, update.streak, update.combo or 1)
		MinigameController.LastCombo = if update.streak == 0 then 1 else update.combo or 1
	end
	if update.quality == "Perfect" then
		punch(2.5)
	end
	if update.gain then
		current.gained += update.gain
		-- Aides : du Cash (rien sur un raté) ; exercices : du Mog
		local isCash = current.kind == "Help"
		if not (isCash and update.gain <= 0) then
			flyGain(
				current.gainLabel,
				Texts.Get(if isCash then "Minigame.GainCash" else "Minigame.Gain", { value = Format.Gain(update.gain) }),
				if isCash then Color3.fromRGB(120, 230, 120) else Color3.fromRGB(255, 255, 255)
			)
		end
	end
end

local function onEnded(update)
	local gained = if current then current.gained else 0
	closeRun()
	-- Les manches de boss et de duel s'enchaînent : c'est BossController / DuelController qui rend la main
	if update.kind == "Boss" or update.kind == "Duel" then
		MinigameController.SetGameplayLocked(false, "Series")
		return
	end
	if (update.kind == "Exercise" or update.kind == "Help") and update.reason == "Completed" then
		continueButton.Visible = update.kind == "Exercise"
		doneButton.Size = if update.kind == "Help" then UDim2.new(1, -32, 0, 60) else UDim2.new(0.5, -24, 0, 60)
		if update.kind == "Help" then
			-- Aide : le Cash vraiment versé (bonus sans faute compris), ou rien si tout est raté
			local cash = update.cash or 0
			endLabel.Text = if cash > 0
				then Texts.Get(if update.flawless then "Help.CompleteFlawless" else "Help.Complete", { cash = cash })
				else Texts.Get("Help.CompleteNothing")
		else
			endLabel.Text = Texts.Get("Series.Complete", { mog = Format.Gain(gained) })
		end
		-- Le gain s'envole vers le compteur (D84) : billets pour une aide, muscles pour une série
		if update.kind == "Help" and (update.cash or 0) > 0 then
			UIController.FlyToCounter("Cash")
		elseif update.kind == "Exercise" and gained > 0 then
			UIController.FlyToCounter("Mog")
		end
		local grade = update.grade
		gradeLabel.Text = grade or "-"
		gradeLabel.TextColor3 = GRADE_COLORS[grade] or GRADE_COLORS.C
		starsLabel.Text = string.rep("★", GRADE_STARS[grade] or 0) .. string.rep("☆", 3 - (GRADE_STARS[grade] or 0))
		accuracyLabel.Text = if update.score
			then Texts.Get("Series.Accuracy", { score = update.score })
			else Texts.Get("Series.NoGrade")
		if update.newRecord then
			recordLabel.Text = Texts.Get("Series.NewRecord")
			recordLabel.TextColor3 = GRADE_COLORS.S
		elseif update.record then
			recordLabel.Text = Texts.Get("Series.Record", { record = update.record })
			recordLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
		else
			recordLabel.Text = ""
		end
		endPanel.Visible = true
		-- La note tombe avec un rebond
		gradeLabel.Size = UDim2.fromOffset(170, 170)
		TweenService:Create(gradeLabel, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(110, 110),
		}):Play()
		if update.newRecord then
			punch(5)
		end
		return
	end
	if update.reason == "TooFar" then
		UIController.Toast(Texts.Get("Series.TooFar"))
	end
	MinigameController.SetGameplayLocked(false)
end

local function buildGui()
	gui = Ui.create("ScreenGui", { Name = "Minigame", ResetOnSpawn = false })

	endPanel = Ui.create("Frame", {
		Name = "EndPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = if Ui.isPhonePortrait() then UDim2.new(1, -20, 0, 260) else UDim2.fromOffset(440, 260),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(UDim.new(0, 16)) })
	Ui.watchViewport(function()
		endPanel.Size = if Ui.isPhonePortrait() then UDim2.new(1, -20, 0, 260) else UDim2.fromOffset(440, 260)
	end)

	-- Note (S/A/B/C) à gauche, détails à droite
	gradeLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(80, 82),
		Size = UDim2.fromOffset(110, 110),
		Text = "",
		Parent = endPanel,
	})
	starsLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(80, 138),
		Size = UDim2.fromOffset(130, 30),
		TextColor3 = Color3.fromRGB(255, 210, 60),
		Parent = endPanel,
	})
	endLabel = Ui.label({
		Position = UDim2.fromOffset(160, 18),
		Size = UDim2.new(1, -176, 0, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = endPanel,
	})
	accuracyLabel = Ui.label({
		Position = UDim2.fromOffset(160, 74),
		Size = UDim2.new(1, -176, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(220, 220, 230),
		Parent = endPanel,
	})
	recordLabel = Ui.label({
		Position = UDim2.fromOffset(160, 110),
		Size = UDim2.new(1, -176, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = endPanel,
	})

	continueButton = Ui.button({
		Name = "Continue",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(0.5, -24, 0, 60),
		BackgroundColor3 = Color3.fromRGB(60, 170, 80),
		Text = Texts.Get("Series.Continue"),
		Parent = endPanel,
	})
	doneButton = Ui.button({
		Name = "Done",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0.5, -24, 0, 60),
		BackgroundColor3 = Color3.fromRGB(90, 90, 90),
		Text = Texts.Get("Series.Done"),
		Parent = endPanel,
	})

	continueButton.Activated:Connect(function()
		endPanel.Visible = false
		if not lastExerciseId then
			MinigameController.SetGameplayLocked(false)
			return
		end
		pendingContinue = true
		Remotes.StartSeries:FireServer(lastExerciseId)
		-- Si le serveur refuse (joueur trop loin…), on rend la main au joueur
		task.delay(2, function()
			if pendingContinue then
				pendingContinue = false
				MinigameController.SetGameplayLocked(false)
			end
		end)
	end)
	doneButton.Activated:Connect(function()
		endPanel.Visible = false
		MinigameController.SetGameplayLocked(false)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Cadre du mini-jeu en cours (nil hors run) : les coups spéciaux des boss le font bouger (BossSpecials)
function MinigameController.CurrentRoot(): Frame?
	return current and current.root
end

function MinigameController.Init(controllers)
	SettingsController = controllers.SettingsController
	MinigameKit.SetSettingsGetter(SettingsController.Get)
	MinigameKit.SetRepListener(controllers.ActivityController.LocalRep)
	MinigameKit.SetSoundPlayer(controllers.SoundController.Play)
	SprintController = controllers.SprintController
	UIController = controllers.UIController
end

function MinigameController.Start()
	buildGui()

	-- Un nouveau personnage (mort, respawn) repart avec ses valeurs par défaut
	player.CharacterAdded:Connect(function()
		savedMovement = nil
	end)

	Remotes.SeriesUpdate.OnClientEvent:Connect(function(update)
		if update.state == "Started" then
			openRun(update)
		elseif update.state == "Rep" then
			onRepConfirmed(update)
		elseif update.state == "Ended" then
			onEnded(update)
		end
	end)
end

return MinigameController
