-- Free assisted play issues the same legal actions. It never awards manual grades.
local C = require(script.Parent.Common)
local ParkingSolver = require(script.Parent.ParkingSolver)

return function(s, dt, config, input)
	s.autoClock = (s.autoClock or 0) + dt
	if s.t < 0 or s.finished or s.autoClock < config.AutoInterval then
		return
	end
	s.autoClock = 0
	local g = s.rules
	local function act(kind, x, y)
		input(s, kind, x or s.x, y or s.y)
	end
	local function tap(x, y)
		act("up", x, y)
		act("down", x, y)
		act("up", x, y)
	end
	if s.name == "ScrapPress" then
		if s.compression >= g.targets[s.item] + (g.rebound[s.item] or 0) then
			act("up")
		elseif s.t > s.pause then
			act("down")
		end
	elseif s.name == "TireDomino" then
		if not s.ball and s.t > s.pause and s.shots < g.shots then
			local x = s.columns[s.shots + 1]
			act("down", x, 0.49)
			act("up", x, 0.49)
		end
	elseif s.name == "MagnetHaul" then
		if #s.load >= 4 then
			act("move", 0.5, 0.9)
		else
			local target
			for _, p in s.plates do
				if not p.taken then
					target = p
					break
				end
			end
			if target then
				act("move", target.x, target.y)
			else
				act("move", 0.5, 0.9)
			end
		end
	elseif s.name == "SwingKing" then
		if
			not s.flying
			and s.t > s.pause
			and math.cos(s.t * g.speed) > 0.5
			and math.abs(math.sin(s.t * g.speed)) < 0.5
		then
			tap()
		end
	elseif s.name == "RopeRave" then
		for i = 1, g.goal do
			local target = g.lead + (math.floor((i - 1) / #g.phrase) * 6 + g.phrase[(i - 1) % #g.phrase + 1]) * g.beat
			if not s.hit[i] and math.abs(s.t - target) < g.perfect then
				tap()
				break
			end
		end
	elseif s.name == "AtlasStack" then
		if not s.drop and s.t > s.pause then
			local base = s.stack[#s.stack]
			local x = (if base then base.x else s.baseX) - math.sin(s.t * g.driftSpeed + s.item) * g.drift
			act("down", x, 0.2)
			act("up", x, 0.2)
		end
	elseif s.name == "PeelGood" then
		local a, b = g.path[s.segment], g.path[s.segment + 1]
		if b then
			if not s.grabbed then
				act("up")
				act("down", a[1] + (b[1] - a[1]) * s.peel, a[2] + (b[2] - a[2]) * s.peel)
			else
				act("move", b[1], b[2])
			end
		end
	elseif s.name == "AirwayExpress" then
		local solution = s.solution
		for _, i in s.route do
			local modulo = if s.pipes[i].straight then 2 else 4
			if s.pipes[i].rot % modulo ~= solution[i].rot % modulo then
				local x, y = C.xy(i, 3)
				tap(x, y)
				break
			end
		end
	elseif s.name == "ChopShop" then
		if s.t > s.pause then
			local x = g.targets[math.min(s.item, #g.targets)]
			act("down", x, 0.25)
			act("up", x, 0.75)
		end
	elseif s.name == "ParkingKnot" then
		if not s.autoPlan then
			s.autoPlan = ParkingSolver(s.cars, g.size, config.PuzzleSearchLimit)
			s.autoPlanAt = s.moves
		end
		local m = s.autoPlan and s.autoPlan[s.moves - s.autoPlanAt + 1]
		if not m then
			return
		end
		local x, y = C.xy(m.from, g.size)
		act("down", x, y)
		x, y = C.xy(m.to, g.size)
		act("up", x, y)
	elseif s.name == "PianoPolish" then
		for i = 1, g.goal do
			if not s.clean[i] then
				local x, y = C.xy(i, g.size)
				act("down", x, y)
				act("move", x, y)
				break
			end
		end
	elseif s.name == "TowelFold" then
		local folds = g.folds
		local f = folds[math.min(s.fold, #folds)]
		if s.t > s.pause then
			act("down", f[1], f[2])
			act("up", f[3], f[4])
		end
	elseif s.name == "ProduceParade" then
		if #s.path >= g.minimum then
			act("up")
		elseif #s.path == 0 then
			local chosen
			for i, fruit in s.fruit do
				if fruit > 0 then
					local neighbors = 0
					for j, other in s.fruit do
						if other == fruit and C.adjacent(i, j, g.size) then
							neighbors += 1
						end
					end
					if neighbors == 1 then
						chosen = i
						break
					end
				end
			end
			if chosen then
				local x, y = C.xy(chosen, g.size)
				act("down", x, y)
			end
		else
			local last = s.path[#s.path]
			for i, fruit in s.fruit do
				if fruit == s.fruit[last] and C.adjacent(i, last, g.size) and not table.find(s.path, i) then
					local x, y = C.xy(i, g.size)
					act("move", x, y)
					break
				end
			end
		end
	elseif s.name == "ShortcutChalk" then
		if s.walk > 0 then
			return
		end
		local route = g.route
		if not s.held then
			local x, y = C.xy(route[1], g.size)
			act("down", x, y)
		elseif #s.path >= #route then
			act("up")
		else
			local x, y = C.xy(route[#s.path + 1], 6)
			act("move", x, y)
		end
	end
end
