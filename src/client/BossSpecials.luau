-- Coups spéciaux des boss pendant la dernière manche (validé le 16/10) : chaque boss perturbe la LECTURE du
-- mini-jeu à sa façon, jamais les règles (les fenêtres de timing et le score restent ceux du serveur).
-- Effets doux et lisibles : on voit toujours le mini-jeu.
-- - Kevin « Nap Time » : l'écran s'assombrit par vagues, des Zzz montent.
-- - Brayan « Bronze Glare » : éclairs dorés de son bronzage.
-- - Coach Turbo « Whistle Drill » : coups de sifflet qui secouent l'écran.
-- - Mr. No-Legs « Wobble » : le mini-jeu tangue.
-- - King of the Block « Royal Wind » : le vent de son ventilateur fait dériver le mini-jeu.
-- - The Pump God « Mega Pump » : l'écran gonfle au rythme de son pump.
-- BossSpecials.Start(bossId, root, overlay) -> stop() ; root = cadre du mini-jeu, overlay = ScreenGui des effets.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Texts = require(game:GetService("ReplicatedStorage").Shared.Config.Texts)
local Ui = require(script.Parent.Ui)

local BossSpecials = {}

local function floatingLabel(parent: Instance, text: string, color: Color3, from: UDim2, to: UDim2, duration: number)
	local label = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = from,
		Size = UDim2.fromOffset(90, 60),
		Text = text,
		TextColor3 = color,
		Parent = parent,
	})
	TweenService:Create(label, TweenInfo.new(duration, Enum.EasingStyle.Sine), {
		Position = to,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(duration, function()
		label:Destroy()
	end)
end

local EFFECTS: { [string]: (root: GuiObject, overlay: Instance) -> () -> () } = {}

EFFECTS.Kevin = function(_root, overlay)
	local shade = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 10, 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = overlay,
	})
	local nextZ = 0
	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		-- Jamais plus sombre que 45 % : le mini-jeu reste lisible
		shade.BackgroundTransparency = 0.55 + 0.4 * (0.5 + 0.5 * math.cos(t * 1.4))
		if t > nextZ then
			nextZ = t + 0.7
			local x = 0.2 + math.random() * 0.6
			floatingLabel(
				overlay,
				"Z",
				Color3.fromRGB(180, 200, 255),
				UDim2.fromScale(x, 0.8),
				UDim2.fromScale(x + 0.05, 0.35),
				2.2
			)
		end
	end)
	return function()
		connection:Disconnect()
		shade:Destroy()
	end
end

EFFECTS.Brayan = function(_root, overlay)
	local flash = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 220, 140),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = overlay,
	})
	local running = true
	task.spawn(function()
		while running do
			task.wait(2.2 + math.random() * 1.6)
			if not running then
				break
			end
			flash.BackgroundTransparency = 0.4
			TweenService:Create(flash, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
			floatingLabel(
				overlay,
				"✦",
				Color3.fromRGB(255, 240, 180),
				UDim2.fromScale(0.5, 0.5),
				UDim2.fromScale(0.5, 0.42),
				0.8
			)
		end
	end)
	return function()
		running = false
		flash:Destroy()
	end
end

EFFECTS.CoachTurbo = function(root, overlay)
	local base = root.Position
	local shakeUntil = 0
	local nextWhistle = os.clock() + 1.5
	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		if t > nextWhistle then
			nextWhistle = t + 2.6 + math.random() * 1.2
			shakeUntil = t + 0.45
			floatingLabel(
				overlay,
				Texts.Get("BossSpecial.Whistle"),
				Color3.fromRGB(255, 255, 255),
				UDim2.fromScale(0.85, 0.3),
				UDim2.fromScale(0.85, 0.22),
				0.8
			)
		end
		if t < shakeUntil then
			root.Position = base + UDim2.fromOffset(math.random(-12, 12), math.random(-8, 8))
		else
			root.Position = base
		end
	end)
	return function()
		connection:Disconnect()
		root.Position = base
	end
end

EFFECTS.NoLegs = function(root, _overlay)
	local connection = RunService.RenderStepped:Connect(function()
		root.Rotation = math.sin(os.clock() * 1.3) * 6
	end)
	return function()
		connection:Disconnect()
		root.Rotation = 0
	end
end

EFFECTS.BlockKing = function(root, overlay)
	local base = root.Position
	local nextLeaf = 0
	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		root.Position = base + UDim2.fromOffset(math.sin(t * 0.9) * 40, 0)
		if t > nextLeaf then
			nextLeaf = t + 0.35
			local y = 0.15 + math.random() * 0.7
			floatingLabel(
				overlay,
				"~",
				Color3.fromRGB(220, 220, 255),
				UDim2.fromScale(-0.05, y),
				UDim2.fromScale(1.05, y + 0.05),
				1.4
			)
		end
	end)
	return function()
		connection:Disconnect()
		root.Position = base
	end
end

EFFECTS.PumpGod = function(root, _overlay)
	local scale = Ui.create("UIScale", { Parent = root })
	local connection = RunService.RenderStepped:Connect(function()
		local beat = (os.clock() * 1.2) % 1
		scale.Scale = 1 + 0.05 * math.max(0, 1 - beat * 4)
	end)
	return function()
		connection:Disconnect()
		scale:Destroy()
	end
end

-- Le boss a-t-il un coup spécial ?
function BossSpecials.Has(bossId: string): boolean
	return EFFECTS[bossId] ~= nil
end

function BossSpecials.Start(bossId: string, root: GuiObject, overlay: Instance): () -> ()
	local effect = EFFECTS[bossId]
	if not effect then
		return function() end
	end
	return effect(root, overlay)
end

return BossSpecials
