-- Bras de fer (duel entre joueurs, D68) : debout de chaque côté d'une table haute, coude droit sur le coussin du
-- milieu, mains droites jointes au-dessus du centre, main gauche agrippée au bord de la table. Les mains basculent vers
-- le coussin de plaquage selon l'attribut Lean des emplacements (publié par DuelService) : tout le monde voit qui
-- est en train de gagner. À chaque répétition validée, le joueur force (p = 1) : buste penché, épaule engagée.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Duels = require(ReplicatedStorage.Shared.Config.Duels)

local MAX_TILT = math.rad(68) -- bras presque à plat sur la table quand l'inclinaison est au maximum

local ArmWrestle = {}
ArmWrestle.__index = ArmWrestle

-- Sur l'emplacement, face à la table (l'emplacement regarde vers son centre)
function ArmWrestle.Stand(top: CFrame): CFrame
	return top
end

function ArmWrestle.new(ctx)
	local self = setmetatable({ ctx = ctx }, ArmWrestle)
	local anchor = ctx.anchor :: BasePart
	local top = anchor:GetAttribute("TableTop")
	local pinAxis = anchor:GetAttribute("PinAxis")
	self.tableTop = if typeof(top) == "Vector3"
		then top
		else anchor.Position + anchor.CFrame.LookVector * Duels.Table.Spacing + Vector3.new(
			0,
			Duels.Table.Height,
			0
		)
	self.pinAxis = if typeof(pinAxis) == "Vector3" then pinAxis else anchor.CFrame.RightVector
	return self
end

function ArmWrestle:Pose(p: number, shake: number, _u: number, time: number)
	local ctx = self.ctx
	local rig, m = ctx.rig, ctx.measures
	local root = rig.root.CFrame
	local tremble = shake * math.sin(time * 34) * 0.05
	-- Inclinaison commune aux deux joueurs (> 0 : le côté A gagne), qui tremble un peu sous l'effort
	local lean = tonumber(ctx.anchor:GetAttribute("Lean")) or 0
	local share = math.clamp(lean / Duels.LeanLimit, -1, 1)
	local strain = math.sin(time * 22) * 0.04 * (1 - math.abs(share))
	local angle = share * MAX_TILT + strain
	-- Coude posé sur le coussin du milieu, avant-bras dressé, incliné vers le coussin de plaquage
	local forearm = m.armLength * 0.5
	local pivot = self.tableTop + Vector3.new(0, 0.15, 0)
	local clasp = pivot + (Vector3.new(0, 1, 0) * math.cos(angle) + self.pinAxis * math.sin(angle)) * forearm
	-- Buste penché sur la table, épaule droite engagée pendant l'effort
	rig:Set("Waist", CFrame.Angles(-0.4 - 0.12 * p + tremble, 0.15 + 0.15 * p, 0))
	rig:Set("Neck", CFrame.Angles(0.3, -0.1, 0))
	local toMe = Vector3.new(root.Position.X - self.tableTop.X, 0, root.Position.Z - self.tableTop.Z)
	toMe = if toMe.Magnitude > 0.05 then toMe.Unit else -root.LookVector
	rig:Reach("RightArm", clasp + Vector3.new(0, tremble, 0), -Vector3.new(0, 1, 0) + toMe)
	-- Main gauche agrippée au bord de la table, de son côté
	local edge = self.tableTop + toMe * 0.85 - root.RightVector * 0.75 + Vector3.new(0, 0.1, 0)
	rig:Reach("LeftArm", edge, -Vector3.new(0, 1, 0) - root.RightVector)
end

function ArmWrestle:Destroy() end

return ArmWrestle
