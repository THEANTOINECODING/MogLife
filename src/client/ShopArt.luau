-- Habillage animé des offres payantes et des récompenses (D137) : rayons qui tournent, reflet qui balaie, étincelles,
-- rubans, pastilles de bonus, pluie d'icônes et grande scène de célébration après un achat ou l'ouverture d'un coffre.
-- Une seule boucle RenderStepped anime tout ; un objet détruit sort tout seul de la boucle. Purement visuel.
-- Utilisé par StoreController (boutique Robux), RewardsController (pack de départ) et WeeklyController (coffre).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Ui = require(script.Parent.Ui)

local ShopArt = {}

-- ------------------------------------------------------------------ boucle commune

type Entry = { object: Instance, step: (t: number, dt: number) -> boolean? }
local entries: { Entry } = {}
local loop: RBXScriptConnection? = nil
local clock = 0

local function tick(dt: number)
	clock += dt
	for index = #entries, 1, -1 do
		local entry = entries[index]
		if not entry.object.Parent or entry.step(clock, dt) == false then
			table.remove(entries, index)
		end
	end
	if #entries == 0 and loop then
		loop:Disconnect()
		loop = nil
	end
end

-- `step` est appelé à chaque image tant que `object` existe ; il renvoie false pour s'arrêter
local function track(object: Instance, step: (t: number, dt: number) -> boolean?)
	table.insert(entries, { object = object, step = step })
	if not loop then
		loop = RunService.RenderStepped:Connect(tick)
	end
end
ShopArt.Track = track

local function visible(object: GuiObject): boolean
	local node: Instance? = object
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	return true
end

-- ------------------------------------------------------------------ éléments

export type RaysProps = {
	color: Color3,
	count: number?,
	speed: number?, -- degrés par seconde
	transparency: number?, -- transparence au centre des rayons
	size: UDim2?,
	position: UDim2?,
	zIndex: number?,
}

-- Soleil de rayons derrière une récompense : un carré centré, des faisceaux qui s'estompent vers le bord, un halo
function ShopArt.rays(parent: Instance, props: RaysProps): Frame
	local holder = Ui.create("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		Size = props.size or UDim2.fromScale(1.4, 1.4),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex or 1,
		Parent = parent,
	})
	local count = props.count or 8
	local base = props.transparency or 0.45
	for index = 1, count do
		local beam = Ui.create("Frame", {
			Name = "Beam",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.13, 1),
			Rotation = (index - 1) * 180 / count,
			BackgroundColor3 = props.color,
			BorderSizePixel = 0,
			ZIndex = holder.ZIndex,
			Parent = holder,
		}, {
			Ui.create("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.3, base + (1 - base) * 0.35),
					NumberSequenceKeypoint.new(0.5, base),
					NumberSequenceKeypoint.new(0.7, base + (1 - base) * 0.35),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		-- Faisceaux en éventail : plus larges au bout (deux bandes inclinées donnent un vrai rayon)
		beam.Size = UDim2.fromScale(if index % 2 == 0 then 0.08 else 0.14, 1)
	end
	Ui.create("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = props.color,
		BackgroundTransparency = base,
		BorderSizePixel = 0,
		ZIndex = holder.ZIndex,
		Parent = holder,
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	local speed = props.speed or 20
	track(holder, function(_, dt)
		if visible(holder) then
			holder.Rotation = (holder.Rotation + speed * dt) % 360
		end
		return nil
	end)
	return holder
end

-- Reflet blanc qui balaie `target` en diagonale toutes les `period` secondes (bouton, carte, titre)
function ShopArt.shine(target: GuiObject, period: number?, strength: number?): Frame
	local corner = target:FindFirstChildOfClass("UICorner")
	local sheen = Ui.create("Frame", {
		Name = "Shine",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = target.ZIndex + 1,
		Active = false,
		Parent = target,
	}, {
		Ui.create("UICorner", { CornerRadius = if corner then corner.CornerRadius else UDim.new(0, 12) }),
	})
	local peak = 1 - (strength or 0.55)
	local gradient = Ui.create("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 1),
			NumberSequenceKeypoint.new(0.5, peak),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-1, 0),
		Parent = sheen,
	})
	local every = period or 2.6
	local phase = math.random() * every
	track(sheen, function(t)
		local u = ((t + phase) % every) / 0.7 -- le passage dure 0,7 s, puis une pause
		gradient.Offset = Vector2.new(if u < 1 then -1 + u * 2 else 1.5, 0)
		return nil
	end)
	return sheen
end

-- Étincelles (une croix fine et un point qui brillent) qui scintillent à des places tirées au hasard dans `parent`.
-- Dessinées avec des cadres : la police du jeu n'a pas les glyphes ✦ / ★.
function ShopArt.twinkles(parent: Instance, color: Color3, count: number, seed: number?, zIndex: number?)
	local rng = Random.new(seed or math.random(1, 1e6))
	for _ = 1, count do
		local star = Ui.create("Frame", {
			Name = "Twinkle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(rng:NextNumber(0.08, 0.92), rng:NextNumber(0.08, 0.92)),
			Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 1,
			ZIndex = zIndex or 3,
			Parent = parent,
		})
		local bars: { Frame } = {}
		for _, spec in { { 0.16, 1 }, { 1, 0.16 } } do
			table.insert(
				bars,
				Ui.create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(spec[1], spec[2]),
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					ZIndex = star.ZIndex,
					Parent = star,
				}, { Ui.corner(UDim.new(1, 0)) })
			)
		end
		table.insert(
			bars,
			Ui.create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.38, 0.38),
				Rotation = 45,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ZIndex = star.ZIndex,
				Parent = star,
			}, { Ui.corner(UDim.new(0.2, 0)) })
		)
		local speed = rng:NextNumber(1.4, 2.6)
		local phase = rng:NextNumber(0, math.pi * 2)
		local size = rng:NextNumber(12, 24)
		track(star, function(t)
			local on = math.max(math.sin(t * speed + phase), 0)
			for _, bar in bars do
				bar.BackgroundTransparency = 1 - on
			end
			local k = size * (0.3 + on * 0.7)
			star.Size = UDim2.fromOffset(k, k)
			star.Rotation = t * 40 + phase * 30
			return nil
		end)
	end
end

-- Mouvement continu d'un élément (flottement vertical, léger roulis, respiration) autour de sa place d'origine
function ShopArt.float(target: GuiObject, amplitude: number?, speed: number?, breathe: number?)
	local base = target.Position
	local baseSize = target.Size
	local lift = amplitude or 5
	local rate = speed or 2
	local grow = breathe or 0.04
	local phase = math.random() * math.pi * 2
	track(target, function(t)
		local wave = math.sin(t * rate + phase)
		target.Position = base + UDim2.fromOffset(0, -lift * wave)
		target.Rotation = math.sin(t * rate * 0.5 + phase) * 4
		local k = 1 + grow * math.sin(t * rate * 1.3 + phase)
		target.Size =
			UDim2.new(baseSize.X.Scale * k, baseSize.X.Offset * k, baseSize.Y.Scale * k, baseSize.Y.Offset * k)
		return nil
	end)
end

-- Ruban penché collé en haut d'une carte (« BEST VALUE ») qui palpite doucement
function ShopArt.ribbon(parent: Instance, text: string, color: Color3, zIndex: number?): Frame
	local ribbon = Ui.create("Frame", {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(0.86, 0, 0, 28),
		Rotation = -4,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = zIndex or 8,
		Parent = parent,
	}, {
		Ui.corner(UDim.new(0, 8)),
		Ui.gradient(Ui.shade(color, 1.35), color),
		Ui.stroke(Ui.Ink, 2.5),
	})
	local label = Ui.label({
		Size = UDim2.new(1, -10, 1, -4),
		Position = UDim2.fromOffset(5, 2),
		Text = text,
		ZIndex = ribbon.ZIndex + 1,
		Parent = ribbon,
	})
	Ui.outline(label, 2)
	ShopArt.shine(ribbon, 1.8, 0.7)
	local scale = Ui.create("UIScale", { Parent = ribbon })
	track(ribbon, function(t)
		scale.Scale = 1 + 0.05 * math.max(math.sin(t * 4), 0)
		return nil
	end)
	return ribbon
end

-- Pastille ronde penchée (« +64% ») dans un coin
function ShopArt.sticker(parent: Instance, text: string, color: Color3, position: UDim2, zIndex: number?): Frame
	local sticker = Ui.create("Frame", {
		Name = "Sticker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(62, 62),
		Rotation = -14,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = zIndex or 8,
		Parent = parent,
	}, {
		Ui.corner(UDim.new(1, 0)),
		Ui.gradient(Ui.shade(color, 1.4), color),
		Ui.stroke(Ui.Ink, 2.5),
	})
	local label = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.62),
		Text = text,
		ZIndex = sticker.ZIndex + 1,
		Parent = sticker,
	})
	Ui.outline(label, 1.8)
	track(sticker, function(t)
		sticker.Rotation = -14 + math.sin(t * 3) * 6
		return nil
	end)
	return sticker
end

-- Bordure dont la couleur tourne (or, blanc, couleur du rang) : pour l'offre la plus forte
function ShopArt.glowStroke(target: GuiObject, color: Color3, thickness: number?): UIStroke
	local stroke = target:FindFirstChildOfClass("UIStroke") or Ui.create("UIStroke", { Parent = target })
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = thickness or 3
	stroke.Transparency = 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local gradient = Ui.create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(0.25, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, color),
			ColorSequenceKeypoint.new(0.75, Ui.shade(color, 0.6)),
			ColorSequenceKeypoint.new(1, color),
		}),
		Parent = stroke,
	})
	track(stroke, function(t)
		gradient.Rotation = (t * 90) % 360
		return nil
	end)
	return stroke
end

-- Texte dont la couleur ondule (dégradé qui défile) : montants des packs, titres
function ShopArt.shimmerText(label: TextLabel, from: Color3, to: Color3)
	label.TextColor3 = Color3.new(1, 1, 1)
	local gradient = Ui.create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, from),
			ColorSequenceKeypoint.new(0.45, from),
			ColorSequenceKeypoint.new(0.5, to),
			ColorSequenceKeypoint.new(0.55, from),
			ColorSequenceKeypoint.new(1, from),
		}),
		Rotation = 15,
		Parent = label,
	})
	local phase = math.random() * 3
	track(label, function(t)
		local u = ((t + phase) % 3) / 1.2
		gradient.Offset = Vector2.new(if u < 1 then -1 + u * 2 else 1, 0)
		return nil
	end)
end

-- Gerbe d'icônes (pièces, étoiles…) qui jaillissent d'un point de `parent` puis retombent en tournant
function ShopArt.burst(
	parent: Instance,
	origin: Vector2,
	glyphs: { string },
	count: number,
	power: number?,
	zIndex: number?
)
	local force = power or 420
	for index = 1, count do
		local angle = math.rad(math.random(-160, -20))
		local speed = force * (0.55 + math.random() * 0.6)
		local velocity = Vector2.new(math.cos(angle), math.sin(angle)) * speed
		local position = origin
		local spin = math.random(-360, 360)
		local size = math.random(26, 46)
		local life = 1.1 + math.random() * 0.6
		local label = Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(origin.X, origin.Y),
			Size = UDim2.fromOffset(size, size),
			Text = glyphs[(index - 1) % #glyphs + 1],
			TextStrokeTransparency = 1,
			ZIndex = zIndex or 40,
			Parent = parent,
		})
		local age = 0
		track(label, function(_, dt)
			age += dt
			velocity += Vector2.new(0, 900 * dt)
			position += velocity * dt
			label.Position = UDim2.fromOffset(position.X, position.Y)
			label.Rotation += spin * dt
			label.TextTransparency = math.clamp((age - life * 0.65) / (life * 0.35), 0, 1)
			if age >= life then
				label:Destroy()
				return false
			end
			return nil
		end)
	end
end

-- ------------------------------------------------------------------ célébration plein écran

export type CelebrateOptions = {
	color: Color3, -- couleur des rayons et du titre
	icon: string?, -- grosse icône (si pas de modèle 3D)
	build: ((viewport: ViewportFrame) -> ((t: number) -> ())?)?, -- dessine un modèle 3D ; renvoie son animation
	title: string, -- texte final (« +20.0K CASH! »)
	count: ((progress: number) -> string)?, -- texte pendant le décompte (0 → 1)
	subtitle: string?,
	glyphs: { string },
	duration: number?,
	onDone: (() -> ())?,
}

local busy = false

-- Rideau sombre, rayons géants, la récompense qui jaillit et rebondit, le montant qui défile, une gerbe d'icônes, puis
-- tout se replie (`onDone` : par exemple l'envol des pièces vers le compteur). Une seule à la fois.
function ShopArt.Celebrate(options: CelebrateOptions)
	if busy then
		if options.onDone then
			options.onDone()
		end
		return
	end
	busy = true
	local duration = options.duration or 2.6
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Ui.create("ScreenGui", {
		Name = "Celebration",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 40,
		Parent = playerGui,
	})
	local shade = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(12, 8, 24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	})
	local stage = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.62, 0.62),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = gui,
	})
	local stageScale = Ui.create("UIScale", { Scale = 0, Parent = stage })
	ShopArt.rays(stage, {
		color = options.color,
		count = 12,
		speed = 35,
		transparency = 0.25,
		size = UDim2.fromScale(2.2, 2.2),
		zIndex = 2,
	})
	local rays2 = ShopArt.rays(stage, {
		color = Color3.new(1, 1, 1),
		count = 6,
		speed = -22,
		transparency = 0.6,
		size = UDim2.fromScale(1.6, 1.6),
		zIndex = 2,
	})
	ShopArt.twinkles(stage, Color3.fromRGB(255, 245, 200), 10, nil, 4)
	local animateModel: ((t: number) -> ())? = nil
	if options.build then
		local viewport = Ui.create("ViewportFrame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(190, 180, 170),
			LightColor = Color3.fromRGB(255, 245, 225),
			LightDirection = Vector3.new(-0.4, -1, -0.5),
			ZIndex = 3,
			Parent = stage,
		})
		animateModel = options.build(viewport)
	else
		Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			Text = options.icon or "",
			TextStrokeTransparency = 1,
			ZIndex = 3,
			Parent = stage,
		})
	end
	local title = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromScale(0.9, 0.13),
		Text = if options.count then options.count(0) else options.title,
		ZIndex = 6,
		Parent = gui,
	})
	Ui.create("UITextSizeConstraint", { MaxTextSize = 96, Parent = title })
	Ui.outline(title, 5)
	ShopArt.shimmerText(title, options.color, Color3.new(1, 1, 1))
	local titleScale = Ui.create("UIScale", { Scale = 0, Parent = title })
	local subtitle = if options.subtitle
		then Ui.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.86),
			Size = UDim2.fromScale(0.8, 0.055),
			Text = options.subtitle,
			TextTransparency = 1,
			ZIndex = 6,
			Parent = gui,
		})
		else nil
	if subtitle then
		Ui.outline(subtitle, 3)
	end

	local popAt, countFrom, countTo = 0.15, 0.55, 1.45
	local burstDone = false
	local settledAt: number? = nil
	local outStart = duration - 0.45
	local start = os.clock()
	local function backOut(x: number): number
		x = math.clamp(x, 0, 1)
		local u = x - 1
		return 1 + 2.70158 * u * u * u + 1.70158 * u * u
	end
	track(gui, function()
		local t = os.clock() - start
		-- Rideau, puis la récompense jaillit (dépassement) et se pose ; elle respire ensuite
		shade.BackgroundTransparency = 1
			- 0.55 * math.clamp(t / 0.25, 0, 1) * (1 - math.clamp((t - outStart) / 0.4, 0, 1))
		local pop = backOut((t - popAt) / 0.45)
		local out = math.clamp((t - outStart) / 0.35, 0, 1)
		local thump = if settledAt then 0.22 * math.max(0, 1 - (t - settledAt) / 0.3) else 0
		stageScale.Scale = math.max(pop, 0) * (1 + 0.04 * math.sin(t * 5) + thump) * (1 - out)
		rays2.Visible = t > popAt
		if animateModel then
			animateModel(t)
		end
		if t > countFrom and not burstDone then
			burstDone = true
			local center = stage.AbsolutePosition + stage.AbsoluteSize / 2
			ShopArt.burst(gui, center, options.glyphs, 26, 620, 8)
		end
		titleScale.Scale = math.max(backOut((t - countFrom + 0.15) / 0.4), 0) * (1 - out)
		if options.count then
			local progress = math.clamp((t - countFrom) / (countTo - countFrom), 0, 1)
			progress = 1 - (1 - progress) ^ 3
			title.Text = if progress >= 1 then options.title else options.count(progress)
			if progress >= 1 and not settledAt then
				settledAt = t
			end
		end
		if subtitle then
			subtitle.TextTransparency = 1 - math.clamp((t - countTo) / 0.3, 0, 1) * (1 - out)
		end
		if t >= duration then
			busy = false
			gui:Destroy()
			if options.onDone then
				options.onDone()
			end
			return false
		end
		return nil
	end)
end

return ShopArt
