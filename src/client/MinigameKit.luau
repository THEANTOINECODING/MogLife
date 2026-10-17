-- Boîte à outils commune des mini-jeux : panneau, entrées (clic/toucher, clavier, manette, pointeur),
-- notation Perfect / Good / Miss, boucle d'animation, mode auto et nettoyage.
--
-- Interface commune de tout mini-jeu (module dans src/client/Minigames/) :
--   Minigame.new(parent: GuiObject, interval: number, onRep: (quality: string) -> (), options: Options?)
--   minigame:SetAuto(on: boolean)   -- en mode auto, le mini-jeu s'anime tout seul et ne note rien
--   minigame:Destroy()
-- options.timingScale (< 1 = fenêtres plus serrées, utilisé en combat de boss et en duel)
-- options.seed (graine du motif : en duel, les deux joueurs ont exactement la même suite)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Ui = require(script.Parent.Ui)

export type Options = {
	timingScale: number?,
	seed: number?, -- graine du motif (duels : les deux joueurs jouent la même suite)
}

local Kit = {}
Kit.__index = Kit

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
	self.auto = false
	self.startTime = os.clock()
	self.connections = {}
	self.pointer = Vector2.zero
	self.pointerActive = false
	self.onAutoChanged = nil :: ((boolean) -> ())?
	return self
end

-- Panneau principal (à droite de l'écran). Un TextButton si `tappable`, pour capter les touches.
function Kit:Panel(size: UDim2, tappable: boolean?): GuiObject
	local props = {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 20),
		Size = size,
		Parent = self.parent,
	}
	local panel
	if tappable then
		panel = Ui.create("TextButton", {
			AnchorPoint = props.AnchorPoint,
			Position = props.Position,
			Size = size,
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
	return panel
end

function Kit:Connect(signal: RBXScriptSignal, callback: (...any) -> ())
	table.insert(self.connections, signal:Connect(callback))
end

-- Appelle `callback(dt, t)` à chaque image (t = secondes depuis le début du mini-jeu)
function Kit:OnStep(callback: (number, number) -> ())
	self:Connect(RunService.RenderStepped, function(dt)
		callback(dt, os.clock() - self.startTime)
	end)
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Appui « action » : clic / toucher sur `zone` (ou n'importe où si nil), Espace, bouton A
function Kit:OnPress(callback: () -> (), zone: GuiObject?)
	if zone then
		self:Connect(zone.InputBegan, function(input)
			if isPress(input) and not self.auto then
				callback()
			end
		end)
	end
	self:Connect(UserInputService.InputBegan, function(input)
		if self.auto then
			return
		end
		local key = input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA
		if key or (not zone and isPress(input)) then
			callback()
		end
	end)
end

function Kit:OnRelease(callback: () -> ())
	self:Connect(UserInputService.InputEnded, function(input)
		if isPress(input) or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			callback()
		end
	end)
end

-- Suivi du pointeur (souris, doigt) en coordonnées d'écran : self.pointer, self.pointerActive
function Kit:TrackPointer()
	local function update(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
			self.pointer = Vector2.new(input.Position.X, input.Position.Y)
			self.pointerActive = true
		end
	end
	self:Connect(UserInputService.InputChanged, update)
	self:Connect(UserInputService.InputBegan, update)
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
	self:Connect(UserInputService.InputBegan, function(input)
		local direction = DIRECTION_KEYS[input.KeyCode]
		if direction and not self.auto then
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
	for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if state.KeyCode == Enum.KeyCode.Thumbstick1 and state.Position.Magnitude > 0.2 then
			x, y = state.Position.X, -state.Position.Y
		end
	end
	return Vector2.new(x, y)
end

-- Boutons de direction à l'écran (mobile) : une rangée en bas du panneau
function Kit:AddDirectionButtons(directions: { string }, callback: (string) -> ())
	local count = #directions
	for index, direction in directions do
		local button = Ui.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new((index - 0.5) / count, 0, 1, -10),
			Size = UDim2.new(1 / count, -12, 0, 56),
			BackgroundColor3 = Color3.fromRGB(60, 60, 75),
			Text = Kit.ARROWS[direction] or direction,
			ZIndex = 5,
			Parent = self.root,
		})
		self:Connect(button.Activated, function()
			if not self.auto then
				callback(direction)
			end
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

function Kit:Rep(quality: string)
	if not self.auto then
		self.onRep(quality)
	end
end

function Kit:SetAuto(on: boolean)
	self.auto = on
	if self.onAutoChanged then
		self.onAutoChanged(on)
	end
end

function Kit:Destroy()
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
