-- Communication client <-> serveur. Le serveur crée les remotes, le client les attend.
-- Pour en ajouter un : ajouter son nom dans NAMES et son type en bas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"StatsChanged", -- serveur -> client : (stats: { Mog, Cash, Stage })
	"RequestStats", -- client -> serveur : redemande l'envoi des stats
	"StartSeries", -- client -> serveur : (exerciseId: string) — relancer une série (« Keep going »)
	"Rep", -- client -> serveur : (quality: "Miss" | "Good" | "Perfect" | "Auto")
	"StopSeries", -- client -> serveur : arrêter la série en cours
	"SeriesUpdate", -- serveur -> client : (update: { state: "Started" | "Rep" | "Ended", kind, ... })
	"Notify", -- serveur -> client : ({ key: string, args: { [string]: any }? }) message court (toast)
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
	StartSeries: RemoteEvent,
	Rep: RemoteEvent,
	StopSeries: RemoteEvent,
	SeriesUpdate: RemoteEvent,
	Notify: RemoteEvent,
}
