-- Au point d'apparition, la caméra tactile traversait la maison et le panneau de propriété.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local MobileCameraController = {}

local function ownPlot(): Model?
	for _, plot in CollectionService:GetTagged("Plot") do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function frameStreet(character: Model)
	for _ = 1, 100 do
		if player.Character ~= character then
			return
		end
		local plot = ownPlot()
		local spawn = plot and plot:FindFirstChild("Spawn")
		local root = character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		if
			spawn
			and spawn:IsA("BasePart")
			and root
			and root:IsA("BasePart")
			and camera
			and camera.CameraType == Enum.CameraType.Custom
			and (root.Position - spawn.Position).Magnitude < 16
		then
			-- Sur tablette, le module de caméra peut encore terminer son initialisation après le téléport maison.
			task.wait(0.5)
			if
				player.Character ~= character
				or camera.CameraType ~= Enum.CameraType.Custom
				or (root.Position - spawn.Position).Magnitude >= 16
			then
				continue
			end
			local focus = root.Position + Vector3.new(0, 2, 0)
			local streetView = CFrame.lookAt(focus - spawn.CFrame.LookVector * 12 + Vector3.new(0, 3, 0), focus)
			-- Le module de caméra Roblox conserve son ancien angle si on change seulement CFrame.
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = streetView
			task.wait(0.1)
			if
				player.Character == character
				and workspace.CurrentCamera == camera
				and camera.CameraType == Enum.CameraType.Scriptable
				and (camera.CFrame.Position - streetView.Position).Magnitude < 0.05
			then
				camera.CameraType = Enum.CameraType.Custom
			end
			return
		end
		task.wait(0.1)
	end
end

function MobileCameraController.Start()
	if not UserInputService.TouchEnabled then
		return
	end
	-- Depuis le trottoir, 12 studs laissent voir le décor sans rentrer dans la façade.
	player.CameraMaxZoomDistance = math.min(player.CameraMaxZoomDistance, 12)
	player.CharacterAdded:Connect(function(character)
		task.spawn(frameStreet, character)
	end)
	if player.Character then
		task.spawn(frameStreet, player.Character)
	end
	task.spawn(function()
		local sign: BasePart? = nil
		while player.Parent do
			if not sign or not sign.Parent then
				local plot = ownPlot()
				local found = plot and plot:FindFirstChild("OwnerSign", true)
				if found and found:IsA("BasePart") then
					sign = found
				end
			end
			if sign then
				local camera = workspace.CurrentCamera
				local near = camera ~= nil and (camera.CFrame.Position - sign.Position).Magnitude < 18
				sign.LocalTransparencyModifier = if near then 1 else 0
				local ownerGui = sign:FindFirstChild("OwnerGui")
				if ownerGui and ownerGui:IsA("SurfaceGui") then
					ownerGui.Enabled = not near
				end
			end
			task.wait(0.2)
		end
	end)
end

return MobileCameraController
