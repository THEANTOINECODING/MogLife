-- Mini-jeu « Catch » (aide : rattraper les courses de l'épicier maladroit) : des fruits tombent,
-- déplacer le panier (souris / doigt, A / D, stick) pour les attraper. Au centre du panier = Perfect.

local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local BASKET_Y = 0.86
local KEY_SPEED = 1.6
local FRUITS = { "🍎", "🍌", "🥚", "🥦", "🍞" }

local Catch = {}

function Catch.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(340, 400))
	self:TrackPointer()

	local area = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = Color3.fromRGB(250, 235, 200),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	local basket = self:Emoji(area, "🧺", 70, 4)

	local basketX = 0.5
	local fallTime = interval * 1.3
	local items = {}
	local nextSpawn = 0

	self:OnStep(function(dt, t)
		if t >= nextSpawn then
			nextSpawn = t + interval
			table.insert(items, {
				x = 0.1 + math.random() * 0.8,
				spawnedAt = t,
				label = self:Emoji(area, FRUITS[math.random(1, #FRUITS)], 44, 3),
			})
		end

		local target = items[1] and items[1].x or 0.5
		if self.auto then
			basketX = target
		else
			local held = self:HeldDirection().X
			if held ~= 0 then
				basketX += held * KEY_SPEED * dt
			elseif self.pointerActive then
				basketX = self:PointerIn(area).X
			end
			basketX = math.clamp(basketX, 0.06, 0.94)
		end
		basket.Position = UDim2.fromScale(basketX, BASKET_Y)

		for index = #items, 1, -1 do
			local item = items[index]
			local progress = (t - item.spawnedAt) / fallTime
			item.label.Position = UDim2.fromScale(item.x, progress * BASKET_Y)
			if progress >= 1 then
				self:Rep(self:GradeError(math.abs(item.x - basketX), 0.06, 0.13))
				item.label:Destroy()
				table.remove(items, index)
			end
		end
	end)

	return self
end

return Catch
