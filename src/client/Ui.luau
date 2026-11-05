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

-- Emplacements du menu (D96) : le rond qui ouvre le tiroir, la pastille d'objectif à côté, le tiroir dessous.
-- Téléphone en portrait : le haut à gauche est pris par les compteurs, le rond passe à droite et la pastille dessous.
export type MenuSlots = {
	buttonAnchor: Vector2,
	buttonPosition: UDim2,
	buttonSize: UDim2,
	pillPosition: UDim2,
	pillSize: UDim2,
	drawerAnchor: Vector2,
	drawerPosition: UDim2,
	tileSize: Vector2,
}

function Ui.menuSlots(): MenuSlots
	if Ui.isPhonePortrait() then
		return {
			buttonAnchor = Vector2.new(1, 0),
			buttonPosition = UDim2.new(1, -8, 0, 8),
			buttonSize = UDim2.fromOffset(48, 48),
			pillPosition = UDim2.fromOffset(8, 64),
			pillSize = UDim2.new(1, -16, 0, 34),
			drawerAnchor = Vector2.new(1, 0),
			drawerPosition = UDim2.new(1, -8, 0, 62),
			tileSize = Vector2.new(68, 54),
		}
	elseif UserInputService.TouchEnabled then
		return {
			buttonAnchor = Vector2.zero,
			buttonPosition = UDim2.fromOffset(8, 8),
			buttonSize = UDim2.fromOffset(44, 44),
			pillPosition = UDim2.fromOffset(58, 10),
			pillSize = UDim2.new(0.36, 0, 0, 40),
			drawerAnchor = Vector2.zero,
			drawerPosition = UDim2.fromOffset(8, 58),
			tileSize = Vector2.new(68, 54),
		}
	end
	return {
		buttonAnchor = Vector2.zero,
		buttonPosition = UDim2.fromOffset(12, 12),
		buttonSize = UDim2.fromOffset(52, 52),
		pillPosition = UDim2.fromOffset(72, 16),
		pillSize = UDim2.fromOffset(330, 44),
		drawerAnchor = Vector2.zero,
		drawerPosition = UDim2.fromOffset(12, 72),
		tileSize = Vector2.new(88, 64),
	}
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
	local button = Ui.button(base)
	button:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	Ui.stroke(Color3.new(1, 1, 1), 2, 0.2).Parent = button
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
