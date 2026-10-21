-- Deterministic gameplay, with no player data or networking. Server owns the accepted state.
local Config = require(script.Parent.Config.Playground)
local Autoplay = require(script.Autoplay)
local Variants = require(script.Variants)
local Rules = {}
for _, group in { script.Training, script.Jobs, script.Bosses } do
	for name, rule in require(group) do
		Rules[name] = rule
	end
end

local Playground = {}
Playground.Rules = Rules

function Playground.New(name, seed, difficulty)
	local rule, config = Rules[name], Config.Games[name]
	assert(rule and config, "Unknown playground game: " .. tostring(name))
	local state = {
		rules = Variants.Choose(name, config, seed or 1),
		name = name,
		seed = seed or 1,
		difficulty = difficulty or 0,
		t = -Config.Lead,
		x = 0.5,
		y = 0.5,
		held = false,
		score = 0,
		misses = 0,
		pulse = 0,
		won = false,
		lost = false,
		finished = false,
		nodes = {},
	}
	rule.init(state, state.rules)
	state.rules.inputGrace = Config.TimingGrace
	return state
end

function Playground.Input(state, kind, x, y)
	if state.finished or state.won or state.lost then
		return
	end
	if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y then
		return
	end
	-- Clamp before interpolation: even a finite but huge coordinate must not create an unbounded loop.
	x, y = math.clamp(x, 0, 1), math.clamp(y, 0, 1)
	if kind == "down" and not state.autoplayInput then
		state.autoPlan = nil
		state.autoPlanAt = nil
	end
	local g = state.rules
	if kind == "undo" then
		if state.t < 0 then
			return
		end
		if state.name == "AirwayExpress" and state.history and #state.history > 0 and state.moves < g.turns then
			local i = table.remove(state.history)
			state.pipes[i].rot = (state.pipes[i].rot + 3) % 4
			Rules[state.name].refresh(state)
			state.moves += 1
			state.lost = state.moves >= g.turns
		elseif state.name == "ParkingKnot" and state.history and #state.history > 0 and state.moves < g.moves then
			state.cars = table.remove(state.history)
			state.moves += 1
			state.score = state.cars[1].x / (g.size - state.cars[1].length)
			state.lost = state.moves >= g.moves
		end
		state.autoPlan = nil
		state.held = false
		return
	end
	-- The release can arrive before the next move sample, especially on touch.
	if (kind == "move" or kind == "up") and state.held and state.t >= 0 and g.trace then
		local fromX, fromY = state.x, state.y
		local steps = math.max(1, math.ceil(math.max(math.abs(x - fromX), math.abs(y - fromY)) / Config.TraceSpacing))
		for i = 1, steps do
			state.x, state.y = fromX + (x - fromX) * i / steps, fromY + (y - fromY) * i / steps
			Rules[state.name].step(state, 0, g)
			if state.won or state.lost or state.finished then
				state.held = false
				return
			end
		end
	end
	state.x, state.y = math.clamp(x, 0, 1), math.clamp(y, 0, 1)
	if kind == "down" then
		if state.held then
			return
		end
		state.held = true
	elseif kind == "up" then
		if not state.held then
			return
		end
		state.held = false
	end
	if state.t < 0 then
		return
	end
	local action = Rules[state.name].action
	if action then
		action(state, kind, g)
	end
end

function Playground.Step(state, dt)
	if state.finished then
		return
	end
	local g, rule = state.rules, Rules[state.name]
	state.t += dt
	if state.t < 0 then
		return
	end
	if rule.step then
		rule.step(state, dt, g)
	end
	if state.finished or state.won or state.lost or state.t >= g.duration then
		state.finished = true
		state.held = false
	end
end

-- Solveur des tests automatiques (tests/playground*.luau) : prouve que chaque jeu se gagne. Jamais accessible aux
-- joueurs : le mode Auto a été retiré du jeu (D79).
function Playground.Auto(state, dt)
	state.autoplayInput = true
	Autoplay(state, dt, Config, Playground.Input, Rules)
	state.autoplayInput = nil
end

function Playground.Draw(state)
	state.nodes = {}
	Rules[state.name].draw(state, state.rules)
	return state.nodes
end

function Playground.Quality(state)
	local score = Playground.Accuracy(state) / 100
	if state.won and state.misses == 0 and score >= Config.Perfect then
		return "Perfect"
	end
	if state.won or score >= Config.Good then
		return "Good"
	end
	return "Miss"
end

function Playground.Score(state)
	return Playground.Accuracy(state)
end

function Playground.Completion(state)
	return if state.won then 1 else math.clamp(state.score / state.rules.goal, 0, 1)
end

function Playground.Accuracy(state)
	local precision = if (state.hits or 0) > 0 then state.precision / state.hits else 1
	return math.floor(
		100 * Playground.Completion(state) * precision / (1 + state.misses * Config.Mastery.ErrorPenalty) + 0.5
	)
end

function Playground.Combo(state)
	return 1 + math.min(math.max(0, (state.streak or 0) - 1) * Config.Mastery.ComboStep, Config.Mastery.ComboMax)
end

function Playground.Payout(state)
	local progress = Playground.Completion(state)
	local scale = (state.rules.rewardTime or state.rules.duration) / state.rules.duration
	return scale * progress * (if state.won then 1 else Config.Mastery.PartialReward)
end

function Playground.Snapshot(state)
	-- Render nodes are derived, never sent over the wire.
	local result = {}
	for key, value in state do
		if key ~= "nodes" then
			result[key] = value
		end
	end
	return result
end

return Playground
