-- Only transforms with known solutions. The chosen rules travel with the authoritative state.
local Variants = {}

-- Valeurs tirées au sort entre min et max, espacées d'au moins `gap` (cibles différentes à chaque partie)
local function spread(rng, count, min, max, gap)
	for _ = 1, 200 do
		local values, ok = {}, true
		for i = 1, count do
			values[i] = math.floor((min + rng:NextNumber() * (max - min)) * 1000 + 0.5) / 1000
			for j = 1, i - 1 do
				if math.abs(values[i] - values[j]) < gap then
					ok = false
				end
			end
		end
		if ok then
			return values
		end
	end
	return nil
end

function Variants.Choose(name, base, seed)
	local g = table.clone(base)
	local rng = Random.new(seed * 977 + 13)
	local function pick(values)
		return values[(seed - 1) % #values + 1]
	end
	-- Variété (D79) : là où c'est sûr, des cibles neuves à chaque partie plutôt que 3 versions apprises par cœur.
	-- Les tirages restent dans les bornes des versions vérifiées ; les tests jouent 16 graines de chaque jeu.
	if g.randomTargets then
		local r = g.randomTargets
		local values = spread(rng, r.count, r.min, r.max, r.gap)
		if values then
			g.targetVariants = { values }
		end
	end
	if g.randomPhrase then
		-- Trois temps parmi les cinq de chaque mesure, dans l'ordre
		local beats = { 1, 2, 3, 4, 5 }
		local chosen = {}
		for _ = 1, 3 do
			table.insert(chosen, table.remove(beats, rng:NextInteger(1, #beats)))
		end
		table.sort(chosen)
		g.phrases = { chosen }
	end
	if g.randomColumns then
		local r = g.randomColumns
		local values = spread(rng, 3, r.min, r.max, r.gap)
		if values then
			table.sort(values)
			g.columns = { values }
		end
	end
	if g.targetVariants then
		g.targets = pick(g.targetVariants)
	end
	if g.phrases then
		g.phrase = pick(g.phrases)
	end
	if g.stompVariants then
		g.stomp = pick(g.stompVariants)
	end
	if g.sweepVariants then
		g.sweep = pick(g.sweepVariants)
	end
	if g.layoutMoves then
		-- Parking : chaque plateau a son propre budget de coups (minimum du solveur + 3)
		g.moves = g.layoutMoves[(seed - 1) % #g.layoutMoves + 1]
	end
	if name == "PeelGood" then
		g.path = {}
		for _, p in base.path do
			table.insert(g.path, { if seed % 2 == 0 then 1 - p[1] else p[1], p[2] })
		end
	elseif name == "TowelFold" then
		g.folds = {}
		for _, f in base.folds do
			table.insert(
				g.folds,
				{ if seed % 2 == 0 then 1 - f[1] else f[1], f[2], if seed % 2 == 0 then 1 - f[3] else f[3], f[4] }
			)
		end
	elseif name == "ShortcutChalk" then
		local function transform(i)
			local x, y = (i - 1) % g.size, math.floor((i - 1) / g.size)
			for _ = 1, (seed - 1) % 4 do
				x, y = g.size - 1 - y, x
			end
			return y * g.size + x + 1
		end
		g.route, g.blocked = {}, {}
		for _, i in base.route do
			table.insert(g.route, transform(i))
		end
		for _, i in base.blocked do
			table.insert(g.blocked, transform(i))
		end
	end
	return g
end

return Variants
