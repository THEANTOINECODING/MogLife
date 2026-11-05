-- Boosts temporaires (D47) côté client : la boutique du camion à shakes / du distributeur, et un badge sous le HUD
-- avec le boost en cours et son minuteur. Le serveur décide de tout (BoostService) ; ici, on affiche.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local SHOP_TAG = "BoostShop"

local player = Players.LocalPlayer

local MinigameController

local panel: Frame
local list: ScrollingFrame
local badge: Frame
local badgeLabel: TextLabel
local badgeBar: Frame
local cash = 0
local stage = 1
local active: { id: string?, endsAt: number } = { id = nil, endsAt = 0 }
-- Bien reposé (D111, meubles de la maison) : un second badge sous celui du boost
local rest = { bonus = 0, endsAt = 0, home = false }
local restBadge: Frame
local restLabel: TextLabel
local restBar: Frame

local BoostController = {}

local function sortedBoosts(): { string }
	local ids = {}
	for id in Boosts do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Boosts[a].order < Boosts[b].order
	end)
	return ids
end

local function render()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index, id in sortedBoosts() do
		local boost = Boosts[id]
		local row = Ui.create("Frame", {
			Name = id,
			Size = UDim2.new(1, -12, 0, 64),
			BackgroundColor3 = Color3.fromRGB(40, 35, 55),
			BackgroundTransparency = 0.2,
			LayoutOrder = index,
			Parent = list,
		}, { Ui.corner(UDim.new(0, 10)) })
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = boost.color,
			Parent = row,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.3) })
		Ui.label({
			Position = UDim2.fromOffset(60, 6),
			Size = UDim2.new(1, -210, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = Texts.Get(`Boost.{id}`),
			Parent = row,
		})
		Ui.label({
			Position = UDim2.fromOffset(60, 36),
			Size = UDim2.new(1, -210, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(200, 200, 210),
			Text = Texts.Get(
				"Boost.Effect",
				{ multiplier = boost.mogMultiplier, minutes = math.ceil(boost.duration / 60) }
			),
			Parent = row,
		})
		local locked = stage < boost.requiredStage
		local price = Format.Short(boost.price)
		local text = if locked
			then Texts.Get("Boost.Locked", { stage = Texts.Get(`Stage.{Stages.List[boost.requiredStage].id}`) })
			elseif active.id == id then Texts.Get("Boost.Extend", { price = price })
			else Texts.Get("Boost.Buy", { price = price })
		local button = Ui.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(136, 46),
			BackgroundColor3 = if locked
				then Color3.fromRGB(60, 60, 60)
				elseif cash >= boost.price then Color3.fromRGB(60, 150, 70)
				else Color3.fromRGB(110, 50, 50),
			Text = text,
			Parent = row,
		})
		button.Activated:Connect(function()
			if not locked then
				Remotes.BuyBoost:FireServer(id)
			end
		end)
	end
end

local function open()
	panel.Visible = true
	MinigameController.SetGameplayLocked(true, "Boost")
	render()
end

local function close()
	panel.Visible = false
	MinigameController.SetGameplayLocked(false, "Boost")
end

local function updateBadge()
	local remaining = active.endsAt - workspace:GetServerTimeNow()
	local boost = active.id and Boosts[active.id]
	badge.Visible = boost ~= nil and remaining > 0
	if boost and remaining > 0 then
		local minutes = math.floor(remaining / 60)
		local seconds = math.floor(remaining % 60)
		badgeLabel.Text = `{Texts.Get("Boost.Active", {
			boost = Texts.Get(`Boost.{active.id}`),
			multiplier = boost.mogMultiplier,
		})}  {string.format("%d:%02d", minutes, seconds)}`
		badgeBar.Size = UDim2.fromScale(math.clamp(remaining / boost.duration, 0, 1), 1)
		badgeBar.BackgroundColor3 = boost.color
	end

	local restLeft = rest.endsAt - workspace:GetServerTimeNow()
	restBadge.Visible = rest.bonus > 0 and (rest.home or restLeft > 0)
	if restBadge.Visible then
		local percent = Format.Gain(rest.bonus * 100)
		restLabel.Text = if rest.home
			then Texts.Get("Rest.BadgeHome", { percent = percent })
			else Texts.Get("Rest.Badge", {
				percent = percent,
				time = string.format("%d:%02d", math.floor(restLeft / 60), math.floor(restLeft % 60)),
			})
		restBar.Size = UDim2.fromScale(if rest.home then 1 else math.clamp(restLeft / Balance.Rest.Duration, 0, 1), 1)
		local below = if badge.Visible then badge.Size.Y.Offset + 4 else 0
		restBadge.Position = badge.Position + UDim2.fromOffset(0, below)
		restBadge.Size = badge.Size
	end
end

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "Boosts", ResetOnSpawn = false, DisplayOrder = 4 })

	-- Badge du boost en cours, juste sous le HUD central
	badge = Ui.create("Frame", {
		Name = "ActiveBoost",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 118),
		Size = UDim2.fromOffset(300, 30),
		BackgroundColor3 = Color3.fromRGB(25, 20, 40),
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(UDim.new(0, 8)) })
	local track = Ui.create("Frame", {
		Position = UDim2.new(0, 4, 1, -6),
		Size = UDim2.new(1, -8, 0, 3),
		BackgroundColor3 = Color3.fromRGB(60, 60, 70),
		Parent = badge,
	})
	badgeBar = Ui.create("Frame", { Size = UDim2.fromScale(1, 1), Parent = track })
	badgeLabel = Ui.label({
		Position = UDim2.fromOffset(8, 2),
		Size = UDim2.new(1, -16, 1, -8),
		Parent = badge,
	})

	restBadge = badge:Clone()
	restBadge.Name = "Rested"
	restBadge.Parent = gui
	restLabel = restBadge:FindFirstChildOfClass("TextLabel") :: TextLabel
	local restTrack = restBadge:FindFirstChildOfClass("Frame") :: Frame
	restBar = restTrack:FindFirstChildOfClass("Frame") :: Frame
	restBar.BackgroundColor3 = Color3.fromRGB(120, 200, 255)

	panel = Ui.panel({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(0.9, 0.8),
		Visible = false,
		Parent = gui,
	})
	Ui.create("UISizeConstraint", { MaxSize = Vector2.new(560, 440), Parent = panel })
	Ui.label({
		Position = UDim2.fromOffset(60, 12),
		Size = UDim2.new(1, -120, 0, 38),
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Text = Texts.Get("Boost.Title"),
		Parent = panel,
	})
	Ui.label({
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(1, -32, 0, 20),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Text = Texts.Get("Boost.Subtitle"),
		Parent = panel,
	})
	list = Ui.create("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 82),
		Size = UDim2.new(1, -32, 1, -96),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, { Ui.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local closeButton = Ui.closeButton({ Text = Texts.Get("Shop.Close"), Parent = panel })
	closeButton.Activated:Connect(close)
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Téléphone et tablette en paysage : le badge monte dans la rangée du haut, juste sous le HUD (D82). Placé sous
	-- la barre de Roblox, il tombait au milieu d'un écran de téléphone.
	Ui.watchViewport(function()
		local touchLandscape = UserInputService.TouchEnabled and not Ui.isPhonePortrait()
		gui.IgnoreGuiInset = touchLandscape
		badge.Position = if touchLandscape then UDim2.new(0.5, 0, 0, 50) else UDim2.new(0.5, 0, 0, 118)
		badge.Size = if touchLandscape then UDim2.fromOffset(230, 24) else UDim2.fromOffset(300, 30)
	end)
end

function BoostController.Init(controllers)
	MinigameController = controllers.MinigameController
end

function BoostController.Start()
	buildGui()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local parent = prompt.Parent
		if parent and CollectionService:HasTag(parent, SHOP_TAG) then
			open()
		end
	end)
	Remotes.StatsChanged.OnClientEvent:Connect(function(stats)
		cash = stats.Cash
		stage = stats.Stage or stage
		if panel.Visible then
			render()
		end
	end)
	Remotes.RestState.OnClientEvent:Connect(function(state)
		rest = { bonus = state.bonus or 0, endsAt = state.endsAt or 0, home = state.home == true }
		updateBadge()
	end)
	Remotes.BoostState.OnClientEvent:Connect(function(state)
		active = { id = state.id, endsAt = state.endsAt or 0 }
		updateBadge()
		if panel.Visible then
			render()
		end
	end)
	task.spawn(function()
		while true do
			updateBadge()
			task.wait(0.5)
		end
	end)
end

return BoostController
