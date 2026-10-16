-- Tutoriel et paroles du mentor (étape 5) :
-- - une carte d'objectif en haut à gauche (étape, objectif, bouton « Passer ») ;
-- - un trait lumineux bleu jusqu'à la cible de l'étape (sa station de curl, Maman, le coiffeur, Kevin) ;
-- - une bulle en bas de l'écran où le mentor parle (les répliques s'enchaînent, une à la fois).
-- Le serveur décide de l'étape (TutorialService) ; ce contrôleur ne fait qu'afficher.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local PLOT_TAG = "Plot"
local GUIDE_COLOR = Color3.fromRGB(90, 220, 255)
local SPEECH_TIME = 4.5 -- secondes par réplique du mentor

local player = Players.LocalPlayer

local UIController
local card: Frame
local goalLabel: TextLabel
local progressLabel: TextLabel
local speech: Frame
local speechLabel: TextLabel
local beam: Beam
local startAttachment: Attachment?
local endAttachment: Attachment
local marker: BillboardGui
local current: { step: number, total: number, done: boolean }? = nil
local queue: { string } = {}
local speaking = false

local TutorialController = {}

local function inOwnPlot(instance: Instance): boolean
	local node = instance.Parent
	while node and node ~= workspace do
		if CollectionService:HasTag(node, PLOT_TAG) then
			return node:GetAttribute("OwnerUserId") == player.UserId
		end
		node = node.Parent
	end
	return false
end

-- La cible de l'étape (la plus proche s'il y en a plusieurs)
local function findTarget(target: Tutorial.Target): BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local best, bestDistance = nil, math.huge
	for _, part in CollectionService:GetTagged(target.tag) do
		if part:IsA("BasePart") and part:GetAttribute(target.attribute) == target.value then
			if target.own and not inOwnPlot(part) then
				continue
			end
			local distance = if root then (part.Position - root.Position).Magnitude else 0
			if distance < bestDistance then
				best, bestDistance = part, distance
			end
		end
	end
	return best
end

local function updateGuide()
	local step = if current and not current.done then Tutorial.Steps[current.step] else nil
	local target = step and findTarget(step.target)
	local visible = target ~= nil and startAttachment ~= nil and startAttachment.Parent ~= nil
	if target then
		endAttachment.WorldPosition = target.Position + Vector3.new(0, 1, 0)
	end
	beam.Enabled = visible
	marker.Enabled = visible
end

local function render()
	local step = if current and not current.done then Tutorial.Steps[current.step] else nil
	card.Visible = step ~= nil
	if step and current then
		goalLabel.Text = Texts.Get(`Tutorial.{step.id}.Goal`)
		progressLabel.Text = Texts.Get("Tutorial.Progress", { step = current.step, total = current.total })
	end
	updateGuide()
end

-- Le mentor parle : une réplique à la fois
local function speakNext()
	if speaking or #queue == 0 then
		return
	end
	speaking = true
	speechLabel.Text = table.remove(queue, 1) :: string
	speech.Visible = true
	speech.GroupTransparency = 1
	TweenService:Create(speech, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
	task.delay(SPEECH_TIME, function()
		TweenService:Create(speech, TweenInfo.new(0.25), { GroupTransparency = 1 }):Play()
		task.wait(0.3)
		speech.Visible = false
		speaking = false
		speakNext()
	end)
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "Tutorial", ResetOnSpawn = false, DisplayOrder = 3 })

	-- Carte d'objectif (sous les boutons du menu Roblox, à gauche)
	card = Ui.panel({
		Name = "Objective",
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.fromOffset(250, 100),
		Visible = false,
		Parent = gui,
	})
	Ui.label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Text = Texts.Get("Tutorial.Title"),
		Parent = card,
	})
	goalLabel = Ui.label({
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -24, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = card,
	})
	progressLabel = Ui.label({
		Position = UDim2.new(0, 12, 1, -28),
		Size = UDim2.new(0.5, -12, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Parent = card,
	})
	local skip = Ui.button({
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -8),
		Size = UDim2.fromOffset(84, 26),
		BackgroundColor3 = Color3.fromRGB(90, 90, 100),
		Text = Texts.Get("Tutorial.Skip"),
		Parent = card,
	})
	skip.Activated:Connect(function()
		Remotes.TutorialAction:FireServer("Skip")
	end)

	-- Bulle du mentor, en bas au centre
	speech = Ui.create("CanvasGroup", {
		Name = "MentorSpeech",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.new(0.9, 0, 0, 74),
		BackgroundColor3 = Color3.fromRGB(25, 20, 40),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(UDim.new(0, 14)),
		Ui.stroke(GUIDE_COLOR, 3, 0),
		Ui.create("UISizeConstraint", { MaxSize = Vector2.new(640, 74) }),
	})
	Ui.label({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GUIDE_COLOR,
		Text = Texts.Get("Npc.Mentor"),
		Parent = speech,
	})
	speechLabel = Ui.label({
		Position = UDim2.fromOffset(14, 28),
		Size = UDim2.new(1, -28, 1, -34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = speech,
	})
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Trait lumineux jusqu'à la cible
	beam = Instance.new("Beam")
	beam.Name = "TutorialGuide"
	beam.Color = ColorSequence.new(GUIDE_COLOR)
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.2)
	beam.Width0 = 0.7
	beam.Width1 = 0.7
	beam.FaceCamera = true
	beam.Enabled = false
	endAttachment = Instance.new("Attachment")
	endAttachment.Name = "TutorialTarget"
	endAttachment.Parent = workspace.Terrain
	beam.Attachment1 = endAttachment
	beam.Parent = workspace.Terrain
	marker = Ui.create("BillboardGui", {
		Name = "TutorialMarker",
		Size = UDim2.fromScale(5, 2.5),
		StudsOffsetWorldSpace = Vector3.new(0, 9, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		Adornee = endAttachment,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextColor3 = GUIDE_COLOR,
		Text = Texts.Get("Tutorial.Marker"),
		Parent = marker,
	})
end

local function attachToCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "TutorialGuideStart"
	attachment.Position = Vector3.new(0, -2.5, 0)
	attachment.Parent = root
	startAttachment = attachment
	beam.Attachment0 = attachment
	render()
end

function TutorialController.Init(controllers)
	UIController = controllers.UIController
end

function TutorialController.Start()
	buildGui()
	player.CharacterAdded:Connect(attachToCharacter)
	if player.Character then
		task.spawn(attachToCharacter, player.Character)
	end
	Remotes.Tutorial.OnClientEvent:Connect(function(state)
		current = state
		render()
	end)
	Remotes.MentorSay.OnClientEvent:Connect(function(message)
		table.insert(queue, UIController.Resolve(message))
		speakNext()
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			updateGuide()
		end
	end)
end

return TutorialController
