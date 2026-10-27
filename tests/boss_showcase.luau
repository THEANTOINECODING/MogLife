-- Vitrine d'un duel de boss (D85), pour le regarder dans Studio sans faire un vrai combat (rien n'est envoyé au
-- serveur, aucune donnée touchée). À exécuter comme LocalScript dans PlayerGui (même mémoire que le jeu) :
-- attributs du joueur : ShowcaseBoss (id), ShowcaseWin (fin gagnée ?), puis ShowcaseFinish = true pour jouer la fin.
-- Le joueur est placé devant le boss, des coups (joueur et boss) sont simulés, puis la fin du combat est jouée.
-- La caméra est libre (Custom) : screen_capture peut la placer où il faut.
-- Le script ne doit pas être détruit avant la fin : les boucles de la scène lui appartiennent (ShowcaseDone à la fin).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local client = player.PlayerScripts:WaitForChild("Client")
local Rig = require(client.Activities.Rig)
local Scene = require(client.BossFights.Scene)
local ActivityController = require(client.Controllers.ActivityController)

local bossId = player:GetAttribute("ShowcaseBoss") or "CoachTurbo"
local win = player:GetAttribute("ShowcaseWin") ~= false
local module = require(client.BossFights:FindFirstChild(bossId))

local anchor
for _, spot in game:GetService("CollectionService"):GetTagged("BossSpot") do
	if spot:GetAttribute("BossId") == bossId then
		anchor = spot
	end
end
local character = player.Character
local humanoid = character:FindFirstChildOfClass("Humanoid")
local top = anchor.CFrame * CFrame.new(0, anchor.Size.Y / 2, 0)
character:PivotTo(module.Stand(top) * CFrame.new(0, humanoid.HipHeight + character.HumanoidRootPart.Size.Y / 2, 0))
humanoid.WalkSpeed = 0
task.wait(0.3)
ActivityController.SetBusy(player, true)
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
player:SetAttribute("ShowcaseReady", true)

local qualities = { "Perfect", "Good", "Perfect", "Miss", "Perfect", "Good" }
local repAt, repQuality, repIndex = -math.huge, "Good", 0
local nextPlayer, nextBoss = os.clock() + 0.6, os.clock() + 1.1
local connection = RunService.PreSimulation:Connect(function()
	local now = os.clock()
	if now >= nextPlayer then
		nextPlayer = now + 1.2
		repIndex += 1
		repQuality = if win then qualities[(repIndex - 1) % #qualities + 1] else "Miss"
		repAt = now
		round:PlayerRep(repQuality)
	end
	if now >= nextBoss then
		nextBoss = now + 1.2
		round:OpponentRep(if win then "Miss" else "Perfect")
	end
	-- Même courbe d'effort que ActivityController (montée, maintien, descente)
	local u = math.clamp((now - repAt) / 0.8, 0, 1)
	local p = if u < 0.4 then u / 0.4 elseif u < 0.55 then 1 else 1 - (u - 0.55) / 0.45
	p = p * p * (3 - 2 * p)
	rig:Clear()
	round:Pose(p, if repQuality == "Miss" then 1 else 0, u, now)
	rig:Apply()
end)
repeat
	task.wait(0.1)
until player:GetAttribute("ShowcaseFinish")
connection:Disconnect()
round:Destroy()
rig:Release()
Scene.Finish(player, win)
repeat
	task.wait(0.2)
until not Scene.Active(player)
humanoid.WalkSpeed = 16
player:SetAttribute("ShowcaseDone", true)
