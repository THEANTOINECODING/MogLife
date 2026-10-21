-- Cinématiques (D53) : bandes noires façon cinéma, plans de caméra enchaînés, légendes, bouton « Passer ».
-- - Intro de Muscle City (première arrivée d'un nouveau joueur, demandée par le serveur) : survol de la ville,
--   puis descente jusqu'au garage du joueur.
-- - Présentation d'un boss à la première rencontre (demandée par le serveur) : contre-plongée sur le boss, carte
--   « BOSS » avec son nom, son stade et sa réplique.
-- CutsceneController.Play(shots, onDone) est aussi utilisé par BossController (entrée en scène du défi).
-- Un plan : { from: CFrame, to: CFrame, duration: number, caption: string?, sub: string?, onStart: (() -> ())? }

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local GOLD = Color3.fromRGB(255, 210, 60)
local BAR_HEIGHT = 0.11 -- part de l'écran occupée par chaque bande noire

local player = Players.LocalPlayer

local MinigameController

local gui: ScreenGui
local topBar: Frame
local bottomBar: Frame
local captionLabel: TextLabel
local subLabel: TextLabel
local skipButton: TextButton
local playing: { connection: RBXScriptConnection?, done: (() -> ())?, token: number }? = nil
local token = 0

local CutsceneController = {}

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Pendant une cinématique, le reste de l'interface disparaît (HUD, objectif, classement, chat)
local hiddenGuis: { ScreenGui } = {}
local function setInterfaceHidden(hidden: boolean)
	if hidden then
		for _, other in player:WaitForChild("PlayerGui"):GetChildren() do
			if other:IsA("ScreenGui") and other ~= gui and other.Enabled then
				other.Enabled = false
				table.insert(hiddenGuis, other)
			end
		end
	else
		for _, other in hiddenGuis do
			other.Enabled = true
		end
		table.clear(hiddenGuis)
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not hidden)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not hidden)
	end)
end

local function setBars(visible: boolean)
	local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(topBar, info, { Position = UDim2.fromScale(0, if visible then 0 else -BAR_HEIGHT) }):Play()
	TweenService:Create(bottomBar, info, { Position = UDim2.fromScale(0, if visible then 1 - BAR_HEIGHT else 1) })
		:Play()
end

local function showCaption(caption: string?, sub: string?)
	captionLabel.Text = caption or ""
	subLabel.Text = sub or ""
	for _, label in { captionLabel, subLabel } do
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	end
end

local function finish()
	if not playing then
		return
	end
	local done = playing.done
	if playing.connection then
		playing.connection:Disconnect()
	end
	playing = nil
	setBars(false)
	setInterfaceHidden(false)
	showCaption(nil, nil)
	skipButton.Visible = false
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
	MinigameController.SetGameplayLocked(false, "Cutscene")
	if done then
		done()
	end
end

-- Joue une suite de plans ; onDone est appelé à la fin (ou si le joueur passe). keepCamera : ne pas rendre la
-- caméra au joueur à la fin (l'appelant enchaîne avec sa propre caméra).
function CutsceneController.Play(shots: { any }, onDone: (() -> ())?, keepCamera: boolean?)
	if playing then
		finish()
	end
	local camera = workspace.CurrentCamera
	if not camera or #shots == 0 then
		if onDone then
			onDone()
		end
		return
	end
	token += 1
	local myToken = token
	MinigameController.SetGameplayLocked(true, "Cutscene")
	camera.CameraType = Enum.CameraType.Scriptable
	setBars(true)
	setInterfaceHidden(true)
	skipButton.Visible = true
	local index, shotStart = 0, 0
	local function nextShot()
		index += 1
		local shot = shots[index]
		if not shot then
			return false
		end
		shotStart = os.clock()
		showCaption(shot.caption, shot.sub)
		if shot.onStart then
			task.spawn(shot.onStart)
		end
		return true
	end
	nextShot()
	playing = { token = myToken, done = nil, connection = nil }
	playing.done = function()
		if keepCamera then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		if onDone then
			onDone()
		end
	end
	playing.connection = RunService.RenderStepped:Connect(function()
		local shot = shots[index]
		if not shot then
			return
		end
		local t = (os.clock() - shotStart) / shot.duration
		camera.CFrame = shot.from:Lerp(shot.to, smooth(t))
		if t >= 1 and not nextShot() then
			finish()
		end
	end)
end

function CutsceneController.IsPlaying(): boolean
	return playing ~= nil
end

-- Mesure d'un PNJ modélisé pour le cadrer : le pivot importé peut être tourné (axes du FBX), mais le corps
-- (PrimaryPart) est droit et regarde vers l'avant du PNJ. Renvoie les pieds, la hauteur et la direction du regard.
function CutsceneController.Measure(model: Model): (Vector3, number, Vector3)
	local body = model.PrimaryPart
	if body then
		return body.Position - Vector3.new(0, body.Size.Y / 2, 0), body.Size.Y, body.CFrame.LookVector
	end
	local cf, size = model:GetBoundingBox()
	return cf.Position - Vector3.new(0, size.Y / 2, 0), size.Y, Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit
end

-- Sa propre maison (tag Plot, OwnerUserId), pour finir l'intro devant son garage
local function ownPlot(): Instance?
	for _, plot in CollectionService:GetTagged("Plot") do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function intro()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plot = ownPlot()
	local home = if plot and plot:IsA("Model")
		then plot:GetPivot().Position
		else (if root then root.Position else Vector3.zero)
	local target = if root then root.Position else home
	local center = Vector3.new(0, 4, 0)
	CutsceneController.Play({
		{
			from = CFrame.lookAt(Vector3.new(-170, 120, -170), center),
			to = CFrame.lookAt(Vector3.new(-120, 90, 150), center),
			duration = 4,
			caption = Texts.Get("Cutscene.Intro1"),
		},
		{
			from = CFrame.lookAt(Vector3.new(40, 30, -40), center + Vector3.new(0, 6, 0)),
			to = CFrame.lookAt(Vector3.new(-30, 18, -30), center + Vector3.new(0, 8, 25)),
			duration = 3.5,
			caption = Texts.Get("Cutscene.Intro2"),
		},
		{
			from = CFrame.lookAt(home + Vector3.new(0, 60, -60), home),
			to = CFrame.lookAt(target + Vector3.new(6, 6, -10), target + Vector3.new(0, 2, 0)),
			duration = 3.5,
			caption = Texts.Get("Cutscene.Intro3"),
			sub = Texts.Get("Cutscene.Intro4"),
		},
	}, function()
		Remotes.CutsceneDone:FireServer("Intro")
	end)
end

-- Présentation d'un boss : contre-plongée qui monte jusqu'à son visage, carte BOSS
local function bossIntro(bossId: string, spot: BasePart)
	local _, stageIndex = Stages.FindBoss(bossId)
	local model: Model? = nil
	local folder = workspace:FindFirstChild("Npcs")
	local best = 15
	for _, candidate in if folder then folder:GetChildren() else {} do
		if candidate:IsA("Model") and (candidate:GetPivot().Position - spot.Position).Magnitude < best then
			model, best = candidate, (candidate:GetPivot().Position - spot.Position).Magnitude
		end
	end
	local base, height, front = spot.Position, 6, spot.CFrame.LookVector
	if model then
		base, height, front = CutsceneController.Measure(model)
	end
	local face = base + Vector3.new(0, height * 0.85, 0)
	local side = Vector3.new(0, 1, 0):Cross(front)
	local stage = stageIndex and Stages.List[stageIndex]
	CutsceneController.Play({
		{
			-- Contre-plongée de face, qui s'approche
			from = CFrame.lookAt(base + front * (height * 1.9 + 4) + Vector3.new(0, 1, 0), face),
			to = CFrame.lookAt(base + front * (height * 1.3 + 3) + Vector3.new(0, height * 0.3, 0), face),
			duration = 2.2,
			caption = Texts.Get("Cutscene.BossTitle"),
			sub = Texts.Get(`Boss.{bossId}`),
			onStart = function()
				-- Le boss se gonfle en arrivant
				if model then
					local scale = model:GetScale()
					model:ScaleTo(scale * 1.25)
					task.wait(0.5)
					if model.Parent then
						model:ScaleTo(scale)
					end
				end
			end,
		},
		{
			-- Glissé latéral de trois quarts à trois quarts, à hauteur de visage
			from = CFrame.lookAt(
				base + front * (height * 1.3 + 3) + side * (height * 0.6) + Vector3.new(0, height * 0.7, 0),
				face
			),
			to = CFrame.lookAt(
				base + front * (height * 1.1 + 3) - side * (height * 0.6) + Vector3.new(0, height * 0.8, 0),
				face
			),
			duration = 3,
			caption = if stage then Texts.Get("Cutscene.BossStage", { stage = Texts.Get(`Stage.{stage.id}`) }) else "",
			sub = Texts.Get(`BossLine.{bossId}`),
		},
	}, function()
		Remotes.CutsceneDone:FireServer("Boss")
	end)
end

local function buildGui()
	gui = Ui.create("ScreenGui", { Name = "Cutscene", ResetOnSpawn = false, DisplayOrder = 20, IgnoreGuiInset = true })
	topBar = Ui.create("Frame", {
		Position = UDim2.fromScale(0, -BAR_HEIGHT),
		Size = UDim2.fromScale(1, BAR_HEIGHT),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = gui,
	})
	bottomBar = Ui.create("Frame", {
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, BAR_HEIGHT),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = gui,
	})
	captionLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1 - BAR_HEIGHT, -60),
		Size = UDim2.new(0.8, 0, 0, 56),
		TextColor3 = GOLD,
		TextTransparency = 1,
		Parent = gui,
	})
	subLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1 - BAR_HEIGHT, -18),
		Size = UDim2.new(0.8, 0, 0, 36),
		Font = Enum.Font.GothamMedium,
		TextTransparency = 1,
		Parent = gui,
	})
	skipButton = Ui.button({
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 1 - BAR_HEIGHT / 2, 0),
		Size = UDim2.fromOffset(110, 40),
		BackgroundColor3 = Color3.fromRGB(70, 70, 80),
		Text = Texts.Get("Cutscene.Skip"),
		Visible = false,
		ZIndex = 2,
		Parent = gui,
	})
	skipButton.Activated:Connect(finish)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function CutsceneController.Init(controllers)
	MinigameController = controllers.MinigameController
end

function CutsceneController.Start()
	buildGui()
	Remotes.Cutscene.OnClientEvent:Connect(function(request)
		if typeof(request) ~= "table" then
			return
		end
		if request.kind == "Intro" then
			-- Laisse le personnage et la ville se charger
			task.delay(1, intro)
		elseif request.kind == "Boss" and typeof(request.bossId) == "string" and typeof(request.spot) == "Instance" then
			bossIntro(request.bossId, request.spot)
		end
	end)
end

return CutsceneController
