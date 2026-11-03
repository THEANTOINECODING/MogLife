-- Maisons des joueurs : chaque joueur reçoit une maison de maman libre (tag "Plot") en arrivant,
-- apparaît chez lui, et son nom s'affiche sur le panneau devant la maison.
-- Le serveur accueille 20 joueurs max (réglage de la place sur Roblox) : une maison par joueur.
-- Si un serveur est plus grand que le nombre de maisons, les joueurs en trop attendent la prochaine maison libérée.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Texts = require(ReplicatedStorage.Shared.Config.Texts)

local PLOT_TAG = "Plot"
local SLOT_TAG = "FurnitureSlot"
local OWNER_ATTRIBUTE = "OwnerUserId"

local DataService

local owners: { [Player]: Model } = {}
local waiting: { Player } = {} -- joueurs chargés sans maison, par ordre d'arrivée
local assignedCallbacks: { (Player, Model) -> () } = {}
local releasedCallbacks: { (Player, Model) -> () } = {}

local PlotService = {}

local function sortedPlots(): { Model }
	local plots = {}
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plot:IsA("Model") and plot:IsDescendantOf(workspace) then
			table.insert(plots, plot)
		end
	end
	table.sort(plots, function(a, b)
		return (a:GetAttribute("PlotIndex") or 0) < (b:GetAttribute("PlotIndex") or 0)
	end)
	return plots
end

-- Texte du panneau devant la maison
local function setSign(plot: Model, player: Player?)
	local sign = plot:FindFirstChild("OwnerSign", true)
	if not sign or not sign:IsA("BasePart") then
		return
	end
	local gui = sign:FindFirstChild("OwnerGui") :: SurfaceGui?
	if not gui then
		local created = Instance.new("SurfaceGui")
		created.Name = "OwnerGui"
		created.Face = Enum.NormalId.Front
		created.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		created.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(0.9, 0.8)
		label.Position = UDim2.fromScale(0.05, 0.1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(60, 40, 30)
		label.Parent = created
		created.Parent = sign
		gui = created
	end
	local label = (gui :: SurfaceGui):FindFirstChild("Text") :: TextLabel
	label.Text = if player then Texts.Get("Plot.Owner", { name = player.DisplayName }) else Texts.Get("Plot.Free")
end

local function spawnCFrame(plot: Model): CFrame?
	local spawn = plot:FindFirstChild("Spawn")
	if not spawn or not spawn:IsA("BasePart") then
		return nil
	end
	-- Le trottoir laisse la caméra derrière le personnage sans traverser le mur de la maison.
	-- Le repère du point d'apparition regarde la rue : on fait face à la maison.
	return spawn.CFrame * CFrame.new(0, 0, -8) * CFrame.Angles(0, math.pi, 0) + Vector3.new(0, 2, 0)
end

local function sendHome(player: Player, character: Model)
	local plot = owners[player]
	local target = plot and spawnCFrame(plot)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not target or not root or player.Character ~= character then
		return
	end
	task.wait() -- laisse Roblox finir de placer le personnage avant de le déplacer
	character:PivotTo(target)
end

local function assign(player: Player)
	if owners[player] or player.Parent ~= Players then
		return
	end
	for _, plot in sortedPlots() do
		if plot:GetAttribute(OWNER_ATTRIBUTE) == nil then
			plot:SetAttribute(OWNER_ATTRIBUTE, player.UserId)
			owners[player] = plot
			setSign(plot, player)
			for _, callback in assignedCallbacks do
				task.spawn(callback, player, plot)
			end
			if player.Character then
				task.spawn(sendHome, player, player.Character)
			end
			return
		end
	end
	if not table.find(waiting, player) then
		table.insert(waiting, player)
	end
	warn(`[PlotService] No free house for {player.Name}`)
end

local function release(player: Player)
	local index = table.find(waiting, player)
	if index then
		table.remove(waiting, index)
	end
	local plot = owners[player]
	if not plot then
		return
	end
	owners[player] = nil
	for _, callback in releasedCallbacks do
		task.spawn(callback, player, plot)
	end
	plot:SetAttribute(OWNER_ATTRIBUTE, nil)
	setSign(plot, nil)
	local heir = table.remove(waiting, 1)
	if heir then
		assign(heir)
	end
end

-- Maison du joueur (nil s'il n'en a pas)
-- Endroit où le joueur apparaît chez lui (devant sa maison), nil s'il n'a pas de maison
function PlotService.GetHomeCFrame(player: Player): CFrame?
	local plot = owners[player]
	return plot and spawnCFrame(plot)
end

function PlotService.GetPlot(player: Player): Model?
	return owners[player]
end

-- Emplacements de meubles d'une maison, par nom d'emplacement
function PlotService.GetSlots(plot: Model): { [string]: BasePart }
	local slots = {}
	for _, part in plot:GetDescendants() do
		if part:IsA("BasePart") and CollectionService:HasTag(part, SLOT_TAG) then
			local slot = part:GetAttribute("Slot")
			if typeof(slot) == "string" then
				slots[slot] = part
			end
		end
	end
	return slots
end

-- Appelé quand un joueur reçoit sa maison / la libère en partant
function PlotService.OnAssigned(callback: (Player, Model) -> ())
	table.insert(assignedCallbacks, callback)
end

function PlotService.OnReleased(callback: (Player, Model) -> ())
	table.insert(releasedCallbacks, callback)
end

function PlotService.Init(services)
	DataService = services.DataService
end

function PlotService.Start()
	for _, plot in sortedPlots() do
		setSign(plot, nil)
	end
	-- La maison est attribuée une fois les données chargées (les meubles en dépendent)
	DataService.PlayerLoaded:Connect(assign)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			sendHome(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			sendHome(player, character)
		end)
	end
	Players.PlayerRemoving:Connect(release)
end

return PlotService
