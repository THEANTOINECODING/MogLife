-- HUD provisoire : affiche Force, Cash et Rang. À remplacer par une vraie interface plus tard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local UIController = {}

local label: TextLabel

local function formatNumber(n: number): string
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

local function buildHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 12)
	label.Size = UDim2.fromOffset(420, 44)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "Chargement..."
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	gui.Parent = player:WaitForChild("PlayerGui")
end

function UIController.Start()
	buildHud()

	Remotes.StatsChanged.OnClientEvent:Connect(function(stats)
		label.Text = `💪 {formatNumber(stats.Strength)}   💵 {formatNumber(stats.Cash)}   🏆 {stats.Rank}`
	end)
	Remotes.RequestStats:FireServer()
end

return UIController
