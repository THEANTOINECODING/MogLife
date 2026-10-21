-- Sièges automatiques (Config/Seating.luau) : sur chaque banc, canapé ou fauteuil du décor (et sur les meubles
-- posés chez soi), des Seat invisibles posés sur l'assise. Un joueur qui monte dessus s'assoit tout seul (il se
-- relève en sautant). La hauteur et la profondeur de l'assise sont mesurées sur le modèle par lancers de rayons.
-- Jamais pendant une activité, un combat ou un duel (ni juste après) : le joueur serait bloqué sur place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Seating = require(ReplicatedStorage.Shared.Config.Seating)

local SEAT_NAME = "AutoSeat"

local SeatService = {}

local BossService
local DuelService
-- Dernier moment où le joueur était occupé (fin d'une série, d'une manche, d'un duel)
local lastBusy: { [Player]: number } = {}

local function isBusy(player: Player): boolean
	return player:GetAttribute("InRun") == true
		or player:GetAttribute("InDuel") == true
		or BossService.IsFighting(player)
		or DuelService.IsDueling(player)
		or os.clock() - (lastBusy[player] or -math.huge) < Seating.BusyGrace
end

-- Un siège automatique attrape le joueur pendant (ou juste après) une activité : on le relève aussitôt
local function watchPlayer(player: Player)
	local function markBusy()
		lastBusy[player] = os.clock()
	end
	player:GetAttributeChangedSignal("InRun"):Connect(markBusy)
	player:GetAttributeChangedSignal("InDuel"):Connect(markBusy)
	local function watchCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		humanoid.Seated:Connect(function(active, seat)
			if active and seat and seat.Name == SEAT_NAME and isBusy(player) then
				task.defer(SeatService.StandUp, player)
			end
		end)
	end
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

function SeatService.Init(services)
	BossService = services.BossService
	DuelService = services.DuelService
end

local function configFor(part: Instance): any
	if not part:IsA("BasePart") then
		return nil
	end
	local name = string.gsub(part.Name, "^Furniture_", "")
	return Seating.Props[name]
end

-- Assise : la surface la plus basse de la moitié avant (le dossier est derrière), mesurée au milieu du meuble
local function measureSeat(part: BasePart): (number?, number?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { part }
	local cf, size = part.CFrame, part.Size
	local hits = {}
	for i = 0, 6 do
		local lz = -size.Z / 2 + size.Z * (0.08 + i * 0.07) -- de l'avant vers le milieu
		for _, lx in { -size.X * 0.2, 0, size.X * 0.2 } do
			local origin = cf:PointToWorldSpace(Vector3.new(lx, size.Y, lz))
			local hit = workspace:Raycast(origin, cf.UpVector * -size.Y * 2, params)
			if hit then
				table.insert(hits, { y = cf:PointToObjectSpace(hit.Position).Y, z = lz })
			end
		end
	end
	if #hits == 0 then
		return nil, nil
	end
	local lowest = math.huge
	for _, hit in hits do
		lowest = math.min(lowest, hit.y)
	end
	-- Profondeur : le milieu des points de l'assise (à moins de 0,3 stud de la plus basse)
	local zs = {}
	for _, hit in hits do
		if hit.y - lowest < 0.3 then
			table.insert(zs, hit.z)
		end
	end
	local sum = 0
	for _, z in zs do
		sum += z
	end
	return lowest, sum / #zs
end

local function addSeats(part: Instance)
	local config = configFor(part)
	if not config or part:FindFirstChild(SEAT_NAME) then
		return
	end
	local prop = part :: BasePart
	-- Le meuble doit être posé (les modèles rangés dans ServerStorage ne sont pas dans le monde)
	if not prop:IsDescendantOf(workspace) then
		return
	end
	local seatY, seatZ = measureSeat(prop)
	if not seatY or not seatZ then
		return
	end
	local count = config.seats
	local spacing = prop.Size.X * 0.7 / math.max(count, 1)
	for index = 1, count do
		local lx = (index - (count + 1) / 2) * spacing
		local seat = Instance.new("Seat")
		seat.Name = SEAT_NAME
		seat.Size = Seating.SeatSize
		seat.Transparency = 1
		seat.CanCollide = false
		seat.CanQuery = false
		seat.Anchored = true
		-- Même orientation que le meuble : on s'assoit face à l'avant (-Z)
		seat.CFrame = prop.CFrame * CFrame.new(lx, seatY + Seating.SeatSize.Y / 2, seatZ)
		seat.Parent = prop
	end
end

function SeatService.Start()
	for _, part in workspace:GetDescendants() do
		addSeats(part)
	end
	-- Meubles posés plus tard (maisons des joueurs, décors installés après le démarrage)
	workspace.DescendantAdded:Connect(function(part)
		if configFor(part) then
			task.defer(addSeats, part)
		end
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		lastBusy[player] = nil
	end)
end

-- Relève un joueur assis (avant une activité ou un combat : sinon il resterait collé au siège)
function SeatService.StandUp(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		(humanoid :: Humanoid).Sit = false
	end
end

return SeatService
