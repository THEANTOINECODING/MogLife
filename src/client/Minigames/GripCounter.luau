-- Bras de fer : prise annoncée, résistance, contre au moment doré. Un geste maintenu par échange.
-- Les deux joueurs reçoivent la même graine ; le même motif et les mêmes seuils s'appliquent partout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Duels = require(ReplicatedStorage.Shared.Config.Duels)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local GripCounter = {}
local GOLD = Color3.fromRGB(255, 215, 70)
local GREEN = Color3.fromRGB(105, 220, 125)
local DARK = Color3.fromRGB(51, 39, 73)
local ARROWS = { "◀", "●", "▶" }

local function laneFromX(panel: GuiObject, x: number): number
	local width = panel.AbsoluteSize.X
	if width <= 0 then
		return 2
	end
	return math.clamp(math.floor((x - panel.AbsolutePosition.X) / width * 3) + 1, 1, 3)
end

local function keyLane(key: Enum.KeyCode): number?
	if key == Enum.KeyCode.Left or key == Enum.KeyCode.A or key == Enum.KeyCode.Q or key == Enum.KeyCode.DPadLeft then
		return 1
	elseif key == Enum.KeyCode.Up or key == Enum.KeyCode.W or key == Enum.KeyCode.Z or key == Enum.KeyCode.DPadUp then
		return 2
	elseif key == Enum.KeyCode.Right or key == Enum.KeyCode.D or key == Enum.KeyCode.DPadRight then
		return 3
	end
	return nil
end

function GripCounter.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(420, 340))
	panel.Name = "GripCounter"
	local rng = Random.new((options and options.seed) or math.floor(os.clock() * 1000))
	local settings = Duels.GripCounter
	local lead = interval * Duels.Lead
	Ui.label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 28),
		Text = Texts.Get("Minigame.Title.GripCounter"),
		TextColor3 = GOLD,
		Parent = panel,
	})
	local hint = Ui.label({
		Position = UDim2.fromOffset(14, 38),
		Size = UDim2.new(1, -28, 0, 28),
		Text = "",
		TextWrapped = true,
		TextStrokeTransparency = 1,
		Parent = panel,
	})
	local leftArm = Ui.create("Frame", {
		Position = UDim2.fromScale(0.13, 0.34),
		Size = UDim2.fromScale(0.28, 0.09),
		Rotation = -18,
		BackgroundColor3 = GREEN,
		BackgroundTransparency = 0.25,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })
	local rightArm = Ui.create("Frame", {
		Position = UDim2.fromScale(0.59, 0.34),
		Size = UDim2.fromScale(0.28, 0.09),
		Rotation = 18,
		BackgroundColor3 = Color3.fromRGB(245, 105, 105),
		BackgroundTransparency = 0.25,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })

	local opponent = self:Emoji(panel, "✊", 84, 3)
	opponent.Position = UDim2.fromScale(0.5, 0.37)
	local cue = self:Emoji(panel, "●", 65, 4)
	cue.Position = UDim2.fromScale(0.5, 0.53)
	cue.TextColor3 = GOLD
	local bar = Ui.create("Frame", {
		Position = UDim2.fromScale(0.09, 0.67),
		Size = UDim2.fromScale(0.82, 0.07),
		BackgroundColor3 = DARK,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(GOLD, 2, 0.55) })
	local goodZone = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(settings.GoodHalf * 2 * self.timingScale, 0, 1, 8),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0.5,
		Parent = bar,
	}, { Ui.corner(UDim.new(1, 0)) })
	local marker = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.04, 1.7),
		BackgroundColor3 = GOLD,
		ZIndex = 4,
		Parent = bar,
	}, { Ui.corner(UDim.new(1, 0)) })
	local fill = Ui.create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = GREEN,
		ZIndex = 3,
		Parent = bar,
	}, { Ui.corner(UDim.new(1, 0)) })
	local function updateControls(inputType: Enum.UserInputType)
		local platform = if inputType == Enum.UserInputType.Touch
			then "Touch"
			elseif string.find(inputType.Name, "Gamepad") then "Gamepad"
			else "Keyboard"
		hint.Text = Texts.Get(`Minigame.Control.Grip.{platform}`)
	end
	updateControls(UserInputService:GetLastInputType())
	self:Connect(UserInputService.LastInputTypeChanged, updateControls)
	local gripTiles = {}
	for index = 1, 3 do
		local tile = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale((index - 0.5) / 3, 0.98),
			Size = UDim2.fromScale(0.29, 0.19),
			BackgroundColor3 = DARK,
			Parent = panel,
		}, { Ui.corner(UDim.new(0, 10)) })
		local label = self:Emoji(tile, ARROWS[index], 44, 4)
		label.Position = UDim2.fromScale(0.5, 0.5)
		gripTiles[index] = tile
	end
	local surface = Ui.create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Selectable = false,
		ZIndex = 10,
		Parent = panel,
	})

	local cycle = -1
	local wanted = 2
	local chosen = 0
	local moment = 0.65
	local held: InputObject? = nil
	local heldKey: Enum.KeyCode? = nil
	local resolved = false
	local quality = "Miss"

	local function start(index: number)
		if resolved or chosen ~= 0 or self.auto then
			return
		end
		chosen = index
		gripTiles[index].BackgroundColor3 = if index == wanted then GREEN else Color3.fromRGB(170, 85, 85)
		SoundController.Play("SceneTouch", 0.9)
	end

	local function finish(t: number)
		if chosen == 0 or resolved or self.auto then
			return
		end
		resolved = true
		local phase = (t - lead) / interval - cycle
		quality = if chosen == wanted
			then self:GradeError(math.abs(phase - moment), settings.PerfectHalf, settings.GoodHalf)
			else "Miss"
		cue.TextColor3 = if quality == "Miss" then Color3.fromRGB(255, 100, 100) else GREEN
		if quality ~= "Miss" then
			SoundController.Play("SceneImpact", if quality == "Perfect" then 1.15 else 0.95)
		end
		self:Rep(quality)
	end

	self:Connect(surface.InputBegan, function(input)
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseButton1
		then
			return
		end
		local t = os.clock() - self.startTime
		if t < lead then
			return
		end
		held = input
		start(laneFromX(panel, input.Position.X))
	end)
	self:Connect(UserInputService.InputEnded, function(input)
		if
			held
			and (
				input == held
				or (
					held.UserInputType == Enum.UserInputType.MouseButton1
					and input.UserInputType == Enum.UserInputType.MouseButton1
				)
			)
		then
			finish(os.clock() - self.startTime)
			held = nil
		end
		if heldKey == input.KeyCode then
			finish(os.clock() - self.startTime)
			heldKey = nil
		end
	end)
	self:Connect(UserInputService.InputBegan, function(input)
		if UserInputService:GetFocusedTextBox() or os.clock() - self.startTime < lead then
			return
		end
		local index = keyLane(input.KeyCode)
		if index then
			heldKey = input.KeyCode
			start(index)
		end
	end)

	self:OnStep(function(_, t)
		if t < lead then
			return
		end
		local index = math.floor((t - lead) / interval)
		if index > cycle then
			if cycle >= 0 and not resolved then
				self:Rep("Miss")
			end
			cycle = index
			wanted = rng:NextInteger(1, 3)
			moment = rng:NextNumber(settings.MomentMin, settings.MomentMax)
			chosen = 0
			resolved = false
			quality = "Miss"
			held = nil
			heldKey = nil
			cue.Text = ARROWS[wanted]
			cue.TextColor3 = GOLD
			leftArm.Rotation = -18
			rightArm.Rotation = 18
			for _, tile in gripTiles do
				tile.BackgroundColor3 = DARK
			end
		end
		local phase = (t - lead) / interval - cycle
		fill.Size = UDim2.fromScale(math.clamp(phase, 0, 1), 1)
		marker.Position = UDim2.fromScale(moment, 0.5)
		goodZone.Position = marker.Position
		opponent.Rotation = math.sin(phase * math.pi) * 12 * (wanted - 2)
		leftArm.Rotation = -18 + phase * 12
		rightArm.Rotation = 18 - phase * 12
	end)

	return self
end

return GripCounter
