-- Drip (D111) : la valeur de la tenue portée donne un petit bonus contre les boss (Mog-off et Colisée). « Mogger »,
-- c'est aussi le look. Le style s'achète en Cash, sauf les tenues Robux (D121) qui donnent le Drip maximal.
-- D122 (choix d'Antoine) : une tenue Robux portée en entier donne un bonus plus fort contre les boss
-- (Balance.Drip.RobuxBossBonus) ; et plus aucun bonus au bras de fer : « l'argent ne doit pas influencer les combats
-- entre vrais joueurs ». Partagé : le serveur calcule le bonus, le client l'affiche.

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
		-- Tenue Robux (D121) : sa valeur de Drip ; sinon le prix de l'ensemble
		return (set.dripValue or set.price or 0) / 2
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

-- Ensemble Robux porté en entier (haut et bas du même ensemble), sinon nil
function Drip.RobuxSet(equipped: { [string]: string }?): string?
	local worn = equipped or {}
	local top = worn.Top and StyleItems[worn.Top]
	local set = top and top.setId and StyleSets.ById[top.setId]
	if set and set.robux and worn.Bottom == set.bottom then
		return set.id
	end
	return nil
end

-- Bonus contre les boss : proportionnel à la valeur de la tenue (0 à Balance.Drip.MaxBonus), ou le bonus des
-- tenues Robux portées en entier. Jamais utilisé entre joueurs (bras de fer, D122).
function Drip.Bonus(equipped: { [string]: string }?): number
	local bonus = DRIP.MaxBonus * Drip.Ratio(equipped)
	if Drip.RobuxSet(equipped) then
		bonus = math.max(bonus, DRIP.RobuxBossBonus)
	end
	return bonus
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
