-- Structured text keys; the client formats/localizes the values.
return function(s)
	local g, n = s.rules, s.name
	if n == "TireDomino" then
		return "Shots", { left = g.shots - s.shots, goal = g.goal, count = s.score }
	elseif n == "AirwayExpress" then
		return "Turns", { left = g.turns - s.moves }
	elseif n == "ParkingKnot" then
		return "Moves", { left = g.moves - s.moves }
	elseif n == "LegDayLandgrab" then
		return "Territory",
			{
				left = g.maxTrail - #s.trail,
				time = math.ceil(g.stomp - s.t % g.stomp),
				lives = math.max(0, g.lives - s.misses),
			}
	elseif n == "MagnetHaul" then
		return "Load", { count = #s.load, goal = g.goal, left = g.goal - s.score }
	elseif n == "RopeRave" then
		return "Beats", { count = s.score, goal = g.goal }
	elseif n == "PianoPolish" then
		return "Dust", { left = g.goal - s.score }
	elseif n == "ProduceParade" then
		return "Chain", { count = #s.path, left = math.max(0, g.lives - s.misses) }
	elseif n == "ShortcutChalk" then
		return "Route", { count = #s.path, goal = g.maxPath }
	elseif g.lives then
		return "Lives", { left = math.max(0, g.lives - s.misses), count = math.floor(s.score), goal = g.goal }
	else
		return "Steps", { count = math.floor(s.score), goal = g.goal }
	end
end
