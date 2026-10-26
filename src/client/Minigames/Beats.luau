-- Mini-jeu « Beats » (boss : Coach Turbo) : des notes descendent sur 2 pistes au rythme du mégaphone ;
-- frapper la bonne piste quand la note touche la ligne (◀ ▶, A / D, flèches, boutons).

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local HIT_Y = 0.8

local Beats = {}

function Beats.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(300, 430))

	local track = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -90),
		BackgroundColor3 = Color3.fromRGB(30, 25, 45),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	Ui.create("Frame", {
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
		Parent = track,
	})

	local fallTime = interval * 1.5
	local notes = {} -- { lane = "Left" | "Right", arrivesAt, frame }
	local nextSpawn = 0

	local function laneX(lane: string): number
		return if lane == "Left" then 0.25 else 0.75
	end

	local function hit(lane: string)
		local now = os.clock() - self.startTime
		local best, bestOffset = nil, math.huge
		for index, note in notes do
			local offset = math.abs(note.arrivesAt - now)
			if note.lane == lane and offset < bestOffset then
				best, bestOffset = index, offset
			end
		end
		-- Frappe dans le vide (trop loin d'une note) : ignorée
		if not best or bestOffset > interval * 0.5 then
			return
		end
		notes[best].frame:Destroy()
		table.remove(notes, best)
		self:Rep(self:GradeOffset(bestOffset))
	end
	self:OnDirection(function(direction)
		if direction == "Left" or direction == "Right" then
			hit(direction)
		end
	end)
	self:AddDirectionButtons({ "Left", "Right" }, hit)

	self:OnStep(function(_, t)
		if t + fallTime >= nextSpawn then
			local arrivesAt = math.max(nextSpawn, fallTime)
			nextSpawn = arrivesAt + interval
			table.insert(notes, {
				lane = if math.random() < 0.5 then "Left" else "Right",
				arrivesAt = arrivesAt,
				frame = Ui.create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.new(0.4, 0, 0, 22),
					BackgroundColor3 = Color3.fromRGB(255, 80, 120),
					ZIndex = 2,
					Parent = track,
				}, { Ui.corner(UDim.new(0, 8)) }),
			})
		end

		for index = #notes, 1, -1 do
			local note = notes[index]
			local progress = 1 - (note.arrivesAt - t) / fallTime
			note.frame.Position = UDim2.fromScale(laneX(note.lane), progress * HIT_Y)
			if self.auto and t >= note.arrivesAt then
				note.frame:Destroy()
				table.remove(notes, index)
			elseif t - note.arrivesAt > interval * 0.5 then
				-- Note ratée
				note.frame:Destroy()
				table.remove(notes, index)
				self:Rep("Miss")
			end
		end
	end)

	return self
end

return Beats
