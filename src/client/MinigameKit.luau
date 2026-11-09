-- Boîte à outils commune des mini-jeux : panneau, entrées (clic/toucher, clavier, manette, pointeur),
-- notation Perfect / Good / Miss, boucle d'animation et nettoyage.
--
-- Interface commune de tout mini-jeu (module dans src/client/Minigames/) :
--   Minigame.new(parent: GuiObject, interval: number, onRep: (quality: string) -> (), options: Options?)
--   minigame:Destroy()
-- options.timingScale (< 1 = fenêtres plus serrées, utilisé en combat de boss et en duel)
-- options.seed (graine du motif : en duel, les deux joueurs ont exactement la même suite)
-- options.level (0, 1, 2… : difficulté donnée par le serveur ; débloque les surprises de chaque jeu, D81)
-- options.name (nom du mini-jeu : la main fantôme ne se montre que les premières fois)
--
-- Pensé d'abord pour le téléphone (D81) : on joue n'importe où sur l'écran, d'un seul pouce, sans petit bouton.
-- Clavier, souris et manette donnent les mêmes gestes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Ui = require(script.Parent.Ui)

local SETTINGS = Balance.Minigames

export type Options = {
	timingScale: number?,
	seed: number?, -- graine du motif (duels : les deux joueurs jouent la même suite)
	level: number?,
	name: string?,
	total: number?,
}

-- Couleurs communes des notes
local QUALITY_COLORS = {
	Perfect = Color3.fromRGB(255, 215, 40),
	Good = Color3.fromRGB(90, 230, 90),
	Miss = Color3.fromRGB(255, 80, 80),
}

-- Nombre de fois où la main fantôme a déjà été montrée pour chaque mini-jeu (pendant la session)
local guidesShown: { [string]: number } = {}

-- Réglages du joueur (vibrations, effets d'écran) : branché par MinigameController
local settingsGet: ((string) -> boolean)? = nil
-- Appelé au moment même de chaque geste noté (le personnage bouge tout de suite) : branché par MinigameController
local repListener: ((string) -> ())? = nil
-- Effets sonores (Config/Sounds.luau) : branché par MinigameController sur SoundController.Play
local soundPlayer: ((string, number?) -> ())? = nil

local Kit = {}
Kit.__index = Kit

-- Source des gestes : l'écran, la souris, le clavier et la manette. Les tests automatiques la remplacent par de faux
-- gestes (tests/minigames_bot.luau) ; en jeu, c'est toujours UserInputService.
Kit.Input = UserInputService :: any

-- Directions communes (flèches, ZQSD/WASD, manette, boutons à l'écran)
Kit.DIRECTIONS = { "Up", "Down", "Left", "Right" }
Kit.ARROWS = { Up = "▲", Down = "▼", Left = "◀", Right = "▶" }
local DIRECTION_KEYS = {
	[Enum.KeyCode.Up] = "Up",
	[Enum.KeyCode.W] = "Up",
	[Enum.KeyCode.Z] = "Up",
	[Enum.KeyCode.DPadUp] = "Up",
	[Enum.KeyCode.Down] = "Down",
	[Enum.KeyCode.S] = "Down",
	[Enum.KeyCode.DPadDown] = "Down",
	[Enum.KeyCode.Left] = "Left",
	[Enum.KeyCode.A] = "Left",
	[Enum.KeyCode.Q] = "Left",
	[Enum.KeyCode.DPadLeft] = "Left",
	[Enum.KeyCode.Right] = "Right",
	[Enum.KeyCode.D] = "Right",
	[Enum.KeyCode.DPadRight] = "Right",
}

function Kit.new(parent: GuiObject, interval: number, onRep: (string) -> (), options: Options?)
	local self = setmetatable({}, Kit)
	self.parent = parent
	self.interval = interval
	self.onRep = onRep
	self.timingScale = (options and options.timingScale) or 1
	self.startTime = os.clock()
	self.connections = {}
	self.pointer = Vector2.zero
	self.pointerActive = false
	self.level = (options and options.level) or 0
	self.name = (options and options.name) or ""
	self.seed = options and options.seed
	self.total = options and options.total -- répétitions du run (nil si inconnu)
	self.reps = 0 -- répétitions notées
	self.lastSendAt = -math.huge
	self.dragDelta = Vector2.zero
	self.dragging = false
	return self
end

Kit.QUALITY_COLORS = QUALITY_COLORS

function Kit.SetSettingsGetter(getter: (string) -> boolean)
	settingsGet = getter
end

-- Réglage du joueur (vrai si aucun réglage n'est encore branché)
function Kit.Setting(key: string): boolean
	return settingsGet == nil or settingsGet(key)
end

function Kit.SetRepListener(listener: (string) -> ())
	repListener = listener
end

function Kit.SetSoundPlayer(player: (string, number?) -> ())
	soundPlayer = player
end

-- Petit son du mini-jeu (clic, choc…) : nom d'un effet de Config/Sounds.luau, hauteur facultative
function Kit.Sound(name: string, pitch: number?)
	if soundPlayer then
		soundPlayer(name, pitch)
	end
end

-- Tire au sort avec la graine du run si elle existe (duels : même suite pour les deux joueurs)
function Kit:Random(): Random
	if not self.rng then
		self.rng = Random.new(self.seed or math.floor(os.clock() * 1000) % 2 ^ 31)
	end
	return self.rng
end

-- Panneau principal (à droite de l'écran). Un TextButton si `tappable`, pour capter les touches.
function Kit:Panel(size: UDim2, tappable: boolean?): GuiObject
	local compact = Ui.isPhonePortrait()
	local panelSize = if compact then UDim2.new(1, -24, size.Y.Scale, size.Y.Offset) else size
	local props = {
		AnchorPoint = if compact then Vector2.new(0.5, 0) else Vector2.new(1, 0.5),
		Position = if compact
			then UDim2.new(0.5, 0, 0, 274)
			else UDim2.new(1, -40, 0.5, if UserInputService.TouchEnabled then 0 else 20),
		Size = panelSize,
		Parent = self.parent,
	}
	local panel
	if tappable then
		panel = Ui.create("TextButton", {
			AnchorPoint = props.AnchorPoint,
			Position = props.Position,
			Size = panelSize,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.15,
			AutoButtonColor = false,
			Text = "",
			Parent = self.parent,
		}, {
			Ui.corner(UDim.new(0, 18)),
			Ui.gradient(Color3.fromRGB(70, 45, 110), Color3.fromRGB(25, 20, 40)),
			Ui.stroke(Color3.fromRGB(255, 220, 120), 3, 0.2),
		})
	else
		panel = Ui.panel(props)
	end
	self.root = panel
	if compact then
		local function fitPortrait()
			local height = self.parent.AbsoluteSize.Y
			if height <= 0 then
				return
			end
			local top = if height < 600 then 230 else 274
			local requestedHeight = height * size.Y.Scale + size.Y.Offset
			panel.Position = UDim2.new(0.5, 0, 0, top)
			panel.Size = UDim2.new(1, -24, 0, math.max(100, math.min(requestedHeight, height - top - 20)))
		end
		self:Connect(self.parent:GetPropertyChangedSignal("AbsoluteSize"), fitPortrait)
		fitPortrait()
	end
	if UserInputService.TouchEnabled and not compact then
		local scale = Ui.create("UIScale", { Parent = panel })
		local function fitHeight()
			local parentHeight = self.parent.AbsoluteSize.Y
			local requestedHeight = parentHeight * panelSize.Y.Scale + panelSize.Y.Offset
			if requestedHeight > 0 and parentHeight > 0 then
				scale.Scale = math.min(1, math.max(1, parentHeight - 24) / requestedHeight)
			end
		end
		self:Connect(self.parent:GetPropertyChangedSignal("AbsoluteSize"), fitHeight)
		fitHeight()
	end
	return panel
end

-- Agrandit le panneau pour qu'il occupe la même part de la hauteur d'écran sur tous les appareils (D110 : sur
-- tablette, le duel était minuscule et le téléphone gagnait plus souvent). Jamais plus que maxScale, jamais plus haut
-- que l'écran. Sans effet en portrait (le panneau y prend déjà toute la largeur).
function Kit:GrowToScreen(heightShare: number, maxScale: number)
	local panel = self.root
	if not panel or Ui.isPhonePortrait() then
		return
	end
	local scale = panel:FindFirstChildOfClass("UIScale") or Ui.create("UIScale", { Parent = panel })
	local function fit()
		local parentHeight = self.parent.AbsoluteSize.Y
		local requested = parentHeight * panel.Size.Y.Scale + panel.Size.Y.Offset
		if requested <= 0 or parentHeight <= 0 then
			return
		end
		local wanted = math.clamp(parentHeight * heightShare / requested, 1, maxScale)
		scale.Scale = math.min(wanted, math.max(1, parentHeight - 24) / requested)
	end
	-- Après le réglage de Panel (qui ne fait que rétrécir), à chaque changement de taille
	self:Connect(self.parent:GetPropertyChangedSignal("AbsoluteSize"), function()
		task.defer(fit)
	end)
	fit()
end

-- Panneau large et bas, pour jouer à deux pouces (D82) : en paysage, il prend toute la largeur à droite de la colonne
-- d'infos, en bas de l'écran, sur `heightScale` de la hauteur ; la scène 3D (joueur, boss) reste visible au-dessus.
-- En portrait, même placement que Panel.
function Kit:WidePanel(heightScale: number): GuiObject
	local panel = self:Panel(UDim2.new(0, 320, heightScale, 0))
	if Ui.isPhonePortrait() then
		return panel
	end
	local scale = panel:FindFirstChildOfClass("UIScale")
	if scale then
		scale:Destroy()
	end
	local function fit()
		local width = self.parent.AbsoluteSize.X
		if width <= 0 then
			return
		end
		if UserInputService.TouchEnabled then
			-- Même largeur de colonne que MinigameController (titre, compteur, Stop à gauche)
			local rail = math.min(260, math.floor(width * 0.28)) + 32
			panel.AnchorPoint = Vector2.new(1, 1)
			panel.Position = UDim2.new(1, -12, 1, -12)
			panel.Size = UDim2.new(0, width - rail - 12, heightScale, 0)
		else
			panel.AnchorPoint = Vector2.new(0.5, 1)
			panel.Position = UDim2.new(0.5, 0, 1, -16)
			panel.Size = UDim2.fromScale(0.62, heightScale)
		end
	end
	self:Connect(self.parent:GetPropertyChangedSignal("AbsoluteSize"), fit)
	fit()
	return panel
end

function Kit:Connect(signal: RBXScriptSignal, callback: (...any) -> ())
	table.insert(self.connections, signal:Connect(callback))
end

-- Appelle `callback(dt, t)` à chaque image (t = secondes depuis le début du mini-jeu)
-- Kit.StepSignal : remplace RenderStepped pour les tests dans Studio réduit (l'affichage est alors en pause)
function Kit:OnStep(callback: (number, number) -> ())
	self:Connect(Kit.StepSignal or RunService.RenderStepped, function(dt)
		callback(dt, os.clock() - self.startTime)
	end)
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Vrai si l'écran est touché sur un bouton de l'interface hors du mini-jeu (Stop…) : ce n'est pas un geste de jeu
function Kit:_overButton(position: Vector3): boolean
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	for _, object in playerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
		if
			object:IsA("GuiButton")
			and object.Visible
			and object ~= self.root
			and not (self.root and object:IsDescendantOf(self.root))
		then
			return true
		end
	end
	return false
end

-- Appui « action » : toucher / clic n'importe où sur l'écran (sauf sur un bouton), Espace, bouton A.
-- `zone` n'est plus utilisé : l'écran entier compte, on joue d'un pouce sans viser (D81).
function Kit:OnPress(callback: () -> (), _zone: GuiObject?)
	self:Connect(Kit.Input.InputBegan, function(input)
		local key = input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA
		if key or (isPress(input) and not self:_overButton(input.Position)) then
			callback()
		end
	end)
end

function Kit:OnRelease(callback: () -> ())
	self:Connect(Kit.Input.InputEnded, function(input)
		if isPress(input) or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			callback()
		end
	end)
end

-- Côté touché : à gauche ou à droite du milieu du panneau de jeu (deux pouces ; un appui hors du panneau compte pour
-- le côté où il est), A / D, flèches, gâchettes et croix de manette.
-- `release` (facultatif) : appelé quand ce doigt ou cette touche est relâché.
local SIDE_KEYS = {
	[Enum.KeyCode.A] = "Left",
	[Enum.KeyCode.Q] = "Left",
	[Enum.KeyCode.Left] = "Left",
	[Enum.KeyCode.DPadLeft] = "Left",
	[Enum.KeyCode.ButtonL1] = "Left",
	[Enum.KeyCode.ButtonL2] = "Left",
	[Enum.KeyCode.D] = "Right",
	[Enum.KeyCode.Right] = "Right",
	[Enum.KeyCode.DPadRight] = "Right",
	[Enum.KeyCode.ButtonR1] = "Right",
	[Enum.KeyCode.ButtonR2] = "Right",
}
function Kit:OnSide(callback: (string) -> (), release: ((string) -> ())?)
	local held: { [InputObject]: string } = {}
	self:Connect(Kit.Input.InputBegan, function(input)
		local side = SIDE_KEYS[input.KeyCode]
		if not side and isPress(input) and not self:_overButton(input.Position) then
			-- Les pistes sont dans le panneau, qui n'est pas forcément au milieu de l'écran
			local root = self.root
			local middle = if root and root.AbsoluteSize.X > 0
				then root.AbsolutePosition.X + root.AbsoluteSize.X / 2
				else (if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize.X / 2 else 500)
			side = if input.Position.X < middle then "Left" else "Right"
		end
		if side then
			held[input] = side
			callback(side)
		end
	end)
	self:Connect(Kit.Input.InputEnded, function(input)
		local side = held[input]
		if side then
			held[input] = nil
			if release then
				release(side)
			end
		end
	end)
end

-- Glissé : un geste du doigt (ou de la souris bouton enfoncé) dans une direction, n'importe où sur l'écran.
-- Le geste compte dès que le doigt a assez bougé (pas besoin de le lever) : un seul par appui.
-- Clavier (flèches, ZQSD/WASD), croix et coup de stick de manette donnent les mêmes directions.
function Kit:OnSwipe(callback: (string) -> ())
	local starts: { [InputObject]: Vector2 } = {}
	local fired: { [InputObject]: boolean } = {}
	local function threshold(): number
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 600
		return math.max(SETTINGS.SwipeMinPixels, height * SETTINGS.SwipeScreenFraction)
	end
	local function fire(delta: Vector2)
		if math.abs(delta.X) > math.abs(delta.Y) then
			callback(if delta.X > 0 then "Right" else "Left")
		else
			callback(if delta.Y > 0 then "Down" else "Up")
		end
	end
	self:Connect(Kit.Input.InputBegan, function(input)
		if isPress(input) and not self:_overButton(input.Position) then
			starts[input] = Vector2.new(input.Position.X, input.Position.Y)
			fired[input] = nil
		end
		local direction = DIRECTION_KEYS[input.KeyCode]
		if direction then
			callback(direction)
		end
	end)
	-- Coup de stick : la direction compte quand le stick dépasse le seuil, puis il doit revenir au centre
	local stickArmed = true
	self:Connect(Kit.Input.InputChanged, function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local stick = Vector2.new(input.Position.X, -input.Position.Y)
			if stick.Magnitude < 0.3 then
				stickArmed = true
			elseif stickArmed and stick.Magnitude > 0.75 then
				stickArmed = false
				fire(stick)
			end
			return
		end
		local key: InputObject? = nil
		if starts[input] then
			key = input
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			-- Souris : le geste appartient à l'appui du bouton gauche en cours
			for pressInput in starts do
				if pressInput.UserInputType == Enum.UserInputType.MouseButton1 then
					key = pressInput
				end
			end
		end
		if not key or fired[key] then
			return
		end
		local delta = Vector2.new(input.Position.X, input.Position.Y) - starts[key]
		if delta.Magnitude >= threshold() then
			fired[key] = true
			fire(delta)
		end
	end)
	self:Connect(Kit.Input.InputEnded, function(input)
		starts[input] = nil
		fired[input] = nil
	end)
end

-- Glisser-déplacer relatif (comme un pavé tactile) : le doigt bouge n'importe où et l'objet suit son déplacement,
-- le pouce ne cache jamais ce qu'il déplace. ConsumeDrag() rend le déplacement (pixels) depuis le dernier appel.
function Kit:TrackDrag()
	local touch: InputObject? = nil
	local last: Vector2? = nil
	self:Connect(Kit.Input.InputBegan, function(input)
		if isPress(input) and touch == nil and not self:_overButton(input.Position) then
			touch = input
			last = Vector2.new(input.Position.X, input.Position.Y)
			self.dragging = true
		end
	end)
	self:Connect(Kit.Input.InputChanged, function(input)
		local moved = input == touch
			or (
				touch ~= nil
				and touch.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseMovement
			)
		if moved and last then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			self.dragDelta += position - last
			last = position
		end
	end)
	self:Connect(Kit.Input.InputEnded, function(input)
		if input == touch then
			touch = nil
			last = nil
			self.dragging = false
		end
	end)
end

function Kit:ConsumeDrag(): Vector2
	local delta = self.dragDelta
	self.dragDelta = Vector2.zero
	return delta
end

-- Suivi du pointeur (souris, doigt) en coordonnées d'écran : self.pointer, self.pointerActive
function Kit:TrackPointer()
	local touch: InputObject? = nil
	local function position(input: InputObject): Vector2
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	local function inPanel(point: Vector2): boolean
		local root = self.root
		return root ~= nil
			and point.X >= root.AbsolutePosition.X
			and point.Y >= root.AbsolutePosition.Y
			and point.X <= root.AbsolutePosition.X + root.AbsoluteSize.X
			and point.Y <= root.AbsolutePosition.Y + root.AbsoluteSize.Y
	end
	self:Connect(Kit.Input.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.Touch and touch == nil and inPanel(position(input)) then
			touch = input
			self.pointer = position(input)
			self.pointerActive = true
		end
	end)
	self:Connect(Kit.Input.InputChanged, function(input)
		if input == touch or (touch == nil and input.UserInputType == Enum.UserInputType.MouseMovement) then
			self.pointer = position(input)
			self.pointerActive = true
		end
	end)
	self:Connect(Kit.Input.InputEnded, function(input)
		if input == touch then
			touch = nil
			self.pointerActive = false
		end
	end)
end

-- Position du pointeur relative à un objet : (0,0) en haut à gauche, (1,1) en bas à droite
function Kit:PointerIn(object: GuiObject): Vector2
	local size = object.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return Vector2.new(0.5, 0.5)
	end
	local relative = (self.pointer - object.AbsolutePosition) / size
	return Vector2.new(math.clamp(relative.X, 0, 1), math.clamp(relative.Y, 0, 1))
end

-- Direction appuyée (clavier / croix de manette). Les boutons à l'écran passent par AddDirectionButtons.
function Kit:OnDirection(callback: (string) -> ())
	self:Connect(Kit.Input.InputBegan, function(input)
		local direction = DIRECTION_KEYS[input.KeyCode]
		if direction then
			callback(direction)
		end
	end)
end

-- Direction maintenue au clavier ou au stick : vecteur (-1..1, -1..1), Y positif vers le bas
function Kit:HeldDirection(): Vector2
	local x, y = 0, 0
	local function down(...)
		for _, key in { ... } do
			if UserInputService:IsKeyDown(key) then
				return true
			end
		end
		return false
	end
	if down(Enum.KeyCode.A, Enum.KeyCode.Q, Enum.KeyCode.Left) then
		x -= 1
	end
	if down(Enum.KeyCode.D, Enum.KeyCode.Right) then
		x += 1
	end
	if down(Enum.KeyCode.W, Enum.KeyCode.Z, Enum.KeyCode.Up) then
		y -= 1
	end
	if down(Enum.KeyCode.S, Enum.KeyCode.Down) then
		y += 1
	end
	if down(Enum.KeyCode.DPadLeft) then
		x -= 1
	end
	if down(Enum.KeyCode.DPadRight) then
		x += 1
	end
	if down(Enum.KeyCode.DPadUp) then
		y -= 1
	end
	if down(Enum.KeyCode.DPadDown) then
		y += 1
	end
	local stick = Vector2.zero
	local dpad = Vector2.zero
	for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if state.KeyCode == Enum.KeyCode.Thumbstick1 then
			stick = Vector2.new(state.Position.X, -state.Position.Y)
		elseif state.UserInputState == Enum.UserInputState.Begin then
			if state.KeyCode == Enum.KeyCode.DPadLeft then
				dpad += Vector2.new(-1, 0)
			elseif state.KeyCode == Enum.KeyCode.DPadRight then
				dpad += Vector2.new(1, 0)
			elseif state.KeyCode == Enum.KeyCode.DPadUp then
				dpad += Vector2.new(0, -1)
			elseif state.KeyCode == Enum.KeyCode.DPadDown then
				dpad += Vector2.new(0, 1)
			end
		end
	end
	if stick.Magnitude > Balance.GamepadDeadzone then
		x, y = stick.X, stick.Y
	elseif dpad.Magnitude > 0 then
		x, y = dpad.X, dpad.Y
	end
	local direction = Vector2.new(x, y)
	return if direction.Magnitude > 1 then direction.Unit else direction
end

-- Boutons de direction à l'écran (mobile) : une rangée en bas du panneau
function Kit:AddDirectionButtons(directions: { string }, callback: (string) -> ())
	local count = #directions
	for index, direction in directions do
		local button = Ui.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new((index - 0.5) / count, 0, 1, -10),
			Size = UDim2.new(1 / count, -12, 0, 56),
			BackgroundColor3 = Color3.fromRGB(72, 55, 104),
			Text = Kit.ARROWS[direction] or direction,
			Selectable = false,
			ZIndex = 5,
			Parent = self.root,
		})
		Ui.stroke(Color3.fromRGB(255, 216, 103), 2, 0.35).Parent = button
		self:Connect(button.Activated, function()
			callback(direction)
		end)
	end
end

-- Note un écart de temps (secondes) avec les fenêtres de Balance.TimingWindows (× timingScale)
function Kit:GradeOffset(seconds: number): string
	local windows = Balance.TimingWindows
	if seconds <= windows.Perfect * self.timingScale then
		return "Perfect"
	elseif seconds <= windows.Good * self.timingScale then
		return "Good"
	end
	return "Miss"
end

-- Note une erreur quelconque (0 = parfait) avec des seuils propres au mini-jeu (× timingScale)
function Kit:GradeError(err: number, perfectMax: number, goodMax: number): string
	if err <= perfectMax * self.timingScale then
		return "Perfect"
	elseif err <= goodMax * self.timingScale then
		return "Good"
	end
	return "Miss"
end

-- Petite vibration (téléphone et manette), sauf si le joueur l'a coupée dans les réglages.
-- kind : "Light" (réussite), "Strong" (Perfect, choc), "Miss" (raté)
function Kit.Haptic(kind: string)
	if settingsGet and not settingsGet("Vibration") then
		return
	end
	if UserInputService.TouchEnabled then
		pcall(function()
			local effect = Instance.new("HapticEffect")
			effect.Type = if kind == "Strong"
				then Enum.HapticEffectType.GameplayCollision
				elseif kind == "Miss" then Enum.HapticEffectType.UINotification
				else Enum.HapticEffectType.UIClick
			effect.Parent = workspace.CurrentCamera
			effect:Play()
			task.delay(1, function()
				effect:Destroy()
			end)
		end)
	end
	if UserInputService.GamepadEnabled then
		pcall(function()
			local HapticService = game:GetService("HapticService")
			local strength = if kind == "Strong" then 0.6 elseif kind == "Miss" then 0.4 else 0.25
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, strength)
			task.delay(0.08, function()
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
			end)
		end)
	end
end

-- Éclat à l'endroit du geste : un cercle qui s'ouvre et s'efface, avec des étincelles sur un Perfect
function Kit:Burst(quality: string, at: GuiObject?)
	local host = at or self.root
	if not host or not host.Parent then
		return
	end
	local color = QUALITY_COLORS[quality] or QUALITY_COLORS.Good
	local ring = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		ZIndex = 30,
		Parent = host,
	}, { Ui.corner(UDim.new(1, 0)) })
	local stroke = Ui.stroke(color, 6, 0)
	stroke.Parent = ring
	local size = if quality == "Perfect" then 170 elseif quality == "Good" then 120 else 80
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(size, size),
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	task.delay(0.4, function()
		ring:Destroy()
	end)
	if quality ~= "Perfect" then
		return
	end
	for index = 1, 6 do
		local angle = index / 6 * 2 * math.pi + math.random() * 0.4
		local spark = Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(26, 26),
			Text = "✦",
			TextColor3 = color,
			TextStrokeTransparency = 1,
			ZIndex = 31,
			Parent = host,
		})
		TweenService:Create(spark, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(angle) * 90, 0.5, math.sin(angle) * 90),
			TextTransparency = 1,
			Rotation = 90,
		}):Play()
		task.delay(0.5, function()
			spark:Destroy()
		end)
	end
end

-- Le panneau tremble un instant (raté, choc)
function Kit:Shake(strength: number?)
	local root = self.root
	if not root or self.shaking or (settingsGet and not settingsGet("ScreenFx")) then
		return
	end
	self.shaking = true
	local origin = root.Position
	local amount = strength or 8
	task.spawn(function()
		for step = 1, 6 do
			if not root.Parent then
				break
			end
			local side = if step % 2 == 0 then 1 else -1
			root.Position = origin + UDim2.fromOffset(side * amount * (1 - step / 7), 0)
			task.wait(0.03)
		end
		if root.Parent then
			root.Position = origin
		end
		self.shaking = false
	end)
end

-- Instant (os.clock) à partir duquel la prochaine répétition peut partir sans être refusée : même quota que
-- MinigameService et MinigameController (une répétition par intervalle × tolérance), plus une petite marge
function Kit:NextRepAt(): number
	local spacing = self.interval * (Balance.RepIntervalTolerance + 0.05)
	return math.max(self.startTime + self.reps * spacing + SETTINGS.RepSafetyMargin, self.lastSendAt + 0.22)
end

-- Vrai si une répétition peut partir tout de suite (jeux au rythme du joueur : le geste n'est pas accepté avant)
function Kit:RepReady(): boolean
	return os.clock() >= self:NextRepAt()
end

-- Note une répétition : retour immédiat (éclat, vibration, tremblement), puis envoi au serveur.
-- Si le geste arrive un peu trop tôt pour la cadence du serveur, l'envoi attend le bon moment au lieu d'être perdu.
function Kit:Rep(quality: string, at: GuiObject?)
	local sendAt = self:NextRepAt()
	self.reps += 1
	self.lastSendAt = math.max(os.clock(), sendAt)
	self:Burst(quality, at)
	if repListener then
		repListener(quality)
	end
	Kit.Haptic(if quality == "Miss" then "Miss" elseif quality == "Perfect" then "Strong" else "Light")
	if quality == "Miss" then
		self:Shake(6)
	end
	if quality ~= "Miss" or self.reps >= SETTINGS.GuideMaxReps then
		self:HideGuide()
	end
	local delay = sendAt - os.clock()
	if delay <= 0 then
		self.onRep(quality)
	else
		task.delay(delay, function()
			if not self.destroyed then
				self.onRep(quality)
			end
		end)
	end
end

-- Geste reçu mais pas au bon moment (outil qui revient, pause après une réussite) : petit « pas encore » visible,
-- pour que le joueur comprenne que son geste a bien été vu (D88 : sans ça, « l'action ne marche pas »)
function Kit:Nope(at: GuiObject?)
	local host = at or self.root
	local now = os.clock()
	if not host or not host.Parent or now - (self.nopeAt or 0) < 0.25 then
		return
	end
	self.nopeAt = now
	local mark = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(44, 44),
		Text = "⏳",
		TextStrokeTransparency = 1,
		ZIndex = 40,
		Parent = host,
	})
	TweenService:Create(mark, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, -30),
		TextTransparency = 1,
	}):Play()
	task.delay(0.5, function()
		mark:Destroy()
	end)
	Kit.Haptic("Light")
end

-- ------------------------------------------------------------------ main fantôme (première répétition guidée)

-- Montre le geste avec une main au-dessus de `target` : "Tap" (appuyer), "Hold" (maintenir), "SwipeUp",
-- "SwipeDown", "SwipeLeft", "SwipeRight", "Drag" (glisser de gauche à droite), "Sides" (un pouce de chaque côté).
-- Pour les jeux de timing, le jeu appelle GuideCue() au bon moment : la main appuie à cet instant.
-- Visible les premières fois de la session pour chaque mini-jeu, jusqu'à la première réussite.
function Kit:Guide(target: GuiObject, gesture: string)
	local count = guidesShown[self.name] or 0
	if count >= SETTINGS.GuideSessions then
		return
	end
	guidesShown[self.name] = count + 1
	local hand = Ui.label({
		Name = "Guide",
		AnchorPoint = Vector2.new(0.35, 0.1),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(64, 64),
		Text = "👆",
		TextStrokeTransparency = 1,
		ZIndex = 40,
		Parent = target,
	})
	self.guide = { hand = hand, cueAt = -math.huge }
	local directions = {
		SwipeUp = Vector2.new(0, -1),
		SwipeDown = Vector2.new(0, 1),
		SwipeLeft = Vector2.new(-1, 0),
		SwipeRight = Vector2.new(1, 0),
	}
	self:OnStep(function(_, t)
		local guide = self.guide
		if not guide or not guide.hand.Parent then
			return
		end
		local pressed = os.clock() - guide.cueAt < 0.2
		local scale = if pressed then 0.78 else 1
		local position = Vector2.new(0.5, 0.5)
		-- Les jeux à direction changeante indiquent la bonne (self.guideDirection : "Up", "Left"…)
		local direction = directions[if self.guideDirection then `Swipe{self.guideDirection}` else gesture]
		local transparency = 0
		if gesture == "Drag" then
			position += Vector2.new(0.3 * math.sin(t * 2.2), 0)
		elseif direction then
			local phase = (t * 1.1) % 1
			position += direction * (0.34 * math.min(phase * 2, 1) - 0.12)
			transparency = if phase > 0.7 then (phase - 0.7) / 0.3 else 0
		elseif gesture == "Hold" then
			scale = 0.86 + 0.05 * math.sin(t * 6)
		elseif gesture == "Sides" then
			-- Le jeu indique le côté attendu (self.guideSide) ; sinon la main alterne
			local side = self.guideSide or (if math.floor(t * 1.4) % 2 == 0 then "Left" else "Right")
			position = Vector2.new(if side == "Left" then 0.25 else 0.75, 0.6)
		end
		guide.hand.Position = UDim2.fromScale(position.X, position.Y)
		guide.hand.Size = UDim2.fromOffset(64 * scale, 64 * scale)
		guide.hand.TextTransparency = transparency
	end)
end

-- Annonce d'une nouveauté du jeu (« anneau rouge : ne touche pas ! »), une seule fois par partie et par clé
function Kit:Announce(key: string)
	self.announced = self.announced or {}
	if self.announced[key] or not self.root then
		return
	end
	self.announced[key] = true
	local banner = Ui.label({
		Name = "Announce",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Color3.fromRGB(255, 90, 60),
		BackgroundTransparency = 0.05,
		Text = Texts.Get(key),
		ZIndex = 35,
		Parent = self.root,
	})
	Ui.corner(UDim.new(0, 10)).Parent = banner
	Ui.create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = banner,
	})
	banner.Size = UDim2.fromScale(1, 0)
	TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 0, 40),
	}):Play()
	task.delay(SETTINGS.AnnounceTime, function()
		if banner.Parent then
			TweenService:Create(banner, TweenInfo.new(0.3), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			task.delay(0.35, function()
				banner:Destroy()
			end)
		end
	end)
end

-- Espace, Entrée ou bouton A de la manette (pour les jeux dont le geste tactile est un glissé)
function Kit:OnAction(callback: () -> ())
	self:Connect(Kit.Input.InputBegan, function(input)
		if
			input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			callback()
		end
	end)
end

-- La main fantôme appuie maintenant (montre le bon moment)
function Kit:GuideCue()
	if self.guide then
		self.guide.cueAt = os.clock()
	end
end

function Kit:HideGuide()
	local guide = self.guide
	if not guide then
		return
	end
	self.guide = nil
	TweenService:Create(guide.hand, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	task.delay(0.35, function()
		guide.hand:Destroy()
	end)
end

function Kit:Destroy()
	self.destroyed = true
	for _, connection in self.connections do
		connection:Disconnect()
	end
	if self.root then
		self.root:Destroy()
	end
end

-- Petit texte au centre d'un objet (emoji ou consigne)
function Kit:Emoji(parent: GuiObject, text: string, size: number, zIndex: number?): TextLabel
	return Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Text = text,
		TextStrokeTransparency = 1,
		ZIndex = zIndex or 3,
		Parent = parent,
	})
end

return Kit
