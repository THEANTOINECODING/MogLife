-- Small physical dioramas. The same geometry is used in the game view and at the station.
local View = {}
View.__index = View
local Art = require(game:GetService("ReplicatedStorage").Shared.Config.PlaygroundArt)

local COLORS = {
	floor = Color3.fromRGB(40, 62, 82),
	frame = Color3.fromRGB(57, 72, 94),
	metal = Color3.fromRGB(167, 195, 213),
	scrap = Color3.fromRGB(240, 116, 79),
	gold = Color3.fromRGB(255, 202, 73),
	goal = Color3.fromRGB(112, 244, 185),
	danger = Color3.fromRGB(251, 105, 111),
	foam = Color3.fromRGB(160, 127, 245),
	tire = Color3.fromRGB(35, 42, 56),
	plate = Color3.fromRGB(96, 174, 239),
	magnet = Color3.fromRGB(245, 93, 105),
	athlete = Color3.fromRGB(116, 225, 203),
	rival = Color3.fromRGB(244, 110, 123),
	rope = Color3.fromRGB(255, 181, 98),
	bell = Color3.fromRGB(255, 202, 73),
	stone = Color3.fromRGB(144, 163, 187),
	paper = Color3.fromRGB(248, 243, 219),
	ink = Color3.fromRGB(30, 35, 50),
	cloth = Color3.fromRGB(113, 205, 239),
	tile = Color3.fromRGB(65, 88, 112),
	water = Color3.fromRGB(100, 214, 244),
	sand = Color3.fromRGB(226, 199, 143),
	sofa = Color3.fromRGB(151, 115, 209),
	popcorn = Color3.fromRGB(255, 239, 169),
	lounger = Color3.fromRGB(106, 214, 212),
	piano = Color3.fromRGB(37, 43, 58),
	dust = Color3.fromRGB(155, 133, 104),
	polished = Color3.fromRGB(57, 71, 89),
	fruit1 = Color3.fromRGB(245, 113, 117),
	fruit2 = Color3.fromRGB(255, 199, 77),
	fruit3 = Color3.fromRGB(151, 221, 113),
	cloud = Color3.fromRGB(223, 231, 246),
	jar = Color3.fromRGB(166, 214, 198),
	pickle = Color3.fromRGB(115, 185, 108),
	seal = Color3.fromRGB(246, 174, 107),
	pipe = Color3.fromRGB(170, 195, 220),
	wood = Color3.fromRGB(216, 164, 112),
	car = Color3.fromRGB(112, 169, 237),
}

local function part(model, size, offset, color, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Size, p.CFrame, p.Color = size, CFrame.new(offset), color
	p.Material = Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Parent = model
	return p
end

local function build(style, name, theme)
	local model = Instance.new("Model")
	local c = COLORS[style] or COLORS.metal
	local function box(x, y, z, sx, sy, sz, color, shape)
		return part(model, Vector3.new(sx, sy, sz), Vector3.new(x, y, z), color or c, shape)
	end
	if style == "backdrop" then
		box(0, 0, -1, 1, 1, 0.04, theme.floor)
	elseif style == "trim" then
		box(0, 0, 0, 1, 1, 0.06, theme.accent)
	elseif style == "cone" then
		box(0, -0.38, 0, 1, 0.14, 0.3, COLORS.ink)
		box(0, -0.15, 0, 0.70, 0.45, 0.25, Color3.fromRGB(255, 143, 70))
		box(0, 0.18, 0, 0.40, 0.35, 0.22, Color3.fromRGB(255, 143, 70))
		box(0, 0.04, 0.13, 0.53, 0.12, 0.04, COLORS.paper)
	elseif style == "pennant" then
		box(-0.35, 0, 0, 0.06, 1, 0.1, COLORS.metal)
		box(0, 0.24, 0.04, 0.65, 0.45, 0.06, theme.accent)
	elseif style == "crown" then
		box(0, -0.20, 0, 0.90, 0.50, 0.25, COLORS.gold)
		for _, x in { -0.34, 0, 0.34 } do
			box(x, 0.18, 0, 0.20, 0.55, 0.25, COLORS.gold)
		end
		box(0, -0.15, 0.15, 0.18, 0.22, 0.1, COLORS.danger, Enum.PartType.Ball)
	elseif style == "athlete" or style == "rival" then
		-- Broad shoulders, tiny legs and a square jaw: the same comic silhouette as the world.
		local skin = if style == "rival" and name == "SunbedSlalom"
			then Color3.fromRGB(211, 125, 64)
			else Color3.fromRGB(255, 212, 167)
		box(0, 0.07, 0, 0.68, 0.48, 0.38)
		box(0, -0.13, 0, 0.43, 0.23, 0.32)
		box(0, 0.40, 0, 0.42, 0.32, 0.38, skin)
		box(0, 0.33, 0.20, 0.47, 0.13, 0.08, skin)
		box(0, 0.58, 0, 0.43, 0.08, 0.38, COLORS.ink)
		box(0, 0.34, 0.25, 0.18, 0.035, 0.025, COLORS.paper)
		for _, side in { -1, 1 } do
			box(side * 0.40, 0.07, 0, 0.24, 0.46, 0.27)
			box(side * 0.40, -0.17, 0.02, 0.23, 0.18, 0.29, skin)
			box(side * 0.13, -0.34, 0, 0.13, 0.34, 0.22, COLORS.ink)
			box(side * 0.13, -0.49, 0.07, 0.20, 0.10, 0.32, COLORS.paper)
			box(side * 0.09, 0.46, 0.20, 0.05, 0.05, 0.025, COLORS.ink)
			local brow = box(side * 0.09, 0.52, 0.21, 0.10, 0.025, 0.03, COLORS.ink)
			brow.CFrame *= CFrame.Angles(0, 0, side * 0.15)
		end
		if style == "rival" then
			if name == "SnackVolley" then
				for _, yy in { -0.06, 0.08, 0.20 } do
					box(0, yy, 0.20, 0.66, 0.035, 0.02, COLORS.paper)
				end
			elseif name == "TreadmillTakeover" then
				box(0, 0.54, 0.02, 0.46, 0.08, 0.42, COLORS.gold)
				box(0, 0.02, 0.24, 0.09, 0.13, 0.04, COLORS.gold)
			elseif name == "CrownSneak" or name == "GravityGauntlet" then
				for _, xx in { -0.15, 0, 0.15 } do
					box(xx, 0.65, 0.02, 0.09, 0.18, 0.38, COLORS.gold)
				end
			elseif name == "SunbedSlalom" then
				box(0, 0.46, 0.24, 0.40, 0.09, 0.04, COLORS.ink)
			end
		end
	elseif style == "tire" or style == "plate" or style == "bell" then
		for i = 1, 12 do
			local a = i * math.pi / 6
			local p = box(math.cos(a) * 0.36, math.sin(a) * 0.36, 0, 0.24, 0.24, 0.35)
			p.CFrame *= CFrame.Angles(0, 0, a)
		end
		if style == "bell" then
			box(0, 0, 0, 0.65, 0.65, 0.30)
		end
	elseif style == "magnet" then
		box(-0.32, 0, 0, 0.28, 0.85, 0.35)
		box(0.32, 0, 0, 0.28, 0.85, 0.35)
		box(0, 0.32, 0, 0.85, 0.28, 0.35)
		for _, side in { -1, 1 } do
			box(side * 0.32, -0.35, 0.01, 0.28, 0.22, 0.36, COLORS.metal)
		end
	elseif style == "glass" then
		box(0, 0, -0.2, 1, 1, 0.04, COLORS.jar)
		for _, side in { -1, 1 } do
			box(side * 0.47, 0, 0, 0.06, 1, 0.1, COLORS.paper)
		end
		box(0, -0.47, 0, 1, 0.06, 0.1, COLORS.paper)
	elseif style == "frame" then
		for _, side in { -1, 1 } do
			box(side * 0.46, 0, -0.15, 0.08, 1, 0.35)
		end
		box(0, -0.46, -0.12, 1, 0.08, 0.4)
		box(0, 0.46, -0.12, 1, 0.08, 0.4)
	elseif style == "scrap" then
		for i = 1, 7 do
			local p = box(
				((i * 7) % 5 - 2) * 0.14,
				((i * 3) % 5 - 2) * 0.15,
				i * 0.01,
				0.48,
				0.36,
				0.25,
				if i % 2 == 0 then COLORS.metal else c
			)
			p.CFrame *= CFrame.Angles(0, 0, i * 0.7)
		end
	elseif style == "fruit2" then
		-- Banana cluster: readable by silhouette, even without color.
		for i = 1, 4 do
			box(-0.3 + i * 0.14, -0.05 + math.sin(i * 0.6) * 0.18, 0, 0.24, 0.62, 0.35, c, Enum.PartType.Ball)
		end
		box(0.22, 0.40, 0, 0.12, 0.18, 0.18, COLORS.wood)
	elseif style == "fruit3" then
		box(0, -0.12, 0, 0.82, 0.72, 0.60, c, Enum.PartType.Ball)
		box(0, 0.22, 0, 0.47, 0.50, 0.42, c, Enum.PartType.Ball)
		box(0.03, 0.47, 0, 0.08, 0.20, 0.10, COLORS.wood)
	elseif string.sub(style, 1, 5) == "fruit" or style == "popcorn" then
		box(0, 0, 0, 0.86, 0.86, 0.68, c, Enum.PartType.Ball)
		box(0.08, 0.41, 0, 0.22, 0.16, 0.12, COLORS.pickle)
		box(-0.19, 0.17, 0.30, 0.16, 0.16, 0.05, COLORS.paper, Enum.PartType.Ball)
	elseif style == "sofa" or style == "lounger" then
		box(0, 0, 0, 0.90, 0.90, 0.20)
		box(0, 0.32, 0.18, 0.70, 0.28, 0.25, COLORS.paper)
		for _, side in { -1, 1 } do
			box(side * 0.44, 0, 0.18, 0.12, 1, 0.25)
		end
	elseif style == "car" or style == "taxi" then
		c = if style == "taxi" then COLORS.gold else c
		box(0, 0, 0, 0.95, 0.87, 0.30)
		for _, yy in { -0.35, 0.35 } do
			box(0, yy, 0.17, 0.75, 0.10, 0.05, COLORS.paper)
		end
		box(0, 0.12, 0.20, 0.60, 0.40, 0.18, COLORS.water)
		for _, x in { -0.48, 0.48 } do
			for _, y in { -0.25, 0.25 } do
				box(x, y, 0, 0.14, 0.22, 0.25, COLORS.tire)
			end
		end
	elseif style == "cloth" then
		box(0, 0, 0, 1, 1, 0.06)
		for _, side in { -1, 1 } do
			box(side * 0.39, 0, 0.045, 0.05, 1, 0.025, COLORS.paper)
		end
		for _, yy in { -0.38, 0.38 } do
			box(0, yy, 0.05, 0.98, 0.035, 0.025, COLORS.paper)
		end
	elseif style == "dust" or style == "dustLast" then
		local color = if style == "dustLast" then COLORS.gold else COLORS.dust
		for i = 1, 4 do
			box(math.sin(i * 2) * 0.23, math.cos(i * 2) * 0.20, 0, 0.36, 0.28, 0.03, color, Enum.PartType.Ball)
		end
	elseif style == "wood" then
		box(0, 0, 0, 1, 1, 0.18)
		for i = 1, 4 do
			box(0, -0.4 + i * 0.17, 0.10, 0.88, 0.025, 0.01, Color3.fromRGB(169, 110, 73))
		end
	elseif style == "tile" then
		box(0, -0.03, -0.04, 1, 1, 0.10, COLORS.ink)
		box(0, 0.03, 0, 0.96, 0.92, 0.09, c)
	elseif style == "foam" then
		for i = 1, 3 do
			box(0, -0.48 + i * 0.28, 0, 0.88, 0.25, 0.28, c)
			box(-0.22, -0.48 + i * 0.28, 0.15, 0.10, 0.10, 0.025, COLORS.paper, Enum.PartType.Ball)
			box(0.22, -0.48 + i * 0.28, 0.15, 0.10, 0.10, 0.025, COLORS.paper, Enum.PartType.Ball)
		end
	elseif style == "stone" then
		box(0, 0, 0, 1, 0.85, 0.30, c)
		box(0, 0, 0.17, 0.30, 0.55, 0.08, COLORS.ink)
		for _, xx in { -0.42, 0.42 } do
			box(xx, 0, 0.04, 0.10, 1, 0.38, COLORS.metal)
		end
	elseif style == "goal" then
		for _, x in { -0.44, 0.44 } do
			box(x, 0, 0, 0.10, 1, 0.08)
		end
		for _, y in { -0.44, 0.44 } do
			box(0, y, 0, 1, 0.10, 0.08)
		end
	else
		box(0, 0, 0, 1, 1, if style == "floor" or style == "sand" then 0.025 else 0.20)
		if style == "gold" or style == "stone" or style == "foam" then
			box(-0.32, 0, 0.11, 0.05, 0.80, 0.02, COLORS.paper)
			box(0.32, 0, 0.11, 0.05, 0.80, 0.02, COLORS.paper)
		end
	end
	model.WorldPivot = CFrame.identity
	return model
end

function View.new(parent, base, scale, name)
	local theme = Art.Themes[Art.Groups[name] or "Gym"]
	local scenery = {
		{ id = "Backdrop", x = 0.5, y = 0.5, w = 0.98, h = 0.98, style = "backdrop", angle = 0 },
		{ id = "TopRail", x = 0.5, y = 0.025, w = 0.96, h = 0.012, style = "trim", angle = 0 },
		{ id = "BottomRail", x = 0.5, y = 0.975, w = 0.96, h = 0.012, style = "trim", angle = 0 },
	}
	for i = 1, 5 do
		table.insert(
			scenery,
			{ id = "FloorLine" .. i, x = 0.5, y = 0.80 + i * 0.025, w = 0.93, h = 0.002, style = "trim", angle = 0 }
		)
	end
	return setmetatable({
		parent = parent,
		base = base or CFrame.identity,
		scale = scale or 10,
		entries = {},
		name = name,
		theme = theme,
		scenery = scenery,
	}, View)
end

function View:Draw(nodes)
	local seen = {}
	local all = table.clone(self.scenery)
	for _, node in nodes do
		table.insert(all, node)
	end
	for order, n in all do
		seen[n.id] = true
		local entry = self.entries[n.id]
		if not entry or entry.style ~= n.style then
			if entry then
				entry.model:Destroy()
			end
			local model = build(n.style, self.name, self.theme)
			model.Name = n.id
			model.Parent = self.parent
			entry = { model = model, style = n.style, parts = {} }
			for _, p in model:GetChildren() do
				table.insert(entry.parts, { part = p, size = p.Size, cf = p.CFrame })
			end
			self.entries[n.id] = entry
		end
		local w, h = math.max(0.002, n.w) * self.scale, math.max(0.002, n.h) * self.scale
		local depth = 0.25
		local cf = self.base
			* CFrame.new((n.x - 0.5) * self.scale, (0.5 - n.y) * self.scale, order * 0.06)
			* CFrame.Angles(0, 0, -math.rad(n.angle))
		for _, p in entry.parts do
			local pos = p.cf.Position
			p.part.Size = Vector3.new(p.size.X * w, p.size.Y * h, math.max(0.015, p.size.Z * depth))
			p.part.CFrame = cf * CFrame.new(pos.X * w, pos.Y * h, pos.Z * depth) * p.cf.Rotation
		end
	end
	for id, entry in self.entries do
		if not seen[id] then
			entry.model:Destroy()
			self.entries[id] = nil
		end
	end
end

function View:Destroy()
	for _, entry in self.entries do
		entry.model:Destroy()
	end
	self.entries = {}
end

return View
