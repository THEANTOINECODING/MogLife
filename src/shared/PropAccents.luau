-- Morceaux d'un décor importé faits d'une vraie matière Roblox (D133 : meubles v3) : tissu, bois, métal doré, néon,
-- verre… Chaque morceau est une MeshPart enfant de la pièce principale, avec l'attribut AccentOffset (sa position
-- dans le repère de la pièce principale). Après avoir posé ou cloné la pièce principale, Sync replace les morceaux.

local PropAccents = {}

PropAccents.ATTRIBUTE = "AccentOffset"

function PropAccents.IsAccent(part: Instance): boolean
	return part:IsA("BasePart") and typeof(part:GetAttribute(PropAccents.ATTRIBUTE)) == "CFrame"
end

-- scale : facteur de taille appliqué une seule fois (copie agrandie ou réduite comme la pièce principale)
function PropAccents.Sync(root: BasePart, scale: number?)
	local s = scale or 1
	for _, child in root:GetChildren() do
		if child:IsA("BasePart") then
			local offset = child:GetAttribute(PropAccents.ATTRIBUTE)
			if typeof(offset) == "CFrame" then
				if s ~= 1 then
					child.Size *= s
					offset = offset.Rotation + offset.Position * s
				end
				child.CFrame = root.CFrame * offset
			end
		end
	end
end

return PropAccents
