-- Événements de ville (EventService) côté client : bandeau d'annonce en haut de l'écran avec ce qu'il reste à
-- trouver (haltères, shakes, plaquages), le temps restant et sa jauge, et repères au-dessus des objets de
-- l'événement pour les retrouver. Le spectacle dans le monde est joué par EventFxController (D100).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Config.Events)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local EVENT_TAG = "CityEventObject"
local GOLD = Color3.fromRGB(255, 210, 60)

local player = Players.LocalPlayer

local UIController

local banner: Frame
local titleLabel: TextLabel
local descLabel: TextLabel
local timerLabel: TextLabel
local counterLabel: TextLabel
local timeBar: Frame
local current: { kind: string, endsAt: number, startedAt: number }? = nil
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

local function hideBanner()
	local tween = TweenService:Create(banner, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -220) })
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			banner.Visible = false
		end
	end)
	tween:Play()
end

local function showBanner(kind: string)
	if EventController.IsBusy() then
		return
	end
	titleLabel.Text = Texts.Get(`Event.{kind}.Title`)
	descLabel.Text = Texts.Get(`Event.{kind}.Desc`, { count = Events.RunawayPiano.Tackles })
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0, -220)
	TweenService:Create(banner, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 222), -- sous le panneau Mog / Cash du HUD
	}):Play()
end

local function onEvent(message)
	if typeof(message) ~= "table" or typeof(message.kind) ~= "string" then
		return
	end
	if message.state == "Started" then
		local endsAt = message.endsAt or workspace:GetServerTimeNow() + 60
		local duration = (Events :: any)[message.kind] and (Events :: any)[message.kind].Duration or 60
		current = { kind = message.kind, endsAt = endsAt, startedAt = endsAt - duration }
		showBanner(message.kind)
	elseif message.state == "Ended" then
		current = nil
		hideBanner()
	elseif message.state == "Stopped" and message.name and not EventController.IsBusy() then
		UIController.Toast(Texts.Get("Event.RunawayPiano.Stopped", { name = message.name }))
	end
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "CityEvent", ResetOnSpawn = false, DisplayOrder = 2 })
	banner = Ui.panel({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -220),
		Size = if Ui.isPhonePortrait() then UDim2.new(1, -20, 0, 120) else UDim2.fromOffset(460, 120),
		Visible = false,
		Parent = gui,
	})
	Ui.watchViewport(function()
		banner.Size = if Ui.isPhonePortrait() then UDim2.new(1, -20, 0, 120) else UDim2.fromOffset(460, 120)
	end)
	titleLabel = Ui.label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 36),
		TextColor3 = GOLD,
		Parent = banner,
	})
	descLabel = Ui.label({
		Position = UDim2.fromOffset(14, 46),
		Size = UDim2.new(1, -28, 0, 26),
		Font = Enum.Font.GothamMedium,
		Parent = banner,
	})
	counterLabel = Ui.label({
		Position = UDim2.fromOffset(14, 76),
		Size = UDim2.new(0.6, -14, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 235, 170),
		Parent = banner,
	})
	timerLabel = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 76),
		Size = UDim2.new(0.4, -14, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(210, 210, 225),
		Parent = banner,
	})
	local track = Ui.create("Frame", {
		Position = UDim2.new(0, 14, 1, -16),
		Size = UDim2.new(1, -28, 0, 7),
		BackgroundColor3 = Color3.fromRGB(50, 46, 66),
		Parent = banner,
	}, { Ui.corner(UDim.new(1, 0)) })
	timeBar = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GOLD,
		Parent = track,
	}, { Ui.corner(UDim.new(1, 0)) })
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
		if current then
			if busy then
				hideBanner()
			else
				showBanner(current.kind)
			end
		end
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
				local total = math.max(current.endsAt - current.startedAt, 1)
				timeBar.Size = UDim2.fromScale(math.clamp((current.endsAt - now) / total, 0, 1), 1)
				counterLabel.Text = counterText(current.kind)
			end
		end
	end)
end

return EventController
