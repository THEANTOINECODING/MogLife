-- Récompenses (D131, serveur : RewardsService, réglages : Config/Rewards.luau) :
-- - fenêtre « News » (case du menu, pastille tant que la version n'est pas vue) : nouveautés, pack de départ, groupe
--   Roblox, codes ;
-- - carte du pack de départ (une fois, après la première victoire de boss) ;
-- - carte « shaker de protéines » : Cash gagné pendant l'absence.
-- Les cartes attendent que le joueur soit libre (pas de série, de combat ni de fenêtre ouverte).
-- Le bonus d'équipe et la Golden Pump Hour s'affichent dans la colonne des badges de boost (BoostController).

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Products = require(ReplicatedStorage.Shared.Config.Products)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer
local STARTER = Products.StarterPack

local GREEN = Color3.fromRGB(46, 190, 90)
local GOLD = Color3.fromRGB(255, 196, 40)
local PURPLE = Color3.fromRGB(150, 80, 235)
local GRAY = Color3.fromRGB(90, 90, 100)

local UIController
local MinigameController
local MenuController
local SoundController

local state = {
	newsVersion = 0,
	newsSeen = 0,
	starterOwned = true,
	starterProduct = 0,
	starterRobux = 0,
	groupId = 0,
	groupClaimed = true,
}

local gui: ScreenGui
local panel: Frame
local list: ScrollingFrame
local closeButton: TextButton
local card: Frame
local cardText: TextLabel
local cardMain: TextButton
local cardOther: TextButton
local cardAction: (() -> ())? = nil
local queue: { { [string]: any } } = {}

local RewardsController = {}

local function free(): boolean
	return not MinigameController.IsGameplayLocked() and not UIController.IsStatsHidden() and not panel.Visible
end

local function priceText(robux: number): string
	return Texts.Get("Shop.BuyRobux", { price = robux })
end

-- ------------------------------------------------------------------ fenêtre News

local function row(order: number, height: number): Frame
	return Ui.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order,
		Parent = list,
	})
end

local function heading(order: number, key: string)
	Ui.label({
		Size = UDim2.new(1, 0, 0, 30),
		Text = Texts.Get(key),
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = list,
	})
end

local function render()
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	heading(nextOrder(), "News.Heading")
	for _, key in Rewards.News.Lines do
		Ui.label({
			Size = UDim2.new(1, 0, 0, 44),
			Text = Texts.Get(key),
			TextScaled = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = nextOrder(),
			Parent = list,
		})
	end

	-- Pack de départ
	if not state.starterOwned and state.starterProduct ~= 0 then
		heading(nextOrder(), "Starter.Heading")
		Ui.label({
			Size = UDim2.new(1, 0, 0, 44),
			Text = Texts.Get("Starter.Content", {
				cash = Format.Short(STARTER.cash),
				minutes = math.floor(STARTER.boostDuration / 60 + 0.5),
			}),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = nextOrder(),
			Parent = list,
		})
		local buy = Ui.button({
			Name = "BuyStarter",
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = GREEN,
			Text = priceText(state.starterRobux),
			LayoutOrder = nextOrder(),
			Parent = list,
		})
		Ui.juice(buy, function()
			Remotes.RewardsAction:FireServer("BuyStarter")
		end)
	end

	-- Groupe Roblox
	if state.groupId ~= 0 and not state.groupClaimed then
		heading(nextOrder(), "Group.Heading")
		Ui.label({
			Size = UDim2.new(1, 0, 0, 44),
			Text = Texts.Get("Group.Content", { amount = Format.Short(Rewards.Group.Cash) }),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = nextOrder(),
			Parent = list,
		})
		local buttons = row(nextOrder(), 52)
		local join = Ui.button({
			Name = "JoinGroup",
			Size = UDim2.new(0.5, -4, 1, 0),
			BackgroundColor3 = PURPLE,
			Text = Texts.Get("Group.Join"),
			Parent = buttons,
		})
		Ui.juice(join, function()
			task.spawn(function()
				pcall(function()
					GroupService:PromptJoinAsync(state.groupId)
				end)
			end)
		end)
		local claim = Ui.button({
			Name = "ClaimGroup",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.5, -4, 1, 0),
			BackgroundColor3 = GREEN,
			Text = Texts.Get("Group.Claim"),
			Parent = buttons,
		})
		Ui.juice(claim, function()
			Remotes.RewardsAction:FireServer("ClaimGroup")
		end)
	end

	-- Codes
	heading(nextOrder(), "Codes.Heading")
	local codeRow = row(nextOrder(), 52)
	local box = Ui.create("TextBox", {
		Name = "Code",
		Size = UDim2.new(0.62, -4, 1, 0),
		BackgroundColor3 = Color3.fromRGB(30, 26, 44),
		TextColor3 = Color3.new(1, 1, 1),
		PlaceholderText = Texts.Get("Codes.Placeholder"),
		PlaceholderColor3 = Color3.fromRGB(150, 150, 165),
		Text = "",
		Font = Ui.Font,
		TextScaled = true,
		ClearTextOnFocus = false,
		Parent = codeRow,
	}, {
		Ui.corner(),
		Ui.stroke(GOLD, 1.5, 0.4),
		Ui.create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		Ui.create("UITextSizeConstraint", { MaxTextSize = 26 }),
	})
	local redeem = Ui.button({
		Name = "Redeem",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.38, -4, 1, 0),
		BackgroundColor3 = GOLD,
		Text = Texts.Get("Codes.Redeem"),
		Parent = codeRow,
	})
	Ui.juice(redeem, function()
		if box.Text ~= "" then
			Remotes.RewardsAction:FireServer("Redeem", box.Text)
			box.Text = ""
		end
	end)
end

local function setOpen(open: boolean)
	panel.Visible = open
	UIController.SetStatsHidden(open, "News")
	MinigameController.SetGameplayLocked(open, "News")
	if open then
		render()
		list.CanvasPosition = Vector2.zero
		if state.newsSeen ~= state.newsVersion then
			Remotes.RewardsAction:FireServer("SeeNews")
		end
	end
end

function RewardsController.Open()
	if SoundController then
		SoundController.Play("UiTap")
	end
	setOpen(true)
end

-- Pastille rouge sur la case « News » : nouveautés pas encore vues
function RewardsController.HasNews(): boolean
	return state.newsSeen ~= state.newsVersion
end

-- ------------------------------------------------------------------ cartes (pack de départ, absence)

local function showCard(popup: { [string]: any })
	if popup.kind == "Starter" then
		cardText.Text = Texts.Get("Starter.Offer", {
			cash = Format.Short(tonumber(popup.cash) or STARTER.cash),
			minutes = tonumber(popup.minutes) or math.floor(STARTER.boostDuration / 60 + 0.5),
		})
		cardMain.Text = priceText(tonumber(popup.robux) or STARTER.robux)
		cardMain.BackgroundColor3 = GREEN
		cardMain.AnchorPoint = Vector2.new(0, 1)
		cardMain.Position = UDim2.new(0, 14, 1, -12)
		cardMain.Size = UDim2.new(0.6, -20, 0, 60)
		cardOther.Visible = true
		cardAction = function()
			Remotes.RewardsAction:FireServer("BuyStarter")
		end
	elseif popup.kind == "Away" then
		cardText.Text = Texts.Get(if popup.capped then "Away.TextCapped" else "Away.Text", {
			amount = Format.Short(tonumber(popup.cash) or 0),
			hours = tonumber(popup.hours) or 0,
		})
		cardMain.Text = Texts.Get("Away.Ok")
		cardMain.BackgroundColor3 = GOLD
		-- Bouton seul : centré
		cardMain.AnchorPoint = Vector2.new(0.5, 1)
		cardMain.Position = UDim2.new(0.5, 0, 1, -12)
		cardMain.Size = UDim2.new(0.6, 0, 0, 60)
		cardOther.Visible = false
		cardAction = nil
	else
		return
	end
	card.Visible = true
	local scale = card:FindFirstChild("Pop") :: UIScale
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if SoundController then
		SoundController.Play("UiTap")
	end
end

local function hideCard()
	card.Visible = false
	cardAction = nil
end

-- ------------------------------------------------------------------ construction

local function build()
	gui = Ui.create("ScreenGui", { Name = "Rewards", ResetOnSpawn = false, DisplayOrder = 2 })

	panel = Ui.panel({
		Name = "News",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 440),
		Visible = false,
		Parent = gui,
	})
	Ui.fitToScreen(panel)
	Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.new(1, -90, 0, 44),
		Text = Texts.Get("News.Title"),
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	closeButton = Ui.closeButton({ Parent = panel })
	Ui.onBack(closeButton, function()
		setOpen(false)
	end)
	list = Ui.create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(18, 66),
		Size = UDim2.new(1, -36, 1, -82),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		Ui.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Ui.markModal(panel, closeButton)

	card = Ui.panel({
		Name = "RewardCard",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(440, 170),
		Visible = false,
		Parent = gui,
	})
	Ui.create("UIScale", { Name = "Pop", Parent = card })
	cardText = Ui.label({
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 76),
		TextWrapped = true,
		Parent = card,
	})
	cardMain = Ui.button({
		Name = "Main",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -12),
		Size = UDim2.new(0.6, -20, 0, 60),
		BackgroundColor3 = GREEN,
		Parent = card,
	})
	cardOther = Ui.button({
		Name = "Later",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -12),
		Size = UDim2.new(0.4, -14, 0, 60),
		BackgroundColor3 = GRAY,
		Text = Texts.Get("Store.NoThanks"),
		Parent = card,
	})
	cardMain.Activated:Connect(function()
		local action = cardAction
		hideCard()
		if action then
			action()
		end
	end)
	Ui.onBack(cardOther, hideCard)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function RewardsController.Init(controllers)
	UIController = controllers.UIController
	MinigameController = controllers.MinigameController
	MenuController = controllers.MenuController
	SoundController = controllers.SoundController
end

function RewardsController.Start()
	build()
	Remotes.RewardsState.OnClientEvent:Connect(function(newState)
		if typeof(newState) ~= "table" then
			return
		end
		for key in state do
			if newState[key] ~= nil then
				state[key] = newState[key]
			end
		end
		if panel.Visible then
			render()
		end
		if MenuController then
			MenuController.Refresh()
		end
	end)
	Remotes.RewardsPopup.OnClientEvent:Connect(function(popup)
		if typeof(popup) == "table" then
			local wait = tonumber(popup.delay) or 0
			task.delay(wait, function()
				table.insert(queue, popup)
			end)
		end
	end)
	-- Les cartes attendent un moment libre, une à la fois
	task.spawn(function()
		while true do
			task.wait(1)
			if #queue > 0 and not card.Visible and free() then
				showCard(table.remove(queue, 1) :: any)
			end
		end
	end)
end

return RewardsController
