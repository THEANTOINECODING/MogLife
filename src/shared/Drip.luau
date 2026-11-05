-- Drip (D111) : la valeur de la tenue portée donne un petit bonus contre les boss (Mog-off et Colisée) et au bras
-- de fer. « Mogger », c'est aussi le look. Le style s'achète en Cash seulement : ce n'est pas de la puissance vendue
-- contre des Robux. Partagé : le serveur calcule le bonus, le client l'affiche.

local Balance = require(script.Parent.Config.Balance)
local StyleItems = require(script.Parent.Config.StyleItems)
local StyleSets = require(script.Parent.Config.StyleSets)

local DRIP = Balance.Drip

local Drip = {}

-- Valeur en Cash d'un article : son prix, la moitié du prix de son ensemble, ou une valeur fixe pour les
-- récompenses de boss (sans prix). Les coupes de départ ne valent rien.
function Drip.ItemValue(itemId: string): number
	local item = StyleItems[itemId]
	if not item or item.starter then
		return 0
	end
	if item.price then
		return item.price
	end
	local set = item.setId and StyleSets.ById[item.setId]
	if set then
		return set.price / 2
	end
	return if item.bossId then DRIP.BossItemValue else 0
end

-- Valeur de la tenue portée (catégorie -> article)
function Drip.Value(equipped: { [string]: string }?): number
	local total = 0
	for _, itemId in equipped or {} do
		total += Drip.ItemValue(itemId)
	end
	return total
end

-- Bonus (0 à Balance.Drip.MaxBonus) : proportionnel à la valeur de la tenue, plein à Balance.Drip.FullValue
function Drip.Bonus(equipped: { [string]: string }?): number
	return DRIP.MaxBonus * math.clamp(Drip.Value(equipped) / DRIP.FullValue, 0, 1)
end

return Drip
