-- Petites aides pour construire l'interface en code.

local Ui = {}

local UserInputService = game:GetService("UserInputService")

Ui.Font = Enum.Font.FredokaOne

function Ui.isPhonePortrait(): boolean
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.zero
	return UserInputService.TouchEnabled and size.X < 600 and size.X < size.Y
end

function Ui.watchViewport(update: () -> ())
	local connection: RBXScriptConnection? = nil
	local function watchCamera()
		if connection then
			connection:Disconnect()
		end
		local camera = workspace.CurrentCamera
		if camera then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

-- Emplacements du HUD (D124) : la pastille d'objectif en haut à gauche, sous les boutons de Roblox, et la colonne
-- du menu dessous (MenuController la place sous la pastille, au milieu du bord gauche si la place le permet).
-- Téléphone en portrait : le haut est pris par les compteurs, la pastille passe dessous.
-- `pillBottom` : bas de la pastille en pixels (dans un ScreenGui qui respecte la barre de Roblox).
export type MenuSlots = {
	pillPosition: UDim2,
	pillSize: UDim2,
	pillBottom: number,
}

function Ui.menuSlots(): MenuSlots
	if Ui.isPhonePortrait() then
		return {
			pillPosition = UDim2.fromOffset(8, 64),
			pillSize = UDim2.new(1, -16, 0, 34),
			pillBottom = 98,
		}
	elseif UserInputService.TouchEnabled then
		return {
			pillPosition = UDim2.fromOffset(10, 6),
			pillSize = UDim2.new(0.36, 0, 0, 36),
			pillBottom = 42,
		}
	end
	return {
		pillPosition = UDim2.fromOffset(12, 10),
		pillSize = UDim2.fromOffset(300, 42),
		pillBottom = 52,
	}
end

-- Petit écran (téléphone) : le plus petit côté fait au plus 500 pixels (même seuil que le bouton de saut de Roblox)
function Ui.isSmallScreen(): boolean
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1000, 1000)
	return math.min(size.X, size.Y) <= 500
end

-- Crée une instance, applique ses propriétés, puis lui ajoute ses enfants.
-- Parent est appliqué en dernier pour éviter des mises à jour inutiles.
function Ui.create(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Ui.corner(radius: UDim?): UICorner
	return Ui.create("UICorner", { CornerRadius = radius or UDim.new(0, 12) })
end

function Ui.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Ui.create("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Thickness = thickness or 3,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.gradient(top: Color3, bottom: Color3, rotation: number?): UIGradient
	return Ui.create("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

-- Panneau de mini-jeu : fond sombre dégradé, coins ronds, contour clair.
function Ui.panel(props: { [string]: any }): Frame
	local base = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.15,
	}
	for key, value in props do
		base[key] = value
	end
	return Ui.create("Frame", base, {
		Ui.corner(UDim.new(0, 18)),
		Ui.gradient(Color3.fromRGB(70, 45, 110), Color3.fromRGB(25, 20, 40)),
		Ui.stroke(Color3.fromRGB(255, 220, 120), 3, 0.2),
	})
end

-- Texte gras, mis à l'échelle automatiquement, fond transparent.
function Ui.label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
	}
	for key, value in props do
		base[key] = value
	end
	return Ui.create("TextLabel", base)
end

function Ui.button(props: { [string]: any }): TextButton
	local base = {
		Font = Ui.Font,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = true,
	}
	for key, value in props do
		base[key] = value
	end
	return Ui.create("TextButton", base, {
		Ui.corner(),
		Ui.create("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
	})
end

-- Croix de fermeture (D106) : pastille ronde dans le coin haut droit du panneau, assez grande pour un pouce
function Ui.closeButton(props: { [string]: any }): TextButton
	local base = {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Color3.fromRGB(220, 60, 70),
		ZIndex = 10,
	}
	for key, value in props do
		base[key] = value
	end
	-- Style bonbon (D124) : dégradé rouge, contour sombre, croix cernée ; elle s'enfonce à l'appui
	local color = base.BackgroundColor3
	base.BackgroundColor3 = Color3.new(1, 1, 1)
	base.AutoButtonColor = false
	local button = Ui.button(base)
	button:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	Ui.gradient(Ui.shade(color, 1.3), color).Parent = button
	Ui.stroke(Ui.Ink, 2.5).Parent = button
	Ui.outline(button, 2)
	Ui.juice(button)
	return button
end

-- Fenêtre de taille fixe : rétrécie (UIScale) si elle dépasse de l'écran, par exemple un téléphone en paysage
-- (≈ 390 points de haut). Jamais agrandie. `margin` : marge totale en pixels autour de la fenêtre.
function Ui.fitToScreen(panel: GuiObject, margin: number?)
	local scale = panel:FindFirstChildOfClass("UIScale") or Ui.create("UIScale", { Parent = panel })
	local gap = margin or 16
	local function update()
		local parent = panel.Parent
		local area = if parent and parent:IsA("GuiBase2d") then parent.AbsoluteSize else Vector2.zero
		if area.X < 1 or area.Y < 1 then
			return
		end
		-- Taille demandée, sans l'échelle actuelle
		local size = panel.Size
		local width = size.X.Offset + size.X.Scale * area.X
		local height = size.Y.Offset + size.Y.Scale * area.Y
		if width < 1 or height < 1 then
			return
		end
		scale.Scale = math.min(1, (area.X - gap) / width, (area.Y - gap) / height)
	end
	panel:GetPropertyChangedSignal("Size"):Connect(update)
	panel:GetPropertyChangedSignal("Parent"):Connect(update)
	panel:GetPropertyChangedSignal("Visible"):Connect(update)
	Ui.watchViewport(function()
		task.defer(update)
	end)
end

-- ------------------------------------------------------------------ style « bonbon » (D124)
-- Langage visuel commun du HUD, repris des jeux Roblox les plus joués (Gym League, Steal a Brainrot, Pet Simulator 99,
-- Adopt Me) : formes rondes, contour sombre épais, relief (une « lèvre » plus foncée sous chaque bouton), reflet en
-- haut, texte blanc cerné de sombre. Chaque bouton s'enfonce quand on appuie et rebondit quand on relâche.

local TweenService = game:GetService("TweenService")

Ui.Ink = Color3.fromRGB(29, 20, 48) -- contour commun (violet presque noir, plus doux que le noir pur)
Ui.Dark = Color3.fromRGB(25, 18, 40) -- fond des pastilles du HUD

-- Couleur assombrie (factor < 1) ou éclaircie vers le blanc (factor > 1)
function Ui.shade(color: Color3, factor: number): Color3
	if factor <= 1 then
		return Color3.new(color.R * factor, color.G * factor, color.B * factor)
	end
	return color:Lerp(Color3.new(1, 1, 1), math.min(factor - 1, 1))
end

-- Contour épais autour des lettres d'un texte (le texte reste lisible sur le ciel comme sur le sol)
function Ui.outline(label: TextLabel | TextButton, thickness: number?, color: Color3?): UIStroke
	label.TextStrokeTransparency = 1
	return Ui.create("UIStroke", {
		Color = color or Ui.Ink,
		Thickness = thickness or 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = label,
	})
end

-- Réaction d'un bouton : il grossit un peu au survol (souris), s'enfonce à l'appui (dès que le doigt touche, pas au
-- relâcher) et rebondit en dépassant légèrement sa taille au relâcher. `onPress` : appelé à l'appui (son du clic).
local PRESS_SCALE = 0.88
local HOVER_SCALE = 1.06
function Ui.juice(button: GuiButton, onPress: (() -> ())?): UIScale
	local scale = button:FindFirstChildOfClass("UIScale") or Ui.create("UIScale", { Parent = button })
	local hovered = false
	local pressed = false
	local function go(target: number, time: number, style: Enum.EasingStyle)
		TweenService:Create(scale, TweenInfo.new(time, style, Enum.EasingDirection.Out), { Scale = target }):Play()
	end
	button.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			pressed = true
			go(PRESS_SCALE, 0.07, Enum.EasingStyle.Quad)
			if onPress then
				onPress()
			end
		elseif kind == Enum.UserInputType.MouseMovement and not hovered then
			hovered = true
			if not pressed then
				go(HOVER_SCALE, 0.12, Enum.EasingStyle.Quad)
			end
		end
	end)
	button.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			pressed = false
			go(if hovered then HOVER_SCALE else 1, 0.3, Enum.EasingStyle.Back)
		elseif kind == Enum.UserInputType.MouseMovement then
			hovered = false
			if not pressed then
				go(1, 0.15, Enum.EasingStyle.Quad)
			end
		end
	end)
	-- Manette : la case choisie grossit comme au survol
	button.SelectionGained:Connect(function()
		go(HOVER_SCALE, 0.12, Enum.EasingStyle.Quad)
	end)
	button.SelectionLost:Connect(function()
		go(1, 0.15, Enum.EasingStyle.Quad)
	end)
	return scale
end

-- Case de menu en relief : lèvre foncée dessous, face en dégradé, reflet, grosse icône, nom qui déborde en bas.
-- Le bouton lui-même est transparent ; `size` est sa taille en pixels (la case est carrée).
export type TileProps = {
	name: string,
	icon: string,
	caption: string,
	color: Color3,
	size: number,
	layoutOrder: number?,
	parent: Instance?,
}
function Ui.tile(props: TileProps): TextButton
	local size = props.size
	local radius = UDim.new(0.26, 0)
	local lip = math.max(math.floor(size * 0.07), 3)
	local button = Ui.create("TextButton", {
		Name = props.name,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = props.layoutOrder or 0,
	})
	Ui.create("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, lip),
		Size = UDim2.new(1, 0, 1, -lip),
		BackgroundColor3 = Ui.shade(props.color, 0.55),
		ZIndex = 1,
		Parent = button,
	}, { Ui.create("UICorner", { CornerRadius = radius }), Ui.stroke(Ui.Ink, 2.5) })
	local face = Ui.create("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -lip),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = button,
	}, {
		Ui.create("UICorner", { CornerRadius = radius }),
		Ui.gradient(Ui.shade(props.color, 1.25), props.color),
		Ui.stroke(Ui.Ink, 2.5),
	})
	Ui.create("Frame", {
		Name = "Gloss",
		Position = UDim2.fromScale(0.08, 0.05),
		Size = UDim2.fromScale(0.84, 0.42),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = face,
	}, {
		Ui.create("UICorner", { CornerRadius = UDim.new(0.4, 0) }),
		Ui.create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new(0.55, 1),
		}),
	})
	Ui.label({
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.62, 0.62),
		Text = props.icon,
		TextStrokeTransparency = 1,
		ZIndex = 4,
		Parent = face,
	})
	-- Nom : à cheval sur le bas de la case, plus large qu'elle (les traductions sont plus longues que l'anglais)
	local caption = Ui.label({
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, math.floor(size * 0.1)),
		Size = UDim2.fromScale(1.35, 0.3),
		Text = props.caption,
		ZIndex = 5,
		Parent = button,
	})
	Ui.outline(caption, if size >= 60 then 3 else 2.5)
	-- Pastille de notification (cachée) : un rond rouge cerné de blanc dans le coin haut droit
	local badge = Ui.create("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromScale(0.38, 0.38),
		BackgroundColor3 = Color3.fromRGB(255, 46, 77),
		Visible = false,
		ZIndex = 7,
		Parent = button,
	}, { Ui.create("UICorner", { CornerRadius = UDim.new(1, 0) }), Ui.stroke(Color3.new(1, 1, 1), 2) })
	Ui.create("UIScale", { Parent = badge })
	Ui.label({
		Name = "Text",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		Text = "!",
		TextStrokeTransparency = 1,
		ZIndex = 8,
		Parent = badge,
	})
	if props.parent then
		button.Parent = props.parent
	end
	return button
end

-- Affiche ou cache la pastille d'une case (Ui.tile)
function Ui.setBadge(tile: GuiObject, on: boolean)
	local badge = tile:FindFirstChild("Badge")
	if badge and badge:IsA("GuiObject") then
		badge.Visible = on
	end
end

-- ------------------------------------------------------------------ manette (GamepadController)
-- Une fenêtre « modale » (boutique, réglages, défi…) est marquée pour la manette : quand elle s'ouvre, son bouton
-- par défaut est sélectionné (A pour valider, croix directionnelle pour naviguer) ; B déclenche son bouton retour.

local CollectionService = game:GetService("CollectionService")

Ui.MODAL_TAG = "GamepadModal"
Ui.BACK_TAG = "GamepadBack"
Ui.DEFAULT_TAG = "GamepadDefault"
Ui.backHandlers = setmetatable({} :: { [GuiButton]: () -> () }, { __mode = "k" })

-- Marque une fenêtre pour la manette ; `default` est le bouton sélectionné à l'ouverture
function Ui.markModal(window: Instance, default: GuiButton?)
	CollectionService:AddTag(window, Ui.MODAL_TAG)
	if default then
		CollectionService:AddTag(default, Ui.DEFAULT_TAG)
	end
end

-- Bouton retour (fermer, annuler, refuser) : le clic et le bouton B de la manette appellent `handler`
function Ui.onBack(button: GuiButton, handler: () -> ()): RBXScriptConnection
	Ui.backHandlers[button] = handler
	CollectionService:AddTag(button, Ui.BACK_TAG)
	return button.Activated:Connect(handler)
end

return Ui
