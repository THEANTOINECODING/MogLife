-- Vendeurs des magasins (décision D38) : un PNJ par magasin, à son comptoir (tag VendorSpot dans la carte).
-- Lui parler ouvre la boutique du magasin : il reçoit le tag de son point de vente (Mirror pour les vêtements et
-- le coiffeur, FurnitureShop pour les meubles) et les mêmes attributs (Store, Categories), donc StyleService,
-- FurnitureService et leurs contrôleurs le traitent exactement comme un miroir ou un comptoir.
-- Les miroirs et le comptoir restent en place (❓ D38 : les garder ou non est au créateur de trancher).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Npc = require(ServerScriptService.Server.Npc)

local SPOT_TAG = "VendorSpot"

local VendorService = {}

local function spawnVendor(spot: Instance)
	if not spot:IsA("BasePart") then
		return
	end
	local npc = spot:GetAttribute("Npc")
	local tag = spot:GetAttribute("Tag")
	if typeof(npc) ~= "string" or typeof(tag) ~= "string" then
		return
	end
	local facing = (spot.CFrame * CFrame.new(0, 0, -10)).Position
	local _, body = Npc.Spawn(npc, Texts.Get(`Npc.{npc}`), spot, facing)
	for _, name in { "Store", "Categories" } do
		local value = spot:GetAttribute(name)
		if value ~= nil then
			body:SetAttribute(name, value)
		end
	end
	CollectionService:AddTag(body, tag)
end

function VendorService.Start()
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		spawnVendor(spot)
	end
end

return VendorService
