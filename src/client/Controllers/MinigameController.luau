-- Séries d'exercices côté client : ouvre le bon mini-jeu, envoie les répétitions au serveur,
-- affiche le feedback (Perfect / Good / Miss), le mode auto et l'écran de fin de série.
-- Le client ne calcule aucun gain : il affiche ce que le serveur confirme.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Exercises = require(ReplicatedStorage.Shared.Config.Exercises)
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
local controls

local gui: ScreenGui
local endPanel: Frame
local endLabel: TextLabel
local lastExerciseId: string? = nil
local pendingContinue = false

local current: {
	exerciseId: string,
	interval: number,
	minigame: any,
	root: Frame,
	counter: TextLabel,
	feedback: TextLabel,
	gainLabel: TextLabel,
	lastLocalRep: number,
	autoHeld: boolean,
	connections: { RBXScriptConnection },
}? =
	nil

local MinigameController = {}

local function setGameplayLocked(locked: boolean)
	ProximityPromptService.Enabled = not locked
	if controls then
		if locked then
			controls:Disable()
		else
			controls:Enable()
		end
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

local function closeSeries()
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

local function openSeries(exerciseId: string, total: number)
	closeSeries()
	pendingContinue = false
	endPanel.Visible = false

	local exercise = Exercises[exerciseId]
	local module = exercise and Minigames:FindFirstChild(exercise.minigame)
	if not module then
		warn(`[MinigameController] No minigame module for {exerciseId}`)
		Remotes.StopSeries:FireServer()
		return
	end

	lastExerciseId = exerciseId
	setGameplayLocked(true)

	-- Le cadre plein écran capte les touches : la caméra ne tourne pas pendant le mini-jeu
	local root = Ui.create("Frame", {
		Name = "Series",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = true,
		Parent = gui,
	})

	local counter = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(200, 46),
		Text = Texts.Get("Minigame.RepCounter", { reps = 0, total = total }),
		Parent = root,
	})
	local feedback = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.45, 0.42),
		Size = UDim2.fromOffset(420, 80),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = root,
	})
	local gainLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.45, 0.52),
		Size = UDim2.fromOffset(260, 40),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = root,
	})
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.fromOffset(560, 34),
		Text = Texts.Get(`Minigame.Hint.{exercise.minigame}`),
		Parent = root,
	})

	local stopButton = Ui.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(130, 56),
		BackgroundColor3 = Color3.fromRGB(200, 60, 60),
		Text = Texts.Get("Minigame.Stop"),
		Parent = root,
	})
	local autoButton = Ui.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 162, 1, -16),
		Size = UDim2.fromOffset(200, 56),
		BackgroundColor3 = Color3.fromRGB(60, 110, 200),
		Text = Texts.Get("Minigame.AutoButton"),
		Parent = root,
	})

	local minigame = require(module :: ModuleScript).new(root, exercise.repInterval, function(quality: string)
		if current and not current.autoHeld then
			sendRep(quality)
		end
	end)

	local session = {
		exerciseId = exerciseId,
		interval = exercise.repInterval,
		minigame = minigame,
		root = root,
		counter = counter,
		feedback = feedback,
		gainLabel = gainLabel,
		lastLocalRep = 0,
		autoHeld = false,
		connections = {},
	}
	current = session

	local function setAuto(held: boolean)
		session.autoHeld = held
		minigame:SetAuto(held)
	end

	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end

	table.insert(
		session.connections,
		stopButton.Activated:Connect(function()
			Remotes.StopSeries:FireServer()
		end)
	)
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
			if isPress(input) or input.KeyCode == Enum.KeyCode.ButtonR2 then
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
	current.counter.Text = Texts.Get("Minigame.RepCounter", { reps = update.reps, total = Balance.SeriesLength })
	pop(
		current.gainLabel,
		Texts.Get("Minigame.Gain", { value = Format.Gain(update.gain) }),
		Color3.fromRGB(255, 255, 255)
	)
end

local function onEnded(update)
	closeSeries()
	if update.reason == "Completed" then
		endLabel.Text = Texts.Get("Series.Complete", { mog = Format.Gain(update.mogGained) })
		endPanel.Visible = true
		return
	end
	if update.reason == "TooFar" then
		UIController.Toast(Texts.Get("Series.TooFar"))
	end
	setGameplayLocked(false)
end

local function buildGui()
	gui = Ui.create("ScreenGui", { Name = "Minigame", ResetOnSpawn = false })

	endPanel = Ui.create("Frame", {
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
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(0.5, -24, 0, 60),
		BackgroundColor3 = Color3.fromRGB(60, 170, 80),
		Text = Texts.Get("Series.Continue"),
		Parent = endPanel,
	})
	local doneButton = Ui.button({
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
			setGameplayLocked(false)
			return
		end
		pendingContinue = true
		Remotes.StartSeries:FireServer(lastExerciseId)
		-- Si le serveur refuse (joueur trop loin…), on rend la main au joueur
		task.delay(2, function()
			if pendingContinue then
				pendingContinue = false
				setGameplayLocked(false)
			end
		end)
	end)
	doneButton.Activated:Connect(function()
		endPanel.Visible = false
		setGameplayLocked(false)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function MinigameController.Init(controllers)
	UIController = controllers.UIController
end

function MinigameController.Start()
	buildGui()

	task.spawn(function()
		local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
		controls = (require(playerModule :: ModuleScript) :: any):GetControls()
	end)

	Remotes.SeriesUpdate.OnClientEvent:Connect(function(update)
		if update.state == "Started" then
			openSeries(update.exerciseId, update.total)
		elseif update.state == "Rep" then
			onRepConfirmed(update)
		elseif update.state == "Ended" then
			onEnded(update)
		elseif update.state == "Locked" then
			local boss = if update.bossId then Texts.Get(`Boss.{update.bossId}`) else "?"
			UIController.Toast(Texts.Get("Series.Locked", { boss = boss }))
		end
	end)
end

return MinigameController
