local C = require(script.Parent.Common)
local Games = {}

Games.SnackVolley = {
	init = function(s, g)
		s.paddle, s.ball, s.serve = 0.5, { x = 0.5, y = 0.20, vx = 0.17, vy = g.speed }, g.serve
	end,
	step = function(s, dt, g)
		s.paddle = select(1, C.move(s.paddle, 0, s.x, 0, dt * g.paddleSpeed))
		if s.t < s.serve then
			return
		end
		local b = s.ball
		local previous = b.y
		b.x += b.vx * dt
		b.y += b.vy * dt
		if b.x < 0.06 or b.x > 0.94 then
			b.vx = -b.vx
			b.x = math.clamp(b.x, 0.06, 0.94)
		end
		if b.vy > 0 and previous < 0.82 and b.y >= 0.82 then
			if math.abs(b.x - s.paddle) <= g.paddle / 2 + g.ballRadius then
				b.y = 0.81
				b.vy = -g.speed * (1 + s.score * g.acceleration + s.difficulty * 0.08)
				b.vx = (b.x - s.paddle) * 2
				s.pulse += 1
				s.feedback = "Returned"
			end
		end
		if b.y < 0.18 then
			C.mark(s, 1)
			s.won = s.score >= g.goal
			b.y, b.vy, b.vx =
				0.20, g.speed * (1 + s.score * g.acceleration), (if (s.score + s.seed) % 2 == 0 then 1 else -1) * 0.19
			s.serve = s.t + g.serve
		elseif b.y > 0.97 then
			C.miss(s)
			s.lost = s.misses >= g.lives
			b.x, b.y, b.vy = 0.5, 0.20, g.speed
			s.serve = s.t + g.serve
		end
	end,
	draw = function(s, g)
		C.node(s, "sofa", 0.5, 0.15, 0.65, 0.18, "sofa")
		C.node(s, "kevin", 0.50, 0.12, 0.15, 0.15, "rival")
		C.node(s, "tray", s.paddle, 0.85, g.paddle, 0.055, "metal")
		C.node(s, "popcorn", s.ball.x, s.ball.y, 0.065, 0.065, "popcorn", s.t * 180)
	end,
}

Games.SunbedSlalom = {
	init = function(s)
		s.px, s.distance, s.rival, s.obstacles, s.nextObstacle, s.hitUntil = 0.5, 0, 0, {}, 0.6, 0
	end,
	step = function(s, dt, g)
		s.px = select(1, C.move(s.px, 0, math.clamp(s.x, 0.23, 0.77), 0, dt * g.steer))
		s.distance += dt / (g.duration * 0.82)
		s.rival += dt / g.duration
		if s.t >= s.nextObstacle then
			local lane = (math.floor(s.nextObstacle / g.spawn) + s.seed) % 3
			table.insert(s.obstacles, { x = 0.23 + lane * 0.27, y = 0.05, hit = false })
			s.nextObstacle += g.spawn / (1 + s.difficulty * 0.08)
		end
		for i = #s.obstacles, 1, -1 do
			local o = s.obstacles[i]
			o.y += g.speed * dt
			if not o.hit and math.abs(o.y - 0.77) < 0.09 and math.abs(o.x - s.px) < g.collision then
				o.hit = true
				C.miss(s)
				s.distance = math.max(0, s.distance - g.penalty)
				s.hitUntil = s.t + 0.4
			end
			if o.y > 1.1 then
				table.remove(s.obstacles, i)
			end
		end
		s.score = math.min(g.goal, s.distance * g.goal)
		s.won = s.distance >= 1
		s.lost = s.rival >= 1 and not s.won
	end,
	draw = function(s)
		C.node(s, "beach", 0.5, 0.5, 0.86, 0.96, "sand")
		for i = 1, 7 do
			C.node(s, "stripe" .. i, 0.5, (i / 7 + s.t * 0.2) % 1, 0.018, 0.04, "paper")
		end
		for i, o in s.obstacles do
			C.node(s, "cone" .. i, o.x, o.y, 0.15, 0.12, if o.hit then "gold" else "cone")
		end
		C.node(s, "lounger", s.px, 0.77, 0.15, 0.23, "lounger", if s.t < s.hitUntil then 20 else 0)
		C.node(s, "brayan", 0.95, 0.90 - s.rival * 0.78, 0.06, 0.10, "rival")
		C.node(s, "playerProgress", 0.05, 0.90 - s.distance * 0.78, 0.06, 0.10, "athlete")
	end,
}

Games.TreadmillTakeover = {
	init = function(s)
		s.coach, s.velocity, s.belt, s.lastReverse, s.pause = 0.14, 0.35, 1, -10, 1
	end,
	action = function(s, kind, g)
		if kind == "down" and s.t > s.pause and s.t - s.lastReverse >= g.cooldown then
			if s.coach >= g.commit then
				s.committed = true
			end
			s.belt = -s.belt
			s.lastReverse = s.t
			s.pulse += 1
			s.feedback = "Reversed"
		end
	end,
	step = function(s, dt, g)
		if s.t < s.pause then
			return
		end
		s.velocity =
			math.clamp(s.velocity + s.belt * g.acceleration * dt, -g.speed, g.speed * (1 + s.difficulty * 0.12))
		s.coach += s.velocity * dt
		if s.coach < 0.09 then
			if s.committed then
				C.mark(s, 1)
			else
				C.miss(s)
			end
			s.committed = false
			s.lost = s.misses >= g.lives
			s.won = s.score >= g.goal
			s.coach, s.velocity, s.belt, s.pause = 0.14, g.speed, 1, s.t + g.reset
		elseif s.coach > 0.86 then
			C.miss(s)
			s.committed = false
			s.lost = s.misses >= g.lives
			s.coach, s.velocity, s.belt, s.pause = 0.14, g.speed, 1, s.t + g.reset
		end
	end,
	draw = function(s, g)
		C.node(s, "commit", g.commit, 0.45, 0.015, 0.40, "gold")
		C.node(s, "treadmill", 0.5, 0.63, 0.88, 0.20, "tire")
		for i = 1, 12 do
			C.node(s, "belt" .. i, 0.08 + ((i / 12 + s.t * s.belt * 0.25) % 1) * 0.84, 0.60, 0.025, 0.10, "metal")
		end
		C.node(s, "pad", 0.06, 0.46, 0.09, 0.34, "goal")
		C.node(s, "coach", s.coach, 0.43, 0.14, 0.24, "rival", -s.velocity * 50)
		C.node(s, "player", 0.93, 0.43, 0.10, 0.22, "athlete")
		C.node(s, "momentum", math.clamp(s.coach + s.velocity * 0.4, 0.1, 0.9), 0.27, 0.045, 0.04, "danger")
	end,
}

local function closeTerritory(s, g)
	local blocked, reachable, queue = table.clone(s.claimed), {}, {}
	for _, i in s.trail do
		blocked[i] = true
	end
	-- Flood from the unclaimed outer boundary; everything sealed off is captured.
	for i = 1, g.size * g.size do
		local col, row = (i - 1) % g.size, math.floor((i - 1) / g.size)
		if (col == g.size - 1 or row == 0 or row == g.size - 1) and not blocked[i] then
			reachable[i] = true
			table.insert(queue, i)
		end
	end
	local nextIndex = 1
	while nextIndex <= #queue do
		local cell = queue[nextIndex]
		nextIndex += 1
		for _, neighbor in { cell - 1, cell + 1, cell - g.size, cell + g.size } do
			if
				neighbor >= 1
				and neighbor <= g.size * g.size
				and C.adjacent(cell, neighbor, g.size)
				and not blocked[neighbor]
				and not reachable[neighbor]
			then
				reachable[neighbor] = true
				table.insert(queue, neighbor)
			end
		end
	end
	for i = 1, g.size * g.size do
		if not s.claimed[i] and (blocked[i] or not reachable[i]) then
			s.claimed[i] = true
			C.mark(s, 1)
		end
	end
	s.trail = {}
	s.won = s.score >= g.goal
end

Games.LegDayLandgrab = {
	init = function(s, g)
		s.claimed, s.trail, s.cell, s.lastStomp = {}, {}, 1, 0
		for row = 0, g.size - 1 do
			s.claimed[row * g.size + 1] = true
		end
	end,
	step = function(s, _, g)
		if s.held then
			local cell = C.cell(s.x, s.y, g.size)
			if cell ~= s.cell and C.adjacent(cell, s.cell, g.size) then
				if s.claimed[cell] then
					if #s.trail > 0 then
						closeTerritory(s, g)
					end
					s.cell = cell
				elseif not table.find(s.trail, cell) and #s.trail < g.maxTrail then
					table.insert(s.trail, cell)
					s.cell = cell
				elseif #s.trail >= g.maxTrail then
					s.notice = "TrailFull"
				end
			end
		end
		local stomp = math.floor(s.t / g.stomp)
		if #s.trail == 0 then
			s.notice = nil
		end
		if stomp > s.lastStomp then
			s.lastStomp = stomp
			if #s.trail > 0 then
				C.miss(s)
				s.trail = {}
				s.cell = 1
				s.lost = s.misses >= g.lives
			end
		end
	end,
	draw = function(s, g)
		local styles = {}
		local warning = s.t % g.stomp > g.stomp - g.warning
		for i = 1, g.size * g.size do
			styles[i] = if s.claimed[i]
				then "gold"
				elseif table.find(s.trail, i) then (if warning then "danger" else "water")
				else "tile"
		end
		C.grid(s, g.size, styles)
		local x, y = C.xy(s.cell, g.size)
		C.node(s, "player", x, y, 0.06, 0.08, "athlete")
		C.node(s, "boss", 0.84, 0.06, 0.16, if warning then 0.12 else 0.08, "rival")
	end,
}

Games.CrownSneak = {
	init = function(s)
		s.distance, s.lastCover, s.caughtUntil = 0.05, 0.05, 0
	end,
	step = function(s, dt, g)
		local phase = s.t % g.sweep
		local watching = phase > g.sweep * g.watchAt
		local safe = false
		for _, cover in g.cover do
			if math.abs(s.distance - cover) < g.safe then
				safe = true
				s.lastCover = cover
			end
		end
		if s.held and s.t > s.caughtUntil then
			s.distance += g.speed * dt
			if watching and not safe then
				C.miss(s)
				s.distance = s.lastCover
				s.caughtUntil = s.t + 0.7
				s.lost = s.misses >= g.lives
			end
		end
		s.score = s.distance
		s.won = s.distance >= 0.96
	end,
	draw = function(s, g)
		local phase = s.t % g.sweep
		local watching = phase > g.sweep * g.watchAt
		C.node(s, "stage", 0.5, 0.62, 0.91, 0.17, "floor")
		for i, cover in g.cover do
			C.node(s, "cover" .. i, cover, 0.48, 0.08, 0.27, "stone")
		end
		C.node(s, "athlete", s.distance, 0.48, 0.07, 0.14, if s.held then "athlete" else "stone")
		C.node(s, "crown", 0.96, 0.45, 0.09, 0.10, "crown")
		C.node(s, "king", 0.82, 0.16, 0.16, 0.20, "rival", if watching then -20 else 20)
		C.node(
			s,
			"light",
			0.5,
			0.27,
			0.45,
			0.025,
			if watching then "danger" elseif phase > g.sweep * g.watchAt - g.warning then "gold" else "goal"
		)
	end,
}

Games.GravityGauntlet = {
	init = function(s)
		s.px, s.py, s.vy, s.gravity, s.lastFlip, s.seal = 0.1, 0.5, 0, 1, -10, 1
	end,
	action = function(s, kind, g)
		if kind == "down" and s.t - s.lastFlip > g.cooldown then
			s.gravity = -s.gravity
			s.lastFlip = s.t
			s.pulse += 1
		end
	end,
	step = function(s, dt, g)
		s.vy += s.gravity * g.gravity * dt
		s.py = math.clamp(s.py + s.vy * dt, 0.13, 0.87)
		if s.py == 0.13 or s.py == 0.87 then
			s.vy = 0
		end
		s.px += g.horizontal * dt
		local tx, ty = 0.78, if s.seal % 2 == 0 then 0.80 else 0.20
		if C.distance(s.px, s.py, tx, ty) < g.radius then
			C.mark(s, 1)
			s.seal += 1
			s.px = 0.12
			s.won = s.score >= g.goal
		elseif s.px > 0.98 then
			C.miss(s)
			s.px = 0.12
			s.lost = s.misses >= g.lives
		end
	end,
	draw = function(s)
		C.node(s, "ceiling", 0.5, 0.08, 0.92, 0.06, "gold")
		C.node(s, "floor", 0.5, 0.92, 0.92, 0.06, "cloud")
		C.node(s, "seal", 0.78, if s.seal % 2 == 0 then 0.80 else 0.20, 0.13, 0.13, "goal", s.t * 45)
		C.node(s, "athlete", s.px, s.py, 0.09, 0.12, "athlete", if s.gravity < 0 then 180 else 0)
		for i = 1, 6 - s.score do
			C.node(s, "divine" .. i, 0.25 + i * 0.08, 0.49, 0.055, 0.08, "stone")
		end
	end,
}

return Games
