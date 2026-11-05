-- Manette (Xbox, PlayStation, manette sur PC ou téléphone) : les fenêtres se pilotent sans souris.
-- - Quand une fenêtre marquée (Ui.markModal) s'ouvre, son bouton par défaut est sélectionné : A valide, la croix
--   directionnelle et le stick gauche passent d'un bouton à l'autre (navigation de Roblox).
-- - B déclenche le bouton retour de la fenêtre du dessus (Ui.onBack : fermer, annuler, refuser).
-- - Sans fenêtre ouverte, aucune sélection : A reste au mini-jeu ou au saut.
-- Rien ne change pour le tactile, la souris et le clavier.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Parent.Ui)

local CHECK_INTERVAL = 0.2

local player = Players.LocalPlayer

local usingGamepad = false
local selectedByUs: GuiObject? = nil

local GamepadController = {}

local function isGamepad(inputType: Enum.UserInputType): boolean
	return inputType.Name:sub(1, 7) == "Gamepad"
end

-- L'objet est-il vraiment affiché à l'écran (lui, ses parents, son ScreenGui) ?
local function shown(instance: Instance): boolean
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui or not instance:IsDescendantOf(playerGui) then
		return false
	end
	local node: Instance? = instance
	while node and node ~= playerGui do
		if node:IsA("GuiObject") then
			if not node.Visible then
				return false
			end
		elseif node:IsA("LayerCollector") then
			if not node.Enabled then
				return false
			end
		end
		node = node.Parent
	end
	if instance:IsA("GuiObject") then
		local size = instance.AbsoluteSize
		return size.X > 0 and size.Y > 0
	end
	return true
end

local function displayOrder(instance: Instance): number
	local screen = instance:FindFirstAncestorOfClass("ScreenGui")
	if instance:IsA("ScreenGui") then
		screen = instance
	end
	return if screen then screen.DisplayOrder else 0
end

local function selectable(button: Instance): boolean
	return button:IsA("GuiButton") and button.Selectable and button.Active and shown(button)
end

-- Bouton à sélectionner dans une fenêtre : son bouton par défaut, sinon le premier bouton (haut à gauche) qui n'est
-- pas un bouton retour, sinon le bouton retour
local function firstButton(window: Instance): GuiButton?
	local best: GuiButton? = nil
	local back: GuiButton? = nil
	for _, descendant in window:GetDescendants() do
		if not selectable(descendant) then
			continue
		end
		local button = descendant :: GuiButton
		if CollectionService:HasTag(button, Ui.DEFAULT_TAG) then
			return button
		end
		if CollectionService:HasTag(button, Ui.BACK_TAG) then
			back = back or button
			continue
		end
		if not best then
			best = button
		else
			local a, b = button.AbsolutePosition, (best :: GuiButton).AbsolutePosition
			if a.Y < b.Y - 4 or (math.abs(a.Y - b.Y) <= 4 and a.X < b.X) then
				best = button
			end
		end
	end
	return best or back
end

-- Fenêtres marquées actuellement affichées et qui ont un bouton à choisir, la plus haute d'abord
local function openModals(): { Instance }
	local list = {}
	for _, window in CollectionService:GetTagged(Ui.MODAL_TAG) do
		if shown(window) and firstButton(window) then
			table.insert(list, window)
		end
	end
	table.sort(list, function(a, b)
		return displayOrder(a) > displayOrder(b)
	end)
	return list
end

local function refresh()
	if not usingGamepad then
		return
	end
	local modals = openModals()
	local current = GuiService.SelectedObject
	if #modals == 0 then
		-- Plus de fenêtre : on rend A au jeu
		if current and current == selectedByUs then
			GuiService.SelectedObject = nil
		end
		selectedByUs = nil
		return
	end
	if current and shown(current) then
		for _, window in modals do
			if current:IsDescendantOf(window) then
				return -- la sélection est déjà dans une fenêtre ouverte
			end
		end
	end
	local target = firstButton(modals[1])
	if target then
		GuiService.SelectedObject = target
		selectedByUs = target
	end
end

-- B : bouton retour de la fenêtre du dessus
local function onBack(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	for _, window in openModals() do
		for _, button in CollectionService:GetTagged(Ui.BACK_TAG) do
			local handler = Ui.backHandlers[button]
			if handler and button:IsDescendantOf(window) and shown(button) then
				task.spawn(handler)
				return Enum.ContextActionResult.Sink
			end
		end
	end
	return Enum.ContextActionResult.Pass
end

function GamepadController.Start()
	usingGamepad = isGamepad(UserInputService:GetLastInputType())
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		local gamepad = isGamepad(inputType)
		-- Les mouvements de souris et touchers ne comptent que s'ils sont vraiment de la souris ou du tactile
		if gamepad ~= usingGamepad then
			usingGamepad = gamepad
			if not gamepad and selectedByUs and GuiService.SelectedObject == selectedByUs then
				GuiService.SelectedObject = nil
				selectedByUs = nil
			end
		end
	end)
	ContextActionService:BindActionAtPriority(
		"MogGamepadBack",
		onBack,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.ButtonB
	)
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			local ok, err = pcall(refresh)
			if not ok then
				warn(`[GamepadController] {err}`)
			end
		end
	end)
end

return GamepadController
