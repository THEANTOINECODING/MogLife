-- Mini-jeu « Beats » (boss : Coach Turbo, D81) : des notes descendent sur 2 pistes au rythme du mégaphone ; toucher
-- la moitié gauche ou droite de l'écran (un pouce de chaque côté) quand la note touche la ligne. Note ratée = raté.
-- Les notes tombent plus vite à chaque manche. Surprise (niveau Beats.LongLevel) : notes longues, garder le doigt
-- jusqu'au bout de la note (lâcher trop tôt la rend Good, ou ratée si c'est beaucoup trop tôt).
-- Clavier : A / D, flèches ; manette : gâchettes, croix.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Beats
local HIT_Y = 0.82
local NOTE_COLOR = { Left = Color3.fromRGB(255, 80, 130), Right = Color3.fromRGB(80, 180, 255) }

local Beats = {}

function Beats.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	-- Panneau large et bas : un pouce sur chaque piste, le joueur et le coach visibles au-dessus (D82)
	local panel = self:WidePanel(SETTINGS.PanelHeight)
	local rng = self:Random()

	local track = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = Color3.fromRGB(30, 25, 45),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = Color3.fromRGB(90, 90, 110),
		Parent = track,
	})
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, HIT_Y),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Color3.fromRGB(255, 220, 120),
		ZIndex = 3,
		Parent = track,
	})
	-- Les deux pads : ils s'allument quand on touche ce côté
	local pads = {}
	for _, lane in { "Left", "Right" } do
		pads[lane] = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(if lane == "Left" then 0.25 else 0.75, HIT_Y),
			Size = UDim2.new(0.42, 0, 0, 34),
			BackgroundColor3 = NOTE_COLOR[lane],
			BackgroundTransparency = 0.7,
			ZIndex = 2,
			Parent = track,
		}, { Ui.corner(UDim.new(0, 10)) })
	end
	local coach = self:Emoji(panel, "📣", 50, 6)
	coach.Position = UDim2.new(0.5, 0, 0, 34)

	local fallTime = interval * math.max(SETTINGS.FallFactor - SETTINGS.FallPerLevel * self.level, 0.9)
	-- { lane, arrivesAt, endsAt (notes longues), frame, tail, held, headQuality }
	local notes = {}
	local nextArrival = os.clock() + fallTime + 0.2
	local pressedAt: { [string]: number } = {}

	local function laneX(lane: string): number
		return if lane == "Left" then 0.25 else 0.75
	end

	local function remove(index: number)
		local note = notes[index]
		note.frame:Destroy()
		if note.tail then
			note.tail:Destroy()
		end
		table.remove(notes, index)
	end

	local function hit(lane: string)
		local now = os.clock()
		pressedAt[lane] = now
		local best, bestOffset = nil, math.huge
		for index, note in notes do
			local offset = math.abs(note.arrivesAt - now)
			if note.lane == lane and not note.held and offset < bestOffset then
				best, bestOffset = index, offset
			end
		end
		-- Frappe dans le vide (trop loin d'une note) : ignorée
		if not best or bestOffset > interval * 0.5 then
			return
		end
		local note = notes[best]
		local quality = self:GradeOffset(bestOffset)
		if note.endsAt and quality ~= "Miss" then
			-- Note longue : il faut garder le doigt jusqu'au bout
			note.held = true
			note.headQuality = quality
			self:Burst(quality, pads[lane])
			return
		end
		remove(best)
		self:Rep(quality, pads[lane])
	end
	local function release(lane: string)
		pressedAt[lane] = nil
		local now = os.clock()
		for index, note in notes do
			if note.lane == lane and note.held then
				local early = note.endsAt - now
				local quality = note.headQuality
				if early > interval * 0.3 then
					quality = "Miss"
				elseif early > Balance.TimingWindows.Good * self.timingScale then
					quality = "Good"
				end
				remove(index)
				self:Rep(quality, pads[lane])
				return
			end
		end
	end
	self:OnSide(hit, release)
	self:Guide(panel, "Sides")

	self:OnStep(function()
		local now = os.clock()
		if now + fallTime >= nextArrival then
			local lane = if rng:NextNumber() < 0.5 then "Left" else "Right"
			local long = self.level >= SETTINGS.LongLevel and rng:NextNumber() < SETTINGS.LongChance
			local note = {
				lane = lane,
				arrivesAt = nextArrival,
				endsAt = if long then nextArrival + interval * SETTINGS.LongLength else nil,
				frame = Ui.create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.new(0.4, 0, 0, 24),
					BackgroundColor3 = NOTE_COLOR[lane],
					ZIndex = 4,
					Parent = track,
				}, { Ui.corner(UDim.new(0, 8)), Ui.stroke(Color3.new(1, 1, 1), 2, 0.3) }),
				tail = nil :: Frame?,
				held = false,
				headQuality = "Good",
			}
			if long then
				self:Announce("Minigame.Twist.Beats.Long")
				note.tail = Ui.create("Frame", {
					AnchorPoint = Vector2.new(0.5, 1),
					Size = UDim2.fromScale(0.16, 0),
					BackgroundColor3 = NOTE_COLOR[lane],
					BackgroundTransparency = 0.35,
					ZIndex = 3,
					Parent = track,
				}, { Ui.corner(UDim.new(0, 6)) })
			end
			table.insert(notes, note)
			-- Une note longue prend la place de la suivante (la cadence moyenne ne change pas)
			nextArrival += interval * (if long then 1 + SETTINGS.LongLength else 1)
		end

		local height = track.AbsoluteSize.Y
		for index = #notes, 1, -1 do
			local note = notes[index]
			local progress = 1 - (note.arrivesAt - now) / fallTime
			local y = if note.held then HIT_Y else progress * HIT_Y
			note.frame.Position = UDim2.fromScale(laneX(note.lane), y)
			if note.tail and note.endsAt then
				local tailTop = 1 - (note.endsAt - now) / fallTime
				local length = math.max(y - tailTop * HIT_Y, 0) * height
				note.tail.Position = UDim2.fromScale(laneX(note.lane), y)
				note.tail.Size = UDim2.new(0.16, 0, 0, length)
			end
			if note.held and note.endsAt and now >= note.endsAt then
				-- Gardée jusqu'au bout
				local lane = note.lane
				local quality = note.headQuality
				remove(index)
				self:Rep(quality, pads[lane])
			elseif not note.held and now - note.arrivesAt > interval * 0.5 then
				local lane = note.lane
				remove(index)
				self:Rep("Miss", pads[lane])
			end
		end
		for lane, pad in pads do
			pad.BackgroundTransparency = if pressedAt[lane] and now - pressedAt[lane] < 0.12 then 0.2 else 0.7
		end
		local first = notes[1]
		if first then
			self.guideSide = first.lane
			if math.abs(first.arrivesAt - now) < 0.02 then
				self:GuideCue()
			end
		end
		coach.Size = UDim2.fromOffset(50 + 10 * (1 - ((now % interval) / interval)), 50)
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { notes = notes }
	end

	return self
end

return Beats
