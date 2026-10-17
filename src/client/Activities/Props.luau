-- Petits accessoires créés le temps d'une activité (bocal, pompe, marteau, transats…) : pièces simples,
-- ancrées, sans collision, rangées dans un dossier détruit à la fin.

local Props = {}
Props.__index = Props

export type Props = typeof(setmetatable({} :: { folder: Folder }, Props))

function Props.new(name: string): Props
	local folder = Instance.new("Folder")
	folder.Name = name
	-- La caméra des activités ignore ces objets (CameraFraming)
	folder:SetAttribute("ActivityProps", true)
	folder.Parent = workspace
	return setmetatable({ folder = folder }, Props)
end

-- shape : "Block" (défaut), "Ball" ou "Cylinder" (axe le long de X)
function Props.Part(self: Props, size: Vector3, color: Color3, material: Enum.Material?, shape: string?): Part
	local part = Instance.new("Part")
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.Parent = self.folder
	return part
end

function Props.Destroy(self: Props)
	self.folder:Destroy()
end

-- Cylindre debout (son axe X tourné vers le haut)
Props.Upright = CFrame.Angles(0, 0, math.pi / 2)

return Props
