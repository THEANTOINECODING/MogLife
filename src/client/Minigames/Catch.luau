-- Mini-jeu « Catch » (aide : rattraper les courses de l'épicier maladroit, D81) : des courses tombent ; glisser le
-- pouce (n'importe où, le panier suit le déplacement du doigt) pour les attraper. Au centre du panier = Perfect.
-- Surprises : objets à ne pas attraper (chaussure, caillou : les laisser tomber = Perfect, niveau Catch.HazardLevel),
-- fruits qui rebondissent de gauche à droite (niveau Catch.BounceLevel).
-- Clavier : A / D, flèches ; manette : stick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Catch
local BASKET_Y = 0.86
local KEY_SPEED = 1.6
local FRUITS = { "🍎", "🍌", "🥚", "🥦", "🍞", "🍊" }
local HAZARDS = { "👟", "🪨" }

local Catch = {}

function Catch.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(340, 420))
	local rng = self:Random()
	self:TrackDrag()

	local area = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = Color3.fromRGB(250, 236, 205),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	local basket = self:Emoji(area, "🧺", 76, 5)
	local basketX = 0.5
	local fallTime = interval * SETTINGS.FallFactor
	local items = {} -- { x, spawnedAt, hazard, bounce, label, shadow }
	local nextSpawn = 0.3
	local spawned = 0

	local function itemX(item, progress: number): number
		if not item.bounce then
			return item.x
		end
		return math.clamp(item.x + 0.25 * math.sin(progress * math.pi * 2 + item.phase), 0.08, 0.92)
	end

	-- Toujours loin du panier : il faut bouger pour chaque objet (rester immobile ne rapporte rien)
	local function farFromBasket(): number
		local x = 0.5
		for _ = 1, 20 do
			x = 0.1 + rng:NextNumber() * 0.8
			if math.abs(x - basketX) >= SETTINGS.MinDistance then
				break
			end
		end
		return x
	end

	self:Guide(panel, "Drag")

	self:OnStep(function(dt, t)
		if t >= nextSpawn then
			nextSpawn = t + interval
			spawned += 1
			local hazard = spawned > 1
				and self.level >= SETTINGS.HazardLevel
				and rng:NextNumber() < SETTINGS.HazardChance
			local bounce = not hazard
				and self.level >= SETTINGS.BounceLevel
				and rng:NextNumber() < SETTINGS.BounceChance
			if hazard then
				self:Announce("Minigame.Twist.Catch.Hazard")
			elseif bounce then
				self:Announce("Minigame.Twist.Catch.Bounce")
			end
			local list = if hazard then HAZARDS else FRUITS
			table.insert(items, {
				x = farFromBasket(),
				phase = rng:NextNumber() * math.pi * 2,
				spawnedAt = t,
				hazard = hazard,
				bounce = bounce,
				label = self:Emoji(area, list[rng:NextInteger(1, #list)], 48, 3),
				-- Ombre sur le sol : on voit où l'objet va tomber
				shadow = Ui.create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(40, 10),
					BackgroundColor3 = if hazard then Color3.fromRGB(200, 60, 60) else Color3.new(0, 0, 0),
					BackgroundTransparency = 0.75,
					Parent = area,
				}, { Ui.corner(UDim.new(1, 0)) }),
			})
		end

		local drag = self:ConsumeDrag()
		if area.AbsoluteSize.X > 0 then
			basketX += drag.X * Balance.Minigames.DragSensitivity / area.AbsoluteSize.X
		end
		basketX = math.clamp(basketX + self:HeldDirection().X * KEY_SPEED * dt, 0.06, 0.94)
		basket.Position = UDim2.fromScale(basketX, BASKET_Y)

		for index = #items, 1, -1 do
			local item = items[index]
			local progress = (t - item.spawnedAt) / fallTime
			local x = itemX(item, progress)
			item.label.Position = UDim2.fromScale(x, progress * BASKET_Y)
			item.label.Rotation = progress * 200
			item.shadow.Position = UDim2.fromScale(x, BASKET_Y + 0.07)
			item.shadow.Size = UDim2.fromOffset(20 + 30 * progress, 8)
			if progress >= 1 then
				local distance = math.abs(x - basketX)
				if item.hazard then
					-- Attrapé : beurk, raté. Laissé tomber : rien (ne rien faire ne doit pas rapporter)
					if distance <= SETTINGS.GoodMax then
						self:Rep("Miss", basket)
					end
				else
					self:Rep(self:GradeError(distance, SETTINGS.PerfectMax, SETTINGS.GoodMax), basket)
				end
				item.label:Destroy()
				item.shadow:Destroy()
				table.remove(items, index)
			end
		end
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		local list = {}
		for _, item in items do
			local progress = (os.clock() - self.startTime - item.spawnedAt) / fallTime
			table.insert(list, { x = itemX(item, progress), hazard = item.hazard, progress = progress })
		end
		return { basketX = basketX, items = list, width = area.AbsoluteSize.X }
	end

	return self
end

return Catch
