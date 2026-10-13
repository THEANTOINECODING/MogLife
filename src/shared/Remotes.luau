-- Communication client <-> serveur. Le serveur crée les remotes, le client les attend.
-- Pour en ajouter un : ajouter son nom dans NAMES et son type en bas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Train", -- client -> serveur : (exerciseId: string)
	"StatsChanged", -- serveur -> client : (stats: { Strength, Cash, Mog, Rank })
	"RequestStats", -- client -> serveur : redemande l'envoi des stats
}

local isServer = RunService:IsServer()
local folder: Folder

if isServer then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
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
	Train: RemoteEvent,
	StatsChanged: RemoteEvent,
	RequestStats: RemoteEvent,
}
