-- Mini-jeu « Wobble » (boss : Monsieur Pas-Les-Jambes, D81) : il pousse avec son poing ; le poing arrive d'un côté
-- (sa trajectoire est tracée), glisser le pouce vers lui (n'importe où) au moment du choc pour le bloquer.
-- Trop tôt, trop tard ou mauvais sens = on vacille (raté). Le poing arrive plus vite à chaque manche.
-- Surprises : coups venant d'en haut (niveau Wobble.UpLevel), deux poings à la suite (niveau Wobble.DoubleLevel).
-- Clavier : flèches, ZQSD/WASD ; manette : croix, coup de stick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Wobble
local ORIGIN = { Left = Vector2.new(-0.05, 0.5), Right = Vector2.new(1.05, 0.5), Up = Vector2.new(0.5, -0.05) }
local CENTER = Vector2.new(0.5, 0.5)
local CONTACT = 0.16 -- distance au centre où le poing touche

local Wobble = {}

function Wobble.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(360, 360))
	local rng = self:Random()

	local arena = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = Color3.fromRGB(45, 35, 70),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(130, 22),
		BackgroundColor3 = Color3.fromRGB(110, 90, 150),
		Parent = arena,
	}, { Ui.corner(UDim.new(1, 0)) })
	local me = self:Emoji(arena, "🧍", 90, 4)
	me.Position = UDim2.fromScale(0.5, 0.5)
	local shield = self:Emoji(arena, "🛡️", 54, 5)
	shield.Visible = false

	local approach = interval * math.max(SETTINGS.Approach - SETTINGS.ApproachPerLevel * self.level, 0.55)
	-- { side, impactAt, label, lane (trajectoire), resolved }
	local fists = {}
	local nextFist = os.clock() + interval * 0.4
	local blockAt = -math.huge
	local blockSide = "Left"
	local wobbleAt = -math.huge

	local function spawnFist(at: number)
		local sides = { "Left", "Right" }
		if self.level >= SETTINGS.UpLevel then
			table.insert(sides, "Up")
		end
		local side = sides[rng:NextInteger(1, #sides)]
		if side == "Up" then
			self:Announce("Minigame.Twist.Wobble.Up")
		end
		local origin = ORIGIN[side]
		local horizontal = side ~= "Up"
		table.insert(fists, {
			side = side,
			spawnAt = at,
			impactAt = at + approach,
			label = self:Emoji(arena, "👊", 64, 6),
			lane = Ui.create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale((origin.X + CENTER.X) / 2, (origin.Y + CENTER.Y) / 2),
				Size = if horizontal then UDim2.new(0.5, 0, 0, 16) else UDim2.new(0, 16, 0.5, 0),
				BackgroundColor3 = Color3.fromRGB(255, 90, 90),
				BackgroundTransparency = 0.75,
				ZIndex = 2,
				Parent = arena,
			}, { Ui.corner(UDim.new(1, 0)) }),
			resolved = false,
		})
	end

	local function clear(index: number)
		local fist = fists[index]
		fist.label:Destroy()
		fist.lane:Destroy()
		table.remove(fists, index)
	end

	local function resolve(index: number, quality: string)
		local fist = fists[index]
		fist.resolved = true
		if quality == "Miss" then
			wobbleAt = os.clock()
		end
		self:Rep(quality, me)
		task.delay(0.15, function()
			for position, other in fists do
				if other == fist then
					clear(position)
					break
				end
			end
		end)
	end

	self:OnSwipe(function(direction)
		local now = os.clock()
		-- Le poing le plus proche du choc
		local best, bestOffset = nil, math.huge
		for index, fist in fists do
			local offset = math.abs(fist.impactAt - now)
			if not fist.resolved and offset < bestOffset then
				best, bestOffset = index, offset
			end
		end
		if not best then
			return
		end
		local fist = fists[best]
		-- Trop tôt (le poing est encore loin) : on lance le bras dans le vide
		if bestOffset > interval * 0.5 then
			return
		end
		blockAt = now
		blockSide = direction
		local quality = if direction == fist.side
			then self:GradeError(bestOffset, SETTINGS.PerfectTime, SETTINGS.GoodTime)
			else "Miss"
		resolve(best, quality)
	end)
	self:Guide(panel, "SwipeLeft")

	self:OnStep(function()
		local now = os.clock()
		if now >= nextFist then
			spawnFist(nextFist)
			nextFist += interval
			if self.level >= SETTINGS.DoubleLevel and rng:NextNumber() < SETTINGS.DoubleChance then
				-- Deuxième poing juste derrière, puis une pause (la cadence moyenne ne change pas)
				spawnFist(nextFist - interval * 0.5)
				nextFist += interval * 0.5
				self:Announce("Minigame.Twist.Wobble.Double")
			end
		end
		for index = #fists, 1, -1 do
			local fist = fists[index]
			local progress = math.clamp((now - fist.spawnAt) / approach, 0, 1)
			local origin = ORIGIN[fist.side]
			local stop = CENTER + (origin - CENTER).Unit * CONTACT
			local position = origin:Lerp(stop, progress)
			fist.label.Position = UDim2.fromScale(position.X, position.Y)
			fist.label.Rotation = if fist.side == "Right" then 180 elseif fist.side == "Up" then 90 else 0
			fist.lane.BackgroundTransparency = 0.85 - 0.35 * progress
			-- Pas bloqué à temps : on vacille
			if not fist.resolved and now - fist.impactAt > SETTINGS.GoodTime * self.timingScale then
				resolve(index, "Miss")
			end
		end
		local first = fists[1]
		if first and not first.resolved then
			self.guideDirection = first.side
			if math.abs(first.impactAt - now) < 0.02 then
				self:GuideCue()
			end
		end
		-- Bouclier dans le sens du blocage, personnage qui vacille après un raté
		local sinceBlock = now - blockAt
		shield.Visible = sinceBlock < 0.25
		local offset = (ORIGIN[blockSide] or CENTER) - CENTER
		shield.Position = UDim2.fromScale(0.5 + offset.X * 0.25, 0.5 + offset.Y * 0.25)
		local sinceWobble = now - wobbleAt
		me.Rotation = if sinceWobble < 0.5 then math.sin(sinceWobble * 30) * 25 * (1 - sinceWobble / 0.5) else 0
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { fists = fists }
	end

	return self
end

return Wobble
