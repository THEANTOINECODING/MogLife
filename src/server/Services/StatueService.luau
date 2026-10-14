-- Statues des 3 plus gros moggers du serveur, sur les socles de la place (tag "MogStatue" + attribut Rank).
-- Chaque statue reprend l'avatar Roblox du joueur, en pose de double biceps, avec son nom et son Mog.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Format = require(ReplicatedStorage.Shared.Format)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)

local PEDESTAL_TAG = "MogStatue"
local STATUES = Balance.Statues

local DataService

local shown: { [number]: number? } = {} -- rang -> UserId de la statue affichée
local descriptions: { [number]: HumanoidDescription } = {}

local StatueService = {}

local function pedestals(): { [number]: BasePart }
	local byRank = {}
	for _, part in CollectionService:GetTagged(PEDESTAL_TAG) do
		local rank = part:GetAttribute("Rank")
		if part:IsA("BasePart") and typeof(rank) == "number" then
			byRank[rank] = part
		end
	end
	return byRank
end

local function setLabel(pedestal: BasePart, text: string)
	local billboard = pedestal:FindFirstChild("StatueLabel") :: BillboardGui?
	if not billboard then
		local created = Instance.new("BillboardGui")
		created.Name = "StatueLabel"
		created.Size = UDim2.fromScale(8, 1.4)
		created.StudsOffsetWorldSpace = Vector3.new(0, pedestal.Size.Y / 2 + 1.4, -pedestal.Size.Z / 2 - 0.5)
		created.MaxDistance = 120
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 230, 140)
		label.TextStrokeTransparency = 0.2
		label.Parent = created
		created.Parent = pedestal
		billboard = created
	end
	((billboard :: BillboardGui):FindFirstChild("Text") :: TextLabel).Text = text
end

-- Pose de double biceps : bras à l'horizontale, avant-bras levés (angles vérifiés dans Studio).
-- Les avatars récents utilisent des AnimationConstraint : on tourne leur Attachment0, ce qui est répliqué.
local POSE = {
	RightShoulder = CFrame.Angles(math.rad(90), 0, 0),
	LeftShoulder = CFrame.Angles(math.rad(90), 0, 0),
	RightElbow = CFrame.Angles(math.rad(100), 0, 0),
	LeftElbow = CFrame.Angles(math.rad(100), 0, 0),
}

local function flex(model: Model)
	for _, joint in model:GetDescendants() do
		local pose = POSE[joint.Name]
		if not pose then
			continue
		end
		if joint:IsA("AnimationConstraint") and joint.Attachment0 then
			joint.Attachment0.CFrame *= pose
		elseif joint:IsA("Motor6D") then
			joint.C0 *= pose
		end
	end
end

local function clearStatue(pedestal: BasePart)
	local old = pedestal:FindFirstChild("Statue")
	if old then
		old:Destroy()
	end
end

local function buildStatue(pedestal: BasePart, rank: number, userId: number)
	local description = descriptions[userId]
	if not description then
		local ok, result = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
		if not ok then
			return
		end
		descriptions[userId] = result
		description = result
	end
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = "Statue"
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	-- Une statue ne bouge pas : pas d'animations
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		animator:Destroy()
	end
	model:ScaleTo(STATUES.Scale[rank] or 1)
	-- Posée sur le socle, tournée comme lui (vers la fontaine)
	local _, size = model:GetBoundingBox()
	local top = pedestal.Position.Y + pedestal.Size.Y / 2
	model:PivotTo(pedestal.CFrame.Rotation + Vector3.new(pedestal.Position.X, top + size.Y / 2, pedestal.Position.Z))
	clearStatue(pedestal)
	model.Parent = pedestal
	flex(model)
end

local function refresh()
	local ranking = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data then
			table.insert(ranking, { player = player, mog = data.Mog })
		end
	end
	table.sort(ranking, function(a, b)
		return a.mog > b.mog
	end)

	for rank, pedestal in pedestals() do
		local entry = ranking[rank]
		if not entry then
			shown[rank] = nil
			clearStatue(pedestal)
			setLabel(pedestal, Texts.Get("Statue.Empty"))
			continue
		end
		setLabel(
			pedestal,
			Texts.Get("Statue.Label", { name = entry.player.DisplayName, mog = Format.Short(entry.mog) })
		)
		if shown[rank] ~= entry.player.UserId then
			shown[rank] = entry.player.UserId
			task.spawn(buildStatue, pedestal, rank, entry.player.UserId)
		end
	end
end

function StatueService.Init(services)
	DataService = services.DataService
end

function StatueService.Start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(STATUES.RefreshSeconds)
		end
	end)
	-- Un joueur qui arrive peut directement prendre une place sur le podium
	DataService.PlayerLoaded:Connect(function()
		task.defer(refresh)
	end)
	Players.PlayerRemoving:Connect(function(player)
		descriptions[player.UserId] = nil
		task.defer(refresh)
	end)
end

return StatueService
