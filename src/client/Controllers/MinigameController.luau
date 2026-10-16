-- Runs de mini-jeu côté client (série d'exercice, aide, manche de boss) : ouvre le bon mini-jeu,
-- envoie les répétitions au serveur, affiche le feedback, le mode auto et l'écran de fin de série.
-- Le client ne calcule aucun gain : il affiche ce que le serveur confirme.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local Minigames = script.Parent.Parent.Minigames

local QUALITY_COLORS = {
	Perfect = Color3.fromRGB(255, 215, 40),
	Good = Color3.fromRGB(90, 230, 90),
	Miss = Color3.fromRGB(170, 170, 170),
	Auto = Color3.fromRGB(120, 180, 255),
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
	streak: number,
	lastLocalRep: number,
	startedAt: number,
	sent: number, -- répétitions envoyées au serveur
	autoHeld: boolean,
	gained: number, -- somme des gains confirmés par le serveur
	connections: { RBXScriptConnection },
}

local current: Current? = nil

local MinigameController = {}
MinigameController.LastCombo = 1

-- Bloque le personnage sur place (le client contrôle son propre personnage).
-- On n'utilise pas PlayerModule : les versions récentes de Roblox ne le fournissent plus.
function MinigameController.SetGameplayLocked(locked: boolean)
	ProximityPromptService.Enabled = not locked

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if locked then
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
	if quality == "Auto" and now - current.lastLocalRep < current.interval then
		return false
	end
	current.lastLocalRep = now
	current.sent += 1
	Remotes.Rep:FireServer(quality)
	pop(current.feedback, Texts.Get(`Minigame.{quality}`), QUALITY_COLORS[quality])
	return true
end

local function closeRun()
	if not current then
		return
	end
	for _, connection in current.connections do
		connection:Disconnect()
	end
	current.minigame:Destroy()
	current.root:Destroy()
	current = nil
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
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

	-- Le cadre plein écran capte les touches : la caméra ne tourne pas pendant le mini-jeu
	local root = Ui.create("Frame", {
		Name = "Series",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = true,
		Parent = gui,
	})

	if update.titleKey then
		Ui.label({
			Name = "Title",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 120),
			Size = UDim2.fromOffset(520, 40),
			TextColor3 = Color3.fromRGB(255, 220, 120),
			Text = UIController.Resolve({ key = update.titleKey, args = update.titleArgs }),
			Parent = root,
		})
	end
	local counter = Ui.label({
		Name = "Counter",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 162),
		Size = UDim2.fromOffset(200, 40),
		Text = Texts.Get("Minigame.RepCounter", { reps = 0, total = update.total }),
		Parent = root,
	})
	local feedback = Ui.label({
		Name = "Feedback",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.42, 0.45),
		Size = UDim2.fromOffset(420, 80),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = root,
	})
	-- Combo (D49) : grossit et change de couleur à chaque palier, « ON FIRE » au dernier
	local comboLabel = Ui.label({
		Name = "Combo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 204),
		Size = UDim2.fromOffset(320, 34),
		TextColor3 = COMBO_COLORS[1],
		Text = "",
		Parent = root,
	})
	local gainLabel = Ui.label({
		Name = "Gain",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.42, 0.55),
		Size = UDim2.fromOffset(260, 40),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = root,
	})
	Ui.label({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.fromOffset(600, 34),
		Text = Texts.Get(`Minigame.Hint.{update.minigame}`),
		Parent = root,
	})

	local stopButton = Ui.button({
		Name = "Stop",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(130, 56),
		BackgroundColor3 = Color3.fromRGB(200, 60, 60),
		Text = Texts.Get("Minigame.Stop"),
		Parent = root,
	})

	local minigame = require(module :: ModuleScript).new(root, update.interval, function(quality: string)
		if current and not current.autoHeld then
			sendRep(quality)
		end
	end, { timingScale = update.timingScale })

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
		streak = 0,
		lastLocalRep = 0,
		startedAt = os.clock(),
		sent = 0,
		autoHeld = false,
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

	if not update.autoAllowed then
		return
	end

	local autoButton = Ui.button({
		Name = "Auto",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 162, 1, -16),
		Size = UDim2.fromOffset(200, 56),
		BackgroundColor3 = Color3.fromRGB(60, 110, 200),
		Text = Texts.Get("Minigame.AutoButton"),
		Parent = root,
	})

	local function setAuto(held: boolean)
		session.autoHeld = held
		minigame:SetAuto(held)
	end

	table.insert(
		session.connections,
		autoButton.InputBegan:Connect(function(input)
			if isPress(input) then
				setAuto(true)
			end
		end)
	)
	-- Relâcher n'importe où (ou gâchette droite de manette) arrête le mode auto
	table.insert(
		session.connections,
		UserInputService.InputEnded:Connect(function(input)
			if session.autoHeld and (isPress(input) or input.KeyCode == Enum.KeyCode.ButtonR2) then
				setAuto(false)
			end
		end)
	)
	table.insert(
		session.connections,
		UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.ButtonR2 then
				setAuto(true)
			end
		end)
	)
	table.insert(
		session.connections,
		RunService.Heartbeat:Connect(function()
			if session.autoHeld then
				sendRep("Auto")
			end
		end)
	)
end

-- Petit coup de zoom de la caméra (répétition parfaite, palier de combo)
local function punch(strength: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local base = camera.FieldOfView
	camera.FieldOfView = base - strength
	TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = base,
	}):Play()
end

local function showCombo(session: Current, streak: number, combo: number)
	local label = session.comboLabel
	local previous = session.streak
	session.streak = streak
	if streak == 0 then
		if previous >= 5 then
			pop(label, Texts.Get("Minigame.ComboBroken"), Color3.fromRGB(200, 200, 200))
		else
			label.Text = ""
		end
		return
	end
	local tier = if combo >= 2 then 4 elseif combo >= 1.5 then 3 elseif combo > 1 then 2 else 1
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
		pop(
			current.gainLabel,
			Texts.Get("Minigame.Gain", { value = Format.Gain(update.gain) }),
			Color3.fromRGB(255, 255, 255)
		)
	end
end

local function onEnded(update)
	local gained = if current then current.gained else 0
	closeRun()
	-- Les manches de boss s'enchaînent : c'est BossController qui rend la main au joueur
	if update.kind == "Boss" then
		return
	end
	if update.kind == "Exercise" and update.reason == "Completed" then
		endLabel.Text = Texts.Get("Series.Complete", { mog = Format.Gain(gained) })
		endPanel.Visible = true
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
		Size = UDim2.fromOffset(400, 190),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(UDim.new(0, 16)) })

	endLabel = Ui.label({
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.new(1, -32, 0, 70),
		Parent = endPanel,
	})

	local continueButton = Ui.button({
		Name = "Continue",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(0.5, -24, 0, 60),
		BackgroundColor3 = Color3.fromRGB(60, 170, 80),
		Text = Texts.Get("Series.Continue"),
		Parent = endPanel,
	})
	local doneButton = Ui.button({
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

function MinigameController.Init(controllers)
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
