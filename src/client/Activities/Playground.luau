-- D76: visible tabletop diorama, synchronized from accepted server state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlaygroundConfig = require(ReplicatedStorage.Shared.Config.Playground)
local Rules = require(ReplicatedStorage.Shared.Playground)
local View = require(script.Parent.Parent.PlaygroundView)
local Activity = {}
Activity.__index = Activity
function Activity.Stand(top)
	return top * CFrame.new(0, 0, PlaygroundConfig.StationStand)
end
function Activity.new(ctx)
	local folder = Instance.new("Folder")
	folder.Name = "StrengthPlayground"
	folder:SetAttribute("ActivityProps", true)
	folder.Parent = workspace
	local self = setmetatable({ ctx = ctx, folder = folder }, Activity)
	self.view = View.new(folder, ctx.top * CFrame.new(0, 2.7, 0), 4.4, ctx.minigame)
	self.state = Rules.New(ctx.minigame, 1)
	self.view:Draw(Rules.Draw(self.state))
	return self
end
function Activity:SetState(state)
	self.state = state
	self.view:Draw(Rules.Draw(state))
end
function Activity:Pose(_p, _shake, _u, time)
	local ctx = self.ctx
	local s = if ctx.isLocal
			and Activity.LocalState
			and Activity.LocalState.name == self.state.name
		then Activity.LocalState
		else self.state
	local rig, name = ctx.rig, s.name
	if s.pulse ~= self.lastPulse then
		self.lastPulse = s.pulse
		self.impactAt = time
	end
	local impact = math.max(0, 1 - (time - (self.impactAt or -10)) * 5)
	local effort = if s.held then 0.20 else 0.04
	local lean, lift, reach = effort, 0.30, 0.65
	if name == "ScrapPress" then
		lean = (s.compression or 0) * 0.32
		lift = 0.8 - (s.compression or 0) * 1.1
	elseif name == "SwingKing" then
		lift, reach = 1.5, 0.4
		lean = math.sin(s.t * 2) * 0.23
	elseif name == "AtlasStack" then
		lift = if s.drop then 0.1 else 1.25
	elseif name == "TireDomino" then
		lean = if s.ball then 0.3 else 0.08
		lift = -0.35
	elseif name == "CrownSneak" then
		lean = if s.held then 0.28 else 0.02
	elseif name == "TreadmillTakeover" then
		lift = 0.5 + impact * 0.5
	end
	rig:Set("Waist", CFrame.Angles(-lean - impact * 0.08, (s.x - 0.5) * 0.22, 0))
	rig:Set("Neck", CFrame.Angles(-0.12, (s.x - 0.5) * 0.25, 0))
	for _, side in { -1, 1 } do
		local y = lift
		if name == "RopeRave" then
			y = 0.35 + math.sin(s.t * 10 + side) * (0.15 + impact * 0.5)
		end
		if name == "ChopShop" then
			y = if s.held then 1.2 else 0.15 - impact * 0.3
		end
		if name == "PeelGood" or name == "PianoPolish" or name == "TowelFold" or name == "ShortcutChalk" then
			y = 0.8 - s.y * 0.7
		end
		local lateral = side * ctx.measures.shoulderWidth * 0.42 + (s.x - 0.5) * 0.65
		local target = rig.root.CFrame * Vector3.new(lateral, y, -ctx.measures.armLength * reach)
		rig:Reach(if side < 0 then "LeftArm" else "RightArm", target, rig.root.CFrame.RightVector * side)
		rig:Set(if side < 0 then "LeftKnee" else "RightKnee", CFrame.Angles(math.max(0, lean) * 0.6, 0, 0))
	end
end
function Activity:Destroy()
	self.view:Destroy()
	self.folder:Destroy()
end
return Activity
