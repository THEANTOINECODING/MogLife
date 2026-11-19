-- Mog Rush (D132) : tableau géant flottant au-dessus de la fontaine de la place, 4 écrans dos à dos (un par avenue).
-- Le tableau est décoratif : il est construit par chaque client (aucune collision, aucun coût serveur) et animé
-- localement : flottement, couronne qui tourne, reflet qui balaie le titre, lignes qui glissent quand le classement
-- change, scores qui défilent, compte à rebours qui rougit la dernière minute, flash « NEW RUSH! » au changement.
-- Les données viennent du serveur (remote MogRushState, MogRushService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage.Shared.Format)
local MogRush = require(ReplicatedStorage.Shared.Config.MogRush)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer
local BOARD = MogRush.Board

local MogRushController = {}
local UIController

-- Couleurs du tableau (nuit violette, or, néons)
local NIGHT = Color3.fromRGB(16, 10, 30)
local NIGHT_2 = Color3.fromRGB(38, 20, 70)
local GOLD = Color3.fromRGB(255, 200, 50)
local GOLD_DEEP = Color3.fromRGB(214, 140, 20)
local MAGENTA = Color3.fromRGB(255, 60, 170)
local CYAN = Color3.fromRGB(60, 230, 255)
local RANK_COLORS = {
	Color3.fromRGB(255, 205, 60), -- or
	Color3.fromRGB(205, 220, 240), -- argent
	Color3.fromRGB(230, 145, 80), -- bronze
}
local ROW_COLOR = Color3.fromRGB(44, 30, 78)
local ROW_YOU = Color3.fromRGB(30, 110, 150)

-- Dimensions de l'écran en pixels (SurfaceGui en pixels par stud)

local CANVAS_H = BOARD.ScreenHeight * BOARD.PixelsPerStud
local HEADER_H = 168
local TIMER_H = 80
local FOOTER_H = 176
local ROW_GAP = 6
local ROWS_TOP = HEADER_H + TIMER_H + 8
local ROWS_H = CANVAS_H - ROWS_TOP - FOOTER_H - 8
local BIG_ROW = 66 -- lignes 1 à 3 (les lignes 4 à 10 se partagent le reste)
local SMALL_ROW = (ROWS_H - 3 * BIG_ROW - (MogRush.TopSize - 1) * ROW_GAP) // (MogRush.TopSize - 3)

type Row = {
	frame: Frame,
	rank: TextLabel,
	rankDisc: Frame,
	avatar: ImageLabel,
	name: TextLabel,
	score: TextLabel,
	glow: UIStroke,
	shown: number, -- score affiché (défile vers la vraie valeur)
	target: number,
	userId: number,
	slot: number,
}

type Face = {
	gui: SurfaceGui,
	rows: { [number]: Row }, -- par userId
	timer: TextLabel,
	bar: Frame,
	barFill: Frame,
	shine: UIGradient,
	titleScale: UIScale,
	you: TextLabel,
	podium: TextLabel,
	empty: TextLabel,
	flash: TextLabel,
}

local model: Model? = nil
local pivotBase: CFrame
local crown: BasePart? = nil
local crownBase: CFrame
local faces: { Face } = {}
local state = nil
local lastRound = 0
local lastRank: number? = nil

-- ------------------------------------------------------------------ modèle 3D

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function buildModel(): Model
	local m = Instance.new("Model")
	m.Name = "MogRushBoard"
	local w, h = BOARD.ScreenWidth, BOARD.ScreenHeight
	local half = w / 2
	local root = CFrame.new(BOARD.Center)

	-- Noyau sombre
	local core = part({
		Name = "Core",
		Size = Vector3.new(w - 0.6, h, w - 0.6),
		CFrame = root,
		Color = NIGHT,
	})
	core.Parent = m
	m.PrimaryPart = core

	-- Quatre écrans (face avant de chaque Part tournée vers l'extérieur)
	for index = 1, 4 do
		local angle = math.rad((index - 1) * 90)
		local facing = root * CFrame.Angles(0, angle, 0)
		local screen = part({
			Name = `Screen{index}`,
			Size = Vector3.new(w - 2.4, h - 2.2, 0.2),
			CFrame = facing * CFrame.new(0, 0, -(half - 0.15)), -- face avant vers l'extérieur
			Color = Color3.new(0, 0, 0),
		})
		screen.Parent = m
	end

	-- Cadre doré : piliers d'angle, bandeaux haut et bas, liserés néon
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part({
				Name = "Pillar",
				Size = Vector3.new(1.8, h + 2.4, 1.8),
				CFrame = root * CFrame.new(sx * half, 0, sz * half),
				Color = GOLD,
				Material = Enum.Material.Metal,
				Reflectance = 0.15,
			}).Parent =
				m
			-- Gemme néon au sommet et en bas de chaque pilier
			for _, sy in { -1, 1 } do
				part({
					Name = "Gem",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1.6, 1.6, 1.6),
					CFrame = root * CFrame.new(sx * half, sy * (h / 2 + 1.6), sz * half),
					Color = MAGENTA,
					Material = Enum.Material.Neon,
				}).Parent =
					m
			end
		end
	end
	for _, sy in { -1, 1 } do
		part({
			Name = "Band",
			Size = Vector3.new(w + 1.2, 1.2, w + 1.2),
			CFrame = root * CFrame.new(0, sy * (h / 2 + 0.4), 0),
			Color = GOLD_DEEP,
			Material = Enum.Material.Metal,
			Reflectance = 0.1,
		}).Parent =
			m
		for index = 1, 4 do
			local angle = math.rad((index - 1) * 90)
			part({
				Name = "Neon",
				Size = Vector3.new(w - 1.6, 0.25, 0.25),
				CFrame = root * CFrame.Angles(0, angle, 0) * CFrame.new(0, sy * (h / 2 - 0.55), -(half + 0.05)),
				Color = if sy > 0 then CYAN else MAGENTA,
				Material = Enum.Material.Neon,
			}).Parent =
				m
		end
	end

	-- Fond pointu sous le tableau (pyramide inversée de 4 coins) et anneau lumineux
	local bottom = root * CFrame.new(0, -(h / 2 + 1), 0)
	for index = 1, 4 do
		local angle = math.rad((index - 1) * 90 + 45)
		local wedge = part({
			Name = "Keel",
			Size = Vector3.new(2.2, 5.5, 2.2),
			CFrame = bottom
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(0, -2.2, -half * 0.55)
				* CFrame.Angles(math.rad(-28), 0, 0),
			Color = GOLD_DEEP,
			Material = Enum.Material.Metal,
		})
		wedge.Parent = m
	end
	local tip = part({
		Name = "Tip",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		CFrame = bottom * CFrame.new(0, -5.2, 0),
		Color = GOLD,
		Material = Enum.Material.Neon,
	})
	tip.Parent = m
	local glow = Instance.new("PointLight")
	glow.Color = GOLD
	glow.Range = 26
	glow.Brightness = 2
	glow.Parent = tip

	-- Poussière d'or qui monte de la fontaine vers le tableau
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	dust.Color = ColorSequence.new(GOLD, Color3.fromRGB(255, 240, 180))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(2.5, 4)
	dust.Rate = 14
	dust.Speed = NumberRange.new(2, 4)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.LightEmission = 1
	dust.Parent = tip

	-- Couronne : anneau d'or et 8 pointes surmontées de gemmes, posée sur le bandeau du haut (elle tourne)
	local crownBaseCf = root * CFrame.new(0, h / 2 + 2.3, 0)
	local ring = part({
		Name = "Crown",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.2, 13, 13),
		CFrame = crownBaseCf * CFrame.Angles(0, 0, math.rad(90)),
		Color = GOLD,
		Material = Enum.Material.Metal,
		Reflectance = 0.2,
	})
	ring.Parent = m
	for index = 1, 8 do
		local angle = math.rad((index - 1) * 45)
		local spike = part({
			Name = "CrownSpike",
			Size = Vector3.new(2.2, 4.2, 1),
			CFrame = crownBaseCf * CFrame.Angles(0, angle, 0) * CFrame.new(0, 2.8, -5.6),
			Color = GOLD,
			Material = Enum.Material.Metal,
			Reflectance = 0.2,
		})
		spike.Parent = m
		local gem = part({
			Name = "CrownGem",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = crownBaseCf * CFrame.Angles(0, angle, 0) * CFrame.new(0, 5.3, -5.6),
			Color = if index % 2 == 0 then CYAN else MAGENTA,
			Material = Enum.Material.Neon,
		})
		gem.Parent = m
	end
	-- Les pièces de la couronne suivent l'anneau (soudées) : on ne fait tourner qu'une pièce
	for _, child in m:GetChildren() do
		if child.Name == "CrownSpike" or child.Name == "CrownGem" then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = ring
			weld.Part1 = child :: BasePart
			weld.Parent = child;
			(child :: BasePart).Anchored = false
		end
	end
	crown = ring
	crownBase = ring.CFrame
	return m
end

-- ------------------------------------------------------------------ écrans

local function text(props: { [string]: any }): TextLabel
	local label = Ui.create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
	})
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

local function slotY(slot: number): number
	if slot <= 3 then
		return (slot - 1) * (BIG_ROW + ROW_GAP)
	end
	return 3 * (BIG_ROW + ROW_GAP) + (slot - 4) * (SMALL_ROW + ROW_GAP)
end

local function slotHeight(slot: number): number
	return if slot <= 3 then BIG_ROW else SMALL_ROW
end

local function buildFace(screen: BasePart, parent: Instance): Face
	local gui = Instance.new("SurfaceGui")
	gui.Name = `MogRush_{screen.Name}`
	gui.Adornee = screen
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = BOARD.PixelsPerStud
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.MaxDistance = BOARD.MaxDistance
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local back = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1), -- teinté par le dégradé
		BorderSizePixel = 0,
		Parent = gui,
	})
	Ui.gradient(NIGHT_2, NIGHT, 90).Parent = back

	-- Titre : « MOG RUSH » en or, avec un reflet qui le balaie
	local title = text({
		Text = Texts.Get("MogRush.Title"),
		Size = UDim2.new(1, -60, 0, 108),
		Position = UDim2.fromOffset(30, 10),
		TextColor3 = Color3.new(1, 1, 1),
		Parent = back,
	})
	local titleStroke = Ui.outline(title, 6, Color3.fromRGB(70, 30, 0))
	titleStroke.Transparency = 0
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(0.42, GOLD),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 235)),
		ColorSequenceKeypoint.new(0.58, GOLD),
		ColorSequenceKeypoint.new(1, GOLD_DEEP),
	})
	shine.Rotation = 20
	shine.Parent = title
	local titleScale = Instance.new("UIScale")
	titleScale.Parent = title
	text({
		Text = Texts.Get("MogRush.Subtitle"),
		Size = UDim2.new(1, -120, 0, 44),
		Position = UDim2.fromOffset(60, 120),
		TextColor3 = CYAN,
		Parent = back,
	})

	-- Compte à rebours et barre qui se vide
	local timer = text({
		Text = "",
		Size = UDim2.new(1, -80, 0, 46),
		Position = UDim2.fromOffset(40, HEADER_H),
		Parent = back,
	})
	Ui.outline(timer, 3, Color3.new(0, 0, 0))
	local bar = Ui.create("Frame", {
		Size = UDim2.new(1, -80, 0, 18),
		Position = UDim2.fromOffset(40, HEADER_H + 54),
		BackgroundColor3 = Color3.fromRGB(10, 6, 20),
		Parent = back,
	}, { Ui.corner(UDim.new(1, 0)) })
	local barFill = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = bar,
	}, { Ui.corner(UDim.new(1, 0)) })
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new(MAGENTA, GOLD)
	fillGradient.Parent = barFill

	-- Zone des lignes
	local list = Ui.create("Frame", {
		Name = "Rows",
		Size = UDim2.new(1, -60, 0, ROWS_H),
		Position = UDim2.fromOffset(30, ROWS_TOP),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = back,
	})
	local empty = text({
		Text = Texts.Get("MogRush.Empty"),
		Size = UDim2.new(1, -80, 0, 60),
		Position = UDim2.fromOffset(40, ROWS_TOP + ROWS_H / 2 - 30),
		TextColor3 = Color3.fromRGB(200, 190, 230),
		Visible = false,
		Parent = back,
	})

	-- Pied : ma place, et les champions de la manche précédente
	local you = text({
		Text = "",
		Size = UDim2.new(1, -60, 0, 62),
		Position = UDim2.new(0, 30, 1, -FOOTER_H + 2),
		Parent = back,
	})
	Ui.outline(you, 3, Color3.new(0, 0, 0))
	text({
		Text = Texts.Get("MogRush.LastChampions"),
		Size = UDim2.new(1, -160, 0, 30),
		Position = UDim2.new(0, 80, 1, -FOOTER_H + 68),
		TextColor3 = Color3.fromRGB(200, 190, 230),
		Parent = back,
	})
	-- Noms des joueurs : jamais traduits
	local podiumLabel = text({
		Text = "",
		Size = UDim2.new(1, -60, 0, 44),
		Position = UDim2.new(0, 30, 1, -FOOTER_H + 98),
		TextColor3 = GOLD,
		Parent = back,
	})
	podiumLabel.AutoLocalize = false
	local hint = text({
		Text = Texts.Get("MogRush.Hint"),
		Size = UDim2.new(1, -120, 0, 30),
		Position = UDim2.new(0, 60, 1, -FOOTER_H + 144),
		TextColor3 = Color3.fromRGB(190, 175, 230),
		Parent = back,
	})
	hint.Name = "Hint"

	-- Flash du changement de manche
	local flash = text({
		Text = Texts.Get("MogRush.NewRoundFlash"),
		Size = UDim2.fromScale(1, 0.3),
		Position = UDim2.fromScale(0, 0.35),
		TextColor3 = GOLD,
		TextTransparency = 1,
		ZIndex = 5,
		Parent = back,
	})
	local flashStroke = Ui.outline(flash, 8, Color3.fromRGB(60, 0, 40))
	flashStroke.Transparency = 1

	gui.Parent = parent
	return {
		gui = gui,
		rows = {},
		timer = timer,
		bar = bar,
		barFill = barFill,
		shine = shine,
		titleScale = titleScale,
		you = you,
		podium = podiumLabel,
		empty = empty,
		flash = flash,
		list = list,
	} :: any
end

local function newRow(face: any, entry, slot: number): Row
	local height = slotHeight(slot)
	local frame = Ui.create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		Position = UDim2.new(1.1, 0, 0, slotY(slot)), -- entre par la droite
		BackgroundColor3 = ROW_COLOR,
		Parent = face.list,
	}, { Ui.corner(UDim.new(0, 18)) })
	local glow = Ui.stroke(GOLD, 4, 1)
	glow.Parent = frame
	local rankDisc = Ui.create("Frame", {
		Size = UDim2.fromOffset(height - 14, height - 14),
		Position = UDim2.fromOffset(10, 7),
		BackgroundColor3 = RANK_COLORS[slot] or Color3.fromRGB(80, 60, 130),
		Parent = frame,
	}, { Ui.corner(UDim.new(1, 0)) })
	local rank = text({
		Text = tostring(slot),
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.1, 0.1),
		TextColor3 = if slot <= 3 then Color3.fromRGB(50, 25, 0) else Color3.new(1, 1, 1),
		Parent = rankDisc,
	})
	rank.AutoLocalize = false
	local avatar = Ui.create("ImageLabel", {
		Size = UDim2.fromOffset(height - 10, height - 10),
		Position = UDim2.fromOffset(height + 8, 5),
		BackgroundColor3 = Color3.fromRGB(70, 50, 110),
		Image = `rbxthumb://type=AvatarHeadShot&id={entry.userId}&w=150&h=150`,
		Parent = frame,
	}, { Ui.corner(UDim.new(1, 0)) })
	local name = text({
		Text = entry.name,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.55, -(2 * height), 0.62, 0),
		Position = UDim2.new(0, 2 * height + 18, 0.19, 0),
		Parent = frame,
	})
	name.AutoLocalize = false
	local score = text({
		Text = Format.Short(entry.score),
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromScale(0.36, 0.62),
		Position = UDim2.new(0.62, -14, 0.19, 0),
		TextColor3 = GOLD,
		Parent = frame,
	})
	score.AutoLocalize = false
	Ui.outline(score, 3, Color3.new(0, 0, 0))
	return {
		frame = frame,
		rank = rank,
		rankDisc = rankDisc,
		avatar = avatar,
		name = name,
		score = score,
		glow = glow,
		shown = entry.score,
		target = entry.score,
		userId = entry.userId,
		slot = slot,
	}
end

local SLIDE = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function updateRows(face: any, top: { any })
	local seen = {}
	for slot, entry in top do
		seen[entry.userId] = true
		local row: Row = face.rows[entry.userId]
		if not row then
			row = newRow(face, entry, slot)
			face.rows[entry.userId] = row
		end
		row.target = entry.score
		row.name.Text = entry.name
		local mine = entry.userId == player.UserId
		row.frame.BackgroundColor3 = if mine then ROW_YOU else ROW_COLOR
		row.glow.Transparency = if slot == 1 or mine then 0 else 1
		row.glow.Color = if mine then CYAN else GOLD
		if row.slot ~= slot or row.frame.Position.X.Scale ~= 0 then
			row.slot = slot
			local height = slotHeight(slot)
			row.rank.Text = tostring(slot)
			row.rankDisc.BackgroundColor3 = RANK_COLORS[slot] or Color3.fromRGB(80, 60, 130)
			row.rank.TextColor3 = if slot <= 3 then Color3.fromRGB(50, 25, 0) else Color3.new(1, 1, 1)
			row.rankDisc.Size = UDim2.fromOffset(height - 14, height - 14)
			row.avatar.Size = UDim2.fromOffset(height - 10, height - 10)
			row.avatar.Position = UDim2.fromOffset(height + 8, 5)
			row.name.Size = UDim2.new(0.55, -(2 * height), 0.62, 0)
			row.name.Position = UDim2.new(0, 2 * height + 18, 0.19, 0)
			TweenService:Create(row.frame, SLIDE, {
				Position = UDim2.fromOffset(0, slotY(slot)),
				Size = UDim2.new(1, 0, 0, height),
			}):Play()
		end
	end
	for userId, row in face.rows do
		if not seen[userId] then
			face.rows[userId] = nil
			local frame = row.frame
			TweenService:Create(frame, FADE, { Position = UDim2.new(-1.1, 0, 0, frame.Position.Y.Offset) }):Play()
			task.delay(FADE.Time + 0.05, function()
				frame:Destroy()
			end)
		end
	end
	face.empty.Visible = #top == 0
end

local function podiumText(podium: { any }): string
	if #podium == 0 then
		return Texts.Get("MogRush.NoChampions")
	end
	local medals = { "🥇", "🥈", "🥉" }
	local parts = {}
	for index, entry in podium do
		table.insert(parts, `{medals[index] or ""} {entry.name} {Format.Short(entry.score)}`)
	end
	return table.concat(parts, "   ")
end

local function youText(you): string
	if you.rank then
		return Texts.Get("MogRush.YouRanked", { rank = you.rank, mog = Format.Short(you.score) })
	elseif you.score > 0 then
		return Texts.Get("MogRush.YouScore", { mog = Format.Short(you.score) })
	end
	return Texts.Get("MogRush.YouNone")
end

local function playFlash()
	for _, face in faces do
		local flash = face.flash
		local stroke = flash:FindFirstChildOfClass("UIStroke")
		flash.TextTransparency = 0
		if stroke then
			stroke.Transparency = 0
		end
		local scale = flash:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Scale = 0.4
		scale.Parent = flash
		TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(2.2, function()
			TweenService:Create(flash, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
		end)
	end
end

local function onState(newState)
	if typeof(newState) ~= "table" or typeof(newState.top) ~= "table" then
		return
	end
	local firstState = state == nil
	state = newState
	if not firstState and newState.round ~= lastRound then
		playFlash()
	end
	lastRound = newState.round
	for _, face in faces do
		updateRows(face, newState.top)
		face.you.Text = youText(newState.you)
		face.podium.Text = podiumText(newState.podium or {})
	end
	-- Petite annonce quand on entre dans le top 10 ou qu'on prend la 1re place
	local rank = newState.you and newState.you.rank
	if not firstState and UIController and rank and rank ~= lastRank then
		if rank == 1 then
			UIController.Toast(Texts.Get("MogRush.ToastFirst"))
		elseif lastRank == nil then
			UIController.Toast(Texts.Get("MogRush.ToastTop", { rank = rank }))
		end
	end
	lastRank = rank
end

-- ------------------------------------------------------------------ animation

local function step(dt: number)
	local current = model
	if not current then
		return
	end
	local camera = Workspace.CurrentCamera
	local far = camera and (camera.CFrame.Position - BOARD.Center).Magnitude > BOARD.MaxDistance
	local t = os.clock()

	if not far then
		-- Flottement du tableau et rotation de la couronne
		local bob = math.sin(t * 2 * math.pi / BOARD.BobPeriod) * BOARD.Bob
		current:PivotTo(pivotBase + Vector3.new(0, bob, 0))
		local ring = crown
		if ring then
			local spin = (t % BOARD.CrownSpin) / BOARD.CrownSpin * 2 * math.pi
			ring.CFrame = (crownBase + Vector3.new(0, bob, 0)) * CFrame.Angles(spin, 0, 0)
		end
	end

	local s = state
	for _, face in faces do
		-- Reflet du titre et léger battement
		face.shine.Offset = Vector2.new(((t * 0.45) % 2.4) - 1.2, 0)
		face.titleScale.Scale = 1 + 0.025 * math.sin(t * 3)
		if s then
			local left = math.max(s.endsAt - Workspace:GetServerTimeNow(), 0)
			local minutes = math.floor(left / 60)
			local seconds = math.floor(left % 60)
			face.timer.Text = Texts.Get("MogRush.ResetsIn", { time = string.format("%d:%02d", minutes, seconds) })
			local urgent = left <= 60
			face.timer.TextColor3 = if urgent
				then Color3.fromRGB(255, 90 + 80 * (0.5 + 0.5 * math.sin(t * 8)), 90)
				else Color3.new(1, 1, 1)
			face.barFill.Size = UDim2.fromScale(math.clamp(left / MogRush.RoundSeconds, 0, 1), 1)
			-- Scores qui défilent vers leur valeur
			for _, row in face.rows do
				if row.shown ~= row.target then
					local diff = row.target - row.shown
					row.shown = if math.abs(diff) < 1 then row.target else row.shown + diff * math.min(dt * 4, 1)
					row.score.Text = Format.Short(row.shown)
				end
				if row.slot == 1 then
					row.glow.Thickness = 4 + 2 * math.sin(t * 4)
				end
			end
		end
	end
end

-- ------------------------------------------------------------------ cycle

function MogRushController.Init(controllers)
	UIController = controllers.UIController
end

function MogRushController.Start()
	local m = buildModel()
	m.Parent = Workspace
	model = m
	pivotBase = m:GetPivot()
	local playerGui = player:WaitForChild("PlayerGui")
	for index = 1, 4 do
		local screen = m:FindFirstChild(`Screen{index}`) :: BasePart
		table.insert(faces, buildFace(screen, playerGui))
	end
	Remotes.MogRushState.OnClientEvent:Connect(onState)
	RunService.RenderStepped:Connect(step)
end

return MogRushController
