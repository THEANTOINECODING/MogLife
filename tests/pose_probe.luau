-- Sonde des poses (D86) : pour chaque activité (exercices, aides) et chaque duel de boss, mesure à plusieurs moments
-- du mouvement l'écart entre les pieds et le sol (négatif = enfoncé) et la distance entre chaque main et l'objet le
-- plus proche (barre, corde, miroir…). Rien n'est envoyé au serveur, aucune donnée touchée.
-- À exécuter comme LocalScript dans PlayerGui (même mémoire que le jeu). Résultat : attribut « ProbeResult » du joueur
-- (texte, une ligne par mesure). Attribut « ProbeOnly » (facultatif) : ne sonder que ce module.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local client = player.PlayerScripts:WaitForChild("Client")
local Rig = require(client.Activities.Rig)
local Ground = require(client.Ground)
local ActivityController = require(client.Controllers.ActivityController)

local character = player.Character
local humanoid = character:FindFirstChildOfClass("Humanoid")
local root = character:FindFirstChild("HumanoidRootPart")
local only = player:GetAttribute("ProbeOnly")
local lines = {}

local function excluded(): { Instance }
	local list: { Instance } = { character }
	local npcs = workspace:FindFirstChild("Npcs")
	if npcs then
		table.insert(list, npcs)
	end
	for _, child in workspace:GetChildren() do
		if child:GetAttribute("ActivityProps") then
			table.insert(list, child)
		end
	end
	return list
end

-- Hauteur du sol sous un point (décor, sans personnages ni accessoires)
local function groundAt(position: Vector3): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded()
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), params)
	return hit and hit.Position.Y
end

local function lowestCorner(cframe: CFrame, size: Vector3): number
	local low = math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				low = math.min(low, (cframe * (Vector3.new(x * size.X, y * size.Y, z * size.Z) / 2)).Y)
			end
		end
	end
	return low
end

local function propParts(borrowed: { [BasePart]: any }): { BasePart }
	local list = {}
	for _, child in workspace:GetChildren() do
		if child:GetAttribute("ActivityProps") then
			for _, part in child:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					table.insert(list, part)
				end
			end
		end
	end
	for part in borrowed do
		table.insert(list, part)
	end
	return list
end

-- Distance d'un point à la surface d'une pièce (boîte englobante)
local function distanceTo(part: BasePart, point: Vector3): number
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	local clamped = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)
	return (localPoint - clamped).Magnitude
end

local function nearest(point: Vector3, parts: { BasePart }): (number, string)
	local best, name = math.huge, "-"
	for _, part in parts do
		local d = distanceTo(part, point)
		if d < best then
			best, name = d, part.Name .. "/" .. tostring(part.Parent and part.Parent.Name)
		end
	end
	return best, name
end

local function report(label: string, rig, borrowed)
	local feet = {}
	for _, name in { "LeftFoot", "RightFoot" } do
		local part = character:FindFirstChild(name) :: BasePart
		local cframe = rig:PartCFrame(name)
		local ground = groundAt(cframe.Position)
		feet[#feet + 1] = if ground then string.format("%+.2f", lowestCorner(cframe, part.Size) - ground) else "air"
	end
	local parts = propParts(borrowed or {})
	local hands = {}
	for _, name in { "LeftHand", "RightHand" } do
		local d, what = nearest(rig:PartCFrame(name).Position, parts)
		hands[#hands + 1] = if d < math.huge then string.format("%.2f(%s)", d, what) else "-"
	end
	table.insert(
		lines,
		string.format("%s | pieds %s | mains %s", label, table.concat(feet, " "), table.concat(hands, " "))
	)
end

local function bossReport(label: string, scene)
	local rig = scene.bossRig
	local part = scene.bossPart
	if not rig or not part then
		return
	end
	local feet = {}
	for _, name in { "LeftFoot", "RightFoot" } do
		-- Bas du pied : la cheville, moins sa hauteur au repos au-dessus du bas du corps
		local ankleRest = rig.restPos[name].Y + part.Size.Y / 2
		local ankle = rig:Joint(name)
		local ground = groundAt(ankle)
		feet[#feet + 1] = if ground then string.format("%+.2f", ankle.Y - ankleRest - ground) else "air"
	end
	local parts = propParts({})
	local hands = {}
	for _, name in { "LeftHand", "RightHand" } do
		local d, what = nearest(rig:Joint(name), parts)
		hands[#hands + 1] = if d < math.huge then string.format("%.2f(%s)", d, what) else "-"
	end
	table.insert(
		lines,
		string.format("  boss %s | pieds %s | mains %s", label, table.concat(feet, " "), table.concat(hands, " "))
	)
end

-- Placé comme le fait ActivityController : pieds sur le vrai sol, racine tenue en place
local function stand(module, anchor: BasePart): CFrame
	local top = anchor.CFrame * CFrame.new(0, anchor.Size.Y / 2, 0)
	local spot = module.Stand(top)
	local ground = Ground.Height(spot.Position) or spot.Y
	root.Anchored = true
	root.CFrame = CFrame.new(spot.X, ground, spot.Z)
		* spot.Rotation
		* CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	return top
end

local function findAnchor(tag: string, attribute: string, id: string): BasePart?
	local best, bestDistance = nil, math.huge
	for _, anchor in CollectionService:GetTagged(tag) do
		if anchor:IsA("BasePart") and anchor:GetAttribute(attribute) == id then
			local distance = (anchor.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = anchor, distance
			end
		end
	end
	return best
end

humanoid.WalkSpeed = 0
ActivityController.SetBusy(player, true)

-- Exercices et aides
local list = {}
for _, id in { "Curl", "PushUp", "BenchPress", "Squat", "PullUp", "JumpRope" } do
	table.insert(list, { id = id, tag = "Station", attribute = "ExerciseId" })
end
for _, id in { "OpenJar", "PumpTire", "Nails", "PushCar", "Piano", "BeachChairs", "Groceries", "Directions" } do
	table.insert(list, { id = id, tag = "HelperSpot", attribute = "HelpId" })
end
for _, entry in list do
	if only and only ~= entry.id then
		continue
	end
	local moduleScript = client.Activities:FindFirstChild(entry.id)
	local anchor = findAnchor(entry.tag, entry.attribute, entry.id)
	if not moduleScript or not anchor then
		table.insert(lines, entry.id .. " : introuvable")
		continue
	end
	local module = require(moduleScript)
	local top = stand(module, anchor)
	task.wait(0.2)
	local rig = Rig.new(character)
	local measures = rig:Measure(humanoid)
	local borrowed = {}
	local activity = module.new({
		minigame = "",
		rig = rig,
		measures = measures,
		character = character,
		anchor = anchor,
		top = top,
		borrow = function(name: string, hide: boolean?, radius: number?)
			local folder = workspace:FindFirstChild("MapProps")
			local best, bestDistance = nil, radius or 8
			for _, part in if folder then folder:GetChildren() else {} do
				if part.Name == name and part:IsA("BasePart") then
					local distance = (part.Position - anchor.Position).Magnitude
					if distance < bestDistance then
						best, bestDistance = part, distance
					end
				end
			end
			if best and not borrowed[best] then
				borrowed[best] = { cframe = best.CFrame, transparency = best.Transparency }
				if hide then
					best.Transparency = 1
				end
			end
			return best
		end,
		isLocal = true,
		player = player,
	})
	for _, p in { 0, 0.5, 1 } do
		rig:Clear()
		activity:Pose(p, 0, p * 0.4, os.clock(), 3, 3)
		rig:Apply()
		task.wait()
		report(string.format("%s p=%.1f", entry.id, p), rig, borrowed)
	end
	activity:Destroy()
	rig:Release()
	for part, saved in borrowed do
		part.CFrame = saved.cframe
		part.Transparency = saved.transparency
	end
end

-- Duels de boss
local Scene = require(client.BossFights.Scene)
for _, bossId in { "Kevin", "Brayan", "CoachTurbo", "NoLegs", "BlockKing" } do
	if only and only ~= bossId then
		continue
	end
	local anchor = findAnchor("BossSpot", "BossId", bossId)
	if not anchor then
		table.insert(lines, bossId .. " : introuvable")
		continue
	end
	local module = require(client.BossFights:FindFirstChild(bossId))
	local top = stand(module, anchor)
	task.wait(0.2)
	local rig = Rig.new(character)
	local measures = rig:Measure(humanoid)
	local round = module.new({
		rig = rig,
		measures = measures,
		character = character,
		anchor = anchor,
		top = top,
		player = player,
		isLocal = true,
	})
	local scene = round.scene
	local function sample(label: string, p: number)
		rig:Clear()
		round:Pose(p, 0, p * 0.4, os.clock())
		rig:Apply()
		task.wait()
		report(bossId .. " " .. label, rig, {})
		bossReport(label, scene)
	end
	sample("garde", 0)
	round:PlayerRep("Perfect")
	task.wait(0.15)
	sample("coup joueur", 1)
	round:OpponentRep("Perfect")
	task.wait(0.2)
	sample("coup boss", 0)
	-- Fin : le joueur n'est plus animé par la manche
	rig:Release()
	Scene.Finish(player, true)
	task.wait(1.6)
	bossReport("fin gagnée mi-chemin", scene)
	repeat
		task.wait(0.1)
	until not Scene.Active(player)
end

ActivityController.SetBusy(player, false)
root.Anchored = false
humanoid.WalkSpeed = 16
player:SetAttribute("ProbeResult", table.concat(lines, "\n"))
