-- Mini-jeu « Sequence » (aide : indiquer le chemin au touriste perdu, D81) : sur le petit plan, le touriste montre
-- son chemin (une case après l'autre, depuis l'épingle), puis le chemin s'efface. Le refaire en glissant le pouce
-- dans chaque direction (n'importe où). Une erreur = raté (le bon chemin s'affiche) ; sans erreur et vite =
-- Perfect, sans erreur = Good. Le chemin s'allonge à chaque niveau (3, puis 4, puis 5 pas).
-- Clavier : flèches, ZQSD/WASD ; manette : croix, coup de stick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Sequence
local GRID = 5
local STEP = { Up = Vector2.new(0, -1), Down = Vector2.new(0, 1), Left = Vector2.new(-1, 0), Right = Vector2.new(1, 0) }
local OPPOSITE = { Up = "Down", Down = "Up", Left = "Right", Right = "Left" }
local TOURIST = Color3.fromRGB(255, 200, 60)
local PLAYER = Color3.fromRGB(90, 220, 100)
local WRONG = Color3.fromRGB(255, 80, 80)

local Sequence = {}

function Sequence.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(340, 380))
	local rng = self:Random()

	local map = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(300, 300),
		BackgroundColor3 = Color3.fromRGB(120, 185, 110),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 14)) })
	-- Rues du quartier
	for index = 0, GRID - 1 do
		local p = (index + 0.5) / GRID
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, p),
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundColor3 = Color3.fromRGB(215, 205, 185),
			BorderSizePixel = 0,
			Parent = map,
		})
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(p, 0),
			Size = UDim2.new(0, 14, 1, 0),
			BackgroundColor3 = Color3.fromRGB(215, 205, 185),
			BorderSizePixel = 0,
			Parent = map,
		})
	end
	local pin = self:Emoji(map, "📍", 40, 6)
	local walker = self:Emoji(map, "🧳", 36, 7)
	local timer = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 326),
		Size = UDim2.new(1, -40, 0, 14),
		BackgroundColor3 = Color3.fromRGB(120, 200, 255),
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })

	local function cellPosition(cell: Vector2): UDim2
		return UDim2.fromScale((cell.X + 0.5) / GRID, (cell.Y + 0.5) / GRID)
	end

	local trail: { Frame } = {}
	local function clearTrail()
		for _, frame in trail do
			frame:Destroy()
		end
		table.clear(trail)
	end
	-- Un trait de rue entre deux cases
	local function segment(from: Vector2, to: Vector2, color: Color3)
		local a = (from + Vector2.new(0.5, 0.5)) / GRID
		local b = (to + Vector2.new(0.5, 0.5)) / GRID
		local horizontal = from.Y == to.Y
		local frame = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale((a.X + b.X) / 2, (a.Y + b.Y) / 2),
			Size = if horizontal then UDim2.new(1 / GRID, 14, 0, 14) else UDim2.new(0, 14, 1 / GRID, 14),
			BackgroundColor3 = color,
			ZIndex = 4,
			Parent = map,
		}, { Ui.corner(UDim.new(1, 0)) })
		table.insert(trail, frame)
	end

	local path: { string } = {}
	local start = Vector2.new(2, 2)
	local position = start
	local typed = 0
	local state = "Showing" -- "Showing" (le touriste montre), "Input" (au joueur), "Done"
	local stateAt = os.clock()
	local inputStart = 0

	local function length(): number
		return math.min(SETTINGS.Length + SETTINGS.LengthPerLevel * self.level, SETTINGS.MaxLength)
	end

	local function newPath()
		clearTrail()
		path = {}
		start = Vector2.new(rng:NextInteger(1, GRID - 2), rng:NextInteger(1, GRID - 2))
		local cell = start
		local visited = { [cell.X .. "," .. cell.Y] = true }
		local previous: string? = nil
		while #path < length() do
			local choices = {}
			for direction, step in STEP do
				local nextCell = cell + step
				local inside = nextCell.X >= 0 and nextCell.Y >= 0 and nextCell.X < GRID and nextCell.Y < GRID
				if
					inside
					and direction ~= OPPOSITE[previous or ""]
					and not visited[nextCell.X .. "," .. nextCell.Y]
				then
					table.insert(choices, direction)
				end
			end
			if #choices == 0 then
				-- Impasse (rare) : on recommence
				return newPath()
			end
			table.sort(choices)
			local direction = choices[rng:NextInteger(1, #choices)]
			table.insert(path, direction)
			cell += STEP[direction]
			visited[cell.X .. "," .. cell.Y] = true
			previous = direction
		end
		position = start
		typed = 0
		state = "Showing"
		stateAt = math.max(os.clock(), self:NextRepAt() - SETTINGS.ShowPerStep * #path)
		pin.Position = cellPosition(start)
		walker.Position = cellPosition(start)
	end
	newPath()

	local function finish(quality: string)
		state = "Done"
		stateAt = os.clock()
		self:Rep(quality, walker)
		if quality == "Miss" then
			-- Montre le bon chemin en rouge
			clearTrail()
			local cell = start
			for _, direction in path do
				segment(cell, cell + STEP[direction], WRONG)
				cell += STEP[direction]
			end
		end
		task.delay(0.8, function()
			if not self.destroyed then
				newPath()
			end
		end)
	end

	self:OnSwipe(function(direction)
		if state ~= "Input" then
			return
		end
		typed += 1
		local nextCell = position + STEP[direction]
		if direction ~= path[typed] then
			segment(position, nextCell, WRONG)
			finish("Miss")
			return
		end
		segment(position, nextCell, PLAYER)
		position = nextCell
		self.guideDirection = path[typed + 1]
		walker.Position = cellPosition(position)
		if typed == #path then
			local took = os.clock() - inputStart
			finish(if took <= SETTINGS.PerfectPerStep * #path / self.timingScale then "Perfect" else "Good")
		end
	end)
	self:Guide(panel, "SwipeRight")

	self:OnStep(function()
		local now = os.clock()
		if state == "Showing" then
			-- Le touriste trace son chemin, un pas après l'autre
			local shown = math.floor((now - stateAt) / SETTINGS.ShowPerStep)
			while #trail < math.min(shown, #path) do
				local cell = start
				for index = 1, #trail do
					cell += STEP[path[index]]
				end
				segment(cell, cell + STEP[path[#trail + 1]], TOURIST)
				walker.Position = cellPosition(cell + STEP[path[#trail]])
			end
			if shown > #path then
				clearTrail()
				walker.Position = cellPosition(start)
				state = "Input"
				inputStart = now
				self.guideDirection = path[1]
			end
			timer.Size = UDim2.new(1, -40, 0, 14)
			timer.BackgroundColor3 = TOURIST
		elseif state == "Input" then
			local limit = interval * 1.5
			local left = 1 - (now - inputStart) / limit
			timer.Size = UDim2.new(math.clamp(left, 0, 1), -40, 0, 14)
			timer.BackgroundColor3 = PLAYER
			if left <= 0 then
				finish("Miss")
			end
		end
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { state = state, path = path, typed = typed }
	end

	return self
end

return Sequence
