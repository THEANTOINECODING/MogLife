-- Menu (D124, remplace le rond ☰ et son tiroir de D96) : une colonne de cases toujours visible au bord gauche, comme
-- dans les jeux Roblox les plus joués (Gym League, Steal a Brainrot, Pet Simulator 99, Blox Fruits). Un seul toucher
-- pour tout : plus de tiroir à ouvrir d'abord.
-- - Cases en relief (Ui.tile), une couleur par case, grosse icône, nom en dessous ; elles s'enfoncent à l'appui.
-- - Boutique Robux (seulement si des packs sont en vente), Style, Flex, Maison, Récompenses (pastille rouge quand une
--   récompense de la semaine attend), Maisons ; puis un petit rond ⚙ pour les réglages.
-- - Placement calculé sur la place réelle : sous la pastille d'objectif, au milieu du bord gauche si possible, jamais
--   dans le bas de l'écran tactile (le pouce gauche y tient le joystick) ; 1, 2 ou 3 colonnes selon la place.
-- - Rangée pendant une série, un combat, un duel (MinigameController, ScreenGui « Menu »), quand une fenêtre est
--   ouverte (UIController.SetStatsHidden) et pendant le tutoriel (sa carte occupe le même coin).
-- - Manette : Select met la sélection sur la première case (la croix choisit, A ouvre, B ou Select ressort).

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")

local Texts = require(ReplicatedStorage.Shared.Config.Texts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer

local UIController
local MinigameController
local ShopController
local StoreController
local EmoteController
local WeeklyController
local HouseController
local SettingsController
local SoundController

local MenuController = {}

type Entry = {
	id: string,
	icon: string,
	caption: string,
	color: Color3,
	action: (tile: TextButton) -> (),
	shown: (() -> boolean)?,
	badge: (() -> boolean)?,
}

local gui: ScreenGui
local rail: Frame
local tiles: { [string]: TextButton } = {}
local entries: { Entry } = {}
local gear: TextButton
local builtSize = 0
local focused = false
local tutorialActive = false
local canInvite = false -- le compte peut inviter des amis (D126)

-- Une fenêtre est-elle déjà ouverte (ou une série, une scène) ? Les cases ne font alors rien
local function busy(): boolean
	return MinigameController.IsGameplayLocked() or UIController.IsStatsHidden()
end

local function tapSound()
	SoundController.Play("UiTap")
end

-- ------------------------------------------------------------------ manette

local function setFocus(on: boolean)
	if on == focused then
		return
	end
	focused = on
	if on then
		CollectionService:AddTag(rail, Ui.MODAL_TAG)
	else
		CollectionService:RemoveTag(rail, Ui.MODAL_TAG)
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(rail) then
			GuiService.SelectedObject = nil
		end
	end
end

-- ------------------------------------------------------------------ placement

local function tileSize(): number
	if Ui.isSmallScreen() then
		return 52
	end
	return if UserInputService.TouchEnabled then 60 else 64
end

local function build(size: number)
	builtSize = size
	for _, tile in tiles do
		tile:Destroy()
	end
	table.clear(tiles)
	for index, entry in entries do
		local tile = Ui.tile({
			name = entry.id,
			icon = entry.icon,
			caption = entry.caption,
			color = entry.color,
			size = size,
			layoutOrder = index,
			parent = rail,
		})
		Ui.juice(tile, tapSound)
		tile.Activated:Connect(function()
			setFocus(false)
			if not busy() then
				entry.action(tile)
			end
		end)
		tiles[entry.id] = tile
	end
	local gearSize = math.floor(size * 0.72)
	gear.Size = UDim2.fromOffset(gearSize, gearSize)
end

local function layout()
	if not rail then
		return
	end
	local size = tileSize()
	if size ~= builtSize then
		build(size)
	end
	local area = gui.AbsoluteSize
	if area.X < 1 or area.Y < 1 then
		return
	end
	local visible: { TextButton } = {}
	for _, entry in entries do
		local tile = tiles[entry.id]
		local on = entry.shown == nil or entry.shown()
		tile.Visible = on
		if on then
			table.insert(visible, tile)
		end
	end
	local gap = if size < 60 then 6 else 8
	local rowGap = gap + math.floor(size * 0.12) -- les noms débordent sous les cases
	local gearSize = math.floor(size * 0.72)
	local top = Ui.menuSlots().pillBottom + 14
	-- Écran tactile : le bas de l'écran appartient au joystick (pouce gauche)
	local limit = if UserInputService.TouchEnabled
		then area.Y * (if Ui.isPhonePortrait() then 0.62 else 0.66)
		else area.Y - 16
	local count = #visible
	-- Hauteur avec `columns` colonnes : le ⚙ prend la place libre de la dernière rangée s'il y en a une, sinon une
	-- petite rangée à lui
	local function heightFor(columns: number): (number, boolean)
		local rows = math.max(math.ceil(count / columns), 1)
		local gearInRow = count % columns ~= 0
		return rows * (size + rowGap) + (if gearInRow then 0 else gearSize), gearInRow
	end
	local columns, height, gearInRow = 1, 0, false
	for tryColumns = 1, 3 do
		columns = tryColumns
		height, gearInRow = heightFor(columns)
		if top + height <= limit then
			break
		end
	end
	local y = math.max(top, math.min(area.Y / 2 - height / 2, limit - height))
	rail.Position = UDim2.fromOffset(12, y)
	rail.Size = UDim2.fromOffset(columns * size + (columns - 1) * gap, height)
	for index, tile in visible do
		local column = (index - 1) % columns
		local row = (index - 1) // columns
		tile.Position = UDim2.fromOffset(column * (size + gap), row * (size + rowGap))
	end
	local slot = count -- case suivante de la grille (base 0)
	local column = if gearInRow then slot % columns else 0
	local row = if gearInRow then slot // columns else math.max(math.ceil(count / columns), 1)
	local inset = math.floor((size - gearSize) / 2)
	gear.Position =
		UDim2.fromOffset(column * (size + gap) + inset, row * (size + rowGap) + (if gearInRow then inset else 0))
end

-- ------------------------------------------------------------------ vie des cases

-- Pastilles : elles battent ; une case qui a une pastille se dandine de temps en temps pour attirer l'œil
local function animate()
	local t0 = os.clock()
	RunService.Heartbeat:Connect(function()
		if not gui.Enabled or not rail.Visible then
			return
		end
		local t = os.clock() - t0
		for _, entry in entries do
			local tile = tiles[entry.id]
			if not tile then
				continue
			end
			local on = entry.badge ~= nil and entry.badge()
			Ui.setBadge(tile, on)
			if on then
				local badge = tile:FindFirstChild("Badge") :: Frame
				local scale = badge:FindFirstChildOfClass("UIScale") :: UIScale
				scale.Scale = 1 + math.max(math.sin(t * 6), 0) * 0.15
				-- toutes les 3,5 s : un petit tremblement d'une demi-seconde
				local phase = t % 3.5
				tile.Rotation = if phase < 0.5 then math.sin(phase * 40) * 7 * (1 - phase / 0.5) else 0
			else
				tile.Rotation = 0
			end
		end
	end)
end

local function refreshVisible()
	-- Pendant le tutoriel, sa carte occupe ce coin et le joueur apprend les bases : le menu apparaît à la fin
	rail.Visible = not UIController.IsStatsHidden() and not tutorialActive
	if not rail.Visible then
		setFocus(false)
	end
end

-- ------------------------------------------------------------------ construction

local function buildGui()
	gui = Ui.create("ScreenGui", { Name = "Menu", ResetOnSpawn = false, DisplayOrder = 1 })
	rail = Ui.create("Frame", {
		Name = "Rail",
		BackgroundTransparency = 1,
		Parent = gui,
	})
	-- Réglages : petit rond sombre sous les cases (on y va rarement)
	gear = Ui.create("TextButton", {
		Name = "Settings",
		BackgroundColor3 = Color3.fromRGB(42, 35, 64),
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = 99,
		Parent = rail,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(Ui.Ink, 2.5) })
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		Text = Texts.Get("Menu.IconSettings"),
		TextStrokeTransparency = 1,
		Parent = gear,
	})
	Ui.juice(gear, tapSound)
	gear.Activated:Connect(function()
		setFocus(false)
		if not busy() then
			SettingsController.Open()
		end
	end)

	entries = {
		{
			id = "Store",
			icon = Texts.Get("Menu.IconStore"),
			caption = Texts.Get("Menu.Store"),
			color = Color3.fromRGB(255, 196, 40),
			action = function()
				StoreController.Open()
			end,
			shown = function()
				return StoreController.HasProducts()
			end,
		},
		{
			id = "Style",
			icon = Texts.Get("Menu.IconStyle"),
			caption = Texts.Get("Menu.Style"),
			color = Color3.fromRGB(45, 150, 235),
			action = function()
				ShopController.OpenWardrobe()
			end,
		},
		{
			id = "Flex",
			icon = Texts.Get("Menu.IconFlex"),
			caption = Texts.Get("Emote.Button"),
			color = Color3.fromRGB(225, 70, 190),
			action = function(tile)
				EmoteController.Toggle(tile)
			end,
		},
		{
			id = "Home",
			icon = Texts.Get("Menu.IconHome"),
			caption = Texts.Get("Menu.Home"),
			color = Color3.fromRGB(245, 120, 35),
			action = function()
				Remotes.GoHome:FireServer()
			end,
		},
		{
			id = "Rewards",
			icon = Texts.Get("Menu.IconRewards"),
			caption = Texts.Get("Menu.Rewards"),
			color = Color3.fromRGB(235, 60, 75),
			action = function()
				WeeklyController.Open()
			end,
			badge = function()
				return WeeklyController.HasClaim()
			end,
		},
		{
			-- Inviter des amis (D126) : ouvre l'invitation Roblox ; caché si le compte ne peut pas inviter
			id = "Invite",
			icon = Texts.Get("Menu.IconInvite"),
			caption = Texts.Get("Menu.Invite"),
			color = Color3.fromRGB(40, 185, 110),
			action = function()
				pcall(function()
					SocialService:PromptGameInvite(player)
				end)
			end,
			shown = function()
				return canInvite
			end,
		},
		{
			id = "Houses",
			icon = Texts.Get("Menu.IconHouses"),
			caption = Texts.Get("Menu.Houses"),
			color = Color3.fromRGB(135, 85, 235),
			action = function()
				HouseController.Open()
			end,
		},
	}
	gui.Parent = player:WaitForChild("PlayerGui")
	-- Le compte peut-il inviter (contrôle parental, plateforme) ? Demandé une fois, en arrière-plan
	task.spawn(function()
		local ok, result = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and result == true and not canInvite then
			canInvite = true
			task.defer(layout)
		end
	end)
	build(tileSize())
	Ui.watchViewport(function()
		task.defer(layout)
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
end

function MenuController.Init(controllers)
	UIController = controllers.UIController
	MinigameController = controllers.MinigameController
	ShopController = controllers.ShopController
	StoreController = controllers.StoreController
	EmoteController = controllers.EmoteController
	WeeklyController = controllers.WeeklyController
	HouseController = controllers.HouseController
	SettingsController = controllers.SettingsController
	SoundController = controllers.SoundController
end

-- Une case a pu apparaître ou disparaître (packs Robux en vente) : on replace la colonne
function MenuController.Refresh()
	layout()
end

-- Position de la case `id` à l'écran (le tutoriel ou une flèche peuvent la montrer) ; nil si elle est cachée
function MenuController.GetTile(id: string): TextButton?
	local tile = tiles[id]
	return if tile and tile.Visible then tile else nil
end

function MenuController.Start()
	buildGui()
	layout()
	animate()
	UIController.OnStatsHiddenChanged(refreshVisible)
	Remotes.Tutorial.OnClientEvent:Connect(function(tutorial)
		tutorialActive = tutorial ~= nil and not tutorial.done
		refreshVisible()
	end)
	refreshVisible()
	-- Manette : Select entre dans la colonne ou en ressort ; B en ressort
	ContextActionService:BindActionAtPriority("MogMenu", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if gui.Enabled and rail.Visible then
			setFocus(not focused)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonSelect)
	ContextActionService:BindActionAtPriority("MogMenuBack", function(_, state)
		if focused and state == Enum.UserInputState.Begin then
			setFocus(false)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.ButtonB)
	-- Rangée (série, combat) : la manette ressort de la colonne
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not gui.Enabled then
			setFocus(false)
		end
	end)
end

return MenuController
