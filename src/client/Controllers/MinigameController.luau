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
	lastLocalRep: number,
	autoHeld: boolean,
	gained: number, -- somme des gains confirmés par le serveur
	connections: { RBXScriptConnection },
}

local current: Current? = nil

local MinigameController = {}

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
	-- Marge légèrement au-dessus de la tolérance serveur pour absorber la latence
	local minGap = if quality == "Auto"
		then current.interval
		else current.interval * (Balance.RepIntervalTolerance + 0.05)
	if now - current.lastLocalRep < minGap then
		return false
	end
	current.lastLocalRep = now
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
	end)

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
		lastLocalRep = 0,
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

local function onRepConfirmed(update)
	if not current then
		return
	end
	current.counter.Text = Texts.Get("Minigame.RepCounter", { reps = update.reps, total = current.total })
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
