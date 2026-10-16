-- Boss côté client : fenêtre de défi (prêt / trop tôt, perte annoncée), puis la mise en scène du Mog-off (D50) :
-- - présentation : bandeau VS (toi contre le boss, sa réplique), compte à rebours 3-2-1-MOG! ;
-- - caméra de duel qui cadre le joueur et le boss (à gauche du mini-jeu) ;
-- - jauge de Mog en direct (toi contre lui) et pastilles des manches gagnées / perdues ;
-- - annonce de chaque manche (« plus rapide »), le boss qui nargue ou panique selon le score ;
-- - « MOGGED! » géant à la victoire, avant les récompenses. Défaite automatique : le joueur s'envole.
-- Le serveur décide de tout (BossService) ; ici, on met en scène.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local GOLD = Color3.fromRGB(255, 210, 60)
local RED = Color3.fromRGB(230, 60, 60)
local GREEN = Color3.fromRGB(90, 220, 90)
local BOSS_SPOT_TAG = "BossSpot"

local player = Players.LocalPlayer

local UIController
local MinigameController
local CutsceneController

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local lineLabel: TextLabel
local infoLabel: TextLabel
local primaryButton: TextButton
local secondaryButton: TextButton
local onPrimary: (() -> ())? = nil

-- Mise en scène du combat
local vsBand: Frame
local vsBossLabel: TextLabel
local vsLineLabel: TextLabel
local bigLabel: TextLabel -- compte à rebours, annonces de manche, MOGGED!
local subLabel: TextLabel
local meter: Frame
local meterFill: Frame
local meterYou: TextLabel
local meterBoss: TextLabel
local pips: { Frame } = {}
local pipsFrame: Frame
local fight: { bossId: string, rounds: number, results: { boolean } }? = nil
local cameraConnection: RBXScriptConnection? = nil

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

-- Le modèle du boss affronté : le PNJ de l'emplacement de ce boss le plus proche du joueur
local function bossModel(bossId: string): Model?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local folder = workspace:FindFirstChild("Npcs")
	if not root or not folder then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, spot in CollectionService:GetTagged(BOSS_SPOT_TAG) do
		if spot:IsA("BasePart") and spot:GetAttribute("BossId") == bossId then
			local distance = (spot.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = spot, distance
			end
		end
	end
	if not best then
		return nil
	end
	local model, modelDistance = nil, 15
	for _, candidate in folder:GetChildren() do
		if candidate:IsA("Model") then
			local distance = (candidate:GetPivot().Position - best.Position).Magnitude
			if distance < modelDistance then
				model, modelDistance = candidate, distance
			end
		end
	end
	return model
end

-- Grand texte au centre : apparaît en grossissant, puis s'efface
local function shout(text: string, color: Color3, sub: string?, hold: number?)
	bigLabel.Text = text
	bigLabel.TextColor3 = color
	subLabel.Text = sub or ""
	for _, label in { bigLabel, subLabel } do
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0.2
	end
	bigLabel.Size = UDim2.fromScale(0.9, 0.24)
	TweenService:Create(bigLabel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(0.7, 0.16),
	}):Play()
	local fade = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, hold or 0.7)
	for _, label in { bigLabel, subLabel } do
		TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end
end

-- Bulle au-dessus du boss (il nargue ou panique)
local function bossSays(bossId: string, key: string)
	local model = bossModel(bossId)
	local adornee = model
		and (model.PrimaryPart or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart"))
	if not adornee or not Texts.Has(key) then
		return
	end
	local old = adornee:FindFirstChild("BossTaunt")
	if old then
		old:Destroy()
	end
	local bubble = Ui.create("BillboardGui", {
		Name = "BossTaunt",
		Size = UDim2.fromScale(12, 3),
		StudsOffsetWorldSpace = Vector3.new(0, (adornee :: BasePart).Size.Y / 2 + 3, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Adornee = adornee,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = bubble,
	}, {
		Ui.corner(UDim.new(0.3, 0)),
		Ui.stroke(Color3.fromRGB(30, 30, 30), 3, 0),
		Ui.label({
			Position = UDim2.fromScale(0.05, 0.1),
			Size = UDim2.fromScale(0.9, 0.8),
			TextColor3 = Color3.fromRGB(30, 30, 30),
			TextStrokeTransparency = 1,
			TextWrapped = true,
			Text = Texts.Get(key),
		}),
	})
	task.delay(3, function()
		bubble:Destroy()
	end)
end

-- Caméra de duel : le joueur et le boss de profil, décalés à gauche (le mini-jeu est à droite)
local function startDuelCamera(bossId: string)
	local camera = workspace.CurrentCamera
	local model = bossModel(bossId)
	if not camera or not model then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local startCF = camera.CFrame
	local t0 = os.clock()
	cameraConnection = RunService.RenderStepped:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not model.Parent then
			return
		end
		local you, them = root.Position, model:GetPivot().Position
		local mid = (you + them) / 2
		local axis = Vector3.new(them.X - you.X, 0, them.Z - you.Z)
		local gap = math.max(axis.Magnitude, 6)
		axis = if axis.Magnitude > 0.1 then axis.Unit else Vector3.xAxis
		local side = Vector3.new(0, 1, 0):Cross(axis)
		local focus = mid + Vector3.new(0, 2.5, 0) + side * (gap * 0.25)
		local eye = mid + side * (gap * 1.25 + 6) + Vector3.new(0, 5, 0)
		local wanted = CFrame.lookAt(eye, focus)
		-- Entrée en douceur depuis la caméra du joueur
		local blend = math.clamp((os.clock() - t0) / 0.8, 0, 1)
		camera.CFrame = startCF:Lerp(wanted, blend * blend * (3 - 2 * blend))
	end)
end

local function stopDuelCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function setMeter(score: number, opponent: number)
	local total = score + opponent
	local share = if total > 0 then score / total else 0.5
	TweenService:Create(meterFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(share, 1) }):Play()
	meterYou.Text = `{Texts.Get("Boss.You")} {score}`
	meterBoss.Text = `{opponent}`
end

local function renderPips()
	if not fight then
		return
	end
	for _, pip in pips do
		pip:Destroy()
	end
	table.clear(pips)
	for round = 1, fight.rounds do
		local result = fight.results[round]
		local pip = Ui.create("Frame", {
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = if result == true
				then GREEN
				elseif result == false then RED
				else Color3.fromRGB(70, 70, 80),
			LayoutOrder = round,
			Parent = pipsFrame,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.2) })
		table.insert(pips, pip)
	end
end

local function endPresentation()
	fight = nil
	meter.Visible = false
	vsBand.Visible = false
	stopDuelCamera()
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

-- Présentation : bandeau VS, réplique du boss, puis 3-2-1-MOG! calé sur la durée annoncée par le serveur
local function intro(bossId: string, duration: number)
	vsBossLabel.Text = bossName(bossId)
	vsLineLabel.Text = Texts.Get(`BossLine.{bossId}`)
	vsBand.Visible = true
	vsBand.Position = UDim2.fromScale(-1, 0.3)
	TweenService:Create(vsBand, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0, 0.3),
	}):Play()
	local countStart = math.max(duration - 3.4, 0.5)
	task.delay(countStart - 0.3, function()
		vsBand.Visible = false
	end)
	for k, text in { "3", "2", "1" } do
		task.delay(countStart + (k - 1) * 0.8, function()
			if fight and fight.bossId == bossId then
				shout(text, Color3.new(1, 1, 1), nil, 0.25)
			end
		end)
	end
	task.delay(countStart + 2.4, function()
		if fight and fight.bossId == bossId then
			shout(Texts.Get("Boss.Go"), GOLD, nil, 0.4)
		end
	end)
end

local function onBossUpdate(update)
	if update.state == "FightStarted" then
		hidePanel()
		fight = { bossId = update.bossId, rounds = update.rounds or 3, results = {} }
		meter.Visible = true
		setMeter(0, 0)
		renderPips()
		intro(update.bossId, update.intro or 4)
		-- Entrée en scène (D53) : la caméra tourne autour du boss en contre-plongée, il se gonfle, puis on passe au
		-- duel. Elle tient dans le temps de présentation du serveur ; la passer ne fait qu'avancer la caméra de duel.
		local model = bossModel(update.bossId)
		if model then
			local base, size, front = CutsceneController.Measure(model)
			local face = base + Vector3.new(0, size * 0.75, 0)
			local radius = size * 1.3 + 4
			local function around(angle: number, height: number): CFrame
				local offset = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), angle):VectorToWorldSpace(front) * radius
				return CFrame.lookAt(face + offset + Vector3.new(0, height, 0), face)
			end
			CutsceneController.Play({
				{
					from = around(math.rad(-50), -size * 0.35),
					to = around(math.rad(40), size * 0.05),
					duration = 2.2,
					onStart = function()
						local scale = model:GetScale()
						model:ScaleTo(scale * 1.2)
						task.wait(0.6)
						if model.Parent then
							model:ScaleTo(scale)
						end
					end,
				},
			}, function()
				if fight and fight.bossId == update.bossId then
					startDuelCamera(update.bossId)
				end
			end, true)
		else
			startDuelCamera(update.bossId)
		end
	elseif update.state == "RoundStart" then
		setMeter(0, 0)
		if update.round > 1 then
			local final = update.round == update.rounds
			shout(
				if final then Texts.Get("Boss.FinalRound") else Texts.Get("Boss.RoundBanner", { round = update.round }),
				if final then RED else GOLD,
				Texts.Get("Boss.RoundFaster"),
				0.9
			)
		end
	elseif update.state == "Live" then
		setMeter(update.score, update.opponent)
	elseif update.state == "RoundResult" then
		if fight then
			fight.results[update.round] = update.won
			renderPips()
		end
		setMeter(update.score, update.opponent)
		shout(
			Texts.Get(if update.won then "Boss.RoundWonShort" else "Boss.RoundLostShort"),
			if update.won then GREEN else RED,
			`{update.score} - {update.opponent}`,
			1
		)
		bossSays(update.bossId, `BossTaunt.{update.bossId}.{if update.won then "Behind" else "Ahead"}`)
	elseif update.state == "Mogged" then
		hidePanel()
		MinigameController.SetGameplayLocked(false)
		launchPlayer()
		UIController.Toast(Texts.Get("Boss.Mogged", { cash = update.cash }), 3.5)
	elseif update.state == "Victory" then
		endPresentation()
		shout(Texts.Get("Boss.MoggedStamp"), GOLD, bossName(update.bossId), 1.2)
		local name = bossName(update.bossId)
		task.delay(1.6, function()
			if update.firstWin then
				local lines = {
					Texts.Get("Boss.NewStage", { stage = Texts.Get(`Stage.{update.stageId}`) }),
					Texts.Get("Boss.RewardCash", { cash = update.cash }),
				}
				if update.styleItem then
					table.insert(lines, Texts.Get("Boss.RewardItem", { item = Texts.Get(`Style.{update.styleItem}`) }))
				end
				showPanel(
					Texts.Get("Boss.Victory", { boss = name }),
					"",
					table.concat(lines, "\n"),
					Texts.Get("Boss.Ok")
				)
			else
				showPanel(Texts.Get("Boss.RematchWon", { boss = name }), "", "", Texts.Get("Boss.Ok"))
			end
			onPrimary = function()
				hidePanel()
				MinigameController.SetGameplayLocked(false)
			end
		end)
	elseif update.state == "Defeat" then
		endPresentation()
		bossSays(update.bossId, `BossTaunt.{update.bossId}.Ahead`)
		local text = if (update.cash or 0) > 0
			then Texts.Get("Boss.Defeat", { boss = bossName(update.bossId), cash = update.cash })
			else Texts.Get("Boss.DefeatRematch", { boss = bossName(update.bossId) })
		showPanel(bossName(update.bossId), "", text, Texts.Get("Boss.Ok"))
		onPrimary = function()
			hidePanel()
			MinigameController.SetGameplayLocked(false)
		end
	elseif update.state == "Aborted" then
		endPresentation()
		hidePanel()
		MinigameController.SetGameplayLocked(false)
		UIController.Toast(Texts.Get("Boss.Aborted"))
	end
end

local function buildGui()
	gui = Ui.create("ScreenGui", { Name = "Boss", ResetOnSpawn = false, DisplayOrder = 5 })

	-- Bandeau VS de la présentation
	vsBand = Ui.create("Frame", {
		Name = "Vs",
		Position = UDim2.fromScale(0, 0.3),
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundColor3 = Color3.fromRGB(15, 10, 25),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	}, { Ui.stroke(GOLD, 3, 0) })
	Ui.label({
		Position = UDim2.fromScale(0.04, 0.12),
		Size = UDim2.fromScale(0.36, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = `{Texts.Get("Boss.You")} - {player.DisplayName}`,
		Parent = vsBand,
	})
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.fromScale(0.16, 0.6),
		TextColor3 = GOLD,
		Text = Texts.Get("Boss.Vs"),
		Parent = vsBand,
	})
	vsBossLabel = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.96, 0.12),
		Size = UDim2.fromScale(0.36, 0.5),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = RED,
		Parent = vsBand,
	})
	vsLineLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(0.8, 0, 0, 30),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(220, 220, 230),
		Parent = vsBand,
	})

	-- Grands textes (compte à rebours, manches, MOGGED!)
	bigLabel = Ui.label({
		Name = "Big",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.42, 0.4),
		Size = UDim2.fromScale(0.7, 0.16),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 10,
		Parent = gui,
	})
	subLabel = Ui.label({
		Name = "Sub",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.42, 0.49),
		Size = UDim2.fromScale(0.5, 0.06),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 10,
		Parent = gui,
	})

	-- Jauge de Mog : toi (or, à gauche) contre le boss (rouge, à droite), et les manches
	meter = Ui.create("Frame", {
		Name = "Meter",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.new(0.6, 0, 0, 30),
		BackgroundColor3 = RED,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(UDim.new(0, 8)),
		Ui.stroke(Color3.new(1, 1, 1), 3, 0),
		Ui.create("UISizeConstraint", { MaxSize = Vector2.new(560, 30) }),
	})
	meterFill = Ui.create("Frame", {
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = GOLD,
		Parent = meter,
	}, { Ui.corner(UDim.new(0, 8)) })
	meterYou = Ui.label({
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(0.5, -8, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = meter,
	})
	meterBoss = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0.5, -8, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
		Parent = meter,
	})
	pipsFrame = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Parent = meter,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

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
	CutsceneController = controllers.CutsceneController
end

function BossController.Start()
	buildGui()
	Remotes.BossPrompt.OnClientEvent:Connect(onBossPrompt)
	Remotes.BossUpdate.OnClientEvent:Connect(onBossUpdate)
	player.CharacterAdded:Connect(function()
		if fight then
			endPresentation()
		end
	end)
end

return BossController
