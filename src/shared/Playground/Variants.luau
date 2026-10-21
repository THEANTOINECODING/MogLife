-- Only transforms with known solutions. The chosen rules travel with the authoritative state.
local Variants = {}

function Variants.Choose(name, base, seed)
	local g = table.clone(base)
	local function pick(values)
		return values[(seed - 1) % #values + 1]
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
