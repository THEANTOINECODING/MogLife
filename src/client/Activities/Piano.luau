-- Aide « Porter le piano de Mme Do-Ré » : le joueur soulève vraiment le piano au-dessus de sa tête et le pousse
-- vers le ciel à chaque répétition (une ratée vacille dangereusement). Il le repose à la fin. D37.

local Piano = {}
Piano.__index = Piano

function Piano.Stand(top: CFrame): CFrame
	return top * CFrame.new(-3.5, 0, -3)
end

function Piano.new(ctx)
	local self = setmetatable({ ctx = ctx, started = os.clock() }, Piano)
	self.piano = ctx.borrow("UprightPiano", false, 12)
	self.home = if self.piano then self.piano.CFrame else nil
	return self
end

local LIFT_TIME = 0.7

function Piano:Pose(p: number, shake: number, _u: number, time: number)
	local rig, m = self.ctx.rig, self.ctx.measures
	local root = rig.root.CFrame
	local up = root.UpVector
	local wobble = shake * math.sin(time * 9) * 0.18
	-- Jambes un peu fléchies sous le poids, bras qui poussent le piano vers le haut
	rig:Set("Waist", CFrame.Angles(0.08, 0, wobble * 0.5))
	local head = rig:PartCFrame("Head").Position
	local low = head + up * 0.6
	local high = head + up * (m.armLength * 0.85)
	local hands = low:Lerp(high, p) + root.RightVector * wobble
	for _, sx in { -1, 1 } do
		rig:Reach(
			if sx < 0 then "LeftArm" else "RightArm",
			hands + root.RightVector * sx * m.handSpread * 0.9,
			root.RightVector * sx - root.LookVector * 0.3
		)
	end
	if not self.piano or not self.home then
		return
	end
	-- Le piano monte du sol jusqu'aux mains au début, puis reste posé dessus (droit, le clavier vers l'avant)
	local wrists = (rig:JointFrame("LeftWrist").Position + rig:JointFrame("RightWrist").Position) / 2
	local held = CFrame.new(wrists + up * (self.piano.Size.Y / 2 + 0.2))
		* root.Rotation
		* CFrame.Angles(0, math.pi, wobble * 0.3)
	local lift = math.clamp((os.clock() - self.started) / LIFT_TIME, 0, 1)
	self.piano.CFrame = self.home:Lerp(held, lift * lift * (3 - 2 * lift))
end

function Piano:Destroy() end

return Piano
