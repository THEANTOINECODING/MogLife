-- Le joueur range les courses dans un grand sac ; un mauvais ordre les fait rebondir hors du sac.

local Props = require(script.Parent.Props)

local Groceries = {}
Groceries.__index = Groceries

local FRUITS = {
	Color3.fromRGB(220, 40, 40), -- pomme
	Color3.fromRGB(250, 160, 30), -- orange
	Color3.fromRGB(250, 220, 60), -- citron
	Color3.fromRGB(120, 200, 60), -- poire
}

function Groceries.Stand(top: CFrame): CFrame
	return top * CFrame.new(0, 0, -3.6) * CFrame.Angles(0, math.pi, 0)
end

function Groceries.new(ctx)
	local self = setmetatable({ ctx = ctx, props = Props.new("Groceries"), caught = {}, missed = {} }, Groceries)
	self.basket = self.props:Part(Vector3.new(1.8, 0.8, 1.2), Color3.fromRGB(170, 120, 70), Enum.Material.Fabric)
	self.falling = self.props:Part(Vector3.new(0.65, 0.65, 0.65), FRUITS[1])
	return self
end

function Groceries:Pose(_p: number, shake: number, u: number, time: number, count: number)
	local rig = self.ctx.rig
	local root = rig.root.CFrame
	-- Sac tenu devant soi pendant que l'autre main prend chaque objet sur le côté
	local sway = math.sin(time * 2) * 0.08
	local basket = root * CFrame.new(sway, -0.2, -1.4)
	self.basket.CFrame = basket
	for _, sx in { -1, 1 } do
		rig:Reach(
			if sx < 0 then "LeftArm" else "RightArm",
			(basket * CFrame.new(sx * 0.9, 0.35, 0)).Position,
			-root.LookVector + root.RightVector * sx * 0.5
		)
	end
	rig:Set("Neck", CFrame.Angles(-0.2, 0, 0)) -- il vérifie le sac

	-- Les objets rangés restent dans le sac, les lourds au fond
	local done = math.max(count - (if u > 0 and u < 1 then 1 else 0), 0)
	for index = 1, done do
		local fruit = self.caught[index]
		if not fruit then
			local size = if index <= 3 then 0.65 else 0.42
			fruit = self.props:Part(Vector3.new(size, size, size), FRUITS[(index - 1) % #FRUITS + 1])
			self.caught[index] = fruit
		end
		local row = (index - 1) % 6
		fruit.CFrame = basket
			* CFrame.new(
				-0.6 + (row % 3) * 0.6,
				0.3 + math.floor((index - 1) / 6) * 0.3,
				-0.25 + math.floor(row / 3) * 0.5
			)
		fruit.Transparency = if self.missed[index] then 1 else 0
	end

	-- L'objet quitte la réserve à droite et rejoint le sac ; un raté le fait rebondir dehors
	local carrying = u > 0 and u < 1
	self.falling.Transparency = if carrying then 0 else 1
	if carrying then
		local index = done + 1
		self.falling.Color = FRUITS[(index - 1) % #FRUITS + 1]
		self.falling.Size = if index <= 3 then Vector3.new(0.65, 0.65, 0.65) else Vector3.new(0.42, 0.42, 0.42)
		local start = basket.Position + root.RightVector * 2 + Vector3.new(0, 1.2, 0)
		if shake > 0.5 then
			self.missed[index] = true
			local rim = basket.Position + Vector3.new(0, 0.7, 0)
			if u < 0.5 then
				self.falling.Position = start:Lerp(rim, (u / 0.5) ^ 2)
			else
				local t = (u - 0.5) / 0.5
				self.falling.Position = rim
					+ root.RightVector * 4 * t
					+ Vector3.new(0, 2 * math.sin(t * math.pi) - 3 * t * t, 0)
			end
		else
			self.missed[index] = nil
			self.falling.Position = start:Lerp(basket.Position + Vector3.new(0, 0.4, 0), math.clamp(u / 0.6, 0, 1) ^ 2)
		end
	end
end

function Groceries:Destroy()
	self.props:Destroy()
end

return Groceries
