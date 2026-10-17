-- Événements de ville (EventService) côté client : bandeau d'annonce en haut de l'écran avec le temps restant,
-- et repères au-dessus des objets de l'événement (haltères dorés, distributeur, piano) pour les retrouver.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
local current: { kind: string, endsAt: number }? = nil
local inRun = false -- pendant une série ou un combat, le bandeau laisse la place aux textes du mini-jeu

local EventController = {}

-- Repère visible de loin au-dessus d'un objet de l'événement
local function addMarker(object: Instance)
	if not object:IsA("BasePart") then
		return
	end
	Ui.create("BillboardGui", {
		Name = "EventMarker",
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
	if inRun then
		return
	end
	titleLabel.Text = Texts.Get(`Event.{kind}.Title`)
	descLabel.Text = Texts.Get(`Event.{kind}.Desc`)
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
		current = { kind = message.kind, endsAt = message.endsAt or workspace:GetServerTimeNow() + 60 }
		showBanner(message.kind)
	elseif message.state == "Ended" then
		current = nil
		hideBanner()
	elseif message.state == "Stopped" and message.name then
		UIController.Toast(Texts.Get("Event.RunawayPiano.Stopped", { name = message.name }))
	end
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "CityEvent", ResetOnSpawn = false, DisplayOrder = 2 })
	banner = Ui.panel({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -220),
		Size = UDim2.fromOffset(460, 104),
		Visible = false,
		Parent = gui,
	})
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
	timerLabel = Ui.label({
		Position = UDim2.fromOffset(14, 74),
		Size = UDim2.new(1, -28, 0, 22),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(210, 210, 225),
		Parent = banner,
	})
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
	-- Pendant ses séries et combats, le bandeau se range ; il revient après si l'événement dure encore
	Remotes.SeriesUpdate.OnClientEvent:Connect(function(update)
		if update.state == "Started" then
			inRun = true
			if current then
				hideBanner()
			end
		elseif update.state == "Ended" and update.kind ~= "Boss" then
			inRun = false
			if current then
				showBanner(current.kind)
			end
		end
	end)
	-- Combat de boss : plusieurs manches à la suite, le bandeau ne revient qu'à la fin du combat
	Remotes.BossUpdate.OnClientEvent:Connect(function(update)
		local state = update.state
		if state == "Victory" or state == "Defeat" or state == "Aborted" then
			inRun = false
			if current then
				showBanner(current.kind)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if current then
				local left = math.max(0, math.ceil(current.endsAt - workspace:GetServerTimeNow()))
				timerLabel.Text = Texts.Get("Event.TimeLeft", { seconds = left })
			end
		end
	end)
end

return EventController
