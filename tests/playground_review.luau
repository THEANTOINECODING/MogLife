-- Audit regressions. Pure states only: never touches profiles, remotes or currency.
local P = require(game.ReplicatedStorage.Shared.Playground)
local Config = require(game.ReplicatedStorage.Shared.Config.Playground)
local C = require(game.ReplicatedStorage.Shared.Playground.Common)
local Status = require(game.ReplicatedStorage.Shared.Playground.Status)
local Texts = require(game.ReplicatedStorage.Shared.Config.Texts)
assert(Config.Version >= 4, "Rojo has not synced the current rules")
local results = {}
local function check(label, callback)
	local ok, err = pcall(callback)
	table.insert(results, { test = label, passed = ok, error = if ok then nil else tostring(err) })
end
local function run(s, input)
	for _ = 1, math.ceil((s.rules.duration + Config.Lead + 1) / Config.Step) do
		if input then
			input(s)
		end
		P.Step(s, Config.Step)
		if s.finished then
			break
		end
	end
	return s
end
local bosses = {
	SnackVolley = true,
	SunbedSlalom = true,
	TreadmillTakeover = true,
	LegDayLandgrab = true,
	CrownSneak = true,
	GravityGauntlet = true,
}
check("Every assisted game has 12 solvable seeds and valid localized status", function()
	for name in Config.Games do
		if name == "ReadRip" or bosses[name] then
			continue
		end
		for seed = 1, 12 do
			local s = run(P.New(name, seed), function(state)
				P.Auto(state, Config.Step)
			end)
			assert(s.won, name .. " failed seed " .. seed)
			local key, args = Status(s)
			assert(
				Texts.Get("Playground.Budget." .. key, args) ~= "Playground.Budget." .. key,
				name .. " has no status"
			)
		end
		task.wait()
	end
end)
check("Brayan has no stationary winning corridor", function()
	for seed = 1, 6 do
		for i = 0, 100 do
			local s = P.New("SunbedSlalom", seed)
			P.Input(s, "move", i / 100, 0.5)
			run(s)
			assert(not s.won, "stationary win at " .. tostring(i / 100) .. " seed " .. seed)
		end
		task.wait()
	end
end)
check("Atlas needs aiming on both mirrored bases", function()
	for seed = 1, 6 do
		local s = run(P.New("AtlasStack", seed), function(state)
			if state.t > 0 then
				P.Input(state, "down", 0.5, 0.5)
				P.Input(state, "up", 0.5, 0.5)
			end
		end)
		assert(not s.won, "untouched cursor wins")
	end
end)
check("All Good rhythm hits complete every phrase without dead time", function()
	for seed = 1, 3 do
		local s = P.New("RopeRave", seed)
		local g, n = s.rules, 1
		run(s, function(state)
			if n > g.goal then
				return
			end
			local target = g.lead + (math.floor((n - 1) / #g.phrase) * 6 + g.phrase[(n - 1) % #g.phrase + 1]) * g.beat
			if state.t >= target + 0.11 then
				P.Input(state, "down", 0.5, 0.5)
				P.Input(state, "up", 0.5, 0.5)
				n += 1
			end
		end)
		assert(s.won and s.misses == 0 and s.score == 15, "Good hits did not complete")
		assert(P.Score(s) == 70 and P.Quality(s) == "Good", "Good hits must not be Perfect")
		assert(s.t < 20, "empty rhythm tail")
	end
end)
check("Coach clears commitment after the right-side failure", function()
	local s = P.New("TreadmillTakeover", 1)
	local phase = 1
	for _ = 1, 800 do
		if phase == 1 and s.coach >= 0.56 then
			P.Input(s, "down", 0.5, 0.5)
			P.Input(s, "up", 0.5, 0.5)
			phase = 2
		elseif phase == 2 and s.t - s.lastReverse >= 0.41 then
			P.Input(s, "down", 0.5, 0.5)
			P.Input(s, "up", 0.5, 0.5)
			phase = 3
		elseif phase == 3 and s.misses == 1 then
			assert(not s.committed, "stale commitment")
			return
		end
		P.Step(s, Config.Step)
	end
	error("test did not reach failure")
end)
check("Waiting cannot increase a training payout", function()
	local payouts = {}
	for _, waitUntil in { 0, 23 } do
		local s = run(P.New("ScrapPress", 1), function(state)
			if not (state.item == 4 and state.t < waitUntil) then
				P.Auto(state, Config.Step)
			end
		end)
		assert(s.won)
		table.insert(payouts, P.Payout(s))
	end
	assert(math.abs(payouts[1] - payouts[2]) < 0.00001)
end)
check("Mistakes lower precision and validated actions earn combo", function()
	local clean = run(P.New("ScrapPress", 1), function(s)
		P.Auto(s, Config.Step)
	end)
	local flawed = P.New("ScrapPress", 1)
	flawed.t = 0.1
	P.Input(flawed, "down", 0.5, 0.5)
	P.Input(flawed, "up", 0.5, 0.5)
	flawed = run(flawed, function(s)
		P.Auto(s, Config.Step)
	end)
	assert(flawed.won and P.Score(flawed) < P.Score(clean), "errors disappeared from the grade")
	assert(P.Combo(clean) > 1, "combo still unreachable")
end)
check("Undo consumes budget and terminal states cannot be edited", function()
	for _, name in { "AirwayExpress", "ParkingKnot" } do
		local s = P.New(name, 1)
		s.t = 0.1
		if name == "AirwayExpress" then
			local x, y = C.xy(1, 3)
			local before = s.pipes[1].rot
			P.Input(s, "down", x, y)
			P.Input(s, "up", x, y)
			P.Input(s, "undo", x, y)
			assert(s.pipes[1].rot == before and s.moves == 2)
		else
			-- Premier coup de la solution du solveur, puis annulation : le plateau revient, le budget baisse
			local Solver = require(game.ReplicatedStorage.Shared.Playground.ParkingSolver)
			local plan = Solver(s.cars, s.rules.size, Config.PuzzleSearchLimit)
			local before = game:GetService("HttpService"):JSONEncode(s.cars)
			local x, y = C.xy(plan[1].from, s.rules.size)
			P.Input(s, "down", x, y)
			x, y = C.xy(plan[1].to, s.rules.size)
			P.Input(s, "up", x, y)
			assert(s.moves == 1, "move not counted")
			P.Input(s, "undo", x, y)
			assert(s.moves == 2 and game:GetService("HttpService"):JSONEncode(s.cars) == before, "undo failed")
		end
		local won = run(P.New(name, 1), function(state)
			P.Auto(state, Config.Step)
		end)
		local moves = won.moves
		P.Input(won, "undo", 0.5, 0.5)
		assert(won.moves == moves)
	end
end)
check("Delayed rhythm input stays within the bounded grace window", function()
	local s = P.New("RopeRave", 1)
	local g = s.rules
	local target = g.lead + g.phrase[1] * g.beat
	s.t = target + Config.TimingGrace
	s.inputTime = target
	P.Input(s, "down", 0.5, 0.5)
	assert(s.score == 1 and s.precision == 1)
end)
check("Fast release includes the final traced cells", function()
	-- Groupe de fruits tracé en entier, le relâchement arrivant sur la dernière case sans « move » avant
	local s = P.New("ProduceParade", 1)
	s.t = 0.1
	local group = s.groups[1]
	local x, y = C.xy(group[1], 4)
	P.Input(s, "down", x, y)
	for i = 2, #group - 1 do
		x, y = C.xy(group[i], 4)
		P.Input(s, "move", x, y)
	end
	x, y = C.xy(group[#group], 4)
	P.Input(s, "up", x, y)
	assert(s.score == #group and s.misses == 0 and not s.held, "release lost a valid fruit chain")

	s = P.New("ShortcutChalk", 1)
	s.t = 0.1
	x, y = C.xy(s.rules.route[1], 6)
	P.Input(s, "down", x, y)
	for i = 2, #s.rules.route - 1 do
		x, y = C.xy(s.rules.route[i], 6)
		P.Input(s, "move", x, y)
	end
	x, y = C.xy(s.rules.route[#s.rules.route], 6)
	P.Input(s, "up", x, y)
	assert(s.walk > 0 and not s.held, "release lost the route destination")
end)
check("Variants change decisions rather than only colors", function()
	local a, b = P.New("ParkingKnot", 1), P.New("ParkingKnot", 2)
	assert(a.cars[2].y ~= b.cars[2].y)
	a, b = P.New("ShortcutChalk", 1), P.New("ShortcutChalk", 2)
	assert(a.path[1] ~= b.path[1])
	a, b = P.New("AirwayExpress", 1), P.New("AirwayExpress", 2)
	assert(a.route[2] ~= b.route[2])
end)
return results
