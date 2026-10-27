-- Aide « Porter le piano de Mme Do-Ré » : le joueur soulève vraiment le piano au-dessus de sa tête et le pousse
-- vers le ciel à chaque répétition (une ratée vacille dangereusement). Il le repose à la fin. D37.

local Piano = {}
Piano.__index = Piano

local SEARCH_RADIUS = 12
local GAP = 0.9 -- entre le devant du piano et le joueur

-- Le piano droit le plus proche de la dame (posé dans la carte)
local function findPiano(position: Vector3): BasePart?
	local folder = workspace:FindFirstChild("MapProps")
	local best, bestDistance = nil, SEARCH_RADIUS
	for _, part in if folder then folder:GetChildren() else {} do
		if part.Name == "UprightPiano" and part:IsA("BasePart") then
			local distance = (part.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = part, distance
			end
		end
	end
	return best
end

-- Devant le clavier du piano, face à lui (sans piano : à côté de la dalle de la dame)
function Piano.Stand(top: CFrame): CFrame
	local piano = findPiano(top.Position)
	if not piano then
		return top * CFrame.new(-4.5, 0, -3)
	end
	local front = piano.CFrame.LookVector * Vector3.new(1, 0, 1)
	front = if front.Magnitude > 0.1 then front.Unit else Vector3.zAxis
	-- Demi-profondeur du piano dans la direction du clavier
	local depth = 0
	for _, axis in { piano.CFrame.RightVector * piano.Size.X, piano.CFrame.LookVector * piano.Size.Z } do
		depth += math.abs(axis:Dot(front)) / 2
	end
	local spot = piano.Position + front * (depth + GAP + 0.7)
	spot = Vector3.new(spot.X, top.Y, spot.Z)
	return CFrame.lookAt(spot, Vector3.new(piano.Position.X, top.Y, piano.Position.Z))
end

function Piano.new(ctx)
	local self = setmetatable({ ctx = ctx, started = os.clock() }, Piano)
	self.piano = ctx.borrow("UprightPiano", false, SEARCH_RADIUS)
	self.home = if self.piano then self.piano.CFrame else nil
	return self
end

local LIFT_TIME = 0.7

function Piano:Pose(p: number, shake: number, _u: number, time: number)
	local rig, m = self.ctx.rig, self.ctx.measures
	local root = rig.root.CFrame
	local up = root.UpVector
	local wobble = shake * math.sin(time * 9) * 0.18
	-- Jambes fléchies sous le poids (pieds à plat au sol), bras qui poussent le piano vers le haut
	local lower = rig:RestFrame("LowerTorso")
	local bend = m.legLength * (0.1 - 0.06 * p)
	rig:Place("LowerTorso", root * CFrame.new(0, -bend, 0) * lower)
	rig:PlantFeet()
	rig:Set("Waist", CFrame.Angles(0.08, 0, wobble * 0.5))
	local head = rig:PartCFrame("Head").Position
	local low = head + up * 0.6
	local high = head + up * (m.armLength * 0.85)
	local hands = low:Lerp(high, p) + root.RightVector * wobble
	for _, sx in { -1, 1 } do
		rig:Grip(
			if sx < 0 then "LeftArm" else "RightArm",
			hands + root.RightVector * sx * m.handSpread * 0.9,
			root.RightVector * sx - root.LookVector * 0.3
		)
	end
	if not self.piano or not self.home then
		return
	end
	-- Le piano monte du sol jusqu'aux mains au début, puis reste posé sur les paumes (droit, le clavier vers l'avant)
	local palms = (rig:Palm("Left") + rig:Palm("Right")) / 2
	local held = CFrame.new(palms + up * (self.piano.Size.Y / 2 + 0.15))
		* root.Rotation
		* CFrame.Angles(0, math.pi, wobble * 0.3)
	local lift = math.clamp((os.clock() - self.started) / LIFT_TIME, 0, 1)
	self.piano.CFrame = self.home:Lerp(held, lift * lift * (3 - 2 * lift))
end

function Piano:Destroy() end

return Piano
