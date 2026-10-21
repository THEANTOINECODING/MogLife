local C = require(script.Parent.Common)
local Games = {}

Games.PeelGood = {
	init = function(s)
		s.segment, s.peel, s.tearing, s.grabbed = 1, 0, 0, false
	end,
	action = function(s, kind, g)
		if kind == "down" then
			local a, b = g.path[s.segment], g.path[s.segment + 1]
			if b then
				local x, y = a[1] + (b[1] - a[1]) * s.peel, a[2] + (b[2] - a[2]) * s.peel
				s.grabbed = C.distance(s.x, s.y, x, y) <= g.width
			end
		elseif kind == "up" then
			s.grabbed = false
			s.tearing = 0
		end
	end,
	step = function(s, dt, g)
		if not s.held or not s.grabbed then
			return
		end
		local a, b = g.path[s.segment], g.path[s.segment + 1]
		if not b then
			return
		end
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local length = math.sqrt(dx * dx + dy * dy)
		local along = ((s.x - a[1]) * dx + (s.y - a[2]) * dy) / (length * length)
		local across = math.abs((s.x - a[1]) * dy - (s.y - a[2]) * dx) / length
		if across < g.width then
			s.peel = math.min(1, math.max(s.peel, math.min(along, s.peel + g.speed * dt / length)))
			s.tearing = 0
		else
			s.tearing += dt
			if s.tearing > g.tearGrace then
				C.miss(s)
				s.grabbed = false
				s.tearing = 0
			end
		end
		s.score = (s.segment - 1 + s.peel) / (#g.path - 1)
		if s.peel >= 0.95 then
			s.segment += 1
			s.peel = 0
			C.mark(s, 0)
			if s.segment >= #g.path then
				s.score = 1
				s.won = true
			end
		end
	end,
	draw = function(s, g)
		C.node(s, "jar", 0.49, 0.55, 0.58, 0.48, "glass")
		for i = 1, 5 do
			C.node(s, "pickle" .. i, 0.24 + i * 0.08, 0.58, 0.045, 0.25, "pickle", i * 7)
		end
		for i = 1, #g.path - 1 do
			local a, b = g.path[i], g.path[i + 1]
			C.node(
				s,
				"seal" .. i,
				(a[1] + b[1]) / 2,
				(a[2] + b[2]) / 2,
				math.abs(a[1] - b[1]) + 0.04,
				math.abs(a[2] - b[2]) + 0.04,
				if i < s.segment then "gold" else "paper"
			)
		end
		local a, b = g.path[math.min(s.segment, #g.path - 1)], g.path[math.min(s.segment + 1, #g.path)]
		C.node(s, "tab", a[1] + (b[1] - a[1]) * s.peel, a[2] + (b[2] - a[2]) * s.peel, 0.10, 0.08, "goal")
		C.node(s, "pull", b[1], b[2], 0.065, 0.065, "gold")
		for i = 1, math.floor(s.score * 12) do
			C.node(s, "ribbon" .. i, 0.31 + i * 0.027, 0.85 + math.sin(i) * 0.025, 0.04, 0.03, "paper", i * 25)
		end
	end,
}

local function pipeEnds(tile)
	if tile.straight then
		return { tile.rot % 2, tile.rot % 2 + 2 }
	end
	return { tile.rot % 4, (tile.rot + 1) % 4 }
end

local function connected(s)
	local index, incoming, seen = 1, 3, {}
	s.flow = {}
	while index >= 1 and index <= 9 and not seen[index] do
		seen[index] = true
		local ends = pipeEnds(s.pipes[index])
		local out = if ends[1] == incoming then ends[2] elseif ends[2] == incoming then ends[1] else nil
		if out == nil then
			return false
		end
		s.flow[index] = true
		if index == 9 and out == 1 then
			return true
		end
		local col = (index - 1) % 3
		if (out == 1 and col == 2) or (out == 3 and col == 0) then
			return false
		end
		index += ({ -3, 1, 3, -1 })[out + 1]
		incoming = (out + 2) % 4
	end
	return false
end

Games.AirwayExpress = {
	refresh = connected,
	init = function(s, g)
		s.pipes, s.moves, s.history = {}, 0, {}
		s.solution, s.route = {}, g.routes[(s.seed - 1) % #g.routes + 1]
		local function direction(a, b)
			return if b == a - 3 then 0 elseif b == a + 1 then 1 elseif b == a + 3 then 2 else 3
		end
		for k, i in s.route do
			local incoming = if k == 1 then 3 else direction(i, s.route[k - 1])
			local outgoing = if k == #s.route then 1 else direction(i, s.route[k + 1])
			local straight = (incoming + 2) % 4 == outgoing
			local rot = if straight then incoming % 2 elseif (incoming + 1) % 4 == outgoing then incoming else outgoing
			s.solution[i] = { rot = rot, straight = straight }
		end
		for i = 1, 9 do
			local solution = s.solution[i] or { rot = i % 4, straight = i % 2 == 0 }
			-- One or two clockwise turns from a valid solution, always within the visible budget.
			s.pipes[i] = { rot = (solution.rot - 1 - (s.seed + i) % 2) % 4, straight = solution.straight }
		end
		connected(s)
	end,
	action = function(s, kind, g)
		if kind ~= "down" then
			return
		end
		if s.moves >= g.turns then
			s.lost = true
			return
		end
		local i = C.cell(s.x, s.y, g.size)
		table.insert(s.history, i)
		s.pipes[i].rot = (s.pipes[i].rot + 1) % 4
		s.moves += 1
		s.pulse += 1
		s.feedback = "Turned"
		if connected(s) then
			C.mark(s, 1)
			s.won = true
		end
		s.lost = s.moves >= g.turns and not s.won
	end,
	draw = function(s, g)
		C.grid(s, g.size, {})
		for i, tile in s.pipes do
			local x, y = C.xy(i, g.size)
			for j, dir in pipeEnds(tile) do
				local dx, dy = ({ 0, 1, 0, -1 })[dir + 1], ({ -1, 0, 1, 0 })[dir + 1]
				C.node(
					s,
					"pipe" .. i .. "_" .. j,
					x + dx * 0.06,
					y + dy * 0.06,
					if dx == 0 then 0.045 else 0.14,
					if dy == 0 then 0.045 else 0.14,
					if s.won then "gold" elseif s.flow[i] then "water" else "pipe"
				)
			end
		end
		C.node(s, "inlet", 0.07, 0.247, 0.08, 0.08, "goal")
		C.node(s, "wheel", 0.93, 0.755, 0.09, 0.13, "tire")
	end,
}

Games.ChopShop = {
	init = function(s)
		s.item, s.cutX, s.pause = 1, 0.5, 0
	end,
	action = function(s, kind, g)
		if s.t < s.pause then
			return
		end
		if kind == "down" then
			s.ax, s.ay = s.x, s.y
		elseif kind == "up" and s.ax then
			local dy = s.y - s.ay
			if math.abs(dy) > 0.20 and math.min(s.y, s.ay) < 0.5 and math.max(s.y, s.ay) > 0.5 then
				s.cutX = s.ax + (s.x - s.ax) * (0.5 - s.ay) / dy
				local error = math.abs(s.cutX - g.targets[s.item])
				if error <= g.tolerance then
					C.mark(s, 1, if error <= g.perfect then 1 else 0.75)
					s.item += 1
					s.won = s.item > #g.targets
				else
					C.miss(s)
				end
				s.pause = s.t + g.reset
			end
			s.ax = nil
		end
	end,
	draw = function(s, g)
		C.node(s, "plank", 0.5, 0.5, 0.80, 0.27, "wood")
		local target = g.targets[math.min(s.item, #g.targets)]
		C.node(s, "seam", target, 0.5, 0.012, 0.40, "goal")
		for i = 1, s.item - 1 do
			C.node(s, "house" .. i, 0.3 + i * 0.1, 0.82, 0.08, 0.16, "gold", if i == 3 then 90 else 0)
		end
		if s.ax then
			C.node(s, "blade", s.x, s.y, 0.04, 0.12, "metal", -20)
		end
	end,
}

local function carAt(s, x, y, ignore)
	for i, car in s.cars do
		if
			i ~= ignore
			and x >= car.x
			and y >= car.y
			and x < car.x + (if car.horizontal then car.length else 1)
			and y < car.y + (if car.horizontal then 1 else car.length)
		then
			return i
		end
	end
	return nil
end

Games.ParkingKnot = {
	init = function(s, g)
		s.moves = 0
		s.history = {}
		s.cars = {}
		for _, car in g.layouts[(s.seed - 1) % #g.layouts + 1] do
			table.insert(s.cars, { x = car[1], y = car[2], length = car[3], horizontal = car[4] })
		end
	end,
	action = function(s, kind, g)
		if kind == "down" then
			local cell = C.cell(s.x, s.y, g.size)
			s.selected = carAt(s, (cell - 1) % g.size, math.floor((cell - 1) / g.size), nil)
			s.ax, s.ay = s.x, s.y
		elseif kind == "up" and s.selected then
			if s.moves >= g.moves then
				s.lost = true
				return
			end
			local car = s.cars[s.selected]
			local before = {}
			for i, c in s.cars do
				before[i] = table.clone(c)
			end
			local oldX, oldY = car.x, car.y
			local delta = (if car.horizontal then s.x - s.ax else s.y - s.ay) / (0.76 / g.size)
			local count = math.floor(math.abs(delta) + 0.5)
			local direction = if delta >= 0 then 1 else -1
			for _ = 1, math.min(count, g.size) do
				local nx = car.x + (if car.horizontal then direction else 0)
				local ny = car.y + (if car.horizontal then 0 else direction)
				local clear = nx >= 0
					and ny >= 0
					and nx + (if car.horizontal then car.length else 1) <= g.size
					and ny + (if car.horizontal then 1 else car.length) <= g.size
				for part = 0, car.length - 1 do
					if
						carAt(
							s,
							nx + (if car.horizontal then part else 0),
							ny + (if car.horizontal then 0 else part),
							s.selected
						)
					then
						clear = false
					end
				end
				if not clear then
					break
				end
				car.x, car.y = nx, ny
			end
			if car.x ~= oldX or car.y ~= oldY then
				s.moves += 1
				table.insert(s.history, before)
			end
			s.selected = nil
			s.pulse += 1
			s.feedback = "Moved"
			s.won = s.cars[1].x == g.size - s.cars[1].length
			s.lost = s.moves >= g.moves and not s.won
			s.score = if s.won then 1 else s.cars[1].x / (g.size - s.cars[1].length)
		end
	end,
	draw = function(s, g)
		C.grid(s, g.size, {})
		for i, car in s.cars do
			local w, h = if car.horizontal then car.length else 1, if car.horizontal then 1 else car.length
			C.node(
				s,
				"car" .. i,
				0.12 + (car.x + w / 2) * 0.76 / g.size,
				0.12 + (car.y + h / 2) * 0.76 / g.size,
				w * 0.76 / g.size - 0.015,
				h * 0.76 / g.size - 0.015,
				if i == 1 then "taxi" else "car"
			)
		end
		C.node(s, "exit", 0.94, 0.5, 0.07, 0.13, "goal")
	end,
}

Games.PianoPolish = {
	init = function(s)
		s.clean, s.wiping, s.cx, s.cy = {}, {}, 0.5, 0.5
	end,
	step = function(s, dt, g)
		s.cx, s.cy = C.move(s.cx, s.cy, s.x, s.y, dt * g.speed)
		if not s.held then
			return
		end
		for i = 1, g.size * g.size do
			local x, y = C.xy(i, g.size)
			if not s.clean[i] and C.distance(x, y, s.cx, s.cy) <= g.radius then
				s.wiping[i] = (s.wiping[i] or 0) + dt
				if s.wiping[i] >= g.wipeTime then
					s.clean[i] = true
					C.mark(s, 1)
				end
			end
		end
		if s.score >= g.goal - g.finishRemaining then
			s.score = g.goal
			s.won = true
		end
	end,
	draw = function(s, g)
		C.node(s, "piano", 0.5, 0.52, 0.87, 0.83, "piano")
		for i = 1, g.size * g.size do
			local x, y = C.xy(i, g.size)
			local dust = if s.clean[i]
				then "polished"
				elseif s.score >= g.goal - g.finishHighlight then "dustLast"
				else "dust"
			C.node(
				s,
				"dust" .. i,
				x,
				y,
				0.72 / g.size,
				0.72 / g.size,
				dust,
				if s.clean[i] then 0 else (i * 17 + s.seed * 11) % 90
			)
		end
		for i = 1, 10 do
			C.node(s, "key" .. i, 0.15 + i * 0.063, 0.92, 0.054, 0.08, if i % 3 == 0 then "ink" else "paper")
		end
		C.node(s, "cloth", s.cx, s.cy, 0.17, 0.13, "cloth", math.sin(s.t * 4) * 6)
	end,
}

Games.TowelFold = {
	init = function(s)
		s.fold, s.grabbed, s.pause = 1, false, 0
	end,
	action = function(s, kind, g)
		if s.t < s.pause then
			return
		end
		local f = g.folds[math.min(s.fold, #g.folds)]
		if kind == "down" then
			s.grabbed = C.distance(s.x, s.y, f[1], f[2]) < g.grab
		elseif kind == "up" and s.grabbed then
			local error = C.distance(s.x, s.y, f[3], f[4])
			if error < g.snap then
				C.mark(s, 1, if error < g.perfect then 1 else 0.75)
				s.fold += 1
				s.won = s.fold > #g.folds
				s.pause = s.t + g.reset
			else
				C.miss(s)
			end
			s.grabbed = false
		end
	end,
	draw = function(s, g)
		local f = g.folds[math.min(s.fold, #g.folds)]
		local w, h = if s.fold > 1 then 0.28 else 0.56, if s.fold > 2 then 0.28 else 0.56
		local center = 0.78 - w / 2
		C.node(s, "towel", if s.seed % 2 == 0 then 1 - center else center, 0.22 + h / 2, w, h, "cloth")
		C.node(s, "corner", if s.grabbed then s.x else f[1], if s.grabbed then s.y else f[2], 0.10, 0.10, "paper")
		if s.grabbed then
			C.node(
				s,
				"folding",
				(s.x + f[1]) / 2,
				(s.y + f[2]) / 2,
				math.max(0.04, math.abs(s.x - f[1])),
				math.max(0.04, math.abs(s.y - f[2])),
				"cloth",
				10
			)
		end
		C.node(s, "foldTarget", f[3], f[4], 0.12, 0.12, "goal")
		for i = 1, s.fold - 1 do
			C.node(s, "folded" .. i, 0.35 + i * 0.1, 0.89, 0.08, 0.06, "gold")
		end
	end,
}

local function extendProduce(s, g)
	local cell = C.cell(s.x, s.y, g.size)
	local last = s.path[#s.path]
	if s.fruit[cell] == 0 or table.find(s.path, cell) then
		return
	end
	if not last or (s.fruit[cell] == s.fruit[last] and C.adjacent(cell, last, g.size)) then
		table.insert(s.path, cell)
	end
end

Games.ProduceParade = {
	init = function(s, g)
		s.fruit, s.path = {}, {}
		for i = 1, g.size * g.size do
			local row, col = math.floor((i - 1) / g.size), (i - 1) % g.size
			if math.floor(s.seed / g.colors) % 2 == 1 then
				row, col = col, row
			end
			if math.floor(s.seed / (g.colors * 2)) % 2 == 1 then
				col = g.size - 1 - col
			end
			local snake = row * g.size + (if row % 2 == 0 then col else g.size - 1 - col)
			s.fruit[i] = (math.floor(snake / g.minimum) + s.seed) % g.colors + 1
		end
	end,
	action = function(s, kind, g)
		if kind == "down" then
			s.path = {}
			extendProduce(s, g)
		elseif kind == "up" then
			if #s.path >= g.minimum then
				C.mark(s, #s.path)
				for _, cell in s.path do
					s.fruit[cell] = 0
				end
				s.won = s.score >= g.goal
			elseif #s.path > 0 then
				C.miss(s)
			end
			s.path = {}
		end
	end,
	step = function(s, _, g)
		if s.held then
			extendProduce(s, g)
		end
	end,
	draw = function(s, g)
		for i, fruit in s.fruit do
			if fruit > 0 then
				local x, y = C.xy(i, g.size)
				C.node(s, "fruit" .. i, x, y, 0.125, 0.125, if table.find(s.path, i) then "gold" else "fruit" .. fruit)
			end
		end
	end,
}

local function extendRoute(s, g)
	local cell = C.cell(s.x, s.y, g.size)
	local last = s.path[#s.path]
	if cell == last or s.blocked[cell] then
		return
	end
	if #s.path > 1 and cell == s.path[#s.path - 1] then
		table.remove(s.path)
		return
	end
	if C.adjacent(cell, last, g.size) and not table.find(s.path, cell) and #s.path < g.maxPath then
		table.insert(s.path, cell)
	end
end

Games.ShortcutChalk = {
	init = function(s, g)
		s.path, s.blocked, s.walk = { g.route[1] }, {}, 0
		for _, cell in g.blocked do
			s.blocked[cell] = true
		end
	end,
	action = function(s, kind, g)
		if s.walk > 0 then
			return
		end
		if kind == "down" and C.cell(s.x, s.y, g.size) == g.route[1] then
			s.path = { g.route[1] }
		elseif kind == "up" and s.path[#s.path] == g.route[#g.route] then
			s.walk = 1
			s.pulse += 1
		end
	end,
	step = function(s, dt, g)
		if s.walk > 0 then
			s.walk += dt * g.walkSpeed
			if s.walk >= #s.path then
				C.mark(s, 1)
				s.won = true
			end
		elseif s.held then
			extendRoute(s, g)
		end
	end,
	draw = function(s, g)
		local styles = {}
		for i = 1, g.size * g.size do
			styles[i] = if s.blocked[i] then "danger" elseif table.find(s.path, i) then "gold" else "tile"
		end
		C.grid(s, g.size, styles)
		local x, y = C.xy(g.route[#g.route], g.size)
		C.node(s, "landmark", x, y, 0.08, 0.11, "goal")
		x, y = C.xy(s.path[math.clamp(math.floor(s.walk), 1, #s.path)], g.size)
		C.node(s, "tourist", x, y, 0.065, 0.09, "athlete")
	end,
}

return Games
