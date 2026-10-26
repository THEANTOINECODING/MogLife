-- Mini-jeu « Lanes » (aide : porter le piano de Mme Do-Ré) : le piano avance dans un couloir à
-- 3 voies ; chaque vague de vases bloque 2 voies sur 3. Rejoindre la voie libre (◀ ▶, A / D, flèches, boutons).
-- Vague passée = Perfect (Good si esquive de dernière seconde), percutée = Miss.
-- Sans rien faire, on ne passe qu'une vague sur trois.

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local LANES = 3
local PIANO_Y = 0.72
local LAST_SECOND = 0.3 -- esquive tardive (secondes avant l'impact)

local Lanes = {}

function Lanes.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(330, 420))

	local hall = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -90),
		BackgroundColor3 = Color3.fromRGB(230, 210, 180),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	for i = 1, LANES - 1 do
		Ui.create("Frame", {
			Position = UDim2.fromScale(i / LANES, 0),
			Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = Color3.fromRGB(180, 150, 120),
			Parent = hall,
		})
	end
	local piano = self:Emoji(hall, "🎹", 70, 4)

	local lane = 2
	local lastMoveAt = 0
	local fallTime = interval * 1.6
	local waves = {} -- { free = voie libre, spawnedAt, labels }
	local nextSpawn = 0

	local function laneX(index: number): number
		return (index - 0.5) / LANES
	end

	local function move(direction: string)
		local before = lane
		if direction == "Left" then
			lane = math.max(lane - 1, 1)
		elseif direction == "Right" then
			lane = math.min(lane + 1, LANES)
		end
		if lane ~= before then
			lastMoveAt = os.clock()
		end
	end
	self:OnDirection(move)
	self:AddDirectionButtons({ "Left", "Right" }, move)

	self:OnStep(function(_, t)
		if t >= nextSpawn then
			nextSpawn = t + interval
			local wave = { free = math.random(1, LANES), spawnedAt = t, labels = {} }
			for vaseLane = 1, LANES do
				if vaseLane ~= wave.free then
					wave.labels[vaseLane] = self:Emoji(hall, "🏺", 48, 3)
				end
			end
			table.insert(waves, wave)
		end

		for index = #waves, 1, -1 do
			local wave = waves[index]
			local progress = (t - wave.spawnedAt) / fallTime
			for vaseLane, label in wave.labels do
				label.Position = UDim2.fromScale(laneX(vaseLane), progress * PIANO_Y)
			end
			if self.auto and progress >= 0.7 then
				-- En mode auto, le piano rejoint tout seul la voie libre
				lane = wave.free
			end
			if progress >= 1 then
				if not self.auto then
					if lane ~= wave.free then
						self:Rep("Miss")
					else
						local late = os.clock() - lastMoveAt < LAST_SECOND / self.timingScale
						self:Rep(if late then "Good" else "Perfect")
					end
				end
				for _, label in wave.labels do
					label:Destroy()
				end
				table.remove(waves, index)
			end
		end

		piano.Position = UDim2.fromScale(laneX(lane), PIANO_Y + 0.12)
	end)

	return self
end

return Lanes
