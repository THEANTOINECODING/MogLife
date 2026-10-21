-- Independent rules, shared by authoritative simulation and client prediction.
local C = require(script.Parent.Common)
local Games = {}

Games.ScrapPress = {
	init = function(s)
		s.compression, s.item, s.pause = 0, 1, 0
	end,
	step = function(s, dt, g)
		if s.pause > s.t then
			return
		end
		if s.held then
			s.compression = math.min(1, s.compression + g.rate * dt)
		end
	end,
	action = function(s, kind, g)
		if kind ~= "up" or s.pause > s.t then
			return
		end
		local target = g.targets[s.item]
		local error = math.abs(s.compression - (g.rebound[s.item] or 0) - target)
		if error <= g.tolerance then
			C.mark(s, 1, if error <= g.perfect then 1 else 0.75)
			s.item += 1
			if s.item > #g.targets then
				s.won = true
			end
		else
			C.miss(s)
		end
		s.compression, s.pause = 0, s.t + g.reset
	end,
	draw = function(s, g)
		local target = g.targets[math.min(s.item, #g.targets)]
		C.node(s, "frame", 0.5, 0.56, 0.68, 0.63, "frame")
		C.node(s, "sleeve", 0.83, 0.80 - (1 - target) * 0.25, 0.12, (1 - target) * 0.5, "goal")
		C.node(
			s,
			"scrap",
			0.49,
			0.80 - (1 - s.compression) * 0.25,
			0.36 + s.compression * 0.12,
			(1 - s.compression) * 0.5 + 0.03,
			"scrap"
		)
		C.node(s, "press", 0.49, 0.26 + s.compression * 0.5, 0.55, 0.07, "metal")
		for i = 1, s.item - 1 do
			C.node(s, "cube" .. i, 0.25 + i * 0.13, 0.94, 0.09, 0.08, "gold")
		end
	end,
}

Games.TireDomino = {
	init = function(s, g)
		s.ball, s.shots, s.targets, s.pause = nil, 0, {}, 0
		s.columns = g.columns[(s.seed - 1) % #g.columns + 1]
		for row = 1, 3 do
			for col = 1, 3 do
				table.insert(s.targets, { x = s.columns[col], y = 0.16 + row * 0.11, hit = false, fall = 0 })
			end
		end
	end,
	action = function(s, kind, g)
		if kind ~= "up" or s.ball or s.pause > s.t or s.shots >= g.shots then
			return
		end
		local dx, dy = s.x - 0.5, s.y - 0.88
		local d = math.max(C.distance(s.x, s.y, 0.5, 0.88), 0.01)
		s.ball = { x = 0.5, y = 0.88, vx = dx / d * g.speed, vy = math.min(-g.minimumPower, dy / d) * g.speed }
		s.shots += 1
	end,
	step = function(s, dt, g)
		for _, t in s.targets do
			if t.hit then
				t.fall = math.min(1, t.fall + dt * 3)
			end
		end
		local b = s.ball
		if not b then
			return
		end
		b.x += b.vx * dt
		b.y += b.vy * dt
		if b.x < 0.08 or b.x > 0.92 then
			b.vx = -b.vx
			b.x = math.clamp(b.x, 0.08, 0.92)
		end
		for _, t in s.targets do
			if not t.hit and C.distance(b.x, b.y, t.x, t.y) < g.radius then
				t.hit = true
				C.mark(s, 1)
			end
		end
		-- A toppling tower reaches the next tower in its column.
		for i, t in s.targets do
			if t.hit and t.fall > 0.5 then
				local nextTarget = s.targets[i - 3]
				if nextTarget and not nextTarget.hit then
					nextTarget.hit = true
					C.mark(s, 1)
				end
			end
		end
		if b.y < 0.02 then
			s.ball, s.pause = nil, s.t + g.reset
			if s.shots >= g.shots then
				s.finished = true
			end
		end
		s.won = s.score >= g.goal
	end,
	draw = function(s)
		C.node(s, "lane", 0.5, 0.52, 0.87, 0.91, "floor")
		for i, t in s.targets do
			C.node(s, "tower" .. i, t.x, t.y, 0.075, 0.08, if t.hit then "gold" else "foam", t.fall * 85)
		end
		local b = s.ball or { x = 0.5, y = 0.88 }
		C.node(s, "tire", b.x, b.y, 0.10, 0.10, "tire", s.t * 180)
		if not s.ball then
			for i = 1, 5 do
				C.node(s, "aim" .. i, 0.5 + (s.x - 0.5) * i / 6, 0.88 + (s.y - 0.88) * i / 6, 0.013, 0.013, "goal")
			end
		end
	end,
}

Games.MagnetHaul = {
	init = function(s, g)
		s.mx, s.my, s.load, s.plates, s.bumped = 0.5, 0.88, {}, {}, 0
		local offset = g.layoutOffsets[(s.seed - 1) % #g.layoutOffsets + 1]
		for i = 1, 12 do
			table.insert(
				s.plates,
				{ x = 0.16 + ((i - 1) % 4) * 0.22 + offset, y = 0.17 + math.floor((i - 1) / 4) * 0.18, taken = false }
			)
		end
	end,
	step = function(s, dt, g)
		s.mx, s.my = C.move(s.mx, s.my, s.x, s.y, g.speed / (1 + #s.load * g.loadSlow) * dt)
		for i, p in s.plates do
			if not p.taken and C.distance(s.mx, s.my, p.x, p.y) < g.radius then
				p.taken = true
				table.insert(s.load, i)
				s.pulse += 1
				s.feedback = "Collected"
			end
		end
		if s.my > 0.83 and math.abs(s.mx - 0.5) < 0.24 and #s.load > 0 then
			C.mark(s, #s.load)
			s.load = {}
			s.won = s.score >= g.goal
		end
		if
			C.distance(s.mx, s.my, 0.5 + math.sin(s.t * g.bumperSpeed) * g.bumperSwing, 0.66) < g.bumper
			and #s.load > 0
			and s.t > s.bumped
		then
			for _ = 1, math.min(g.spill, #s.load) do
				local i = table.remove(s.load)
				s.plates[i].taken = false
				s.plates[i].x = math.clamp(s.mx + (#s.load % 2 * 2 - 1) * g.radius, 0.10, 0.90)
				s.plates[i].y = math.clamp(s.my - g.bumper, 0.12, 0.78)
			end
			C.miss(s)
			s.bumped = s.t + 1
		end
	end,
	draw = function(s, g)
		C.node(s, "bay", 0.5, 0.90, 0.48, 0.13, "goal")
		C.node(s, "bumper", 0.5 + math.sin(s.t * g.bumperSpeed) * g.bumperSwing, 0.66, 0.14, 0.08, "danger")
		for i, p in s.plates do
			if not p.taken then
				C.node(s, "plate" .. i, p.x, p.y, 0.065, 0.065, "plate")
			end
		end
		C.node(s, "magnet", s.mx, s.my, 0.10, 0.09, "magnet")
		for i in s.load do
			local a = i * 2.4
			C.node(s, "load" .. i, s.mx + math.cos(a) * 0.055, s.my + math.sin(a) * 0.055, 0.045, 0.045, "plate")
		end
	end,
}

Games.SwingKing = {
	init = function(s)
		s.bar, s.flying, s.px, s.py, s.pause = 1, false, 0.22, 0.6, 0
	end,
	action = function(s, kind, g)
		if kind ~= "down" or s.flying or s.t < s.pause then
			return
		end
		local angle = math.sin(s.t * g.speed) * 1.1
		s.px, s.py = 0.22 + math.sin(angle) * 0.25, 0.22 + math.cos(angle) * 0.32
		s.vx, s.vy = g.launch + math.cos(s.t * g.speed) * 0.3, -0.5
		s.flying = true
	end,
	step = function(s, dt, g)
		if not s.flying then
			return
		end
		s.vy += g.gravity * dt
		s.px += s.vx * dt
		s.py += s.vy * dt
		if C.distance(s.px, s.py, g.targets[(s.bar + s.seed - 2) % #g.targets + 1], 0.42) < g.catch then
			C.mark(s, 1)
			s.bar += 1
			s.flying = false
			s.pause = s.t + g.reset
			s.won = s.score >= g.goal
		elseif s.py > 0.9 or s.px > 1 then
			C.miss(s)
			s.flying = false
			s.pause = s.t + g.reset
		end
	end,
	draw = function(s, g)
		C.node(s, "bar", 0.22, 0.20, 0.29, 0.04, "metal")
		C.node(s, "next", g.targets[(s.bar + s.seed - 2) % #g.targets + 1], 0.42, 0.24, 0.045, "goal")
		for i = 1, s.bar - 1 do
			C.node(s, "flag" .. i, 0.25 + i * 0.12, 0.08, 0.06, 0.08, "pennant")
		end
		C.node(s, "net", 0.5, 0.92, 0.88, 0.055, "foam")
		local angle = math.sin(s.t * g.speed) * 1.1
		local x, y = s.px, s.py
		if not s.flying then
			x, y = 0.22 + math.sin(angle) * 0.25, 0.22 + math.cos(angle) * 0.32
		end
		C.node(s, "athlete", x, y, 0.10, 0.15, "athlete", if s.flying then -20 else -math.deg(angle))
		if not s.flying then
			for i = 1, 5 do
				local time = i * 0.12
				C.node(
					s,
					"arc" .. i,
					x + (g.launch + math.cos(s.t * g.speed) * 0.3) * time,
					y - 0.5 * time + g.gravity * time ^ 2 / 2,
					0.014,
					0.014,
					"goal"
				)
			end
		end
	end,
}

Games.RopeRave = {
	init = function(s)
		s.hit, s.wave, s.expired = {}, -10, {}
	end,
	action = function(s, kind, g)
		if kind ~= "down" then
			return
		end
		local best, distance
		for i = 1, g.goal do
			local phrase = math.floor((i - 1) / #g.phrase)
			local target = g.lead + (phrase * 6 + g.phrase[(i - 1) % #g.phrase + 1]) * g.beat
			local err = math.abs((s.inputTime or s.t) - target)
			if not s.hit[i] and not s.expired[i] and (not distance or err < distance) then
				best, distance = i, err
			end
		end
		if best and distance <= g.good then
			s.hit[best] = true
			C.mark(s, 1, if distance <= g.perfect then 1 else 0.7)
		else
			C.miss(s)
		end
		s.wave = s.t
	end,
	step = function(s, _, g)
		local last = 0
		for i = 1, g.goal do
			last = g.lead + (math.floor((i - 1) / #g.phrase) * 6 + g.phrase[(i - 1) % #g.phrase + 1]) * g.beat
			if s.t > last + g.good + g.inputGrace and not s.hit[i] and not s.expired[i] then
				s.expired[i] = true
				C.miss(s)
			end
		end
		s.won = s.score >= g.goal
		if s.t > last + g.good + g.inputGrace then
			s.finished = true
		end
	end,
	draw = function(s, g)
		for rope = 1, 2 do
			for i = 1, 20 do
				local x = i / 23 + 0.04
				local wave = math.exp(-((x - (s.t - s.wave) * 1.2) * 9) ^ 2) * 0.08 * math.sin(x * 35 - s.t * 12)
				C.node(s, "rope" .. rope .. "_" .. i, x, 0.40 + rope * 0.13 + wave, 0.045, 0.025, "rope")
			end
		end
		for i = 1, g.goal do
			local phrase = math.floor((i - 1) / #g.phrase)
			local target = g.lead + (phrase * 6 + g.phrase[(i - 1) % #g.phrase + 1]) * g.beat
			local x = 0.3 + (target - s.t) * 0.2
			if x > 0.08 and x < 0.95 then
				C.node(s, "beat" .. i, x, 0.26, 0.055, 0.055, if s.hit[i] then "gold" else "bell")
			end
		end
		C.node(s, "strike", 0.30, 0.26, 0.012, 0.18, "goal")
		C.node(s, "bell", 0.93, 0.58, 0.10, 0.20, "bell")
	end,
}

Games.AtlasStack = {
	init = function(s, g)
		s.stack, s.item, s.drop, s.pause = {}, 1, nil, 0
		s.baseX = g.bases[(s.seed - 1) % #g.bases + 1]
	end,
	action = function(s, kind, g)
		if kind == "up" and not s.drop and s.pause < s.t then
			s.drop = {
				x = math.clamp(s.x + math.sin(s.t * g.driftSpeed + s.item) * g.drift, 0.12, 0.88),
				y = 0.2,
				w = g.widths[math.min(s.item, #g.widths)],
			}
		end
	end,
	step = function(s, dt, g)
		local p = s.drop
		if not p then
			return
		end
		p.y += g.fall * dt
		local base = s.stack[#s.stack] or { x = s.baseX, y = g.floor, w = g.baseWidth }
		local landing = base.y - 0.095
		if p.y >= landing then
			local overlap =
				math.max(0, math.min(p.x + p.w / 2, base.x + base.w / 2) - math.max(p.x - p.w / 2, base.x - base.w / 2))
			if overlap / p.w >= g.overlap then
				p.y = landing
				table.insert(s.stack, p)
				C.mark(s, 1, if overlap / p.w >= g.perfect then 1 else 0.75)
				s.item += 1
				s.won = #s.stack >= g.goal
			else
				C.miss(s)
			end
			s.drop, s.pause = nil, s.t + g.reset
		end
	end,
	draw = function(s, g)
		C.node(s, "base", s.baseX, g.floor, g.baseWidth, 0.06, "metal")
		for i, p in s.stack do
			C.node(s, "weight" .. i, p.x, p.y, p.w, 0.12, "gold")
		end
		local p = s.drop
			or {
				x = math.clamp(s.x + math.sin(s.t * g.driftSpeed + s.item) * g.drift, 0.12, 0.88),
				y = 0.2,
				w = g.widths[math.min(s.item, #g.widths)],
			}
		C.node(s, "weight", p.x, p.y, p.w, 0.12, "stone")
		C.node(s, "shadow", p.x, (s.stack[#s.stack] or { y = g.floor }).y - 0.095, p.w, 0.02, "goal")
	end,
}

return Games
