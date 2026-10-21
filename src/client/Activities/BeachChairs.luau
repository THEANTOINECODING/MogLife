-- Le joueur prend chaque transat et l'installe dans un emplacement au soleil ou à l'ombre.

local Props = require(script.Parent.Props)

local BeachChairs = {}
BeachChairs.__index = BeachChairs

local COLORS = {
	Color3.fromRGB(250, 120, 80),
	Color3.fromRGB(250, 200, 60),
	Color3.fromRGB(80, 170, 230),
	Color3.fromRGB(240, 240, 240),
}
local CHAIR = Vector3.new(2.6, 0.35, 4.2)
local COLUMNS = 3
local GAP_X = 2.9
local GAP_Z = 4.5

local function chairSlot(floor: CFrame, index: number): CFrame
	local column = (index - 1) % COLUMNS
	local row = math.floor((index - 1) / COLUMNS)
	return floor * CFrame.new(2.2 + column * GAP_X, 0.25, -1.8 - row * GAP_Z)
end

function BeachChairs.Stand(top: CFrame): CFrame
	return top * CFrame.new(0, 0, -3.6) * CFrame.Angles(0, math.pi, 0)
end

function BeachChairs.new(ctx)
	local self = setmetatable({ ctx = ctx, props = Props.new("BeachChairs"), chairs = {}, tilts = {} }, BeachChairs)
	return self
end

-- Le transat n° index (créé à la demande), aux couleurs alternées
function BeachChairs:Chair(index: number): Part
	local chair = self.chairs[index]
	if not chair then
		chair = self.props:Part(CHAIR, COLORS[(index - 1) % #COLORS + 1], Enum.Material.Fabric)
		self.chairs[index] = chair
	end
	return chair
end

function BeachChairs:Pose(_p: number, shake: number, u: number, _time: number, count: number)
	local rig, m = self.ctx.rig, self.ctx.measures
	local root = rig.root.CFrame
	local floor = CFrame.new(root.Position - Vector3.new(0, root.Position.Y - m.ground, 0)) * root.Rotation
	local pile = floor * CFrame.new(-2.4, 0, -1.5)
	-- Chaque transat rejoint une place sur la plage ; un raté reste de travers
	local placed = math.max(count - (if u > 0 and u < 1 then 1 else 0), 0)
	for index = 1, placed do
		local chair = self:Chair(index)
		self.tilts[index] = self.tilts[index] or (if shake > 0 then 0.35 else (index % 3 - 1) * 0.06)
		chair.CFrame = chairSlot(floor, index) * CFrame.Angles(0, self.tilts[index], 0)
	end
	-- Le transat porté passe du tas à son emplacement au fil de la répétition
	local carrying = u > 0 and u < 1
	local from = pile * CFrame.new(0, 1.2, 0)
	local to = chairSlot(floor, placed + 1) * CFrame.new(0, 0.3, 0)
	local arc = math.sin(math.min(u, 1) * math.pi) * 1.4
	local held = from:Lerp(to, math.clamp(u * 1.25, 0, 1)) * CFrame.new(0, arc, 0)
	if carrying then
		self:Chair(placed + 1).CFrame = held
	end
	-- Le joueur se tourne vers le tas puis vers la place libre, bras sous le transat
	rig:Set("Waist", CFrame.Angles(-0.2, (0.5 - math.clamp(u * 1.25, 0, 1)) * 0.9, 0))
	local hands = if carrying
		then held.Position - Vector3.new(0, 0.3, 0)
		else (floor * CFrame.new(0, m.hipHeight, -1)).Position
	for _, sx in { -1, 1 } do
		rig:Reach(
			if sx < 0 then "LeftArm" else "RightArm",
			hands + root.RightVector * sx * 0.9,
			-Vector3.yAxis + root.RightVector * sx * 0.5
		)
	end
end

function BeachChairs:Destroy()
	self.props:Destroy()
end

return BeachChairs
