local C = {}
local MISS_REASONS = {
	ScrapPress = "ReleaseTarget",
	MagnetHaul = "Spilled",
	SwingKing = "CatchMissed",
	RopeRave = "OffBeat",
	AtlasStack = "Align",
	PeelGood = "SealTorn",
	ChopShop = "CutAim",
	TowelFold = "FoldAim",
	ProduceParade = "ChainShort",
	SnackVolley = "Dropped",
	SunbedSlalom = "Crash",
	TreadmillTakeover = "ReverseTarget",
	LegDayLandgrab = "Stomp",
	CrownSneak = "Spotted",
	GravityGauntlet = "SealMissed",
}

function C.distance(x, y, a, b)
	return math.sqrt((x - a) ^ 2 + (y - b) ^ 2)
end

function C.move(x, y, a, b, amount)
	local d = C.distance(x, y, a, b)
	local u = math.min(1, amount / math.max(d, 0.00001))
	return x + (a - x) * u, y + (b - y) * u
end

function C.node(s, id, x, y, w, h, style, angle)
	local n = { id = id, x = x, y = y, w = w, h = h, style = style, angle = angle or 0 }
	table.insert(s.nodes, n)
	return n
end

function C.cell(x, y, size)
	local col = math.clamp(math.floor((x - 0.12) / 0.76 * size) + 1, 1, size)
	local row = math.clamp(math.floor((y - 0.12) / 0.76 * size) + 1, 1, size)
	return (row - 1) * size + col
end

function C.xy(index, size)
	return 0.12 + ((index - 1) % size + 0.5) * 0.76 / size, 0.12 + (math.floor((index - 1) / size) + 0.5) * 0.76 / size
end

function C.adjacent(a, b, size)
	return math.abs((a - 1) % size - (b - 1) % size) + math.abs(math.floor((a - 1) / size) - math.floor((b - 1) / size))
		== 1
end

function C.mark(s, amount, precision)
	s.score += amount
	s.pulse += 1
	s.hits = (s.hits or 0) + 1
	s.precision = (s.precision or 0) + (precision or 1)
	s.streak = (s.streak or 0) + 1
	s.bestStreak = math.max(s.bestStreak or 0, s.streak)
	s.perfectStreak = if (precision or 1) >= 1 then (s.perfectStreak or 0) + 1 else 0
	s.feedback = if (precision or 1) >= 1 then "Perfect" else "Good"
end

function C.miss(s, reason)
	s.misses += 1
	s.pulse += 1
	s.streak = 0
	s.perfectStreak = 0
	s.feedback = reason or MISS_REASONS[s.name] or "Miss"
end

function C.grid(s, size, styles)
	for i = 1, size * size do
		local x, y = C.xy(i, size)
		C.node(s, "tile" .. i, x, y, 0.70 / size, 0.70 / size, styles[i] or "tile")
	end
end

return C
