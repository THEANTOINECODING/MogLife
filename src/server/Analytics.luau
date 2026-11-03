-- Envoi des mesures aux tableaux de bord Roblox (AnalyticsService). Jamais bloquant : une erreur de l'API est
-- ignorée (le jeu continue). Dans Studio, Roblox n'envoie rien vers le tableau de bord publié.
-- Analytics.Step(player, data, "FirstRep")  : étape du funnel des premières minutes (une seule fois par joueur)
-- Analytics.Event(player, "BossWon", value, "Kevin") : événement libre (valeur et un identifiant facultatifs)

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Analytics)

local stepOf: { [string]: number } = {}
for _, entry in Config.Funnel do
	stepOf[entry.name] = entry.step
end

local Analytics = {}

function Analytics.Step(player: Player, data: any, name: string)
	local step = stepOf[name]
	if not step or not data or data.Funnel[name] then
		return
	end
	data.Funnel[name] = true
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function Analytics.Event(player: Player, name: string, value: number?, id: string?)
	pcall(function()
		local fields = if id then { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = id } else nil
		AnalyticsService:LogCustomEvent(player, name, value or 1, fields)
	end)
end

return Analytics
