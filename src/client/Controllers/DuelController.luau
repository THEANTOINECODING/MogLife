-- Duels entre joueurs côté client (bras de fer, D68) :
-- - un bouton « Arm Wrestle » sur chaque autre joueur proche, n'importe où (prompt local) pour l'inviter ;
-- - la fenêtre d'invitation reçue (Accepter / Refuser, refus automatique) ;
-- - la mise en scène : bandeau VS, 3-2-1, caméra qui filme les deux joueurs de profil autour de la table, jauge du
--   bras de fer (toi à gauche, l'adversaire à droite), pastilles des manches, annonces, petit recul à la manche
--   perdue, pose de victoire, fenêtre du résultat (Cash, plafond du jour, bilan).
-- Le serveur décide de tout (DuelService) ; ici, on met en scène.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Duels = require(ReplicatedStorage.Shared.Config.Duels)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CameraFraming = require(script.Parent.Parent.CameraFraming)
local Ui = require(script.Parent.Parent.Ui)

local GOLD = Color3.fromRGB(255, 210, 60)
local RED = Color3.fromRGB(230, 60, 60)
local GREEN = Color3.fromRGB(90, 220, 90)
local GRAY = Color3.fromRGB(70, 70, 80)
local PROMPT_NAME = "DuelPrompt"
local VICTORY_POSE = 5 -- bras en V (MogOff.Strike)

local player = Players.LocalPlayer

local UIController
local MinigameController

type Duel = {
	opponent: Player?,
	opponentModel: Model?,
	name: string,
	theirSpot: BasePart?,
	rounds: number,
	results: { [number]: string },
	limit: number,
}

local gui: ScreenGui
local invitePanel: Frame
local inviteLabel: TextLabel
local inviteBar: Frame
local inviteToken = 0
local vsBand: Frame
local vsThem: TextLabel
local bigLabel: TextLabel
local subLabel: TextLabel
local meter: Frame
local meterKnob: TextLabel
local meterThem: TextLabel
local pipsFrame: Frame
local resultPanel: Frame
local resultTitle: TextLabel
local resultInfo: TextLabel

local duel: Duel? = nil
local pendingResult = false
local resultSequence = 0
local stopFollow: (() -> ())? = nil
local prompts: { [Player]: ProximityPrompt } = {}

local DuelController = {}

-- Surnom affiché d'un joueur (celui du jeu, au-dessus de sa tête)
local function nickname(other: Player): string
	local humanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
	return if humanoid and humanoid.DisplayName ~= "" then humanoid.DisplayName else other.DisplayName
end

-- ------------------------------------------------------------------ invitations (prompts sur les autres joueurs)

local function refreshPrompt(other: Player)
	local prompt = prompts[other]
	if not prompt then
		return
	end
	prompt.ObjectText = nickname(other)
	prompt.Enabled = not other:GetAttribute("DuelsOff")
		and not other:GetAttribute("InRun")
		and not other:GetAttribute("InDuel")
		and not player:GetAttribute("InDuel")
		and duel == nil
end

local function refreshAllPrompts()
	for other in prompts do
		refreshPrompt(other)
	end
end

local function attachPrompt(other: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or other.Character ~= character then
		return
	end
	local old = prompts[other]
	if old then
		old:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = Texts.Get("Duel.Prompt")
	prompt.ObjectText = nickname(other)
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = Duels.InviteDistance - 4
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function()
		Remotes.DuelInvite:FireServer(other)
	end)
	prompts[other] = prompt
	refreshPrompt(other)
end

local function watchPlayer(other: Player)
	if other == player then
		return
	end
	other.CharacterAdded:Connect(function(character)
		attachPrompt(other, character)
	end)
	if other.Character then
		task.spawn(attachPrompt, other, other.Character)
	end
	for _, attribute in { "DuelsOff", "InRun", "InDuel" } do
		other:GetAttributeChangedSignal(attribute):Connect(function()
			refreshPrompt(other)
		end)
	end
end

local function hideInvite()
	inviteToken += 1
	invitePanel.Visible = false
end

local function showInvite(from: Player, timeout: number)
	inviteToken += 1
	inviteLabel.Text = Texts.Get("Duel.InviteFrom", { name = nickname(from) })
	invitePanel.Visible = true
	inviteBar.Size = UDim2.fromScale(1, 1)
	TweenService:Create(inviteBar, TweenInfo.new(timeout, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
		:Play()
	-- Rebond d'arrivée
	invitePanel.Position = UDim2.new(0.5, 0, 0, -120)
	TweenService:Create(invitePanel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 90),
	}):Play()
end

-- ------------------------------------------------------------------ mise en scène

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

-- Jauge du bras de fer : le poing glisse vers celui qui gagne (à gauche quand c'est toi) ; arrivé au bout, le bras
-- de l'autre est plaqué. lean > 0 = le bras penche en ta faveur.
local function setLean(lean: number, limit: number)
	local share = math.clamp(lean / math.max(limit, 1), -1, 1)
	TweenService:Create(meterKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5 - share * 0.5, 0.5),
	}):Play()
end

local RESULT_COLORS = { Won = GREEN, Lost = RED, Draw = GOLD }

local function renderPips()
	for _, child in pipsFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if not duel then
		return
	end
	for round = 1, duel.rounds do
		Ui.create("Frame", {
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = RESULT_COLORS[duel.results[round] or ""] or GRAY,
			LayoutOrder = round,
			Parent = pipsFrame,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.2) })
	end
end

local function opponentCharacter(): Model?
	if not duel then
		return nil
	end
	if duel.opponent then
		return duel.opponent.Character
	end
	return duel.opponentModel
end

-- Caméra de duel : les deux joueurs de profil (toi à gauche), dans la moitié gauche de l'écran (le mini-jeu est à
-- droite). Caméra stable (CameraFraming.Follow) : angle choisi une fois, changé seulement si un mur gêne.
local function startCamera()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root or not duel then
		return
	end
	local current = duel
	local function theirPosition(): Vector3
		local other = opponentCharacter()
		local otherRoot = other and (other:FindFirstChild("HumanoidRootPart") or other.PrimaryPart) :: BasePart?
		if otherRoot then
			return otherRoot.Position
		end
		return if current.theirSpot then current.theirSpot.Position + Vector3.new(0, 3, 0) else root.Position
	end
	local function points(): { Vector3 }
		local list = CameraFraming.BodyPoints(character :: Model)
		local other = opponentCharacter()
		if other then
			for _, point in CameraFraming.BodyPoints(other) do
				table.insert(list, point)
			end
		end
		if #list == 0 then
			table.insert(list, theirPosition())
		end
		return list
	end
	stopFollow = CameraFraming.Follow({
		anchor = function()
			return if root.Parent then root.Position else nil
		end,
		plan = function()
			local you, them = root.Position, theirPosition()
			local axis = Vector3.new(them.X - you.X, 0, them.Z - you.Z)
			local gap = math.max(axis.Magnitude, 3)
			axis = if axis.Magnitude > 0.1 then axis.Unit else Vector3.xAxis
			local side = Vector3.new(0, 1, 0):Cross(axis)
			local center = (you + them) / 2 + Vector3.new(0, 0.5, 0)
			-- Assez près pour voir les bras sur la table, assez loin pour garder les deux joueurs en entier
			local distance = gap * 1.2 + 5.5
			-- Caméra du côté où l'adversaire est à droite de l'écran (toi à gauche, comme la jauge), en légère
			-- plongée : on voit la table et les deux bras, et une caméra basse aurait le décor devant elle
			local steps = { { 0, 0.45 }, { 20, 0.45 }, { -20, 0.45 }, { 45, 0.5 }, { -45, 0.5 }, { 0, 1.1 } }
			local directions = CameraFraming.Around(-side, distance, 1.5, 1, steps)
			for _, direction in CameraFraming.Around(side, distance, 1.5, 1, steps) do
				table.insert(directions, direction)
			end
			local eye = CameraFraming.Best(center, directions, nil, points())
			local look = (center - eye).Unit
			local right = look:Cross(Vector3.new(0, 1, 0))
			return eye,
				center + right * ((center - eye).Magnitude * (math.tan(
					math.rad(workspace.CurrentCamera.FieldOfView / 2)
				) * workspace.CurrentCamera.ViewportSize.X / math.max(1, workspace.CurrentCamera.ViewportSize.Y) * 0.50))
		end,
		points = points,
		ignore = function()
			local other = opponentCharacter()
			return if other then { other } else {}
		end,
		enterTime = 0.8,
	})
end

local function stopCamera()
	if stopFollow then
		stopFollow()
		stopFollow = nil
	end
end

local function setLayout(active: boolean)
	UIController.SetStatsHidden(active, "Duel")
	MinigameController.SetSideButtonsHidden(active, "Duel")
end

-- Manche perdue : le joueur recule d'un petit bond, le bras plaqué
local function yank()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = -root.CFrame.LookVector * 14 + Vector3.new(0, 12, 0)
	end
end

local function intro(name: string, duration: number)
	vsThem.Text = name
	vsBand.Visible = true
	vsBand.Position = UDim2.fromScale(-1, 0.3)
	TweenService:Create(vsBand, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0, 0.3),
	}):Play()
	local current = duel
	local countStart = math.max(duration - 3.2, 0.5)
	task.delay(countStart - 0.3, function()
		vsBand.Visible = false
	end)
	for k, text in { "3", "2", "1" } do
		task.delay(countStart + (k - 1) * 0.8, function()
			if duel == current then
				shout(text, Color3.new(1, 1, 1), nil, 0.25)
			end
		end)
	end
	task.delay(countStart + 2.4, function()
		if duel == current then
			shout(Texts.Get("Duel.Go"), GOLD, nil, 0.4)
		end
	end)
end

local function showResult(update)
	local lines = {}
	if update.result == "Cancelled" then
		resultTitle.Text = Texts.Get("Duel.Cancelled")
		resultTitle.TextColor3 = Color3.fromRGB(220, 220, 230)
	elseif update.result == "Forfeit" then
		resultTitle.Text = Texts.Get("Duel.Forfeit")
		resultTitle.TextColor3 = RED
	else
		resultTitle.Text = Texts.Get(`Duel.Result.{update.result}`, { name = update.opponent })
		resultTitle.TextColor3 = RESULT_COLORS[update.result] or GOLD
		table.insert(lines, Texts.Get("Duel.Score", { wins = update.wins, theirWins = update.theirWins }))
	end
	if update.counted then
		table.insert(lines, Texts.Get("Duel.RewardCash", { cash = Format.Short(update.cash) }))
	elseif update.capped then
		table.insert(lines, Texts.Get("Duel.Capped", { count = Duels.RewardsPerPairPerDay }))
	elseif update.result ~= "Cancelled" and update.result ~= "Forfeit" and not update.valid then
		table.insert(lines, Texts.Get("Duel.NotValid", { hits = update.minHits }))
	end
	table.insert(lines, Texts.Get("Duel.TotalWins", { wins = update.totalWins }))
	resultInfo.Text = table.concat(lines, "\n")
	resultPanel.Visible = true
end

local function onUpdate(update)
	if typeof(update) ~= "table" then
		return
	end
	local state = update.state
	if state == "Invited" then
		if typeof(update.from) == "Instance" and update.from:IsA("Player") then
			showInvite(update.from, update.timeout or Duels.InviteTimeout)
		end
	elseif state == "InviteClosed" then
		hideInvite()
	elseif state == "Started" then
		hideInvite()
		resultSequence += 1
		pendingResult = false
		resultPanel.Visible = false
		duel = {
			opponent = update.opponent,
			opponentModel = update.opponentModel,
			name = if update.opponent then nickname(update.opponent) else update.opponentName,
			theirSpot = update.theirSpot,
			rounds = update.rounds or Duels.Rounds,
			results = {},
			limit = update.limit or Duels.LeanLimit,
		}
		refreshAllPrompts()
		MinigameController.SetGameplayLocked(true, "Duel")
		setLayout(true)
		meter.Visible = true
		meterThem.Text = (duel :: Duel).name
		setLean(0, (duel :: Duel).limit)
		renderPips()
		intro((duel :: Duel).name, update.intro or Duels.IntroTime)
		-- Le temps que le serveur pose la table et place les deux joueurs
		task.delay(0.4, function()
			if duel and not stopFollow then
				startCamera()
			end
		end)
	elseif state == "RoundStart" then
		if duel then
			setLean(0, duel.limit)
		end
		if update.round > 1 then
			local final = update.round == update.rounds
			shout(
				if final then Texts.Get("Duel.FinalRound") else Texts.Get("Duel.RoundBanner", { round = update.round }),
				if final then RED else GOLD,
				Texts.Get("Duel.RoundFaster"),
				0.9
			)
		end
	elseif state == "Live" then
		if duel then
			setLean(update.lean, update.limit or duel.limit)
		end
	elseif state == "RoundResult" then
		if duel then
			duel.results[update.round] = update.result
			renderPips()
		end
		local sub = if update.knockout then Texts.Get("Duel.Knockout") else nil
		if update.result == "Won" then
			shout(Texts.Get("Duel.RoundWon"), GREEN, sub, 1)
		elseif update.result == "Lost" then
			shout(Texts.Get("Duel.RoundLost"), RED, sub, 1)
			yank()
		else
			shout(Texts.Get("Duel.RoundDraw"), GOLD, nil, 1)
		end
	elseif state == "Result" then
		pendingResult = true
		local sequence = resultSequence
		local won = update.result == "Won"
		if won then
			shout(Texts.Get("Duel.Mogged"), GOLD, nil, 1.2)
			-- Pose de victoire, vue par tout le monde
			task.delay(0.3, function()
				Remotes.Emote:FireServer(VICTORY_POSE)
			end)
		end
		-- La fenêtre arrive après le « MOGGED! » (sinon elle passe dessous)
		task.delay(if won then 1.5 else 0.6, function()
			if resultSequence == sequence then
				showResult(update)
			end
		end)
	elseif state == "Finished" then
		duel = nil
		stopCamera()
		meter.Visible = false
		vsBand.Visible = false
		if not pendingResult then
			setLayout(false)
			MinigameController.SetGameplayLocked(false, "Duel")
		end
		refreshAllPrompts()
	end
end

-- ------------------------------------------------------------------ interface

local function buildGui()
	gui = Ui.create("ScreenGui", { Name = "Duel", ResetOnSpawn = false, DisplayOrder = 6 })

	-- Invitation reçue : en haut, sans bloquer le jeu
	invitePanel = Ui.panel({
		Name = "Invite",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = if Ui.isPhonePortrait() then UDim2.new(1, -20, 0, 150) else UDim2.fromOffset(460, 150),
		Visible = false,
		Parent = gui,
	})
	Ui.create("UISizeConstraint", { MaxSize = Vector2.new(460, 150), Parent = invitePanel })
	inviteLabel = Ui.label({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 56),
		TextWrapped = true,
		TextColor3 = GOLD,
		Parent = invitePanel,
	})
	local barBack = Ui.create("Frame", {
		Position = UDim2.fromOffset(16, 74),
		Size = UDim2.new(1, -32, 0, 6),
		BackgroundColor3 = Color3.fromRGB(40, 35, 55),
		Parent = invitePanel,
	}, { Ui.corner(UDim.new(1, 0)) })
	inviteBar = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GOLD,
		Parent = barBack,
	}, { Ui.corner(UDim.new(1, 0)) })
	local accept = Ui.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -12),
		Size = UDim2.new(0.5, -24, 0, 50),
		BackgroundColor3 = Color3.fromRGB(60, 170, 80),
		Text = Texts.Get("Duel.Accept"),
		Parent = invitePanel,
	})
	local decline = Ui.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -12),
		Size = UDim2.new(0.5, -24, 0, 50),
		BackgroundColor3 = Color3.fromRGB(90, 90, 90),
		Text = Texts.Get("Duel.Decline"),
		Parent = invitePanel,
	})
	accept.Activated:Connect(function()
		hideInvite()
		Remotes.DuelAnswer:FireServer(true)
	end)
	decline.Activated:Connect(function()
		hideInvite()
		Remotes.DuelAnswer:FireServer(false)
	end)

	-- Bandeau VS
	vsBand = Ui.create("Frame", {
		Name = "Vs",
		Position = UDim2.fromScale(0, 0.3),
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundColor3 = Color3.fromRGB(15, 10, 25),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	}, { Ui.stroke(GOLD, 3, 0) })
	Ui.label({
		Position = UDim2.fromScale(0.04, 0.15),
		Size = UDim2.fromScale(0.36, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = Texts.Get("Duel.You"),
		Parent = vsBand,
	})
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.08),
		Size = UDim2.fromScale(0.16, 0.6),
		TextColor3 = GOLD,
		Text = Texts.Get("Duel.Vs"),
		Parent = vsBand,
	})
	vsThem = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.96, 0.15),
		Size = UDim2.fromScale(0.36, 0.5),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = RED,
		Parent = vsBand,
	})
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(0.8, 0, 0, 26),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(220, 220, 230),
		Text = Texts.Get("Duel.Tagline"),
		Parent = vsBand,
	})

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

	-- Jauge du bras de fer : ton camp (or) à gauche, celui de l'adversaire (rouge) à droite, le poing entre les deux
	meter = Ui.create("Frame", {
		Name = "Lean",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.new(0.6, 0, 0, 34),
		BackgroundColor3 = RED,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(UDim.new(0, 8)),
		Ui.stroke(Color3.new(1, 1, 1), 3, 0),
		Ui.create("UISizeConstraint", { MaxSize = Vector2.new(560, 34) }),
	})
	Ui.create("Frame", {
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = GOLD,
		Parent = meter,
	}, { Ui.corner(UDim.new(0, 8)) })
	-- Repère du milieu
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 3, 1, 10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = meter,
	})
	Ui.label({
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(0.4, -8, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = Texts.Get("Duel.You"),
		ZIndex = 3,
		Parent = meter,
	})
	meterThem = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0.4, -8, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		Parent = meter,
	})
	meterKnob = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		TextStrokeTransparency = 1,
		Text = "✊",
		ZIndex = 4,
		Parent = meter,
	})
	pipsFrame = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -8),
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

	-- Résultat
	resultPanel = Ui.panel({
		Name = "Result",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = if Ui.isPhonePortrait() then UDim2.new(1, -20, 0, 270) else UDim2.fromOffset(480, 270),
		Visible = false,
		Parent = gui,
	})
	Ui.create("UISizeConstraint", { MaxSize = Vector2.new(480, 270), Parent = resultPanel })
	resultTitle = Ui.label({
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 0, 48),
		Parent = resultPanel,
	})
	resultInfo = Ui.label({
		Position = UDim2.fromOffset(16, 70),
		Size = UDim2.new(1, -32, 0, 110),
		TextWrapped = true,
		Parent = resultPanel,
	})
	local ok = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(200, 54),
		BackgroundColor3 = Color3.fromRGB(220, 120, 30),
		Text = Texts.Get("Duel.Ok"),
		Parent = resultPanel,
	})
	ok.Activated:Connect(function()
		resultPanel.Visible = false
		pendingResult = false
		if not duel then
			setLayout(false)
			MinigameController.SetGameplayLocked(false, "Duel")
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function DuelController.Init(controllers)
	UIController = controllers.UIController
	MinigameController = controllers.MinigameController
end

function DuelController.Start()
	buildGui()
	Remotes.DuelUpdate.OnClientEvent:Connect(onUpdate)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(other)
		local prompt = prompts[other]
		if prompt then
			prompt:Destroy()
		end
		prompts[other] = nil
	end)
	player:GetAttributeChangedSignal("InDuel"):Connect(refreshAllPrompts)
	player.CharacterAdded:Connect(function()
		if duel then
			onUpdate({ state = "Finished" })
		end
	end)
end

return DuelController
