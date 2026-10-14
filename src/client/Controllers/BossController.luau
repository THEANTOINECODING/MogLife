-- Boss côté client : fenêtre de défi (prêt / trop tôt, perte annoncée), résultats des manches,
-- défaite comique (le joueur s'envole) et écran de victoire.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer

local UIController
local MinigameController

local gui: ScreenGui
local panel: Frame
local scoreboard: TextLabel
local titleLabel: TextLabel
local lineLabel: TextLabel
local infoLabel: TextLabel
local primaryButton: TextButton
local secondaryButton: TextButton
local onPrimary: (() -> ())? = nil

local BossController = {}

local function hidePanel()
	panel.Visible = false
	onPrimary = nil
end

-- Affiche le panneau. secondaryText = nil : un seul bouton.
local function showPanel(title: string, line: string, info: string, primaryText: string, secondaryText: string?)
	titleLabel.Text = title
	lineLabel.Text = line
	infoLabel.Text = info
	primaryButton.Text = primaryText
	secondaryButton.Visible = secondaryText ~= nil
	secondaryButton.Text = secondaryText or ""
	primaryButton.Size = if secondaryText then UDim2.new(0.5, -24, 0, 60) else UDim2.new(1, -32, 0, 60)
	panel.Visible = true
end

local function bossName(bossId: string): string
	return Texts.Get(`Boss.{bossId}`)
end

local function onBossPrompt(info)
	local name = bossName(info.bossId)
	local required = Texts.Get("Boss.Required", { required = info.mogRequired, mog = math.floor(info.mog) })
	local line = Texts.Get(`BossLine.{info.bossId}`)
	MinigameController.SetGameplayLocked(true)

	local function confirm()
		hidePanel()
		Remotes.ChallengeBoss:FireServer(info.bossId)
	end

	if info.beaten then
		showPanel(name, line, Texts.Get("Boss.Rematch"), Texts.Get("Boss.Fight"), Texts.Get("Boss.Later"))
	elseif info.ready then
		local ready = Texts.Get("Boss.Ready", { cash = info.cashLoss })
		showPanel(name, line, `{required}\n{ready}`, Texts.Get("Boss.Fight"), Texts.Get("Boss.Later"))
	elseif info.blockingBossId then
		local warning = Texts.Get("Boss.NotReadyFuture", { boss = bossName(info.blockingBossId), cash = info.cashLoss })
		showPanel(name, line, `{required}\n{warning}`, Texts.Get("Boss.FightAnyway"), Texts.Get("Boss.Later"))
	else
		local warning = Texts.Get("Boss.NotReady", { cash = info.cashLoss })
		showPanel(name, line, `{required}\n{warning}`, Texts.Get("Boss.FightAnyway"), Texts.Get("Boss.Later"))
	end
	onPrimary = confirm
end

-- Le joueur se fait « mogger » d'un regard : il s'envole en arrière
local function launchPlayer()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local back = -root.CFrame.LookVector
	root.AssemblyLinearVelocity = back * 60 + Vector3.new(0, 70, 0)
	root.AssemblyAngularVelocity = Vector3.new(8, 4, 0)
end

local function showScoreboard(bossId: string?, score: number?, opponent: number?)
	scoreboard.Visible = bossId ~= nil
	if bossId then
		scoreboard.Text = Texts.Get("Boss.Scoreboard", {
			score = score or 0,
			opponent = opponent or 0,
			boss = bossName(bossId),
		})
	end
end

local function onBossUpdate(update)
	if update.state == "FightStarted" then
		showScoreboard(update.bossId, 0, 0)
	elseif update.state == "Live" then
		showScoreboard(update.bossId, update.score, update.opponent)
	elseif update.state ~= "RoundResult" then
		showScoreboard(nil)
	end

	if update.state == "Mogged" then
		hidePanel()
		MinigameController.SetGameplayLocked(false)
		launchPlayer()
		UIController.Toast(Texts.Get("Boss.Mogged", { cash = update.cash }), 3.5)
	elseif update.state == "RoundResult" then
		local key = if update.won then "Boss.RoundWon" else "Boss.RoundLost"
		UIController.Toast(Texts.Get(key, { round = update.round, score = update.score, opponent = update.opponent }))
		showScoreboard(update.bossId, 0, 0)
	elseif update.state == "Victory" then
		local name = bossName(update.bossId)
		if update.firstWin then
			local lines = {
				Texts.Get("Boss.NewStage", { stage = Texts.Get(`Stage.{update.stageId}`) }),
				Texts.Get("Boss.RewardCash", { cash = update.cash }),
			}
			if update.styleItem then
				table.insert(lines, Texts.Get("Boss.RewardItem", { item = Texts.Get(`Style.{update.styleItem}`) }))
			end
			showPanel(Texts.Get("Boss.Victory", { boss = name }), "", table.concat(lines, "\n"), Texts.Get("Boss.Ok"))
		else
			showPanel(Texts.Get("Boss.RematchWon", { boss = name }), "", "", Texts.Get("Boss.Ok"))
		end
		onPrimary = function()
			hidePanel()
			MinigameController.SetGameplayLocked(false)
		end
	elseif update.state == "Defeat" then
		local text = if (update.cash or 0) > 0
			then Texts.Get("Boss.Defeat", { boss = bossName(update.bossId), cash = update.cash })
			else Texts.Get("Boss.DefeatRematch", { boss = bossName(update.bossId) })
		showPanel(bossName(update.bossId), "", text, Texts.Get("Boss.Ok"))
		onPrimary = function()
			hidePanel()
			MinigameController.SetGameplayLocked(false)
		end
	elseif update.state == "Aborted" then
		hidePanel()
		MinigameController.SetGameplayLocked(false)
		UIController.Toast(Texts.Get("Boss.Aborted"))
	end
end

local function buildGui()
	gui = Ui.create("ScreenGui", { Name = "Boss", ResetOnSpawn = false, DisplayOrder = 5 })

	-- Score en direct pendant le Mog-off : toi contre le boss
	scoreboard = Ui.label({
		Name = "Scoreboard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 210),
		Size = UDim2.fromOffset(560, 44),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Visible = false,
		Parent = gui,
	})
	Ui.corner().Parent = scoreboard

	panel = Ui.panel({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(520, 300),
		Visible = false,
		Parent = gui,
	})
	titleLabel = Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 0, 44),
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Parent = panel,
	})
	lineLabel = Ui.label({
		Name = "Line",
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 0, 30),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(220, 220, 230),
		Parent = panel,
	})
	infoLabel = Ui.label({
		Name = "Info",
		Position = UDim2.fromOffset(16, 98),
		Size = UDim2.new(1, -32, 0, 100),
		Parent = panel,
	})
	primaryButton = Ui.button({
		Name = "Primary",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(0.5, -24, 0, 60),
		BackgroundColor3 = Color3.fromRGB(220, 120, 30),
		Parent = panel,
	})
	secondaryButton = Ui.button({
		Name = "Secondary",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0.5, -24, 0, 60),
		BackgroundColor3 = Color3.fromRGB(90, 90, 90),
		Parent = panel,
	})

	primaryButton.Activated:Connect(function()
		if onPrimary then
			onPrimary()
		end
	end)
	secondaryButton.Activated:Connect(function()
		hidePanel()
		MinigameController.SetGameplayLocked(false)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function BossController.Init(controllers)
	UIController = controllers.UIController
	MinigameController = controllers.MinigameController
end

function BossController.Start()
	buildGui()
	Remotes.BossPrompt.OnClientEvent:Connect(onBossPrompt)
	Remotes.BossUpdate.OnClientEvent:Connect(onBossUpdate)
end

return BossController
