-- Badges au-dessus des habitants : « ! » si l'aide est disponible, cadenas si le stade est trop bas,
-- sablier avec le temps restant si le délai n'est pas écoulé. Le « ! » flotte et s'agite pour attirer l'œil (D84).
-- Habitants qui réagissent (D112) : quand on passe près d'un habitant, il commente le look (selon le palier de Drip)
-- et rappelle son « dress code » (bonus de Cash si on le respecte). Purement visuel : le bonus est décidé par le
-- serveur à la fin de l'aide (HelpService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Drip = require(ReplicatedStorage.Shared.Drip)
local Helps = require(ReplicatedStorage.Shared.Config.Helps)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local HELPER_TAG = "Helper"
local DRIP = Balance.Drip
local LINES_PER_TIER = 3

local player = Players.LocalPlayer
local MinigameController
local equipped: { [string]: string } = {}
local lastCompliment: { [Model]: number } = {}
local bubbles: { [Model]: BillboardGui } = {}

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

-- Bulle au-dessus de l'habitant : un compliment sur le look, puis son dress code
local function say(model: Model, body: BasePart, offset: number, helpId: string)
	local old = bubbles[model]
	if old then
		old:Destroy()
	end
	local help = Helps[helpId]
	local tier = Drip.Tier(equipped)
	local line = Texts.Get(`Compliment.T{tier}.{math.random(1, LINES_PER_TIER)}`)
	local text = line
	if help.dressCode then
		local code = Texts.Get(`DressCode.{help.dressCode}`)
		local percent = math.floor(DRIP.DressCodeBonus * 100 + 0.5)
		text = Texts.Get(
			if Drip.MeetsDressCode(help.dressCode, equipped) then "DressCode.Met" else "DressCode.Ask",
			{ line = line, code = code, percent = percent }
		)
	end
	local bubble = Ui.create("BillboardGui", {
		Name = "Compliment",
		Size = UDim2.fromOffset(230, 70),
		StudsOffset = Vector3.new(0, offset + 2.4, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 60,
		Adornee = body,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = bubble,
	}, {
		Ui.corner(UDim.new(0.3, 0)),
		Ui.stroke(Color3.fromRGB(30, 30, 30), 2, 0),
		Ui.label({
			Position = UDim2.fromScale(0.05, 0.08),
			Size = UDim2.fromScale(0.9, 0.84),
			TextColor3 = Color3.fromRGB(30, 30, 30),
			TextStrokeTransparency = 1,
			TextWrapped = true,
			Text = text,
		}),
	})
	bubbles[model] = bubble
	task.delay(4, function()
		if bubbles[model] == bubble then
			bubbles[model] = nil
		end
		bubble:Destroy()
	end)
end

local function checkCompliments()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (MinigameController and MinigameController.IsGameplayLocked()) then
		return
	end
	local now = os.clock()
	for model, billboard in billboards do
		local body = billboard.Adornee :: BasePart?
		local helpId = model:GetAttribute("HelpId")
		if not body or typeof(helpId) ~= "string" or not Helps[helpId] then
			continue
		end
		if (body.Position - root.Position).Magnitude > DRIP.ComplimentDistance then
			continue
		end
		if now - (lastCompliment[model] or -math.huge) >= DRIP.ComplimentCooldown then
			lastCompliment[model] = now
			say(model, body, baseOffsets[model] or 3, helpId)
		end
	end
end

function HelpController.Init(controllers)
	MinigameController = controllers.MinigameController
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
	Remotes.StyleState.OnClientEvent:Connect(function(state)
		if typeof(state) == "table" and typeof(state.equipped) == "table" then
			equipped = state.equipped
		end
	end)

	task.spawn(function()
		while true do
			refresh()
			checkCompliments()
			task.wait(0.5)
		end
	end)
end

return HelpController
