-- Événements de ville (EventService) côté client : petit bandeau en haut de l'écran (D106 : une ligne, icône, titre,
-- ce qu'il reste à trouver, temps restant et sa jauge ; la consigne seulement les premières secondes) avec une croix ;
-- fermé, il laisse une pastille ronde qui le rouvre. Repères au-dessus des objets de l'événement pour les retrouver. Le spectacle dans le monde est joué par EventFxController (D100).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local EVENT_TAG = "CityEventObject"
local GOLD = Color3.fromRGB(255, 210, 60)

local player = Players.LocalPlayer

local UIController

local BANNER = Balance.EventBanner
local banner: Frame
local pill: TextButton
local pillTimer: TextLabel
local iconLabel: TextLabel
local titleLabel: TextLabel
local descLabel: TextLabel
local timerLabel: TextLabel
local counterLabel: TextLabel
local timeBar: Frame
local current: { kind: string, endsAt: number, startedAt: number }? = nil
local dismissed = false -- le joueur a fermé le bandeau de cet événement : seule la pastille reste
local detailUntil = 0 -- la consigne reste affichée jusque-là
local markers: { BillboardGui } = {}
local busySignal = Instance.new("BindableEvent")

local EventController = {}

-- Occupé (série, aide, combat de boss du début à la fin, Dieu du Pump, duel) : l'événement ne se montre pas du tout
-- (ni bandeau, ni repères, ni messages, ni spectacle) ; il revient à la fin s'il dure encore.
local BUSY_ATTRIBUTES = { "InRun", "InFight", "InDuel" }
function EventController.IsBusy(): boolean
	for _, attribute in BUSY_ATTRIBUTES do
		if player:GetAttribute(attribute) then
			return true
		end
	end
	return false
end
EventController.BusyChanged = busySignal.Event

-- Repère visible de loin au-dessus d'un objet de l'événement
local function addMarker(object: Instance)
	if not object:IsA("BasePart") then
		return
	end
	local marker = Ui.create("BillboardGui", {
		Name = "EventMarker",
		Enabled = not EventController.IsBusy(),
		Size = UDim2.fromOffset(46, 46),
		StudsOffsetWorldSpace = Vector3.new(0, object.Size.Y / 2 + 2.5, 0),
		AlwaysOnTop = true,
		MaxDistance = 400,
		LightInfluence = 0,
		Adornee = object,
		Parent = object,
	}, {
		Ui.label({
			Size = UDim2.fromScale(1, 1),
			Text = "✦",
			TextColor3 = GOLD,
		}),
	})
	table.insert(markers, marker)
	marker.Destroying:Connect(function()
		local index = table.find(markers, marker)
		if index then
			table.remove(markers, index)
		end
	end)
end

-- Ce qu'il reste à faire : haltères et shakes encore dans la ville, plaquages avant que le piano s'arrête
local function counterText(kind: string): string
	if kind == "GoldenDumbbells" then
		return Texts.Get("Event.GoldenDumbbells.Left", { count = #CollectionService:GetTagged("EventDumbbell") })
	elseif kind == "FreeShakes" then
		return Texts.Get("Event.FreeShakes.Left", { count = #CollectionService:GetTagged("EventShake") })
	elseif kind == "RunawayPiano" then
		local piano = CollectionService:GetTagged("EventPiano")[1]
		local hits = piano and piano:GetAttribute("Hits")
		return if typeof(hits) == "number" then Texts.Get("Event.RunawayPiano.Left", { count = hits }) else ""
	end
	return ""
end

-- Emplacement : en haut à droite sur téléphone ou tablette en paysage (le centre est au HUD, la gauche au menu),
-- sous la pastille d'objectif en portrait, sous le HUD sur ordinateur
local function layoutBanner()
	local wide = false
	if Ui.isPhonePortrait() then
		banner.AnchorPoint = Vector2.new(0.5, 0)
		banner.Position = UDim2.new(0.5, 0, 0, BANNER.PortraitTop)
		wide = true
	elseif UserInputService.TouchEnabled then
		banner.AnchorPoint = Vector2.new(1, 0)
		banner.Position = UDim2.new(1, -8, 0, 8)
	else
		banner.AnchorPoint = Vector2.new(0.5, 0)
		banner.Position = UDim2.new(0.5, 0, 0, BANNER.DesktopTop)
	end
	local detail = os.clock() < detailUntil
	local height = if detail then BANNER.Height + BANNER.DetailHeight else BANNER.Height
	banner.Size = if wide then UDim2.new(1, -16, 0, height) else UDim2.fromOffset(BANNER.Width, height)
	descLabel.Visible = detail
	pill.AnchorPoint = banner.AnchorPoint
	pill.Position = banner.Position
end

-- Ce qui se voit : rien quand on est occupé ou sans événement ; sinon le bandeau, ou la pastille s'il a été fermé
local function refreshBanner()
	local show = current ~= nil and not EventController.IsBusy()
	banner.Visible = show and not dismissed
	pill.Visible = show and dismissed
end

local function showBanner(kind: string)
	titleLabel.Text = Texts.Get(`Event.{kind}.Title`)
	descLabel.Text = Texts.Get(`Event.{kind}.Desc`, { count = Events.RunawayPiano.Tackles })
	iconLabel.Text = Texts.Get(`Event.{kind}.Icon`)
	pill.Text = iconLabel.Text
	detailUntil = os.clock() + BANNER.DetailSeconds
	layoutBanner()
	refreshBanner()
end

local function onEvent(message)
	if typeof(message) ~= "table" or typeof(message.kind) ~= "string" then
		return
	end
	if message.state == "Started" then
		local endsAt = message.endsAt or workspace:GetServerTimeNow() + 60
		local duration = (Events :: any)[message.kind] and (Events :: any)[message.kind].Duration or 60
		current = { kind = message.kind, endsAt = endsAt, startedAt = endsAt - duration }
		dismissed = false
		showBanner(message.kind)
	elseif message.state == "Ended" then
		current = nil
		refreshBanner()
	elseif message.state == "Stopped" and message.name and not EventController.IsBusy() then
		UIController.Toast(Texts.Get("Event.RunawayPiano.Stopped", { name = message.name }))
	end
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "CityEvent", ResetOnSpawn = false, DisplayOrder = 2 })
	banner = Ui.panel({
		Name = "Banner",
		Visible = false,
		Parent = gui,
	})
	iconLabel = Ui.label({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(8, BANNER.Height / 2),
		Size = UDim2.fromOffset(32, 32),
		Parent = banner,
	})
	titleLabel = Ui.label({
		Position = UDim2.fromOffset(46, 5),
		Size = UDim2.new(1, -94, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		Parent = banner,
	})
	counterLabel = Ui.label({
		Position = UDim2.fromOffset(46, 26),
		Size = UDim2.new(0.6, -46, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 235, 170),
		Parent = banner,
	})
	timerLabel = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -48, 0, 26),
		Size = UDim2.new(0.4, -48, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(210, 210, 225),
		Parent = banner,
	})
	descLabel = Ui.label({
		Position = UDim2.fromOffset(10, BANNER.Height),
		Size = UDim2.new(1, -20, 0, BANNER.DetailHeight - 8),
		Font = Enum.Font.GothamMedium,
		Parent = banner,
	})
	local track = Ui.create("Frame", {
		Position = UDim2.new(0, 10, 1, -6),
		Size = UDim2.new(1, -20, 0, 3),
		BackgroundColor3 = Color3.fromRGB(50, 46, 66),
		Parent = banner,
	}, { Ui.corner(UDim.new(1, 0)) })
	timeBar = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GOLD,
		Parent = track,
	}, { Ui.corner(UDim.new(1, 0)) })
	local closeButton = Ui.closeButton({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0, BANNER.Height / 2),
		Size = UDim2.fromOffset(36, 36),
		Text = Texts.Get("Shop.Close"),
		Parent = banner,
	})
	closeButton.Activated:Connect(function()
		dismissed = true
		refreshBanner()
	end)
	-- Bandeau fermé : pastille ronde (icône de l'événement, temps restant dessous) ; la toucher le rouvre
	pill = Ui.button({
		Name = "Pill",
		Size = UDim2.fromOffset(BANNER.Height, BANNER.Height),
		BackgroundColor3 = Color3.fromRGB(60, 40, 100),
		Visible = false,
		Parent = gui,
	})
	pill:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	Ui.stroke(GOLD, 2, 0).Parent = pill
	pillTimer = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(BANNER.Height + 16, 16),
		Font = Enum.Font.GothamBold,
		Parent = pill,
	})
	pill.Activated:Connect(function()
		dismissed = false
		if current then
			showBanner(current.kind)
		end
	end)
	Ui.watchViewport(layoutBanner)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function EventController.Init(controllers)
	UIController = controllers.UIController
end

function EventController.Start()
	buildGui()
	for _, object in CollectionService:GetTagged(EVENT_TAG) do
		addMarker(object)
	end
	CollectionService:GetInstanceAddedSignal(EVENT_TAG):Connect(addMarker)
	Remotes.CityEvent.OnClientEvent:Connect(onEvent)
	local wasBusy = EventController.IsBusy()
	local function refreshBusy()
		local busy = EventController.IsBusy()
		if busy == wasBusy then
			return
		end
		wasBusy = busy
		for _, marker in markers do
			marker.Enabled = not busy
		end
		refreshBanner()
		busySignal:Fire(busy)
	end
	for _, attribute in BUSY_ATTRIBUTES do
		player:GetAttributeChangedSignal(attribute):Connect(refreshBusy)
	end
	task.spawn(function()
		while true do
			task.wait(0.25)
			if current then
				local now = workspace:GetServerTimeNow()
				local left = math.max(0, math.ceil(current.endsAt - now))
				timerLabel.Text = Texts.Get("Event.TimeLeft", { seconds = left })
				pillTimer.Text = timerLabel.Text
				if descLabel.Visible ~= (os.clock() < detailUntil) then
					layoutBanner()
				end
				local total = math.max(current.endsAt - current.startedAt, 1)
				timeBar.Size = UDim2.fromScale(math.clamp((current.endsAt - now) / total, 0, 1), 1)
				counterLabel.Text = counterText(current.kind)
			end
		end
	end)
end

return EventController
