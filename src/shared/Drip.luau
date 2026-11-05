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

-- Part du Drip maximal (0 à 1), pleine à Balance.Drip.FullValue
function Drip.Ratio(equipped: { [string]: string }?): number
	return math.clamp(Drip.Value(equipped) / DRIP.FullValue, 0, 1)
end

-- Bonus (0 à Balance.Drip.MaxBonus) : proportionnel à la valeur de la tenue
function Drip.Bonus(equipped: { [string]: string }?): number
	return DRIP.MaxBonus * Drip.Ratio(equipped)
end

-- Palier de Drip (0 à #Balance.Drip.Tiers) : choisit les compliments des habitants (D112)
function Drip.Tier(equipped: { [string]: string }?): number
	local ratio = Drip.Ratio(equipped)
	local tier = 0
	for index, threshold in DRIP.Tiers do
		if ratio >= threshold then
			tier = index
		end
	end
	return tier
end

-- La tenue respecte-t-elle le « dress code » d'une aide (Helps.dressCode) ?
function Drip.MeetsDressCode(code: string?, equipped: { [string]: string }?): boolean
	if not code then
		return false
	end
	local worn = equipped or {}
	if code == "FullSet" then
		local top = worn.Top and StyleItems[worn.Top]
		local bottom = worn.Bottom and StyleItems[worn.Bottom]
		return top ~= nil and bottom ~= nil and top.setId ~= nil and top.setId == bottom.setId
	end
	local itemId = worn[code]
	return itemId ~= nil and Drip.ItemValue(itemId) > 0
end

return Drip
