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

local function buildHud()
	local gui = Ui.create("ScreenGui", { Name = "Hud", ResetOnSpawn = false })

	local panel = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(380, 104),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0.25,
		Parent = gui,
	}, { Ui.corner() })

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
	if stats.Mog >= boss.mogRequired then
		bossLabel.Text = Texts.Get("Hud.BossReady", { boss = bossName })
	else
		bossLabel.Text = Texts.Get("Hud.NextBoss", { boss = bossName })
	end
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

function UIController.Start()
	buildHud()
	Remotes.StatsChanged.OnClientEvent:Connect(update)
	Remotes.RequestStats:FireServer()
end

return UIController
