-- Petites silhouettes dessinées en UI : chaque activité garde un décor identifiable sans texture ni asset externe.
-- Elles restent derrière le geste et l'objectif pour préserver la lisibilité sur téléphone.

local Ui = require(script.Parent.Ui)

local SceneArt = {}

function SceneArt.Build(parent: GuiObject, name: string, accent: Color3)
	local gold = Color3.fromRGB(255, 216, 103)
	local pale = Color3.fromRGB(231, 235, 246)
	local dark = Color3.fromRGB(18, 17, 32)
	local function shape(x: number, y: number, w: number, h: number, color: Color3, angle: number?, round: boolean?)
		return Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			Rotation = angle or 0,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.43,
			ZIndex = 1,
			Parent = parent,
		}, { Ui.corner(if round then UDim.new(1, 0) else UDim.new(0, 5)) })
	end
	local function ring(x: number, y: number, w: number, h: number, color: Color3)
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			BackgroundTransparency = 1,
			ZIndex = 1,
			Parent = parent,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(color, 4, 0.25) })
	end

	if name == "WatermelonCurl" then
		shape(0.5, 0.57, 0.62, 0.035, pale)
		ring(0.2, 0.57, 0.2, 0.32, accent)
		ring(0.8, 0.57, 0.2, 0.32, accent)
	elseif name == "ChestCatapult" then
		shape(0.5, 0.79, 0.66, 0.07, gold)
		for i = 1, 4 do
			shape(0.39 + i * 0.045, 0.7 - i * 0.095, 0.2, 0.025, accent, if i % 2 == 0 then 28 else -28)
		end
	elseif name == "BarRescue" then
		shape(0.5, 0.31, 0.8, 0.035, pale)
		for _, x in { 0.16, 0.84 } do
			shape(x, 0.31, 0.08, 0.21, accent, 0, true)
		end
	elseif name == "CrackedFloor" then
		for _, x in { 0.2, 0.5, 0.8 } do
			shape(x, 0.65, 0.27, 0.2, dark)
			shape(x, 0.55, 0.27, 0.025, accent)
		end
		shape(0.2, 0.66, 0.15, 0.015, gold, -31)
		shape(0.8, 0.66, 0.15, 0.015, gold, 31)
	elseif name == "TravelingBar" then
		shape(0.5, 0.25, 0.86, 0.045, pale)
		for _, x in { 0.2, 0.5, 0.8 } do
			shape(x, 0.35, 0.05, 0.23, accent, 0, true)
		end
	elseif name == "ShowRope" then
		shape(0.18, 0.53, 0.035, 0.66, gold)
		shape(0.82, 0.53, 0.035, 0.66, gold)
		shape(0.5, 0.67, 0.64, 0.025, accent, 0, true)
	elseif name == "SecretSeal" then
		shape(0.5, 0.57, 0.36, 0.42, accent)
		shape(0.5, 0.34, 0.44, 0.075, gold)
		ring(0.5, 0.48, 0.22, 0.24, pale)
	elseif name == "LeakHunt" then
		ring(0.5, 0.51, 0.51, 0.72, dark)
		ring(0.5, 0.51, 0.27, 0.42, accent)
		shape(0.75, 0.44, 0.035, 0.16, pale, 18)
	elseif name == "NailAngle" then
		shape(0.5, 0.73, 0.7, 0.14, gold)
		for _, x in { 0.26, 0.5, 0.74 } do
			shape(x, 0.59, 0.035, 0.22, pale)
		end
	elseif name == "CarSlingshot" then
		shape(0.5, 0.66, 0.92, 0.38, dark)
		for _, x in { 0.18, 0.42, 0.66, 0.9 } do
			shape(x, 0.67, 0.12, 0.018, gold)
		end
	elseif name == "PianoPivot" then
		shape(0.5, 0.47, 0.72, 0.5, pale)
		for i = 1, 5 do
			shape(0.22 + i * 0.1, 0.55, 0.055, 0.28, dark)
		end
	elseif name == "PerfectSpot" then
		shape(0.5, 0.81, 0.92, 0.16, gold)
		shape(0.68, 0.43, 0.025, 0.58, pale)
		shape(0.68, 0.19, 0.39, 0.1, accent, 18)
	elseif name == "ImpossibleBag" then
		shape(0.5, 0.59, 0.45, 0.42, gold)
		ring(0.5, 0.34, 0.28, 0.31, pale)
		shape(0.5, 0.7, 0.36, 0.04, accent)
	elseif name == "LivingPostcard" then
		shape(0.5, 0.53, 0.78, 0.63, pale)
		shape(0.4, 0.59, 0.32, 0.12, accent, -25)
		shape(0.68, 0.54, 0.31, 0.12, accent, 25)
		shape(0.75, 0.36, 0.11, 0.16, gold, 0, true)
	elseif name == "SofaEscape" then
		shape(0.5, 0.62, 0.66, 0.25, accent)
		shape(0.5, 0.42, 0.66, 0.22, accent)
		for _, x in { 0.19, 0.81 } do
			shape(x, 0.7, 0.08, 0.22, dark)
		end
	elseif name == "TanMirror" then
		ring(0.28, 0.35, 0.2, 0.3, gold)
		shape(0.7, 0.57, 0.3, 0.37, pale, -18)
		shape(0.5, 0.49, 0.39, 0.025, gold, -25)
	elseif name == "MegaphoneRebel" then
		shape(0.31, 0.51, 0.24, 0.26, accent, -18)
		ring(0.7, 0.5, 0.22, 0.35, gold)
		ring(0.7, 0.5, 0.42, 0.58, pale)
	elseif name == "ToothpickSweep" then
		for _, x in { 0.32, 0.68 } do
			shape(x, 0.48, 0.035, 0.56, pale)
		end
		shape(0.5, 0.75, 0.72, 0.06, accent)
	elseif name == "Headwind" then
		ring(0.72, 0.48, 0.36, 0.55, pale)
		for _, angle in { 0, 60, 120 } do
			shape(0.72, 0.48, 0.3, 0.04, accent, angle, true)
		end
		shape(0.5, 0.79, 0.82, 0.06, gold)
	end
end

return SceneArt
