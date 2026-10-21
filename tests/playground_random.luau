-- D79 : aucun mini-jeu ne doit se gagner en cliquant au hasard (« pas de clic sans réfléchir », 00_VISION).
-- À lancer avec execute_luau (Server ou Edit) : états isolés, aucune donnée de joueur touchée.
-- Deux joueurs « au hasard » : un qui tape et glisse très vite, un qui tape environ une fois par seconde.
-- Seuil : au plus 10 % de victoires sur 60 parties (un petit casse-tête peut parfois tomber juste).
local P = require(game.ReplicatedStorage.Shared.Playground)
local Config = require(game.ReplicatedStorage.Shared.Config.Playground)
local LIMIT = 6 -- victoires max sur 60
local function run(s, input)
	for _ = 1, math.ceil((s.rules.duration + Config.Lead + 1) / Config.Step) do
		input(s)
		P.Step(s, Config.Step)
		if s.finished then
			break
		end
	end
	return s
end
local results = {}
for name in Config.Games do
	if name == "ReadRip" then
		continue
	end
	local fast, slow = 0, 0
	for seed = 1, 60 do
		local rng = Random.new(seed * 31)
		local held = false
		local s = run(P.New(name, seed), function(state)
			if state.t <= 0 then
				return
			end
			local x, y, r = rng:NextNumber(), rng:NextNumber(), rng:NextNumber()
			if r < 0.25 then
				P.Input(state, if held then "up" else "down", x, y)
				held = not held
			elseif r < 0.6 and held then
				P.Input(state, "move", x, y)
			end
		end)
		if s.won then
			fast += 1
		end
		local rng2 = Random.new(seed * 97)
		s = run(P.New(name, seed), function(state)
			if state.t > 0 and rng2:NextNumber() < 0.035 then
				local x, y = rng2:NextNumber(), rng2:NextNumber()
				P.Input(state, "down", x, y)
				P.Input(state, "up", x, y)
			end
		end)
		if s.won then
			slow += 1
		end
	end
	local passed = fast <= LIMIT and slow <= LIMIT
	table.insert(results, string.format("%s %s : %d/60 et %d/60", if passed then "OK" else "ÉCHEC", name, fast, slow))
	task.wait()
end
table.sort(results)
return table.concat(results, "\n")
