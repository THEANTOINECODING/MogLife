-- Finale de Pump God : mémoriser puis jouer quatre directions avant que le ventilateur efface la séquence.
-- Un motif par intervalle serveur, identique au doigt, aux touches et à la croix directionnelle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SceneGames = require(ReplicatedStorage.Shared.Config.SceneGames)
local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local C = SceneGames.Common
local DARK = Color3.fromRGB(34, 27, 54)
local GOLD = Color3.fromRGB(255, 216, 103)
local GOOD = Color3.fromRGB(110, 225, 130)
local MISS = Color3.fromRGB(255, 110, 110)

local Combo = {}

function Combo.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(420, 340))
	panel.Name = "Combo"
	local rng = Random.new((options and options.seed) or math.floor(os.clock() * 1000))

	Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 31),
		Text = Texts.Get("Minigame.Title.Combo"),
		TextColor3 = GOLD,
		Parent = panel,
	})
	Ui.label({
		Name = "Hint",
		Position = UDim2.fromOffset(14, 40),
		Size = UDim2.new(1, -28, 0, 34),
		Text = Texts.Get("Minigame.Hint.Combo"),
		TextWrapped = true,
		TextStrokeTransparency = 1,
		Parent = panel,
	})
	local stage = Ui.create("Frame", {
		Position = UDim2.fromOffset(12, 80),
		Size = UDim2.new(1, -24, 1, -163),
		BackgroundColor3 = DARK,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 14)), Ui.stroke(GOLD, 2, 0.45) })
	local fan = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.15),
		Size = UDim2.fromScale(0.28, 0.3),
		Text = "✦",
		TextColor3 = Color3.fromRGB(130, 205, 255),
		TextTransparency = 0.25,
		TextStrokeTransparency = 1,
		Parent = stage,
	})
	local slots = {}
	for i = 1, C.ComboLength do
		local slot = Ui.label({
			Name = `Step{i}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale((i - 0.5) / C.ComboLength, 0.53),
			Size = UDim2.new(1 / C.ComboLength, -12, 0.42, 0),
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(70, 55, 94),
			TextStrokeTransparency = 1,
			Parent = stage,
		})
		Ui.corner(UDim.new(0, 12)).Parent = slot
		slots[i] = slot
	end
	local stepLabel = Ui.label({
		Position = UDim2.fromScale(0.08, 0.77),
		Size = UDim2.fromScale(0.84, 0.16),
		Text = "",
		TextColor3 = GOLD,
		TextStrokeTransparency = 1,
		Parent = stage,
	})
	local timer = Ui.create("Frame", {
		Position = UDim2.new(0, 14, 1, -73),
		Size = UDim2.new(1, -28, 0, 10),
		BackgroundColor3 = DARK,
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })
	local timerFill = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GOLD,
		Parent = timer,
	}, { Ui.corner(UDim.new(1, 0)) })

	local combo: { string } = {}
	local cycle = -1
	local typed = 0
	local resolved = false

	local function showStep()
		stepLabel.Text =
			Texts.Get("Minigame.ComboStep", { step = math.min(typed + 1, C.ComboLength), total = C.ComboLength })
	end

	local function finish(quality: string)
		if resolved or self.auto then
			return
		end
		resolved = true
		stepLabel.Text = Texts.Get(`Minigame.{quality}`)
		stepLabel.TextColor3 = if quality == "Miss" then MISS else GOOD
		if quality ~= "Miss" then
			SoundController.Play("SceneImpact", if quality == "Perfect" then 1.12 else 0.94)
		end
		self:Rep(quality)
	end

	local function input(direction: string)
		if cycle < 0 or resolved or self.auto then
			return
		end
		typed += 1
		local slot = slots[typed]
		SoundController.Play("SceneTouch", 0.9)
		if direction ~= combo[typed] then
			slot.BackgroundColor3 = MISS
			finish("Miss")
			return
		end
		slot.BackgroundColor3 = GOOD
		if typed == C.ComboLength then
			local phase = ((os.clock() - self.startTime) / interval) % 1
			finish(self:GradeError(phase, C.ComboPerfectShare, C.ComboGoodShare))
		else
			showStep()
		end
	end

	self:OnDirection(input)
	self:AddDirectionButtons(Kit.DIRECTIONS, input)
	self:OnStep(function(_, t)
		local index = math.floor(t / interval)
		if index > cycle then
			if cycle >= 0 and not resolved and not self.auto then
				self:Rep("Miss")
			end
			cycle = index
			typed = 0
			resolved = false
			for i = 1, C.ComboLength do
				combo[i] = Kit.DIRECTIONS[rng:NextInteger(1, #Kit.DIRECTIONS)]
				slots[i].Text = Kit.ARROWS[combo[i]]
				slots[i].BackgroundColor3 = Color3.fromRGB(70, 55, 94)
			end
			stepLabel.TextColor3 = GOLD
			showStep()
		end
		local phase = (t / interval) % 1
		timerFill.Size = UDim2.fromScale(1 - phase, 1)
		fan.Rotation = phase * C.ComboFanRotation
	end)

	return self
end

return Combo
