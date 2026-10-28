-- Communication client <-> serveur. Le serveur crée les remotes, le client les attend.
-- Pour en ajouter un : ajouter son nom dans NAMES et son type en bas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"StatsChanged", -- serveur -> client : (stats: { Mog, Cash, Stage })
	"RequestStats", -- client -> serveur : redemande l'envoi des stats
	"SetSprint", -- client -> serveur : (pressed: boolean, locked: boolean) sprint et verrouillage des fenêtres
	"StartSeries", -- client -> serveur : (exerciseId: string) — relancer une série (« Keep going »)
	"Rep", -- client -> serveur : (quality: "Miss" | "Good" | "Perfect")
	"StopSeries", -- client -> serveur : arrêter la série en cours
	"SeriesUpdate", -- serveur -> client : (update: { state: "Started" | "Rep" | "Ended", kind, ... })
	"Notify", -- serveur -> client : ({ key: string, args: { [string]: any }? }) message court (toast)
	"BossPrompt", -- serveur -> client : infos avant un défi (prêt ou non, perte annoncée)
	"ChallengeBoss", -- client -> serveur : (bossId: string) confirmation du défi
	"BossUpdate", -- serveur -> client : ({ state: "Mogged" | "RoundResult" | "Victory" | "Defeat" | "Aborted", ... })
	"HelpState", -- serveur -> client : ({ [helpId]: readyAt }) heure serveur où chaque aide redevient disponible
	"BuyStyle", -- client -> serveur : (itemId: string)
	"EquipStyle", -- client -> serveur : (category: string, itemId: string?) nil = retirer
	"BuyStyleSet", -- client -> serveur : (setId: string), achète haut + bas en une transaction
	"EquipStyleSet", -- client -> serveur : (setId: string), équipe haut + bas possédés
	"StyleState", -- serveur -> client : ({ owned: { [itemId]: true }, equipped: { [category]: itemId } })
	"BuyFurniture", -- client -> serveur : (itemId: string) au comptoir du magasin de meubles
	"PlaceFurniture", -- client -> serveur : (slot: string, itemId: string?) nil = vider l'emplacement
	"FurnitureState", -- serveur -> client : ({ owned: { [itemId]: true }, placed: { [slot]: itemId } })
	"GoHome", -- client -> serveur : retour à sa maison
	"TakeBus", -- client -> serveur : (stopId: string) depuis un arrêt de bus, vers un autre arrêt
	-- serveur -> tous les clients : ({ player, state: "Started" | "Rep" | "OpponentRep" | "Ended", kind, id, anchor,
	-- interval, quality }) pour que chacun voie l'activité se réaliser vraiment (D37) ; OpponentRep = le boss joue
	"Activity",
	"BodyTransform", -- serveur -> tous les clients : (player, stageId) un joueur change de corps (nouveau stade)
	"Tutorial", -- serveur -> client : ({ step, total, done }) étape du tutoriel
	"TutorialAction", -- client -> serveur : ("Skip") passer le tutoriel
	"MentorSay", -- serveur -> client : ({ key, args }) le mentor parle (tutoriel, conseils)
	"BuyBoost", -- client -> serveur : (boostId: string) au camion à shakes ou au distributeur
	"BoostState", -- serveur -> client : ({ id: string?, endsAt: number }) boost en cours (heure serveur)
	"Records", -- serveur -> client : ({ [exerciseId]: score }) meilleures notes de série
	"Cutscene", -- serveur -> client : ({ kind: "Intro" | "Boss", bossId?, spot? }) jouer une cinématique
	"CutsceneDone", -- client -> serveur : (kind: string) cinématique finie ou passée
	"OpenCreator", -- serveur -> client : ({ mode: "Create" | "Edit", look, hair: string }) ouvrir le menu de création
	"SetLook", -- client -> serveur : (look, hair: string) valider l'apparence choisie (le serveur vérifie tout)
	"Emote", -- client -> serveur : (index: number) prendre une pose de culturisme
	"EmotePlay", -- serveur -> tous : (player, index) ce joueur prend cette pose
	"CityEvent", -- serveur -> tous : ({ kind, state: "Started" | "Ended" | ..., endsAt? }) événement de ville
	"SetSetting", -- client -> serveur : (key: string, value: boolean) changer un réglage
	"SettingsState", -- serveur -> client : ({ [key]: boolean }) réglages sauvegardés
	"DuelInvite", -- client -> serveur : (target: Player) inviter un joueur proche à un bras de fer
	"DuelAnswer", -- client -> serveur : (accept: boolean) réponse à l'invitation reçue
	-- serveur -> client : ({ state: "Invited" | "InviteSent" | "Started" | "RoundStart" | "Live" | "RoundResult" |
	-- "Result" | "Finished", ... }) invitation reçue, puis déroulement du duel
	"DuelUpdate",
	"WeeklyState", -- serveur -> client : (état des défis, du coffre et des trophées de la semaine)
	"WeeklyClaim", -- client -> serveur : (what: "Challenge" | "Bonus" | "Chest", index: number?) réclamer
	"ColosseumTravel", -- serveur -> clients : ({ player, from: Vector3 }) un joueur monte dans un pilier de lumière
	"PumpGodUpdate", -- serveur -> clients : combat du Dieu du Pump ({ state: "Start" | "Attack" | "Hit" | "Roll" | "End", player, ... })
	"PumpGodRoll", -- client -> serveur : roulade pendant le combat du Dieu du Pump
}

local isServer = RunService:IsServer()
local folder: Folder

if isServer then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		folder = created
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local remotes = {}
for _, name in NAMES do
	remotes[name] = if isServer then folder:FindFirstChild(name) else folder:WaitForChild(name)
end

return remotes :: {
	StatsChanged: RemoteEvent,
	RequestStats: RemoteEvent,
	SetSprint: RemoteEvent,
	StartSeries: RemoteEvent,
	Rep: RemoteEvent,
	StopSeries: RemoteEvent,
	SeriesUpdate: RemoteEvent,
	Notify: RemoteEvent,
	BossPrompt: RemoteEvent,
	ChallengeBoss: RemoteEvent,
	BossUpdate: RemoteEvent,
	HelpState: RemoteEvent,
	BuyStyle: RemoteEvent,
	EquipStyle: RemoteEvent,
	BuyStyleSet: RemoteEvent,
	EquipStyleSet: RemoteEvent,
	StyleState: RemoteEvent,
	BuyFurniture: RemoteEvent,
	PlaceFurniture: RemoteEvent,
	FurnitureState: RemoteEvent,
	GoHome: RemoteEvent,
	TakeBus: RemoteEvent,
	Activity: RemoteEvent,
	BodyTransform: RemoteEvent,
	Tutorial: RemoteEvent,
	TutorialAction: RemoteEvent,
	MentorSay: RemoteEvent,
	BuyBoost: RemoteEvent,
	BoostState: RemoteEvent,
	Records: RemoteEvent,
	Cutscene: RemoteEvent,
	CutsceneDone: RemoteEvent,
	OpenCreator: RemoteEvent,
	SetLook: RemoteEvent,
	Emote: RemoteEvent,
	EmotePlay: RemoteEvent,
	CityEvent: RemoteEvent,
	SetSetting: RemoteEvent,
	SettingsState: RemoteEvent,
	DuelInvite: RemoteEvent,
	DuelAnswer: RemoteEvent,
	DuelUpdate: RemoteEvent,
	WeeklyState: RemoteEvent,
	WeeklyClaim: RemoteEvent,
	ColosseumTravel: RemoteEvent,
	PumpGodUpdate: RemoteEvent,
	PumpGodRoll: RemoteEvent,
}
