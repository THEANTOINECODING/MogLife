-- HUD : Mog, Cash, progression vers le prochain boss, et messages courts (toasts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer

local UIController = {}

local mogLabel: TextLabel
local cashLabel: TextLabel
local bossLabel: TextLabel
local progressLabel: TextLabel
local barFill: Frame
local toastLabel: TextLabel
local toastToken = 0
local hudPanel: Frame

local function buildHud()
	local gui = Ui.create("ScreenGui", { Name = "Hud", ResetOnSpawn = false })

	local panel = Ui.create("Frame", {
		Name = "Stats",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(380, 104),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0.25,
		Parent = gui,
	}, { Ui.corner() })
	hudPanel = panel

	mogLabel = Ui.label({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(0.5, -15, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	cashLabel = Ui.label({
		Position = UDim2.new(0.5, 5, 0, 6),
		Size = UDim2.new(0.5, -15, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(140, 255, 140),
		Parent = panel,
	})
	bossLabel = Ui.label({
		Position = UDim2.fromOffset(10, 44),
		Size = UDim2.new(1, -20, 0, 24),
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Parent = panel,
	})

	local bar = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 72),
		Size = UDim2.new(1, -20, 0, 24),
		BackgroundColor3 = Color3.fromRGB(60, 60, 60),
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 8)) })
	barFill = Ui.create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(255, 190, 40),
		Parent = bar,
	}, { Ui.corner(UDim.new(0, 8)) })
	progressLabel = Ui.label({
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = bar,
	})

	toastLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.28),
		Size = UDim2.fromOffset(520, 48),
		Text = "",
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = gui,
	})

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function update(stats)
	mogLabel.Text = Texts.Get("Hud.Mog", { value = Format.Short(stats.Mog) })
	cashLabel.Text = Texts.Get("Hud.Cash", { value = Format.Short(stats.Cash) })

	local stage = Stages.List[stats.Stage]
	local boss = stage and stage.boss
	if not boss then
		bossLabel.Text = Texts.Get("Hud.MaxStage")
		progressLabel.Text = ""
		barFill.Size = UDim2.fromScale(1, 1)
		return
	end

	local bossName = Texts.Get(`Boss.{boss.id}`)
	local progress = math.clamp(stats.Mog / boss.mogRequired, 0, 1)
	barFill.Size = UDim2.fromScale(progress, 1)
	progressLabel.Text = Texts.Get("Hud.BossProgress", {
		current = Format.Short(math.min(stats.Mog, boss.mogRequired)),
		required = Format.Short(boss.mogRequired),
	})
	if boss.comingSoon then
		bossLabel.Text = Texts.Get("Hud.ComingSoon", { boss = bossName })
	elseif stats.Mog >= boss.mogRequired then
		bossLabel.Text = Texts.Get("Hud.BossReady", { boss = bossName })
	else
		bossLabel.Text = Texts.Get("Hud.NextBoss", { boss = bossName })
	end
end

-- Cache le panneau Mog / Cash et la carte d'objectif pendant un combat de boss (la jauge du duel les remplace, et
-- ils couvraient les annonces sur les petits écrans) ou quand une fenêtre est ouverte (boutique, garde-robe,
-- réglages). Plusieurs raisons peuvent se cumuler : le panneau revient quand il n'y en a plus aucune.
local hideReasons: { [string]: boolean } = {}
local ObjectiveController
function UIController.SetStatsHidden(hidden: boolean, reason: string?)
	hideReasons[reason or "Default"] = if hidden then true else nil
	local anyReason = next(hideReasons) ~= nil
	hudPanel.Visible = not anyReason
	if ObjectiveController then
		ObjectiveController.SetHidden(anyReason)
	end
end

function UIController.Init(controllers)
	ObjectiveController = controllers.ObjectiveController
end

-- Affiche un message court au centre de l'écran.
function UIController.Toast(text: string, duration: number?)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.TextTransparency = 0
	toastLabel.TextStrokeTransparency = 0.4
	task.delay(duration or 2.5, function()
		if token ~= toastToken then
			return
		end
		TweenService:Create(toastLabel, TweenInfo.new(0.4), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
	end)
end

-- Résout un message du serveur : { key, args }. Un argument { key = "..." } est lui-même traduit.
function UIController.Resolve(message: { key: string, args: { [string]: any }? }): string
	local args = {}
	if message.args then
		for name, value in message.args do
			if typeof(value) == "table" and value.key then
				args[name] = Texts.Get(value.key, value.args)
			elseif typeof(value) == "number" then
				args[name] = Format.Short(value)
			else
				args[name] = value
			end
		end
	end
	return Texts.Get(message.key, args)
end

function UIController.Start()
	buildHud()
	Remotes.StatsChanged.OnClientEvent:Connect(update)
	Remotes.Notify.OnClientEvent:Connect(function(message)
		UIController.Toast(UIController.Resolve(message))
	end)
	Remotes.RequestStats:FireServer()
end

return UIController
