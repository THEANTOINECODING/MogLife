-- Mini-jeu « Combo » (boss : le Roi du Quartier, et le Dieu du Pump en attendant son vrai combat, D81) : une
-- combinaison de flèches s'affiche ; la refaire en glissant le pouce (n'importe où) dans chaque direction, avant que
-- son ventilateur ne l'efface (la barre). Une erreur = raté. Vite = Perfect.
-- Surprise (niveau Combo.LongLevel) : 5 flèches au lieu de 4. Clavier : flèches, ZQSD/WASD ; manette : croix, stick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Combo
local MAX_SLOTS = 5
local DONE = Color3.fromRGB(90, 230, 90)
local WRONG = Color3.fromRGB(255, 80, 80)

local Combo = {}

function Combo.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(420, 300))
	local rng = self:Random()
	local length = if self.level >= SETTINGS.LongLevel then SETTINGS.Length + 1 else SETTINGS.Length
	length = math.min(length, MAX_SLOTS)
	if length > SETTINGS.Length then
		self:Announce("Minigame.Twist.Combo.Long")
	end

	local king = self:Emoji(panel, "🤴", 56, 3)
	king.Position = UDim2.new(0.12, 0, 0, 40)
	local fan = self:Emoji(panel, "🌀", 50, 3)
	fan.Position = UDim2.new(0.88, 0, 0, 40)

	local slots = {}
	for index = 1, length do
		local slot = Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new((index - 0.5) / length, 0, 0, 140),
			Size = UDim2.fromOffset(72, 72),
			BackgroundTransparency = 0.25,
			BackgroundColor3 = Color3.fromRGB(40, 40, 60),
			ZIndex = 4,
			Parent = panel,
		})
		Ui.corner(UDim.new(0, 14)).Parent = slot
		slots[index] = slot
	end
	local timerBack = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 200),
		Size = UDim2.new(1, -40, 0, 16),
		BackgroundColor3 = Color3.fromRGB(30, 25, 45),
		Parent = panel,
	}, { Ui.corner(UDim.new(1, 0)) })
	local timer = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(120, 200, 255),
		Parent = timerBack,
	}, { Ui.corner(UDim.new(1, 0)) })

	local combo: { string } = {}
	local typed = 0
	local startedAt = 0
	local active = false
	local limit = interval

	local function newCombo()
		combo = {}
		for index = 1, length do
			combo[index] = Kit.DIRECTIONS[rng:NextInteger(1, 4)]
			slots[index].Text = Kit.ARROWS[combo[index]]
			slots[index].TextColor3 = Color3.new(1, 1, 1)
			slots[index].Rotation = 0
			slots[index].TextTransparency = 0
			slots[index].BackgroundTransparency = 0.25
		end
		typed = 0
		-- La combinaison suivante attend que le serveur accepte la répétition suivante
		startedAt = math.max(os.clock(), self:NextRepAt() - interval * 0.5)
		active = true
		self.guideDirection = combo[1]
	end
	newCombo()

	local function finish(quality: string)
		active = false
		self:Rep(quality, slots[math.clamp(typed, 1, length)])
		if quality == "Miss" then
			-- Le ventilateur souffle les flèches
			for _, slot in slots do
				TweenService:Create(slot, TweenInfo.new(0.3), {
					Rotation = 40,
					TextTransparency = 1,
					BackgroundTransparency = 1,
				}):Play()
			end
		end
		task.delay(0.4, function()
			if not self.destroyed then
				newCombo()
			end
		end)
	end

	self:OnSwipe(function(direction)
		if not active or os.clock() < startedAt then
			return
		end
		typed += 1
		local slot = slots[typed]
		if direction ~= combo[typed] then
			slot.TextColor3 = WRONG
			finish("Miss")
			return
		end
		slot.TextColor3 = DONE
		self:Burst("Good", slot)
		if typed == length then
			local fraction = (os.clock() - startedAt) / limit
			finish(self:GradeError(fraction, SETTINGS.PerfectFraction, SETTINGS.GoodFraction))
		else
			self.guideDirection = combo[typed + 1]
		end
	end)
	self:Guide(panel, "SwipeUp")

	self:OnStep(function(dt)
		local now = os.clock()
		local elapsed = now - startedAt
		local left = math.clamp(1 - elapsed / limit, 0, 1)
		timer.Size = UDim2.fromScale(if active then left else 0, 1)
		timer.BackgroundColor3 = if left < 0.3 then WRONG else Color3.fromRGB(120, 200, 255)
		fan.Rotation += dt * (200 + 600 * (1 - left))
		if active and elapsed >= limit then
			finish("Miss")
		end
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { combo = combo, typed = typed, active = active, startedAt = startedAt }
	end

	return self
end

return Combo
