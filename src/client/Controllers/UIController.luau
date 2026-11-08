-- HUD : Mog, Cash, progression vers le prochain boss, et messages courts (toasts).
-- Interface vivante (D84) : les compteurs défilent jusqu'à leur nouvelle valeur et rebondissent quand ils montent ;
-- FlyToCounter fait s'envoler des icônes (billets, muscles) vers le compteur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Format = require(ReplicatedStorage.Shared.Format)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer

local UIController = {}

local bossLabel: TextLabel
local progressLabel: TextLabel
local barFill: Frame
local toastLabel: TextLabel
local toastToken = 0
local hudPanel: Frame
local progressBar: Frame
local chipRow: Frame

-- Pastilles Mog et Cash (D124) : pièce ronde illustrée à gauche, gros nombre cerné, bouton « + » à droite (boutique
-- Robux) ; barre du prochain boss dessous sur ordinateur. Plus de cadre sombre autour : le jeu reste visible.
local function layoutHud()
	local gui = hudPanel.Parent :: ScreenGui
	if UserInputService.TouchEnabled then
		local phone = Ui.isPhonePortrait()
		-- Paysage : le HUD monte dans la rangée de la barre de Roblox, au centre (libre), pour ne pas cacher le jeu
		-- (D82). Portrait : les boutons de Roblox occupent le haut à gauche, il reste dessous.
		gui.IgnoreGuiInset = not phone
		hudPanel.AnchorPoint = if phone then Vector2.zero else Vector2.new(0.5, 0)
		hudPanel.Position = if phone then UDim2.fromOffset(14, 10) else UDim2.new(0.5, 0, 0, 8)
		hudPanel.Size = if phone then UDim2.new(1, -28, 0, 40) else UDim2.fromOffset(300, 38)
		chipRow.Size = UDim2.fromScale(1, 1)
		bossLabel.Visible = false
		progressBar.Visible = false
		toastLabel.Size = UDim2.new(1, -24, 0, 48)
	else
		gui.IgnoreGuiInset = false
		hudPanel.AnchorPoint = Vector2.new(0.5, 0)
		hudPanel.Position = UDim2.new(0.5, 0, 0, 10)
		hudPanel.Size = UDim2.fromOffset(380, 104)
		chipRow.Size = UDim2.new(1, 0, 0, 44)
		bossLabel.Visible = true
		progressBar.Visible = true
		toastLabel.Size = UDim2.fromOffset(560, 52)
	end
end

-- Compteurs qui défilent : une valeur affichée par compteur, qui glisse vers la vraie valeur
local UI_FX = Balance.HudFx
type Counter = {
	label: TextLabel,
	chip: Frame,
	coin: Frame,
	value: NumberValue,
	scale: UIScale,
	target: number?,
	color: Color3,
}
local counters: { [string]: Counter } = {}
local toastStroke: UIStroke

-- Pastille d'un compteur : pièce ronde à gauche (qui dépasse), nombre, place pour le « + » à droite
local function chip(name: string, icon: string, coinColor: Color3, textColor: Color3, order: number): Counter
	local frame = Ui.create("Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(0.5, -20, 1, 0),
		BackgroundColor3 = Ui.Dark,
		BackgroundTransparency = 0.15,
		Parent = chipRow,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Ui.Ink, 2.5) })
	local coin = Ui.create("Frame", {
		Name = "Coin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1.22, 1.22),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = frame,
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.gradient(Ui.shade(coinColor, 1.35), coinColor),
		Ui.stroke(Ui.Ink, 2.5),
	})
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		Text = icon,
		TextStrokeTransparency = 1,
		ZIndex = 4,
		Parent = coin,
	})
	local label = Ui.label({
		Name = "Value",
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = textColor,
		ZIndex = 2,
		Parent = frame,
	})
	Ui.outline(label, 2.5)
	-- Le nombre commence juste après la pièce et s'arrête avant le « + »
	local function fit()
		local height = frame.AbsoluteSize.Y
		label.Position = UDim2.new(0, math.floor(height * 0.72), 0.5, 0)
		label.Size = UDim2.new(1, -math.floor(height * 0.72) - math.floor(height * 1.02), 0.68, 0)
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	local value = Instance.new("NumberValue")
	local scale = Instance.new("UIScale")
	scale.Parent = coin
	local entry = {
		label = label,
		chip = frame,
		coin = coin,
		value = value,
		scale = scale,
		target = nil,
		color = textColor,
	}
	value.Changed:Connect(function(current)
		label.Text = Format.Short(current)
	end)
	counters[name] = entry
	return entry
end

-- Petit rebond de la pièce (et un éclair de couleur sur le nombre)
local function pulse(entry: Counter, color: Color3?)
	entry.scale.Scale = UI_FX.PulseScale
	TweenService:Create(entry.scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	if color then
		entry.label.TextColor3 = color
		TweenService:Create(entry.label, TweenInfo.new(0.6), { TextColor3 = entry.color }):Play()
	end
end

local function setCounter(entry: Counter, target: number)
	local previous = entry.target
	entry.target = target
	if previous == nil then
		entry.value.Value = target
		entry.label.Text = Format.Short(target)
		return
	end
	if target == previous then
		return
	end
	TweenService:Create(entry.value, TweenInfo.new(UI_FX.RollTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Value = target,
	}):Play()
	if target > previous then
		pulse(entry, UI_FX.GainColor)
	end
end

-- Des icônes s'envolent du milieu de l'écran vers un compteur (« Cash » ou « Mog »), puis le compteur rebondit
local fxGui: ScreenGui
function UIController.FlyToCounter(name: string, count: number?)
	local entry = counters[name]
	if not entry or not hudPanel.Visible or not fxGui then
		return
	end
	local hudGui = hudPanel.Parent :: ScreenGui
	fxGui.IgnoreGuiInset = hudGui.IgnoreGuiInset
	local target = entry.coin.AbsolutePosition + entry.coin.AbsoluteSize / 2
	local screen = fxGui.AbsoluteSize
	local start = Vector2.new(screen.X * 0.5, screen.Y * 0.55)
	local icon = Texts.Get(if name == "Cash" then "Hud.CashIcon" else "Hud.FlyMog")
	for index = 1, count or UI_FX.FlyCount do
		task.delay((index - 1) * UI_FX.FlyStagger, function()
			local label = Ui.label({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(start.X + math.random(-60, 60), start.Y + math.random(-30, 30)),
				Size = UDim2.fromOffset(40, 40),
				Text = icon,
				TextStrokeTransparency = 1,
				ZIndex = 10,
				Parent = fxGui,
			})
			-- Petit envol sur place, puis vol jusqu'au compteur
			local burst = label.Position + UDim2.fromOffset(math.random(-50, 50), math.random(-70, -30))
			local up =
				TweenService:Create(label, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = burst,
				})
			up:Play()
			up.Completed:Wait()
			local fly = TweenService:Create(
				label,
				TweenInfo.new(UI_FX.FlyTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					Position = UDim2.fromOffset(target.X, target.Y),
					Size = UDim2.fromOffset(24, 24),
				}
			)
			fly:Play()
			fly.Completed:Wait()
			label:Destroy()
			pulse(entry, nil)
		end)
	end
end

local function buildHud()
	local gui = Ui.create("ScreenGui", { Name = "Hud", ResetOnSpawn = false })

	local panel = Ui.create("Frame", {
		Name = "Stats",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(380, 104),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	hudPanel = panel

	-- Rangée des deux pastilles ; la pièce dépasse à gauche de chacune, d'où l'écart entre elles
	chipRow = Ui.create("Frame", {
		Name = "Chips",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 28),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Ui.create("UIPadding", { PaddingLeft = UDim.new(0, 12) }),
	})
	chip("Mog", Texts.Get("Hud.MogIcon"), Color3.fromRGB(255, 176, 0), Color3.new(1, 1, 1), 1)
	chip("Cash", Texts.Get("Hud.CashIcon"), Color3.fromRGB(47, 191, 69), Color3.fromRGB(182, 255, 158), 2)

	bossLabel = Ui.label({
		Position = UDim2.fromOffset(10, 50),
		Size = UDim2.new(1, -20, 0, 22),
		TextColor3 = Color3.fromRGB(255, 224, 102),
		Parent = panel,
	})
	Ui.outline(bossLabel, 2.5)

	-- Barre du prochain boss : piste sombre, remplissage doré avec un reflet
	local bar = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 76),
		Size = UDim2.new(1, -20, 0, 24),
		BackgroundColor3 = Color3.fromRGB(42, 35, 64),
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Ui.Ink, 2.5) })
	progressBar = bar
	barFill = Ui.create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = bar,
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.gradient(Color3.fromRGB(255, 230, 128), Color3.fromRGB(255, 176, 0)),
	})
	Ui.create("Frame", {
		Name = "Gloss",
		Position = UDim2.new(0, 6, 0.1, 0),
		Size = UDim2.new(1, -12, 0.34, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.6,
		Parent = barFill,
	}, { Ui.corner(UDim.new(1, 0)) })
	progressLabel = Ui.label({
		Position = UDim2.fromScale(0, 0.1),
		Size = UDim2.fromScale(1, 0.8),
		ZIndex = 2,
		Parent = bar,
	})
	Ui.outline(progressLabel, 2)

	toastLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.28),
		Size = UDim2.fromOffset(560, 52),
		Text = "",
		TextTransparency = 1,
		Parent = gui,
	})
	toastStroke = Ui.outline(toastLabel, 3)
	toastStroke.Transparency = 1

	gui.Parent = player:WaitForChild("PlayerGui")
	Ui.watchViewport(layoutHud)
	fxGui = Ui.create("ScreenGui", { Name = "HudFx", ResetOnSpawn = false, DisplayOrder = 30 })
	fxGui.Parent = player:WaitForChild("PlayerGui")
end

local function update(stats)
	setCounter(counters.Mog, stats.Mog)
	setCounter(counters.Cash, stats.Cash)

	local stage = Stages.List[stats.Stage]
	local boss = stage and stage.boss
	if not boss then
		bossLabel.Text = Texts.Get("Hud.MaxStage")
		progressLabel.Text = ""
		barFill.Visible = true
		barFill.Size = UDim2.fromScale(1, 1)
		return
	end

	local bossName = Texts.Get(`Boss.{boss.id}`)
	local progress = math.clamp(stats.Mog / boss.mogRequired, 0, 1)
	-- Remplissage jamais plus fin que ses coins ronds (sinon il se déforme) ; caché à zéro
	barFill.Visible = progress > 0
	barFill.Size = UDim2.fromScale(math.max(progress, 0.07), 1)
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

-- Petit bouton « + » rond dans la pastille d'un compteur (« Mog » ou « Cash ») : ouvre la boutique Robux
-- (StoreController, D122)
function UIController.AttachCounterButton(name: string, color: Color3, onClick: () -> ()): TextButton?
	local entry = counters[name]
	if not entry then
		return nil
	end
	local button = Ui.create("TextButton", {
		Name = "Buy" .. name,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -3, 0.5, 0),
		Size = UDim2.fromScale(0.8, 0.8),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Font = Ui.Font,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = Texts.Get("Hud.Buy"),
		ZIndex = 3,
		Parent = entry.chip,
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.gradient(Ui.shade(color, 1.4), color),
		Ui.stroke(Ui.Ink, 2.5),
		Ui.create("UIPadding", {
			PaddingTop = UDim.new(0.1, 0),
			PaddingBottom = UDim.new(0.14, 0),
		}),
	})
	Ui.outline(button, 2)
	Ui.juice(button)
	button.Activated:Connect(onClick)
	return button
end

-- Cache le panneau Mog / Cash et la carte d'objectif pendant un combat de boss (la jauge du duel les remplace, et
-- ils couvraient les annonces sur les petits écrans) ou quand une fenêtre est ouverte (boutique, garde-robe,
-- réglages). Plusieurs raisons peuvent se cumuler : le panneau revient quand il n'y en a plus aucune.
local hideReasons: { [string]: boolean } = {}
local hiddenListeners: { () -> () } = {}
local ObjectiveController
function UIController.SetStatsHidden(hidden: boolean, reason: string?)
	hideReasons[reason or "Default"] = if hidden then true else nil
	local anyReason = next(hideReasons) ~= nil
	hudPanel.Visible = not anyReason
	if ObjectiveController then
		ObjectiveController.SetHidden(anyReason)
	end
	for _, listener in hiddenListeners do
		task.spawn(listener)
	end
end

-- Le HUD est-il rangé en ce moment (fenêtre ouverte, série, combat) ?
function UIController.IsStatsHidden(): boolean
	return next(hideReasons) ~= nil
end

-- Prévenir `listener` à chaque fois que le HUD est rangé ou revient (le menu de gauche suit le même rythme)
function UIController.OnStatsHiddenChanged(listener: () -> ())
	table.insert(hiddenListeners, listener)
end

function UIController.Init(controllers)
	ObjectiveController = controllers.ObjectiveController
end

-- Messages en attente : plusieurs messages arrivés ensemble (fin d'une aide : merci, dress code, pourboire)
-- s'affichent l'un après l'autre au lieu de s'écraser. Chacun reste au moins TOAST_MIN secondes s'il en reste.
local TOAST_MIN = 1.6
local TOAST_QUEUE_MAX = 4
local toastQueue: { { text: string, duration: number } } = {}
local toastShownAt = -math.huge
local toastPumping = false

local function showToast(text: string, duration: number)
	toastToken += 1
	local token = toastToken
	toastShownAt = os.clock()
	toastLabel.Text = text
	toastLabel.TextTransparency = 0
	toastStroke.Transparency = 0
	-- Le message arrive en claquant (un peu trop gros, puis à sa taille)
	local scale = toastLabel:FindFirstChildOfClass("UIScale") or Ui.create("UIScale", { Parent = toastLabel })
	scale.Scale = 1.25
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	task.delay(duration, function()
		if token ~= toastToken then
			return
		end
		TweenService:Create(toastLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(toastStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	end)
end

local function pumpToasts()
	if toastPumping then
		return
	end
	toastPumping = true
	task.spawn(function()
		while #toastQueue > 0 do
			local wait = TOAST_MIN - (os.clock() - toastShownAt)
			if wait > 0 then
				task.wait(wait)
			end
			local nextToast = table.remove(toastQueue, 1)
			if nextToast then
				showToast(nextToast.text, nextToast.duration)
			end
		end
		toastPumping = false
	end)
end

-- Affiche un message court au centre de l'écran.
function UIController.Toast(text: string, duration: number?)
	-- Le même message répété (deux clics) ne s'empile pas
	local last = toastQueue[#toastQueue]
	if
		(last and last.text == text)
		or (#toastQueue == 0 and toastLabel.Text == text and toastLabel.TextTransparency < 1)
	then
		return
	end
	if #toastQueue >= TOAST_QUEUE_MAX then
		table.remove(toastQueue, 1)
	end
	table.insert(toastQueue, { text = text, duration = duration or 2.5 })
	pumpToasts()
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
