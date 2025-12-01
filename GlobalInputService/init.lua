--// Modules
local Lists = require(script.Lists)
local MobileJoysticks = require(script.MobileJoysticks)
local Scales = require(script.Parent.Scales)

--// Types
type InputCode = Enum.KeyCode | Enum.UserInputType

export type InputAction = {
	Name: string,
	KeyInputs: {
		Keyboard: { InputCode },
		Gamepad: { InputCode },
	},
	Callback: (inputState: Enum.UserInputState, input: InputObject) -> any?,
	Priority: number?,
	IsEnabled: () -> boolean,

	Enable: (self: InputAction) -> nil,
	Disable: (self: InputAction) -> nil,
	Refresh: (self: InputAction) -> nil,
	GetMobileInput: (self: InputAction) -> (ImageButton | GuiJoystick)?,
	GetMobileIcon: (self: InputAction) -> string,
	SetPriority: (self: InputAction, priority: number | Enum.ContextActionPriority) -> nil,
	SetKeybinds: (self: InputAction, bindGroup: "Gamepad" | "Keyboard", ...InputCode) -> nil,
	AddKeybinds: (self: InputAction, bindGroup: "Gamepad" | "Keyboard", ...InputCode) -> nil,
	RemoveKeybinds: (self: InputAction, bindGroup: "Gamepad" | "Keyboard", ...InputCode) -> nil,
	ReplaceKeybinds: (self: InputAction, bindGroup: "Gamepad" | "Keyboard", keybindsTable: { InputCode }) -> nil,

	SetImage: (self: InputAction, image: string) -> nil,
	SetPosition: (self: InputAction, position: UDim2) -> nil,
}

export type GuiJoystick = MobileJoysticks.GuiJoystick
export type ActionGroup = {
	Name: string,
	Actions: { [string]: InputAction },
	IsEnabled: boolean,
	Enable: (self: ActionGroup, index: any?) -> nil,
	Disable: (self: ActionGroup, index: any?) -> nil,
}

type InputType = "Keyboard" | "Gamepad" | "Touch"
type GamepadType = "Ps4" | "Xbox"?

export type InputSource = {
	Type: InputType,
	GamepadType: GamepadType,
	LastGamepadInput: InputObject?,
}

local CUSTOM_GAMEPAD_GUI = true
local CUSTOM_MOBILE_BUTTON_IMAGES = {
	Default = "rbxassetid://117210355214100",
	Pressed = "rbxassetid://117210355214100",
}

--// Services
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

--// Instances
local Player: Player = Players.LocalPlayer
local inputServiceGui: ScreenGui = Instance.new("ScreenGui")
local inputTypeChanged = Instance.new("BindableEvent")

--// Values
local stepped: RBXScriptConnection?

local selectionImage
local hideSelection

local lastInputType: string?
local lastGamepadType: string?
local lastGamepadInput: InputObject?

local globalInputService = {
	InputTypeChanged = inputTypeChanged.Event :: RBXScriptSignal,
	GetInputSource = function(self): InputSource
		return {
			Type = self._inputType,
			GamepadType = self._inputType == "Gamepad" and self._gamepadType,
			LastGamepadInput = lastGamepadInput,
		}
	end,

	inputIcons = Lists.inputIcons,

	inputActions = {} :: { [string]: InputAction },
	actionGroups = {} :: { [string]: ActionGroup },

	_inputType = "Keyboard" :: InputType,
	_gamepadType = "Xbox" :: GamepadType,
}

local ps4Keys = Lists.ps4Keys

local xboxKeys = Lists.xboxKeys

--// Functions
local function createCustomGamepadGui()
	-- Essentials
	selectionImage = Instance.new("ImageLabel")
	selectionImage.Parent = inputServiceGui
	selectionImage.Image = "rbxassetid://94490241725589"
	selectionImage.BackgroundTransparency = 1
	selectionImage.ScaleType = Enum.ScaleType.Slice
	selectionImage.SliceCenter = Rect.new(30, 30, 295, 295)
	selectionImage.SliceScale = 0.5
	selectionImage.ResampleMode = Enum.ResamplerMode.Pixelated
	selectionImage.ImageTransparency = 0.5

	-- Hide Default UI
	hideSelection = Instance.new("ImageLabel")
	hideSelection.BackgroundTransparency = 1
	hideSelection.ImageTransparency = 1

	-- Extra
	local centerImage = Instance.new("ImageLabel")
	centerImage.BackgroundTransparency = 1
	centerImage.Parent = selectionImage
	centerImage.Image = "rbxassetid://78657964270656"
	centerImage.ResampleMode = Enum.ResamplerMode.Pixelated
	centerImage.ScaleType = Enum.ScaleType.Fit
	centerImage.AnchorPoint = Vector2.new(0.5, 0.5)
	centerImage.Position = UDim2.fromScale(0.5, 0.5)
	centerImage.Size = UDim2.fromOffset(100, 100)

	local uiSizeConstraint = Instance.new("UISizeConstraint")
	uiSizeConstraint.Parent = centerImage
	uiSizeConstraint.MinSize = Vector2.new(25, 25)
end

local function setGamepadType(lastInput)
	local inputName = UserInputService:GetStringForKeyCode(lastInput.KeyCode)

	if table.find(ps4Keys, inputName) then
		globalInputService._gamepadType = "Ps4"
	elseif table.find(xboxKeys, inputName) then
		globalInputService._gamepadType = "Xbox"
	end
end

function globalInputService:CheckKeyPrompts()
	for _, image: ImageLabel in ipairs(CollectionService:GetTagged("KeyPrompt")) do
		local iconKey

		local inputName = image:GetAttribute("InputName")

		local reference = {
			Keyboard = "Key",
			Gamepad = "Button",
			Touch = "Touch",
		}

		if image:GetAttribute(reference[globalInputService._inputType]) then
			iconKey = image:GetAttribute(reference[globalInputService._inputType])
		elseif inputName and globalInputService.inputActions[inputName] then
			if globalInputService._inputType == "Touch" then
				local mobileIcon = globalInputService.inputActions[inputName]:GetMobileIcon()

				image.Visible = true
				image.Image = mobileIcon

				continue
			else
				iconKey = globalInputService.inputActions[inputName].KeyInputs[globalInputService._inputType][1].Name
			end
		end

		if not iconKey then
			image.Visible = false
			continue
		end

		image.Visible = true

		local imageId

		if globalInputService.inputIcons.Misc[iconKey] then
			imageId = globalInputService.inputIcons.Misc[iconKey]
		elseif globalInputService.inputIcons.Keyboard[iconKey] then
			imageId = globalInputService.inputIcons.Keyboard[iconKey]
		elseif globalInputService.inputIcons[globalInputService._gamepadType][iconKey] then
			imageId = globalInputService.inputIcons[globalInputService._gamepadType][iconKey]
		else
			imageId = globalInputService.inputIcons.Misc.Unknown
		end

		image.Image = imageId and "rbxassetid://" .. imageId or ""
	end
end

local function setInputType(lastInput)
	if
		(lastInput.KeyCode == Enum.KeyCode.Thumbstick1 or lastInput.KeyCode == Enum.KeyCode.Thumbstick2)
		and lastInput.Position.Magnitude < 0.25
	then
		return
	end

	if lastInput.UserInputType == Enum.UserInputType.Touch then
		MobileJoysticks.setJoystickVisibility(true)
		globalInputService._inputType = "Touch"
		return
	end

	MobileJoysticks.setJoystickVisibility(false)

	if lastInput.UserInputType.Name:find("Gamepad") then
		globalInputService._inputType = "Gamepad"
		setGamepadType(lastInput)
		lastGamepadInput = lastInput
	else
		globalInputService._inputType = "Keyboard"
	end

	if lastInputType ~= globalInputService._inputType or lastGamepadType ~= globalInputService._gamepadType then
		globalInputService:CheckKeyPrompts()
		inputTypeChanged:Fire(globalInputService._inputType, lastInputType, globalInputService._gamepadType)
	end

	lastInputType = globalInputService._inputType
	lastGamepadType = globalInputService._gamepadType
end

local function Lerp(num, goal, i)
	return num + (goal - num) * i
end

local function getUdim2Magnitude(udim2: UDim2)
	local offsetMagnitude = Vector2.new(udim2.X.Offset, udim2.Y.Offset).Magnitude
	return offsetMagnitude
end

local function lerpToDistance(value: UDim2, goal: UDim2, alpha: number, pixelMagnitude: number)
	local valueMagnitude = getUdim2Magnitude(value - goal)

	if valueMagnitude < pixelMagnitude then
		return goal
	end
	return value:Lerp(goal, alpha)
end

local function handleGamepadSelection()
	local object = GuiService.SelectedObject
	if not selectionImage then
		return
	end

	if object then
		if selectionImage.Visible then
			selectionImage.Position = lerpToDistance(
				selectionImage.Position,
				UDim2.fromOffset(object.AbsolutePosition.X, object.AbsolutePosition.Y),
				0.25,
				5
			)

			selectionImage.Size = lerpToDistance(
				selectionImage.Size,
				UDim2.fromOffset(object.AbsoluteSize.X, object.AbsoluteSize.Y),
				0.25,
				5
			)

			selectionImage.Rotation = Lerp(selectionImage.Rotation, object.Rotation, 0.25)
		else
			selectionImage.Position = UDim2.fromOffset(object.AbsolutePosition.X, object.AbsolutePosition.Y)
			selectionImage.Size = UDim2.fromOffset(object.AbsoluteSize.X, object.AbsoluteSize.Y)
			selectionImage.Rotation = object.Rotation
		end

		selectionImage.Visible = true
	else
		selectionImage.Visible = false
	end
end

function globalInputService.CreateNewMobileJoystick(
	stickImage: string?,
	rimImage: string?,
	activationButton: TextButton?,
	size: number?,
	positionType: "AtTouch" | "AtCenter"?,
	visibility: "Dynamic" | "Static"?,
	keyCode: Enum.KeyCode?
)
	local newStick = MobileJoysticks.new(activationButton)

	newStick.StickImage = stickImage or newStick.StickImage
	newStick.RimImage = rimImage or newStick.RimImage

	newStick.Size = size or newStick.Size
	newStick.PositionType = positionType or newStick.PositionType
	newStick.Visibility = visibility or newStick.Visibility
	newStick.KeyCode = keyCode or newStick.KeyCode

	newStick.Instance.Parent = inputServiceGui

	return newStick
end

local function setCustomImage(actionButton)
	if not actionButton then
		return
	end

	-- PIXEL GAME HARDCODING
	actionButton.ResampleMode = Enum.ResamplerMode.Pixelated
	if actionButton:FindFirstChild("ActionIcon") then
		actionButton.ActionIcon.ResampleMode = Enum.ResamplerMode.Pixelated
	end

	actionButton.Image = CUSTOM_MOBILE_BUTTON_IMAGES["Default"]
	actionButton:GetPropertyChangedSignal("Image"):Connect(function()
		actionButton.Image = CUSTOM_MOBILE_BUTTON_IMAGES["Default"]
		actionButton.PressedImage = CUSTOM_MOBILE_BUTTON_IMAGES["Pressed"]
	end)
end

function globalInputService.CreateInputAction(
	inputName: string,
	func: (inputState: Enum.UserInputState, input: InputObject) -> any?,
	keyboardInputs: { InputCode } | InputCode,
	gamepadInputs: ({ InputCode } | InputCode)?,
	mobileInputType: "Button" | "Joystick"?
): InputAction
	if typeof(keyboardInputs) ~= "table" then
		keyboardInputs = { keyboardInputs }
	end

	if typeof(gamepadInputs) ~= "table" then
		gamepadInputs = { gamepadInputs }
	end

	local mobileJoystick: GuiJoystick
	local inputIsEnabled = false
	local buttonPosition = UDim2.new(0, 0, 0, 0)
	local buttonImage = ""

	local newInput: InputAction = {
		Name = inputName,
		KeyInputs = {
			Keyboard = keyboardInputs,
			Gamepad = gamepadInputs,
		},
		Callback = func,
		Priority = nil,

		IsEnabled = function()
			return inputIsEnabled
		end,

		Enable = function(self: InputAction)
			if inputIsEnabled then
				return
			end

			local callback = self.Callback
			inputIsEnabled = true

			local allInputs = {}
			for _, input in ipairs(self.KeyInputs.Gamepad) do
				table.insert(allInputs, input)
			end

			for _, input in ipairs(self.KeyInputs.Keyboard) do
				table.insert(allInputs, input)
			end

			if self.Priority then
				ContextActionService:BindActionAtPriority(
					self.Name,
					function(_, inputState: Enum.UserInputState, input: InputObject)
						return callback(inputState, input)
					end,
					mobileInputType == "Button",
					self.Priority,
					table.unpack(allInputs)
				)
			else
				ContextActionService:BindAction(
					self.Name,
					function(_, inputState: Enum.UserInputState, input: InputObject)
						return callback(inputState, input)
					end,
					mobileInputType == "Button",
					table.unpack(allInputs)
				)
			end

			ContextActionService:SetPosition(self.Name, buttonPosition)
			ContextActionService:SetImage(self.Name, buttonImage)

			local actionButton = ContextActionService:GetButton(self.Name) -- custom Image
			setCustomImage(actionButton)

			if mobileInputType == "Joystick" then
				mobileJoystick = globalInputService.CreateNewMobileJoystick()
				mobileJoystick.InputChanged:Connect(function(inputObject)
					callback(inputObject.UserInputState, inputObject)
				end)
				mobileJoystick.InputBegan:Connect(function(inputObject)
					callback(inputObject.UserInputState, inputObject)
				end)
				mobileJoystick.InputEnded:Connect(function(inputObject)
					callback(inputObject.UserInputState, inputObject)
				end)
			end
		end,

		Disable = function(self: InputAction)
			if not inputIsEnabled then
				return
			end

			inputIsEnabled = false
			if mobileJoystick then
				mobileJoystick:Destroy()
			end

			ContextActionService:UnbindAction(self.Name)
		end,

		Refresh = function(self: InputAction)
			if not inputIsEnabled then
				return
			end

			self:Disable()
			self:Enable()
		end,

		GetMobileInput = function(self: InputAction)
			if not self.IsEnabled() then
				return
			end

			if mobileInputType == "Button" then
				return ContextActionService:GetButton(self.Name)
			elseif mobileInputType == "Joystick" then
				return mobileJoystick
			end

			return
		end,

		GetMobileIcon = function()
			return buttonImage
		end,

		SetPriority = function(self: InputAction, priority: number | Enum.ContextActionPriority)
			self.Priority = tonumber(priority) and priority or priority.Value
			self:Refresh()
		end,

		SetKeybinds = function(self: InputAction, bindGroup: "Gamepad" | "Keyboard", ...)
			self.KeyInputs[bindGroup] = { ... }
			self:Refresh()
		end,
		AddKeybinds = function(self: InputAction, bindGroup: "Gamepad" | "Keyboard", ...)
			local keybinds = { ... }
			for _, keybind: Enum.KeyCode | Enum.UserInputType in ipairs(keybinds) do
				table.insert(self.KeyInputs[bindGroup], keybind)
			end
			self:Refresh()
		end,
		RemoveKeybinds = function(self: InputAction, bindGroup: "Gamepad" | "Keyboard", ...)
			local keybinds = { ... }
			for _, keybind in ipairs(keybinds) do
				local keybindIndex = table.find(self.KeyInputs[bindGroup], keybind)
				if not keybindIndex then
					continue
				end

				table.remove(self.KeyInputs[bindGroup], keybindIndex)
			end
			self:Refresh()
		end,
		ReplaceKeybinds = function(self: InputAction, bindGroup: "Gamepad" | "Keyboard", keybindsTable: { InputCode })
			for toReplace, keybind in pairs(keybindsTable) do
				local keybindIndex = table.find(self.KeyInputs[bindGroup], toReplace)
				if not keybindIndex then
					continue
				end

				self.KeyInputs[bindGroup][keybindIndex] = keybind
			end

			self:Refresh()
		end,

		SetImage = function(self: InputAction, image: string)
			buttonImage = image
			ContextActionService:SetImage(self.Name, buttonImage)
		end,

		SetPosition = function(self: InputAction, position: UDim2)
			buttonPosition = position
			ContextActionService:SetPosition(self.Name, buttonPosition)
		end,
	}

	globalInputService.inputActions[inputName] = newInput
	newInput:Enable()

	return newInput
end

function globalInputService.CreateActionGroup(name: string): ActionGroup
	local newScale = Scales.new()
	local actionGroup: ActionGroup = {
		Name = name,
		Actions = {},
		IsEnabled = not newScale:Check(),
		Enable = function(self: ActionGroup, index: any?)
			newScale:Remove(index)
		end,

		Disable = function(self: ActionGroup, index: any?)
			newScale:Add(index)
		end,
	}

	newScale.Changed:Connect(function(isDisabled)
		actionGroup.IsEnabled = not isDisabled

		if actionGroup.IsEnabled then
			for _, action: InputAction in pairs(actionGroup.Actions) do
				action:Enable()
			end
		else
			for _, action: InputAction in pairs(actionGroup.Actions) do
				action:Disable()
			end
		end
	end)

	globalInputService.actionGroups[name] = actionGroup

	return actionGroup
end

function globalInputService.AddToActionGroup(actionGroup: ActionGroup | string, ...: InputAction)
	if typeof(actionGroup) == "string" then
		local actionGroupName = actionGroup
		actionGroup = globalInputService.actionGroups[actionGroupName]

		if not actionGroup then
			actionGroup = globalInputService.CreateActionGroup(actionGroupName)
		end
	end

	local actions = { ... }

	for _, action in ipairs(actions) do
		actionGroup.Actions[action.Name] = action
	end
end

function globalInputService:SelectGui(frame: GuiObject)
	if self:GetInputSource().Type == "Gamepad" then
		GuiService:Select(frame)
	end
end

function globalInputService.StartGame()
	globalInputService:CheckKeyPrompts()
end

--// Main //--
UserInputService.InputBegan:Connect(setInputType)
UserInputService.InputChanged:Connect(setInputType)

inputServiceGui.DisplayOrder = -1
inputServiceGui.Name = "InputServiceGui"
inputServiceGui.Parent = Player:WaitForChild("PlayerGui")

if not CUSTOM_GAMEPAD_GUI then
	return globalInputService
end

createCustomGamepadGui()

GuiService.Changed:Connect(function()
	if GuiService.SelectedObject then
		if not stepped then
			stepped = RunService.RenderStepped:Connect(handleGamepadSelection)
		end
	elseif stepped then
		stepped:Disconnect()
		stepped = nil
		handleGamepadSelection()
	end
end)

Player:WaitForChild("PlayerGui").SelectionImageObject = hideSelection

return globalInputService
