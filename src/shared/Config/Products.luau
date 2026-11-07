-- Produits Robux à achat répétable (Developer Products, D122, choix d'Antoine) : packs de Cash, packs de Mog et
-- victoire contre un boss qu'on n'arrive pas à battre. Identifiants à créer par Antoine dans le Creator Hub
-- (Créations > le jeu > Monétisation > Produits de développeur). Tant qu'un identifiant vaut 0, le produit reste
-- caché dans le jeu. Le prix réel est celui du Creator Hub ; `robux` n'est qu'un prix conseillé.
-- Seule la confirmation officielle de Roblox (ProcessReceipt, PurchaseService) accorde un produit.
-- ❓ Montants et prix de départ, à ajuster.

export type Pack = {
	id: string,
	productId: number,
	robux: number, -- prix conseillé (affiché si Roblox ne répond pas)
	amount: number?, -- Cash : montant fixe
	share: number?, -- Mog : part du Mog demandé par le boss du stade du joueur (le pack grandit avec lui)
	icon: string,
}

local Stages = require(script.Parent.Stages)

local Products = {}

Products.Cash = {
	{ id = "CashSmall", productId = 0, robux = 49, amount = 1_500, icon = "💵" },
	{ id = "CashMedium", productId = 0, robux = 149, amount = 6_000, icon = "💰" },
	{ id = "CashLarge", productId = 0, robux = 399, amount = 20_000, icon = "🏦" },
} :: { Pack }

Products.Mog = {
	{ id = "MogSmall", productId = 0, robux = 49, share = 0.1, icon = "💪" },
	{ id = "MogMedium", productId = 0, robux = 149, share = 0.35, icon = "🗿" },
	{ id = "MogLarge", productId = 0, robux = 399, share = 1.0, icon = "🔥" },
} :: { Pack }

-- Victoire contre le boss qu'on vient de perdre (proposée sur l'écran de défaite, choix d'Antoine). Seulement pour la
-- première victoire (le boss qui garde le stade du joueur), jamais en revanche, jamais au bras de fer.
Products.BossWin = {
	productId = 0,
	robux = 99,
	OfferWindow = 120, -- secondes après la défaite pendant lesquelles l'offre reste valable
	OfferDelay = 4, -- secondes avant d'afficher l'offre (laisser la fin du combat se jouer)
	-- Si le boss payé n'est plus à battre au moment du reçu (cas rare : reconnexion), le joueur reçoit ce Cash
	FallbackCash = 6_000,
}

Products.MaxReceipts = 200 -- reçus gardés dans la sauvegarde (les plus anciens sont oubliés)

-- Mog d'un pack au stade donné : part du Mog demandé par le boss de ce stade (au dernier stade, celui du dernier boss)
function Products.MogAmount(pack: Pack, stage: number): number
	local required = 0
	for index = math.clamp(stage, 1, #Stages.List), 1, -1 do
		local boss = Stages.List[index].boss
		if boss and boss.mogRequired then
			required = boss.mogRequired
			break
		end
	end
	return math.max(math.floor(required * (pack.share or 0) / 10 + 0.5) * 10, 10)
end

function Products.Find(id: string): (Pack?, string?)
	for _, kind in { "Cash", "Mog" } do
		for _, pack in (Products :: any)[kind] do
			if pack.id == id then
				return pack, kind
			end
		end
	end
	return nil, nil
end

return Products
