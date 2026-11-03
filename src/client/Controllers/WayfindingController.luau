-- Repères pour s'orienter :
-- - une grande icône flottante au-dessus de chaque bâtiment (tag "Landmark" + attribut Icon), visible de loin ;
-- - la même icône 🏠 au-dessus de sa propre maison (tag "HomeIcon"), seulement chez son propriétaire ;
-- - quand le joueur a assez de Mog pour son prochain boss, un repère discret indique sa position proche
--   (pour Kevin : celui du garage de sa propre maison).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local LANDMARK_TAG = "Landmark"
local HOME_ICON_TAG = "HomeIcon"
local BOSS_SPOT_TAG = "BossSpot"
local PLOT_TAG = "Plot"
local GUIDE_COLOR = Color3.fromRGB(255, 210, 60)
local LANDMARK_STROKE = Color3.fromRGB(255, 220, 120)
local HOME_STROKE = Color3.fromRGB(120, 235, 140) -- vert : « chez moi », à part des magasins

local player = Players.LocalPlayer

local targetBossId: string? = nil
local endAttachment: Attachment
local marker: BillboardGui

local WayfindingController = {}

-- Grande icône ronde flottante au-dessus d'un point invisible
local function makeIcon(part: BasePart, name: string, icon: string, stroke: Color3): BillboardGui
	local billboard = Ui.create("BillboardGui", {
		Name = name,
		Size = UDim2.fromScale(9, 9),
		LightInfluence = 0,
		MaxDistance = 600,
		Adornee = part,
		Parent = part,
	})
	Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(30, 25, 45),
		BackgroundTransparency = 0.2,
		Parent = billboard,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(stroke, 3, 0) })
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		Text = Texts.Get(`Icon.{icon}`),
		Parent = billboard,
	})
	return billboard
end

local function addLandmark(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("LandmarkIcon") then
		return
	end
	local icon = part:GetAttribute("Icon")
	if typeof(icon) ~= "string" then
		return
	end
	makeIcon(part, "LandmarkIcon", icon, LANDMARK_STROKE)
end

-- La maison (tag Plot) qui contient cet objet, s'il y en a une
local function plotOf(instance: Instance): Instance?
	local current = instance.Parent
	while current and current ~= workspace do
		if CollectionService:HasTag(current, PLOT_TAG) then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Icône 🏠 d'une maison : visible seulement quand la maison est la nôtre (attribut OwnerUserId du serveur)
local function addHomeIcon(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("HomeIcon") then
		return
	end
	local plot = plotOf(part)
	if not plot then
		return
	end
	local billboard = makeIcon(part, "HomeIcon", "Home", HOME_STROKE)
	local function refresh()
		billboard.Enabled = plot:GetAttribute("OwnerUserId") == player.UserId
	end
	refresh()
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
end

-- Emplacement du boss à suivre : celui de sa propre maison si le boss vit dans les maisons, sinon le plus proche
local function findTarget(bossId: string, from: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, spot in CollectionService:GetTagged(BOSS_SPOT_TAG) do
		if not spot:IsA("BasePart") or spot:GetAttribute("BossId") ~= bossId then
			continue
		end
		local plot = plotOf(spot)
		if plot and plot:GetAttribute("OwnerUserId") == player.UserId then
			return spot
		end
		local distance = (spot.Position - from).Magnitude
		if not plot and distance < bestDistance then
			best, bestDistance = spot, distance
		end
	end
	return best
end

local function buildGuide()
	endAttachment = Instance.new("Attachment")
	endAttachment.Name = "BossGuideTarget"
	endAttachment.Parent = workspace.Terrain

	marker = Ui.create("BillboardGui", {
		Name = "BossGuideMarker",
		Size = UDim2.fromOffset(54, 54),
		StudsOffsetWorldSpace = Vector3.new(0, 7, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 140,
		Enabled = false,
		Adornee = endAttachment,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextColor3 = GUIDE_COLOR,
		Text = Texts.Get("Guide.Marker"),
		Parent = marker,
	})
end

local function update()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = if targetBossId and root then findTarget(targetBossId, root.Position) else nil
	local visible = target ~= nil
	if target then
		endAttachment.WorldPosition = target.Position + Vector3.new(0, 1, 0)
	end
	marker.Enabled = visible
end

function WayfindingController.Start()
	for _, part in CollectionService:GetTagged(LANDMARK_TAG) do
		addLandmark(part)
	end
	CollectionService:GetInstanceAddedSignal(LANDMARK_TAG):Connect(addLandmark)
	for _, part in CollectionService:GetTagged(HOME_ICON_TAG) do
		addHomeIcon(part)
	end
	CollectionService:GetInstanceAddedSignal(HOME_ICON_TAG):Connect(addHomeIcon)

	buildGuide()

	Remotes.StatsChanged.OnClientEvent:Connect(function(stats)
		local stage = Stages.List[stats.Stage]
		local boss = stage and stage.boss
		targetBossId = if boss and not boss.comingSoon and stats.Mog >= boss.mogRequired then boss.id else nil
		update()
	end)
	task.spawn(function()
		while true do
			update()
			task.wait(0.5)
		end
	end)
end

return WayfindingController
