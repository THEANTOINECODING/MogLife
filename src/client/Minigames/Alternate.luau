-- Mini-jeu « Alternate » (exercice : tractions) : une main après l'autre, en rythme.
-- Sur chaque pulsation, frapper le côté indiqué (◀ ▶, A / D, flèches, boutons). Mauvaise main = Miss.

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local Alternate = {}

function Alternate.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(360, 320))

	local function hand(x: number, emoji: string)
		local frame = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, 0, 0, 110),
			Size = UDim2.fromOffset(120, 120),
			BackgroundColor3 = Color3.fromRGB(60, 60, 75),
			Parent = panel,
		}, { Ui.corner(UDim.new(1, 0)) })
		local stroke = Ui.stroke(Color3.new(1, 1, 1), 5, 0)
		stroke.Parent = frame
		self:Emoji(frame, emoji, 70, 3).Position = UDim2.fromScale(0.5, 0.5)
		return frame, stroke
	end
	local left, leftStroke = hand(0.28, "🤛")
	local right, rightStroke = hand(0.72, "🤜")
	-- Barre de traction au-dessus
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.new(1, -40, 0, 10),
		BackgroundColor3 = Color3.fromRGB(180, 180, 190),
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })

	local expected = "Left"
	local lastBeatAnswered = -1

	local function press(side: string)
		local t = os.clock() - self.startTime
		local beat = math.floor(t / interval + 0.5)
		if beat == lastBeatAnswered or beat < 1 then
			return
		end
		lastBeatAnswered = beat
		local offset = math.abs(t - beat * interval)
		local quality = if side == expected then self:GradeOffset(offset) else "Miss"
		if side == expected then
			expected = if expected == "Left" then "Right" else "Left"
		end
		self:Rep(quality)
	end
	self:OnDirection(function(direction)
		if direction == "Left" or direction == "Right" then
			press(direction)
		end
	end)
	self:AddDirectionButtons({ "Left", "Right" }, press)

	self:OnStep(function(_, t)
		-- Le cercle de la main attendue se resserre jusqu'à la pulsation
		local phase = (t / interval) % 1
		local active = if expected == "Left" then left else right
		local idle = if expected == "Left" then right else left
		active.Size = UDim2.fromOffset(160 - 40 * phase, 160 - 40 * phase)
		idle.Size = UDim2.fromOffset(100, 100)
		leftStroke.Color = if expected == "Left" then Color3.fromRGB(255, 220, 60) else Color3.new(1, 1, 1)
		rightStroke.Color = if expected == "Right" then Color3.fromRGB(255, 220, 60) else Color3.new(1, 1, 1)
		if self.auto then
			local beat = math.floor(t / interval)
			if beat > lastBeatAnswered then
				lastBeatAnswered = beat
				expected = if expected == "Left" then "Right" else "Left"
			end
		end
	end)

	return self
end

return Alternate
