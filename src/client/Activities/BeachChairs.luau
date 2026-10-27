-- Aide « Empiler les transats » (le maître-nageur débordé) : le joueur prend un transat sur le tas et le pose
-- vraiment en haut de la pile, un par répétition réussie ; la pile monte. Un raté glisse et tombe à côté (D37, D82).

local Ground = require(script.Parent.Parent.Ground)
local Props = require(script.Parent.Props)
local HelperStand = require(script.Parent.HelperStand)

local BeachChairs = {}
BeachChairs.__index = BeachChairs

local COLORS = {
	Color3.fromRGB(250, 120, 80),
	Color3.fromRGB(250, 200, 60),
	Color3.fromRGB(80, 170, 230),
	Color3.fromRGB(240, 240, 240),
}
local CHAIR = Vector3.new(2.6, 0.35, 4.2)
local LAYER = 0.42
local SIDE = 3 -- tas et pile de chaque côté du joueur (studs)
local BACK = 0.9 -- un peu en arrière : la dalle du maître-nageur est devant lui

function BeachChairs.Stand(top: CFrame): CFrame
	return HelperStand.Around(top)
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

function BeachChairs:Pose(_p: number, shake: number, u: number, _time: number, _count: number, successes: number)
	local rig, m = self.ctx.rig, self.ctx.measures
	local root = rig.root.CFrame
	local flatRoot = CFrame.new(root.Position.X, m.ground, root.Position.Z) * root.Rotation
	-- Le tas (à sa gauche) et la pile (à sa droite), à côté de lui et un peu en arrière : jamais sur la dalle du
	-- maître-nageur, posés sur le vrai sol
	local function onGround(offset: Vector3): CFrame
		local at = flatRoot * CFrame.new(offset)
		local y = Ground.Height(at.Position) or m.ground
		return CFrame.new(at.X, y, at.Z) * at.Rotation
	end
	local stack = onGround(Vector3.new(SIDE, 0, BACK))
	local pile = onGround(Vector3.new(-SIDE, 0, BACK))
	local carrying = u > 0 and u < 1
	-- Une répétition ratée (Miss) : le transat glisse et tombe à côté de la pile, il n'est pas posé
	local failing = carrying and shake >= 1
	-- La pile : seulement les transats réussis (celui qu'on porte n'est pas encore posé)
	local placed = math.max(successes - (if carrying and not failing then 1 else 0), 0)
	for index = 1, placed do
		local chair = self:Chair(index)
		self.tilts[index] = self.tilts[index] or (index % 3 - 1) * 0.06
		chair.CFrame = stack * CFrame.new(0, LAYER * (index - 0.5), 0) * CFrame.Angles(0, self.tilts[index], 0)
	end
	-- Le transat porté : pris sur le tas, levé au-dessus de sa tête, posé en haut de la pile
	local from = pile * CFrame.new(0, LAYER * 0.5, 0)
	local to = stack * CFrame.new(0, LAYER * (placed + 0.5), 0)
	local overhead = flatRoot * CFrame.new(0, m.shoulderHeight + m.armLength * 0.6, -0.4)
	local k = math.clamp(u * 1.25, 0, 1)
	-- Courbe : tas -> au-dessus de lui -> pile
	local first, second = from:Lerp(overhead, k), overhead:Lerp(to, k)
	local held = first:Lerp(second, k)
	if carrying then
		local chair = self:Chair(placed + 1)
		if failing and u > 0.6 then
			-- Il glisse du haut de la pile et tombe au sol, de travers
			local fall = math.clamp((u - 0.6) / 0.4, 0, 1)
			local ground = stack * CFrame.new(1.4, LAYER * 0.5, 1.6) * CFrame.Angles(0.5, 0.9, 0.35)
			chair.CFrame = held:Lerp(ground, fall * fall)
		else
			chair.CFrame = held
		end
	elseif self.chairs[placed + 1] then
		-- Le transat raté disparaît de la scène (il sera repris au tas)
		self.chairs[placed + 1].CFrame = pile * CFrame.new(0, -5, 0)
	end
	-- Le joueur se tourne vers le tas puis vers la pile ; ses mains tiennent le transat par son bord le plus proche,
	-- dessous (au repos, bras le long du corps)
	rig:Set("Waist", CFrame.Angles(-0.1, (0.5 - k) * 0.9, 0))
	if carrying then
		local toChair = (held.Position - root.Position) * Vector3.new(1, 0, 1)
		toChair = if toChair.Magnitude > 0.3 then toChair.Unit else root.LookVector
		local edge = held.Position - toChair * (CHAIR.X * 0.5 - 0.2) - held.UpVector * (CHAIR.Y * 0.5 + 0.15)
		local along = held.LookVector
		for _, sx in { -1, 1 } do
			rig:Grip(
				if sx < 0 then "LeftArm" else "RightArm",
				edge + along * sx * 0.8,
				-Vector3.yAxis + root.RightVector * sx * 0.5
			)
		end
	end
end

function BeachChairs:Destroy()
	self.props:Destroy()
end

return BeachChairs
