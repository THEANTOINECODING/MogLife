-- Petites aides pour construire l'interface en code.

local Ui = {}

Ui.Font = Enum.Font.FredokaOne

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

return Ui
