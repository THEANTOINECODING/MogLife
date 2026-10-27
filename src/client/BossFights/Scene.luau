-- Base commune des duels de boss (D85) : un duel physique par boss (tir à la corde, bataille de polochons…), joué dans
-- le monde et vu par tous les joueurs proches. Le mini-jeu et ses règles ne changent pas : chaque coup du joueur et du
-- boss (envoyés à tous par le serveur) devient une action dans la scène, et une position visible montre qui mène.
--
-- Une scène vit tout le combat (3 manches) : elle est créée à la première manche, reprise aux suivantes, et jouée
-- jusqu'à sa fin (victoire ou défaite, état « FightEnd » envoyé à tous) ; sans nouvelle manche ni fin, elle disparaît.
-- ActivityController la traite comme une activité : Stand(top), new(ctx), Pose(...), PlayerRep, OpponentRep, Destroy.
--
-- Une définition de duel (BossFights/<BossId>.luau) fournit :
--   Distance                         studs entre le centre de l'estrade du boss et le joueur
--   BossShift                        le boss recule d'autant vers le fond de son estrade pendant le duel
--   Setup(scene)                     accessoires du duel
--   PlayerPose(scene, rig, m, p, shake, now)   le joueur pendant une manche (Rig de ActivityController)
--   Boss(scene, dt, now)             le boss, à chaque image (scene.bossRig peut être nil : ancien modèle sans os)
--   PlayerRep(scene, quality)        coup du joueur ; BossRep(scene, quality) : coup du boss
--   Finish(scene, won, t, rig, m)    fin du combat, t de 0 à 1 (le joueur est animé par la scène)
--   BossFeet                         (facultatif) écart des pieds du boss { Left = Vector3, Right = Vector3 },
--                                    dans son repère (X à sa droite, Z derrière lui) : une fente, des pieds écartés
-- Pendant les manches, les pieds du boss restent posés à plat sur le sol (D86) : ses déplacements (scene:MoveBoss)
-- penchent et abaissent le corps, les jambes se plient ; seul un saut (décalage vers le haut) les décolle.
-- Réglages communs dans Config/BossFights.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Fights = require(ReplicatedStorage.Shared.Config.BossFights)
local Props = require(script.Parent.Parent.Activities.Props)
local Rig = require(script.Parent.Parent.Activities.Rig)
local BossRig = require(script.Parent.BossRig)

local QUALITY_POINTS = Balance.Boss.QualityScore

export type Def = {
	Distance: number,
	BossShift: number?,
	BossFeet: { Left: Vector3?, Right: Vector3? }?,
	Setup: ((any) -> ())?,
	PlayerPose: (any, any, any, number, number, number) -> (),
	Boss: (any, number, number) -> (),
	PlayerRep: ((any, string) -> ())?,
	BossRep: ((any, string) -> ())?,
	Finish: (any, boolean, number, any, any) -> (),
}

local Scene = {}
Scene.__index = Scene

local scenes: { [Player]: any } = {}
local hooks = { setBusy = nil :: ((Player, boolean) -> ())?, npcBase = nil :: ((Model) -> CFrame?)? }

-- Branchements fournis par les contrôleurs (ActivityController, NpcController)
function Scene.Connect(setBusy: (Player, boolean) -> (), npcBase: (Model) -> CFrame?)
	hooks.setBusy = setBusy
	hooks.npcBase = npcBase
end

local function findBoss(anchor: BasePart, bossId: string): Model?
	local folder = workspace:FindFirstChild("Npcs")
	local best, bestDistance = nil, 30
	for _, model in if folder then folder:GetChildren() else {} do
		if model:IsA("Model") and model:GetAttribute("BossId") == bossId and model.PrimaryPart then
			local distance = (model.PrimaryPart.Position - anchor.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	return best
end

local function create(player: Player, bossId: string, def: Def, ctx): any
	local boss = findBoss(ctx.anchor, bossId)
	local self = setmetatable({
		player = player,
		bossId = bossId,
		def = def,
		anchor = ctx.anchor,
		top = ctx.top,
		boss = boss,
		bossPart = boss and boss.PrimaryPart,
		bossRig = boss and BossRig.new(boss),
		props = Props.new("BossFight_" .. player.UserId),
		round = 0,
		points = 0, -- points du joueur dans la manche en cours
		bossPoints = 0,
		lead = 0, -- -1 (le boss domine) à 1 (le joueur domine), lissé
		playerHitAt = -math.huge,
		playerQuality = "Good",
		bossHitAt = -math.huge,
		bossQuality = "Good",
		finishing = false,
		data = {}, -- état propre au duel
	}, Scene)
	-- Le boss est à la scène : NpcController ne l'anime plus (attribut local à ce client)
	if boss then
		boss:SetAttribute("FightScene", true)
		self.bossScale = boss:GetScale()
		-- Sa place de repos (rendue à la fin), et sa place pendant le duel : un peu plus au fond de l'estrade
		self.home = (hooks.npcBase and hooks.npcBase(boss)) or (self.bossPart :: BasePart).CFrame
		self.base = self.home * CFrame.new(0, 0, def.BossShift or 0)
	end
	-- Axe du duel : du boss vers l'endroit où se tient le joueur
	local stand = ctx.top * CFrame.new(0, 0, -def.Distance)
	self.ground = ctx.top.Position.Y
	self.playerSpot = stand.Position
	self.bossSpot = if self.base then self.base.Position else ctx.top.Position
	local axis = (self.playerSpot - self.bossSpot) * Vector3.new(1, 0, 1)
	self.toPlayer = if axis.Magnitude > 0.01 then axis.Unit else Vector3.zAxis
	self.middle = (self.playerSpot + self.bossSpot) / 2
	self.middle = Vector3.new(self.middle.X, self.ground, self.middle.Z)
	if def.Setup then
		def.Setup(self)
	end
	self.connection = RunService.PreSimulation:Connect(function(dt)
		self:Step(dt)
	end)
	return self
end

function Scene.Step(self, dt: number)
	if self.boss and not self.boss.Parent then
		self:Cleanup()
		return
	end
	local now = os.clock()
	local wanted =
		math.clamp((self.points - self.bossPoints) / (Balance.Boss.RepsPerRound * 100) * Fights.LeadGain, -1, 1)
	self.lead += (wanted - self.lead) * math.min(dt * Fights.LeadSpeed, 1)
	if self.bossRig then
		self.bossRig:Clear()
	end
	if self.finishing then
		local t = math.clamp((now - self.finishAt) / Fights.FinishTime, 0, 1)
		self:FinishFrame(t)
		if t >= 1 then
			self:Cleanup()
		end
		return
	end
	self.bossOffset = CFrame.identity
	self.def.Boss(self, dt, now)
	if self.bossRig then
		self:PlantBoss()
		self.bossRig:Apply()
	end
end

-- Corps entier du boss : décalage par rapport à sa place (repère du boss). Pendant les manches, autour de ses pieds
-- (et non du centre du corps : il se penche et vacille sans passer sous le sol) ; pendant la fin, autour du centre
-- (chutes et envols réglés ainsi).
function Scene.MoveBoss(self, offset: CFrame)
	if self.bossPart and self.base then
		local feet = if self.finishing then CFrame.identity else CFrame.new(0, -self.bossPart.Size.Y / 2, 0)
		self.bossPart.CFrame = self.base * feet * offset * feet:Inverse()
		self.bossOffset = offset
	end
end

-- Pieds du boss posés au sol, là où le décalage du corps l'a emmené (glissade, demi-tour) ; un décalage vers le haut
-- est un saut : les pieds décollent
function Scene.PlantBoss(self)
	local rig = self.bossRig
	if not rig or not self.base then
		return
	end
	local offset = self.bossOffset or CFrame.identity
	local _, yaw = offset:ToEulerAnglesYXZ()
	local stance = self.base * CFrame.new(offset.X, 0, offset.Z) * CFrame.Angles(0, yaw, 0)
	rig:PlantFeet(stance, self.def.BossFeet, math.max(offset.Y, 0))
end

-- Repère « du duel » : centré au milieu, X vers la droite du joueur, Z vers le joueur
function Scene.Frame(self): CFrame
	return CFrame.lookAt(self.middle, self.middle - self.toPlayer)
end

-- Courbe d'une réaction : 0 avant, monte puis redescend sur `duration` secondes
function Scene.Pulse(_self, since: number, duration: number): number
	if since < 0 or since > duration then
		return 0
	end
	return math.sin(math.pi * since / duration)
end

-- Dernière manche : le coup spécial du boss est en cours
function Scene.Special(self): boolean
	return self.round >= Balance.Boss.Rounds
end

function Scene.FinishFrame(self, t: number)
	local character = self.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	self.outroRig = self.outroRig or (character and Rig.new(character))
	if self.outroRig and humanoid and not self.outroMeasures then
		self.outroMeasures = self.outroRig:Measure(humanoid)
	end
	if self.outroRig then
		self.outroRig:Clear()
	end
	self.def.Finish(self, self.won, t, self.outroRig, self.outroMeasures)
	if self.outroRig then
		self.outroRig:Apply()
	end
	if self.bossRig then
		self.bossRig:Apply()
	end
end

function Scene.Cleanup(self)
	if self.cleaned then
		return
	end
	self.cleaned = true
	scenes[self.player] = nil
	if self.connection then
		self.connection:Disconnect()
	end
	self.props:Destroy()
	if self.bossRig then
		self.bossRig:Release()
	end
	if self.boss and self.boss.Parent then
		if self.bossScale and math.abs(self.boss:GetScale() - self.bossScale) > 1e-3 then
			self.boss:ScaleTo(self.bossScale)
		end
		if self.bossPart and self.home and not self.boss:GetAttribute("Scripted") then
			self.bossPart.CFrame = self.home
		end
		self.boss:SetAttribute("FightScene", nil)
	end
	if self.outroRig then
		self.outroRig:Release()
	end
	if hooks.setBusy then
		hooks.setBusy(self.player, false)
	end
end

-- ------------------------------------------------------------------ activité (une par manche)

local Round = {}
Round.__index = Round

-- Module d'activité d'un boss, pour ActivityController
function Scene.Activity(bossId: string, def: Def)
	local activity = {}
	activity.__index = activity
	function activity.Stand(top: CFrame): CFrame
		return top * CFrame.new(0, 0, -def.Distance) * CFrame.Angles(0, math.pi, 0)
	end
	function activity.new(ctx)
		local player = ctx.player :: Player
		local scene = scenes[player]
		if scene and (scene.bossId ~= bossId or scene.finishing) then
			scene:Cleanup()
			scene = nil
		end
		if not scene then
			scene = create(player, bossId, def, ctx)
			scenes[player] = scene
		end
		scene.round += 1
		scene.points, scene.bossPoints = 0, 0
		scene.expireToken = (scene.expireToken or 0) + 1
		return setmetatable({ scene = scene, ctx = ctx }, Round)
	end
	return activity
end

function Round:Pose(p: number, shake: number, _u: number, time: number)
	local scene = self.scene
	if scene.cleaned then
		return
	end
	scene.def.PlayerPose(scene, self.ctx.rig, self.ctx.measures, p, shake, time)
end

function Round:PlayerRep(quality: string)
	local scene = self.scene
	scene.points += QUALITY_POINTS[quality] or 0
	scene.playerHitAt = os.clock()
	scene.playerQuality = quality
	if scene.def.PlayerRep then
		scene.def.PlayerRep(scene, quality)
	end
end

function Round:OpponentRep(quality: string)
	local scene = self.scene
	scene.bossPoints += QUALITY_POINTS[quality] or 0
	scene.bossHitAt = os.clock()
	scene.bossQuality = quality
	if scene.def.BossRep then
		scene.def.BossRep(scene, quality)
	end
end

-- Fin de manche : la scène reste (pause entre deux manches) ; sans suite, elle disparaît
function Round:Destroy()
	local scene = self.scene
	local token = scene.expireToken
	task.delay(Fights.Linger, function()
		if scenes[scene.player] == scene and scene.expireToken == token and not scene.finishing then
			scene:Cleanup()
		end
	end)
end

-- Fin du combat (vue par tous) : la scène joue sa fin, puis disparaît
function Scene.Finish(player: Player, won: boolean)
	local scene = scenes[player]
	if not scene or scene.finishing then
		return
	end
	scene.finishing = true
	scene.won = won
	scene.finishAt = os.clock()
	if hooks.setBusy then
		hooks.setBusy(player, true)
	end
end

-- Duel en cours pour ce joueur (BossController : timing de la fin)
function Scene.Active(player: Player): boolean
	return scenes[player] ~= nil
end

Players.PlayerRemoving:Connect(function(player)
	local scene = scenes[player]
	if scene then
		scene:Cleanup()
	end
end)

return Scene
