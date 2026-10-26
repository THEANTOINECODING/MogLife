-- Mini-jeu « Lanes » (aide : porter le piano de Mme Do-Ré, D81) : le piano avance dans un couloir à 3 voies ;
-- chaque vague de vases bloque 2 voies sur 3. Glisser le pouce à gauche ou à droite (n'importe où) pour rejoindre
-- la voie libre. Vague passée = Perfect (Good si esquive de dernière seconde), vase percuté = raté.
-- Les vagues tombent plus vite à chaque niveau ; vagues doubles (niveau Lanes.DoubleLevel).
-- Clavier : A / D, flèches ; manette : croix, coup de stick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Kit = require(script.Parent.Parent.MinigameKit)
local Ui = require(script.Parent.Parent.Ui)

local SETTINGS = Balance.Minigames.Lanes
local LANES = 3
local PIANO_Y = 0.8

local Lanes = {}

function Lanes.new(parent: GuiObject, interval: number, onRep: (string) -> (), options)
	local self = Kit.new(parent, interval, onRep, options)
	local panel = self:Panel(UDim2.fromOffset(330, 420))
	local rng = self:Random()

	local hall = Ui.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		BackgroundColor3 = Color3.fromRGB(235, 215, 185),
		ClipsDescendants = true,
		Parent = panel,
	}, { Ui.corner(UDim.new(0, 12)) })
	for index = 1, LANES - 1 do
		Ui.create("Frame", {
			Position = UDim2.fromScale(index / LANES, 0),
			Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = Color3.fromRGB(190, 160, 125),
			Parent = hall,
		})
	end
	local piano = self:Emoji(hall, "🎹", 76, 5)
	local free = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(1 / LANES, -8, 0, 10),
		BackgroundColor3 = Color3.fromRGB(90, 220, 100),
		BackgroundTransparency = 0.3,
		ZIndex = 2,
		Parent = hall,
	}, { Ui.corner(UDim.new(1, 0)) })

	local lane = 2
	local laneShown = 2
	local lastMoveAt = 0
	local fallTime = interval * math.max(SETTINGS.FallFactor - SETTINGS.FallPerLevel * self.level, SETTINGS.FallMin)
	local waves = {} -- { free = voie libre, spawnedAt, labels }
	local nextSpawn = 0.4

	local function laneX(index: number): number
		return (index - 0.5) / LANES
	end

	local function spawn(t: number)
		-- La voie libre n'est jamais celle où se trouve le piano : il faut bouger à chaque vague
		local freeLane = rng:NextInteger(1, LANES - 1)
		if freeLane >= lane then
			freeLane += 1
		end
		local wave = { free = freeLane, spawnedAt = t, labels = {} }
		for vaseLane = 1, LANES do
			if vaseLane ~= wave.free then
				wave.labels[vaseLane] = self:Emoji(hall, "🏺", 52, 3)
			end
		end
		table.insert(waves, wave)
	end

	self:OnSwipe(function(direction)
		local before = lane
		if direction == "Left" then
			lane = math.max(lane - 1, 1)
		elseif direction == "Right" then
			lane = math.min(lane + 1, LANES)
		end
		if lane ~= before then
			lastMoveAt = os.clock()
		end
	end)
	self:Guide(panel, "SwipeLeft")

	self:OnStep(function(dt, t)
		if t >= nextSpawn then
			spawn(t)
			nextSpawn = t + interval
			if self.level >= SETTINGS.DoubleLevel and rng:NextNumber() < SETTINGS.DoubleChance then
				-- Une deuxième vague juste derrière, puis une pause plus longue (la cadence moyenne ne change pas)
				task.delay(interval * 0.5, function()
					if not self.destroyed then
						spawn(os.clock() - self.startTime)
					end
				end)
				nextSpawn = t + interval * 1.5
				self:Announce("Minigame.Twist.Lanes.Double")
			end
		end

		for index = #waves, 1, -1 do
			local wave = waves[index]
			local progress = (t - wave.spawnedAt) / fallTime
			for vaseLane, label in wave.labels do
				label.Position = UDim2.fromScale(laneX(vaseLane), progress * PIANO_Y)
			end
			if progress >= 1 then
				if lane ~= wave.free then
					local blocker = wave.labels[lane]
					if blocker then
						blocker.Text = "💥"
					end
					self:Rep("Miss", piano)
				else
					local sinceMove = os.clock() - lastMoveAt
					local late = sinceMove < SETTINGS.LastSecond / self.timingScale
					-- Déjà dans la bonne voie sans avoir bougé pendant toute la chute : Good, pas Perfect
					local idle = sinceMove > fallTime
					self:Rep(if late or idle then "Good" else "Perfect", piano)
				end
				for _, label in wave.labels do
					task.delay(0.15, function()
						label:Destroy()
					end)
				end
				table.remove(waves, index)
			end
		end
		-- La voie libre de la vague la plus proche est soulignée en vert
		local nearest = waves[1]
		free.Visible = nearest ~= nil
		if nearest then
			free.Position = UDim2.fromScale(laneX(nearest.free), PIANO_Y + 0.1)
		end

		-- Le piano glisse vers sa voie
		laneShown += (lane - laneShown) * math.min(dt * 18, 1)
		piano.Position = UDim2.fromScale(laneX(laneShown), PIANO_Y + 0.08)
	end)

	-- État de la partie pour les tests automatiques (tests/minigames_bot.luau) : ne change rien au jeu
	function self.Probe()
		return { lane = lane, free = waves[1] and waves[1].free }
	end

	return self
end

return Lanes
