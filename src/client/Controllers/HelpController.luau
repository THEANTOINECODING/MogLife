-- Badges au-dessus des habitants : « ! » si l'aide est disponible, cadenas si le stade est trop bas,
-- sablier avec le temps restant si le délai n'est pas écoulé. Le « ! » flotte et s'agite pour attirer l'œil (D84).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Helps = require(ReplicatedStorage.Shared.Config.Helps)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local HELPER_TAG = "Helper"

local stage = 1
local readyAt: { [string]: number } = {}
local badges: { [Model]: TextLabel } = {}
local billboards: { [Model]: BillboardGui } = {}
local baseOffsets: { [Model]: number } = {}

local HelpController = {}

-- Aide faisable tout de suite (stade atteint, délai écoulé) : l'habitant sautille pour attirer l'attention (D83)
function HelpController.IsAvailable(helpId: string): boolean
	local help = Helps[helpId]
	return help ~= nil and stage >= help.requiredStage and (readyAt[helpId] or 0) <= workspace:GetServerTimeNow()
end

local function addBadge(model: Instance)
	if not model:IsA("Model") or badges[model] then
		return
	end
	-- PNJ provisoire (R15) : au-dessus de la tête ; PNJ modélisé (une seule pièce) : au-dessus du corps
	local head = model:FindFirstChild("Head")
	local body = head or model.PrimaryPart or model:WaitForChild(model.Name, 10)
	if not body or not body:IsA("BasePart") then
		return
	end
	local offset = if head then 3.2 else body.Size.Y / 2 + 1.6
	local billboard = Ui.create("BillboardGui", {
		Name = "HelpBadge",
		Size = UDim2.fromOffset(90, 50),
		StudsOffset = Vector3.new(0, offset, 0),
		AlwaysOnTop = true,
		MaxDistance = 80,
		Adornee = body,
		Parent = model,
	})
	badges[model] = Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.fromRGB(255, 220, 60),
		Parent = billboard,
	})
	billboards[model] = billboard
	baseOffsets[model] = offset
end

-- Le « ! » d'une aide disponible flotte, puis grossit et s'agite toutes les deux secondes
local function animateBadges()
	local now = os.clock()
	local available = Texts.Get("Help.Available")
	for model, label in badges do
		local billboard = billboards[model]
		if not billboard then
			continue
		end
		if label.Text == available then
			local beat = now % 2
			local wiggle = if beat < 0.4 then math.sin(beat / 0.4 * math.pi * 3) * 14 else 0
			label.Rotation = wiggle
			local grow = if beat < 0.4 then 1 + 0.25 * math.sin(beat / 0.4 * math.pi) else 1
			billboard.Size = UDim2.fromOffset(90 * grow, 50 * grow)
			billboard.StudsOffset = Vector3.new(0, baseOffsets[model] + 0.25 * math.sin(now * 3), 0)
		else
			label.Rotation = 0
			billboard.Size = UDim2.fromOffset(90, 50)
			billboard.StudsOffset = Vector3.new(0, baseOffsets[model], 0)
		end
	end
end

local function refresh()
	local now = workspace:GetServerTimeNow()
	for model, label in badges do
		if not model.Parent then
			badges[model] = nil
			billboards[model] = nil
			baseOffsets[model] = nil
			continue
		end
		local helpId = model:GetAttribute("HelpId")
		local help = if typeof(helpId) == "string" then Helps[helpId] else nil
		if not help then
			continue
		end
		local remaining = (readyAt[helpId] or 0) - now
		if stage < help.requiredStage then
			label.Text = Texts.Get("Help.LockedBadge")
		elseif remaining > 0 then
			label.Text = Texts.Get("Help.CooldownBadge", { seconds = math.ceil(remaining) })
		else
			label.Text = Texts.Get("Help.Available")
		end
	end
end

function HelpController.Start()
	game:GetService("RunService").RenderStepped:Connect(animateBadges)
	for _, model in CollectionService:GetTagged(HELPER_TAG) do
		task.spawn(addBadge, model)
	end
	CollectionService:GetInstanceAddedSignal(HELPER_TAG):Connect(function(model)
		task.spawn(addBadge, model)
	end)

	Remotes.StatsChanged.OnClientEvent:Connect(function(stats)
		stage = stats.Stage
		refresh()
	end)
	Remotes.HelpState.OnClientEvent:Connect(function(state)
		readyAt = state
		refresh()
	end)

	task.spawn(function()
		while true do
			refresh()
			task.wait(0.5)
		end
	end)
end

return HelpController
