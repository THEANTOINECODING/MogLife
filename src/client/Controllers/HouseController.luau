-- Maisons visitables (D112) :
-- - Pendant la visite de la maison d'un autre joueur, une pastille en bas de l'écran montre à qui elle est et ses
--   « J'aime », avec le bouton ❤ (actif après quelques secondes de visite ; touche L ou flèche haut de la manette).
-- - Le menu ouvre le classement des maisons : celles du serveur (bouton pour y aller) et le classement mondial.
-- Le serveur décide de tout (HouseService) : le client affiche et demande.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage.Shared.Format)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local LIKE = Color3.fromRGB(230, 70, 110)
local WAIT = Color3.fromRGB(90, 90, 105)
local DONE = Color3.fromRGB(70, 170, 95)
local VISIT = Color3.fromRGB(40, 140, 200)

local player = Players.LocalPlayer

local MinigameController
local UIController
local ShopController

type State = { visiting: number?, name: string?, likes: number, liked: boolean?, canLike: boolean? }

local state: State = { likes = 0 }
local pill: Frame
local pillTitle: TextLabel
local likeButton: TextButton
local panel: Frame
local list: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local emptyLabel: TextLabel
local tab = "server"
local ranking = { server = {}, global = {} }

local HouseController = {}

-- ------------------------------------------------------------------ pastille de visite

local function renderPill()
	local visiting = state.visiting ~= nil and not MinigameController.IsGameplayLocked() and not panel.Visible
	pill.Visible = visiting
	if not state.visiting then
		return
	end
	pillTitle.Text = Texts.Get("House.Visiting", { name = state.name or "?", likes = Format.Short(state.likes) })
	if state.liked then
		likeButton.Text = Texts.Get("House.Liked")
		likeButton.BackgroundColor3 = DONE
		likeButton.AutoButtonColor = false
	elseif state.canLike then
		likeButton.Text = Texts.Get("House.Like")
		likeButton.BackgroundColor3 = LIKE
		likeButton.AutoButtonColor = true
	else
		likeButton.Text = Texts.Get("House.LookAround")
		likeButton.BackgroundColor3 = WAIT
		likeButton.AutoButtonColor = false
	end
end

local function like()
	if state.visiting and state.canLike and not state.liked and pill.Visible then
		Remotes.LikeHouse:FireServer(state.visiting)
		local scale = likeButton:FindFirstChildOfClass("UIScale") :: UIScale
		scale.Scale = 1.2
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

local function layoutPill()
	local phone = Ui.isPhonePortrait()
	pill.Size = if phone then UDim2.new(1, -24, 0, 58) else UDim2.fromOffset(420, 62)
	-- Sur écran tactile, au-dessus du joystick et du bouton de saut
	pill.Position = if UserInputService.TouchEnabled then UDim2.new(0.5, 0, 1, -150) else UDim2.new(0.5, 0, 1, -24)
end

-- ------------------------------------------------------------------ classement

local function clearRows()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function renderRanking()
	clearRows()
	for key, button in tabButtons do
		button.BackgroundColor3 = if key == tab then Color3.fromRGB(255, 190, 60) else Color3.fromRGB(70, 60, 95)
	end
	local rows = ranking[tab] or {}
	emptyLabel.Visible = #rows == 0
	emptyLabel.Text = Texts.Get(if tab == "server" then "House.EmptyServer" else "House.EmptyGlobal")
	for index, entry in rows do
		local row = Ui.create("Frame", {
			Name = `Row{index}`,
			LayoutOrder = index,
			Size = UDim2.new(1, -8, 0, 56),
			BackgroundColor3 = if entry.mine then Color3.fromRGB(70, 60, 30) else Color3.fromRGB(40, 35, 55),
			BackgroundTransparency = 0.2,
			Parent = list,
		}, { Ui.corner(UDim.new(0, 10)) })
		Ui.label({
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(40, 40),
			Text = Texts.Get("House.Rank", { rank = index }),
			TextColor3 = if index <= 3 then Color3.fromRGB(255, 210, 90) else Color3.new(1, 1, 1),
			Parent = row,
		})
		local hasVisit = tab == "server" and not entry.mine
		Ui.label({
			Position = UDim2.fromOffset(54, 4),
			Size = UDim2.new(1, if hasVisit then -170 else -64, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = entry.name,
			Parent = row,
		})
		local detail = if tab == "server"
			then Texts.Get("House.RowServer", {
				likes = Format.Short(entry.likes),
				comfort = Format.Short(entry.comfort),
			})
			else Texts.Get("House.RowGlobal", { likes = Format.Short(entry.likes) })
		Ui.label({
			Position = UDim2.fromOffset(54, 31),
			Size = UDim2.new(1, if hasVisit then -170 else -64, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(210, 205, 225),
			Text = detail,
			Parent = row,
		})
		if hasVisit then
			local visit = Ui.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(104, 44),
				BackgroundColor3 = if entry.liked then DONE else VISIT,
				Text = Texts.Get(if entry.liked then "House.VisitLiked" else "House.Visit"),
				Parent = row,
			})
			visit.Activated:Connect(function()
				Remotes.VisitHouse:FireServer(entry.userId)
				HouseController.Close()
			end)
		end
	end
	list.CanvasSize = UDim2.fromOffset(0, #rows * 64)
end

local function setPanel(visible: boolean)
	panel.Visible = visible
	UIController.SetStatsHidden(visible, "Houses")
	MinigameController.SetGameplayLocked(visible, "Houses")
	renderPill()
end

function HouseController.Open()
	if MinigameController.IsGameplayLocked() or ShopController.IsOpen() then
		return
	end
	setPanel(true)
	renderRanking()
	Remotes.HouseRankingRequest:FireServer()
end

function HouseController.Close()
	if panel.Visible then
		setPanel(false)
	end
end

function HouseController.IsOpen(): boolean
	return panel ~= nil and panel.Visible
end

-- ------------------------------------------------------------------ construction

local function buildGui()
	local gui = Ui.create("ScreenGui", { Name = "Houses", ResetOnSpawn = false, DisplayOrder = 2 })

	pill = Ui.panel({
		Name = "VisitPill",
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		Parent = gui,
	})
	pillTitle = Ui.label({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -150, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pill,
	})
	likeButton = Ui.button({
		Name = "Like",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0, 124, 1, -12),
		BackgroundColor3 = WAIT,
		Parent = pill,
	})
	Ui.create("UIScale", { Parent = likeButton })
	likeButton.Activated:Connect(like)

	panel = Ui.panel({
		Name = "RankingPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0, 480, 1, -20),
		Visible = false,
		Parent = gui,
	})
	Ui.create("UISizeConstraint", { MaxSize = Vector2.new(480, 620), Parent = panel })
	Ui.label({
		Position = UDim2.fromOffset(60, 12),
		Size = UDim2.new(1, -120, 0, 40),
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Text = Texts.Get("House.Title"),
		Parent = panel,
	})
	for index, key in { "server", "global" } do
		local button = Ui.button({
			Name = key,
			Position = UDim2.new((index - 1) * 0.5, if index == 1 then 16 else 4, 0, 60),
			Size = UDim2.new(0.5, -20, 0, 40),
			Text = Texts.Get(if key == "server" then "House.TabServer" else "House.TabGlobal"),
			Parent = panel,
		})
		tabButtons[key] = button
		button.Activated:Connect(function()
			tab = key
			renderRanking()
		end)
	end
	Ui.label({
		Position = UDim2.fromOffset(16, 106),
		Size = UDim2.new(1, -32, 0, 22),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(210, 205, 225),
		Text = Texts.Get("House.Hint"),
		Parent = panel,
	})
	list = Ui.create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(16, 134),
		Size = UDim2.new(1, -32, 1, -150),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	})
	Ui.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	emptyLabel = Ui.label({
		Position = UDim2.fromOffset(16, 150),
		Size = UDim2.new(1, -32, 0, 60),
		Font = Enum.Font.GothamMedium,
		Visible = false,
		Parent = panel,
	})
	local closeButton = Ui.closeButton({ Text = Texts.Get("Shop.Close"), Parent = panel })
	closeButton.Activated:Connect(HouseController.Close)

	gui.Parent = player:WaitForChild("PlayerGui")
	Ui.watchViewport(function()
		layoutPill()
		panel.Size = if Ui.isPhonePortrait() then UDim2.new(1, -20, 1, -20) else UDim2.new(0, 480, 1, -20)
	end)
end

function HouseController.Init(controllers)
	MinigameController = controllers.MinigameController
	UIController = controllers.UIController
	ShopController = controllers.ShopController
end

function HouseController.Start()
	buildGui()
	Remotes.HouseState.OnClientEvent:Connect(function(new)
		if typeof(new) == "table" then
			state = new
			renderPill()
		end
	end)
	Remotes.HouseRanking.OnClientEvent:Connect(function(new)
		if typeof(new) == "table" then
			ranking = { server = new.server or {}, global = new.global or {} }
			if panel.Visible then
				renderRanking()
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.L or input.KeyCode == Enum.KeyCode.DPadUp then
			like()
		elseif panel.Visible and (input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Escape) then
			HouseController.Close()
		end
	end)
	-- La pastille se cache pendant les activités et les fenêtres
	local wasLocked = false
	RunService.Heartbeat:Connect(function()
		local locked = MinigameController.IsGameplayLocked()
		if locked ~= wasLocked then
			wasLocked = locked
			renderPill()
		end
	end)
end

return HouseController
