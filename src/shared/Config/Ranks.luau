-- Rangs du joueur selon sa force, du plus faible au plus fort.

local Ranks = {
	{ name = "Normie", minStrength = 0 },
	{ name = "Gym Rat", minStrength = 500 },
	{ name = "Bro", minStrength = 5_000 },
	{ name = "Alpha", minStrength = 50_000 },
	{ name = "Chad", minStrength = 250_000 },
	{ name = "Gigachad", minStrength = 1_000_000 },
}

local function fromStrength(strength: number): string
	local current = Ranks[1].name
	for _, rank in Ranks do
		if strength >= rank.minStrength then
			current = rank.name
		end
	end
	return current
end

return {
	List = Ranks,
	FromStrength = fromStrength,
}
