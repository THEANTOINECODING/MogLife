-- Formatage commun des nombres affichés.

local Format = {}

-- 1234 -> "1.2K", 2500000 -> "2.5M". Les décimales sont tronquées sous 1000.
function Format.Short(n: number): string
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

-- Petit gain avec au plus une décimale : 1 -> "1", 1.25 -> "1.3", 1.6 -> "1.6"
function Format.Gain(n: number): string
	local rounded = math.round(n * 10) / 10
	if rounded == math.floor(rounded) then
		return tostring(math.floor(rounded))
	end
	return string.format("%.1f", rounded)
end

return Format
