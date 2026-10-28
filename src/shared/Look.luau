-- Apparence du personnage (D55), partagée par le serveur (BodyService) et le client (aperçus) :
-- - quel corps porter selon le stade et le genre ;
-- - quelles pièces poser (corps + objets de style), et la couleur de chacune ;
-- - validation de l'apparence envoyée par le client.
-- Les zones teintables des textures sont semi-transparentes : la couleur de la pièce (MeshPart.Color) apparaît
-- au travers. Pièces du corps <Partie>[_<Groupe>] (tools/blender/build_bodies.py) :
--   sans groupe -> peau ; _Hair coupe de base ; _Eyes iris ; _Top et _Shorts tenue de départ ;
--   _Mouth<Expression> (peau) et _Brow<Expression> (cheveux) : seules celles de l'expression choisie sont posées.
-- Pièces des objets de style <Partie>[_<Teinte>] (build_style.py) : _Hair ou _Skin, sinon couleurs fixes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BodyPieces = require(ReplicatedStorage.Shared.Config.BodyPieces)
local LookConfig = require(ReplicatedStorage.Shared.Config.Look)
local StyleItems = require(ReplicatedStorage.Shared.Config.StyleItems)
local StylePieces = require(ReplicatedStorage.Shared.Config.StylePieces)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)

export type LookData = {
	Created: boolean,
	Gender: string,
	Skin: string,
	Hair: string,
	Eyes: string,
	Top: string,
	Shorts: string,
	Expression: string,
	First: string,
	Title: string,
}

export type Piece = {
	folder: string, -- "Bodies" ou "Style" (dans ReplicatedStorage)
	template: string, -- nom du modèle dans ce dossier
	part: string, -- partie R15 à laquelle la pièce est soudée
	offset: Vector3, -- décalage par rapport au centre de cette partie, au repos
	tint: string?, -- "Skin", "Hair", "Eyes", "Top", "Shorts" ou nil (couleurs de la texture)
	key: string, -- nom de la pièce sans le corps (<Partie>[_<Groupe>]) : sa jumelle dans un autre corps a le même
	item: string?, -- objet de style (nil pour le corps)
}

local Look = {}

-- Listes de couleurs de chaque champ teinté
local PALETTES = {
	Skin = LookConfig.Skins,
	Hair = LookConfig.HairColors,
	Eyes = LookConfig.EyeColors,
	Top = LookConfig.ClothesColors,
	Shorts = LookConfig.ClothesColors,
}

local function findSwatch(list: { any }, id: unknown): any?
	for _, swatch in list do
		if swatch.id == id then
			return swatch
		end
	end
	return nil
end

local function contains(list: { string }, value: unknown): boolean
	return table.find(list, value :: any) ~= nil
end

function Look.Default(): LookData
	local d = LookConfig.Defaults
	return {
		Created = false,
		Gender = d.Gender,
		Skin = d.Skin,
		Hair = d.Hair,
		Eyes = d.Eyes,
		Top = d.Top,
		Shorts = d.Shorts,
		Expression = d.Expression,
		First = d.First,
		Title = d.Title,
	}
end

-- Titre exclusif (RewardTitles) : sa condition de déblocage, nil si ce n'est pas un titre exclusif
function Look.RewardTitle(id: unknown): { id: string, trophies: number?, duelWins: number?, godWins: number? }?
	for _, entry in LookConfig.RewardTitles do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

-- Titres exclusifs débloqués avec ce nombre de trophées de la semaine, de victoires en duel et de victoires contre le
-- Dieu du Pump
function Look.UnlockedTitles(trophies: number, duelWins: number, godWins: number?): { [string]: boolean }
	local unlocked = {}
	for _, entry in LookConfig.RewardTitles do
		if
			(entry.trophies and trophies >= entry.trophies)
			or (entry.duelWins and duelWins >= entry.duelWins)
			or (entry.godWins and (godWins or 0) >= entry.godWins)
		then
			unlocked[entry.id] = true
		end
	end
	return unlocked
end

-- Apparence valide à partir de données quelconques (client, ancienne sauvegarde) : chaque champ inconnu
-- reprend la valeur de `fallback` (ou la valeur par défaut). Created n'est jamais pris du client.
-- unlocked : titres exclusifs autorisés (demande du client). nil = données déjà validées (sauvegarde) : un titre
-- exclusif enregistré est gardé.
function Look.Sanitize(raw: unknown, fallback: LookData?, unlocked: { [string]: boolean }?): LookData
	local base = fallback or Look.Default()
	local source = if typeof(raw) == "table" then raw :: any else {}
	local out = table.clone(base)
	if contains(LookConfig.Genders, source.Gender) then
		out.Gender = source.Gender
	end
	for field, list in PALETTES do
		if findSwatch(list, source[field]) then
			(out :: any)[field] = source[field]
		end
	end
	if contains(LookConfig.Expressions, source.Expression) then
		out.Expression = source.Expression
	end
	if contains(LookConfig.NickFirst, source.First) then
		out.First = source.First
	end
	local rewardTitle = Look.RewardTitle(source.Title) ~= nil and (unlocked == nil or unlocked[source.Title] == true)
	if contains(LookConfig.NickTitle, source.Title) or rewardTitle then
		out.Title = source.Title
	end
	return out
end

-- Clé courte de l'apparence (pour savoir s'il faut reconstruire le corps)
function Look.Key(look: LookData): string
	return table.concat({ look.Gender, look.Skin, look.Hair, look.Eyes, look.Top, look.Shorts, look.Expression }, ",")
end

-- Couleur d'une teinte pour cette apparence
function Look.Color(look: LookData, tint: string): Color3?
	local list = PALETTES[tint]
	local swatch = list and (findSwatch(list, (look :: any)[tint]) or list[1])
	return swatch and swatch.color
end

-- Corps à porter : <Stade> ou <Stade>F. Si le corps féminin n'est pas importé, on garde le masculin.
function Look.BodyKey(stageId: string, look: LookData?, bodies: Instance?): string
	if look and look.Gender == "F" then
		local key = stageId .. "F"
		if BodyPieces[key] and (not bodies or bodies:FindFirstChild(key .. "_UpperTorso")) then
			return key
		end
	end
	return stageId
end

-- Teinte et visibilité d'une pièce de corps selon son groupe
local function bodyPieceTint(group: string, look: LookData, hasHair: boolean): (boolean, string?)
	if group == "" then
		return true, "Skin"
	elseif group == "Hair" then
		return not hasHair, "Hair"
	elseif group == "Eyes" then
		return true, "Eyes"
	elseif group == "Top" or group == "Shorts" then
		return true, group
	elseif string.sub(group, 1, 5) == "Mouth" then
		return string.sub(group, 6) == look.Expression, "Skin"
	elseif string.sub(group, 1, 4) == "Brow" then
		return string.sub(group, 5) == look.Expression, "Hair"
	end
	return true, nil
end

-- Pièces à poser pour ce corps, cette apparence et ces objets de style.
-- options.bust : tête seule ; options.noBaseHair : sans la coupe de base (mannequins).
function Look.Pieces(bodyKey: string, look: LookData, items: { string }, options: { [string]: any }?): { Piece }
	local opts = options or {}
	local pieces: { Piece } = {}
	local hasHair = opts.noBaseHair == true
	local hasTop = false
	local hasBottom = false
	for _, itemId in items do
		local item = StyleItems[itemId]
		if item then
			if item.category == "Hair" then
				hasHair = true
			elseif item.category == "Top" then
				hasTop = true
			elseif item.category == "Bottom" then
				hasBottom = true
			end
		end
	end
	for key, offset in BodyPieces[bodyKey] or {} do
		local split = string.split(key, "_")
		local part, group = split[1], split[2] or ""
		local visible, tint = bodyPieceTint(group, look, hasHair)
		if
			visible
			and not (group == "Top" and hasTop or group == "Shorts" and hasBottom)
			and (not opts.bust or part == "Head")
		then
			table.insert(pieces, {
				folder = "Bodies",
				template = `{bodyKey}_{key}`,
				part = part,
				offset = offset,
				tint = tint,
				key = key,
			})
		end
	end
	for _, itemId in items do
		for key, offset in (StylePieces[bodyKey] and StylePieces[bodyKey][itemId]) or {} do
			local split = string.split(key, "_")
			local part = split[1]
			if not opts.bust or part == "Head" then
				table.insert(pieces, {
					folder = "Style",
					template = `{bodyKey}__{itemId}__{key}`,
					part = part,
					offset = offset,
					tint = split[2],
					key = key,
					item = itemId,
				})
			end
		end
	end
	return pieces
end

-- Surnom affiché au-dessus de la tête (« Brad "The Wall" »)
-- Surnom affiché ; duelWins > 0 : le nombre de victoires en duel s'affiche à côté (D67)
function Look.Nickname(look: LookData, duelWins: number?): string
	local args = {
		first = Texts.Get(`Nick.First.{look.First}`),
		title = Texts.Get(`Nick.Title.{look.Title}`),
		wins = duelWins,
	}
	return Texts.Get(if duelWins and duelWins > 0 then "Nick.FormatWins" else "Nick.Format", args)
end

-- Apparence au hasard (bouton « Aléatoire » du menu ; les teintes fantaisie sont plus rares)
function Look.Random(rng: Random): LookData
	local function pick(list: { any }): any
		local natural = {}
		for _, swatch in list do
			if not swatch.fantasy then
				table.insert(natural, swatch)
			end
		end
		local pool = if rng:NextNumber() < 0.15 or #natural == 0 then list else natural
		return pool[rng:NextInteger(1, #pool)].id
	end
	local function any(list: { string }): string
		return list[rng:NextInteger(1, #list)]
	end
	return {
		Created = false,
		Gender = any(LookConfig.Genders),
		Skin = pick(LookConfig.Skins),
		Hair = pick(LookConfig.HairColors),
		Eyes = pick(LookConfig.EyeColors),
		Top = pick(LookConfig.ClothesColors),
		Shorts = pick(LookConfig.ClothesColors),
		Expression = any(LookConfig.Expressions),
		First = any(LookConfig.NickFirst),
		Title = any(LookConfig.NickTitle),
	}
end

return Look
