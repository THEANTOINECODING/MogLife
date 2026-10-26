-- Test des 20 mini-jeux (D81) : un robot joue chaque jeu en passant par les vrais gestes du kit (faux appuis, glissés,
-- glisser-déplacer et touches envoyés à Kit.Input), au niveau 2 (toutes les surprises), en même temps.
-- Il lit l'état de chaque partie avec minigame.Probe() et joue « bien ». Un deuxième passage tape au hasard.
-- Résultat attendu : le robot fait surtout des Perfect et peu de ratés ; le hasard rate presque tout.
-- À coller dans execute_luau (Client) pendant une partie dans Studio. Ne touche ni aux données ni au serveur.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local client = Players.LocalPlayer.PlayerScripts:WaitForChild("Client")
local Kit = require(client.MinigameKit)

local DURATION = 22
local LEVEL = 2
local INTERVALS = {
	Swipe = 1.3,
	Ring = 1.0,
	HoldRelease = 1.4,
	Tilt = 1.5,
	Alternate = 1.2,
	Rope = 1.0,
	Twist = 1.6,
	Pressure = 1.2,
	Hammer = 1.4,
	Steer = 1.0,
	Lanes = 1.1,
	Stack = 1.4,
	Catch = 1.1,
	Sequence = 3.5,
	Reaction = 1.4,
	Spotlight = 1.5,
	Beats = 0.9,
	Wobble = 1.5,
	Combo = 2.6,
	Gauge = 0.95,
}
local KEYS = { Up = Enum.KeyCode.Up, Down = Enum.KeyCode.Down, Left = Enum.KeyCode.Left, Right = Enum.KeyCode.Right }

-- Faux signaux (garder l'identité des objets d'entrée, comme UserInputService)
local function signal()
	local handlers = {}
	local object = {}
	function object:Connect(callback)
		handlers[callback] = true
		return {
			Disconnect = function()
				handlers[callback] = nil
			end,
		}
	end
	function object:Fire(...)
		for callback in table.clone(handlers) do
			callback(...)
		end
	end
	return object
end

-- Une source d'entrée par jeu : les gestes d'un robot ne vont qu'à son jeu
local function newControl()
	local input = { InputBegan = signal(), InputChanged = signal(), InputEnded = signal() }
	local far = Vector3.new(5000, 5000, 0) -- loin de tout bouton de l'interface
	local held: { [Enum.KeyCode]: any } = {}
	local touch: any = nil
	local c = { input = input }
	local function keyObject(code)
		return { UserInputType = Enum.UserInputType.Keyboard, KeyCode = code, Position = far }
	end
	function c.key(code)
		local object = keyObject(code)
		input.InputBegan:Fire(object)
		input.InputEnded:Fire(object)
	end
	function c.keyDown(code)
		held[code] = keyObject(code)
		input.InputBegan:Fire(held[code])
	end
	function c.keyUp(code)
		if held[code] then
			input.InputEnded:Fire(held[code])
			held[code] = nil
		end
	end
	function c.touchDown()
		touch = { UserInputType = Enum.UserInputType.Touch, KeyCode = Enum.KeyCode.Unknown, Position = far }
		input.InputBegan:Fire(touch)
	end
	function c.touchMove(dx: number, dy: number)
		if touch then
			touch.Position += Vector3.new(dx, dy, 0)
			input.InputChanged:Fire(touch)
		end
	end
	function c.touchUp()
		if touch then
			input.InputEnded:Fire(touch)
			touch = nil
		end
	end
	function c.tap()
		c.touchDown()
		c.touchUp()
	end
	function c.swipe(direction: string)
		local step = ({
			Up = Vector2.new(0, -1),
			Down = Vector2.new(0, 1),
			Left = Vector2.new(-1, 0),
			Right = Vector2.new(1, 0),
		})[direction]
		c.touchDown()
		c.touchMove(step.X * 120, step.Y * 120)
		c.touchUp()
	end
	function c.touching()
		return touch ~= nil
	end
	return c
end

local function range(): number
	return workspace.CurrentCamera.ViewportSize.Y * 0.6 / 1.15
end

-- Un robot par jeu : (état de la partie, maintenant, commandes, mémoire du robot)
local BOTS = {}
function BOTS.Swipe(p, now, c, m)
	if not p.answered and now >= p.cycleStart and now >= p.hitAt and m.done ~= p.hitAt then
		m.done = p.hitAt
		c.swipe("Up")
	end
end
function BOTS.Ring(p, now, c, m)
	if p.resolved or p.kind == "Red" then
		return
	end
	local hit = p.hits[p.presses + 1]
	if hit and now >= hit and m.last ~= hit then
		m.last = hit
		c.key(Enum.KeyCode.Space)
	end
end
function BOTS.HoldRelease(p, _, c, m)
	if not m.down and p.ready and p.fill < 0.05 then
		m.down = true
		c.keyDown(Enum.KeyCode.Space)
	elseif m.down and (not p.holding or p.fill >= p.center - 0.01) then
		m.down = false
		c.keyUp(Enum.KeyCode.Space)
	end
end
function BOTS.Tilt(p, now, c, m)
	m.phase = m.phase or "Idle"
	if m.phase == "Idle" then
		if p.ready and not p.descending and p.depth < 0.05 then
			c.touchDown()
			m.phase = "Down"
		end
		return
	end
	-- Descend vers la ligne (un peu à la fois, comme un pouce)
	local gap = p.target - p.depth
	c.touchMove(0, math.clamp(gap, -0.04, 0.04) * range())
	if m.phase == "Down" and math.abs(gap) < 0.012 then
		m.phase = "Hold"
		m.since = now
	elseif m.phase == "Hold" then
		local enough = if p.needsPause then p.pausedFor > 0.6 else now - m.since > 0.1
		if enough then
			c.touchUp()
			m.phase = "Idle"
		end
	end
end
function BOTS.Alternate(p, now, c, m)
	if p.resolved or now < p.beatAt or m.last == p.beatAt then
		return
	end
	m.last = p.beatAt
	if p.expected == "Both" then
		c.key(Enum.KeyCode.A)
		c.key(Enum.KeyCode.D)
	else
		c.key(if p.expected == "Left" then Enum.KeyCode.A else Enum.KeyCode.D)
	end
end
function BOTS.Rope(p, now, c, m)
	if not p.jumped and now >= p.bottomAt and m.last ~= p.bottomAt then
		m.last = p.bottomAt
		c.key(Enum.KeyCode.Space)
	end
end
function BOTS.Twist(p, now, c, m)
	if not p.resting and p.phase == "Free" and now - (m.t or 0) > 0.08 then
		m.t = now
		c.key(Enum.KeyCode.Space)
	end
end
function BOTS.Pressure(p, _, c)
	if not c.touching() then
		c.touchDown()
	end
	local range = workspace.CurrentCamera.ViewportSize.Y * 0.35 / 1.15
	local need = p.center - p.pressure
	if p.state ~= "Pumping" or need <= p.half * 0.4 then
		-- Rien à pomper : la poignée remonte (remonter n'envoie pas d'air)
		c.touchMove(0, -0.1 * range)
	elseif p.stroke >= 0.95 then
		c.touchMove(0, -range)
	else
		c.touchMove(0, math.min(need / p.airPerStroke, 0.04) * range)
	end
end
function BOTS.Hammer(p, now, c, m)
	if p.ready and p.forward and now - (m.t or 0) > 0.4 and math.abs(p.hammerX - p.nailX) < 0.02 then
		m.t = now
		c.key(Enum.KeyCode.Space)
	end
end
function BOTS.Steer(p, _, c)
	if not c.touching() then
		c.touchDown()
	end
	-- Esquive : se mettre du côté opposé à l'obstacle, par rapport à la route
	local target = p.center
	for _, obstacle in p.obstacles do
		if obstacle.y > 0.5 and obstacle.y < 0.9 then
			target = p.center + (if obstacle.offset > 0 then -0.12 else 0.12)
		end
	end
	c.touchMove(math.clamp(target - p.carX, -0.05, 0.05) * p.width / 1.15, 0)
end
function BOTS.Lanes(p, now, c, m)
	if p.free and p.free ~= p.lane and now - (m.t or 0) > 0.1 then
		m.t = now
		c.swipe(if p.free < p.lane then "Left" else "Right")
	end
end
function BOTS.Stack(p, _, c)
	if p.ready and math.abs(p.movingX - p.topX) < 0.012 then
		c.key(Enum.KeyCode.Space)
	end
end
function BOTS.Catch(p, _, c)
	if not c.touching() then
		c.touchDown()
	end
	local target, best = p.basketX, -1
	for _, item in p.items do
		if not item.hazard and item.progress > best then
			best = item.progress
			target = item.x
		end
	end
	for _, item in p.items do
		if item.hazard and item.progress > 0.6 and math.abs(item.x - target) < 0.15 then
			target += if item.x > target then -0.15 else 0.15
		end
	end
	c.touchMove(math.clamp(target - p.basketX, -0.05, 0.05) * p.width / 1.15, 0)
end
function BOTS.Sequence(p, now, c, m)
	if p.state == "Input" and now - (m.t or 0) > 0.15 and p.path[p.typed + 1] then
		m.t = now
		c.key(KEYS[p.path[p.typed + 1]])
	end
end
function BOTS.Reaction(p, now, c, m)
	if not p.resolved and now >= p.showAt + 0.15 and m.last ~= p.showAt then
		m.last = p.showAt
		c.key(KEYS[p.direction])
	end
end
function BOTS.Spotlight(p, _, c)
	if not c.touching() then
		c.touchDown()
	end
	local gap = p.sun - p.cursor
	c.touchMove(math.clamp(gap.X, -0.04, 0.04) * p.size.X / 1.15, math.clamp(gap.Y, -0.04, 0.04) * p.size.Y / 1.15)
end
function BOTS.Beats(p, now, c, m)
	m.down = m.down or {}
	for _, note in p.notes do
		local key = if note.lane == "Left" then Enum.KeyCode.A else Enum.KeyCode.D
		if not m.down[note] and not note.held and now >= note.arrivesAt then
			m.down[note] = true
			c.keyDown(key)
			if not note.endsAt then
				c.keyUp(key)
			end
		elseif note.held and note.endsAt and now >= note.endsAt - 0.05 then
			c.keyUp(key)
		end
	end
end
function BOTS.Wobble(p, now, c, m)
	m.done = m.done or {}
	for _, fist in p.fists do
		if not fist.resolved and not m.done[fist] and now >= fist.impactAt then
			m.done[fist] = true
			c.key(KEYS[fist.side])
		end
	end
end
function BOTS.Combo(p, now, c, m)
	if p.active and now >= p.startedAt and now - (m.t or 0) > 0.1 and p.combo[p.typed + 1] then
		m.t = now
		c.key(KEYS[p.combo[p.typed + 1]])
	end
end
function BOTS.Gauge(p, now, c, m)
	if p.resolved or now - (m.t or 0) < 0.06 then
		return
	end
	local target = if p.effort then p.targets[p.hits + 1] else p.zone
	if target and math.abs(p.position - target) < 0.02 then
		m.t = now
		c.key(Enum.KeyCode.Space)
	end
end

-- Robot « au hasard » : touche, glisse et appuie n'importe quand
local function randomBot(_, now, c, m)
	if now - (m.t or 0) > 0.35 + math.random() * 0.4 then
		m.t = now
		local roll = math.random(1, 4)
		if roll == 1 then
			c.key(Enum.KeyCode.Space)
		elseif roll == 2 then
			c.swipe(({ "Up", "Down", "Left", "Right" })[math.random(1, 4)])
		elseif roll == 3 then
			c.key(({ Enum.KeyCode.A, Enum.KeyCode.D })[math.random(1, 2)])
		else
			c.touchDown()
			c.touchMove(math.random(-60, 60), math.random(-60, 60))
			c.touchUp()
		end
	end
end

local function run(useRandom: boolean)
	local errors = {}
	local log = game:GetService("LogService").MessageOut:Connect(function(message, kind)
		if kind == Enum.MessageType.MessageError then
			table.insert(errors, message)
		end
	end)
	Kit.StepSignal = RunService.Heartbeat
	local sessions = {}
	for _, module in client.Minigames:GetChildren() do
		local control = newControl()
		Kit.Input = control.input -- lu par le mini-jeu à sa création (ses connexions)
		local gui = Instance.new("ScreenGui")
		gui.Name = "BotTest"
		gui.Parent = Players.LocalPlayer.PlayerGui
		local root = Instance.new("Frame")
		root.Size = UDim2.fromOffset(1280, 720)
		root.Parent = gui
		local counts = { Perfect = 0, Good = 0, Miss = 0 }
		local minigame = require(module).new(root, INTERVALS[module.Name] or 1, function(quality)
			counts[quality] += 1
		end, { level = LEVEL, name = "Bot" .. module.Name, total = 8, seed = 3, timingScale = 1 })
		sessions[module.Name] = { minigame = minigame, gui = gui, control = control, counts = counts, memory = {} }
	end
	Kit.Input = game:GetService("UserInputService")
	local connection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for name, session in sessions do
			local ok, err = pcall(function()
				local probe = session.minigame.Probe()
				if useRandom then
					randomBot(probe, now, session.control, session.memory)
				else
					BOTS[name](probe, now, session.control, session.memory)
				end
			end)
			if not ok then
				table.insert(errors, name .. ": " .. tostring(err))
				session.memory.broken = true
			end
		end
	end)
	task.wait(DURATION)
	connection:Disconnect()
	local out = {}
	for name, session in sessions do
		session.minigame:Destroy()
		session.gui:Destroy()
		local c = session.counts
		out[name] = string.format("P%d G%d M%d", c.Perfect, c.Good, c.Miss)
	end
	Kit.StepSignal = nil
	log:Disconnect()
	out._errors = errors
	return out
end

return HttpService:JSONEncode({ bot = run(false), random = run(true) })
