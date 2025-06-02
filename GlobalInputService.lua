export type GuiJoystick = {
	StickImage: string,
	RimImage: string,
	ImageType: Enum.ResamplerMode?,
	Size: number,
	Position: "AtTouch" | "AtCenter",

	Visibility: "Dynamic" | "Static",
	ActivationButton: TextButton,

	InputBegan: RBXScriptSignal,
	InputChanged: RBXScriptSignal,
	InputEnded: RBXScriptSignal,

	Instance: ScreenGui,
}
export type InputAction = {
	Name: string,
	KeyInputs: {
		Keyboard: { InputObject },
		Gamepad: { InputObject },
	},
	Callback: () -> any?,
	Priority: number?,
	IsEnabled: () -> boolean,

	Enable: (self: InputAction) -> nil,
	Disable: (self: InputAction) -> nil,
	Refresh: (self: InputAction) -> nil,
	GetMobileInput: (self: InputAction) -> ImageButton | GuiJoystick?,
	SetPriority: (self: InputAction, priority: number | Enum.ContextActionPriority) -> nil,
	SetKeybinds: (self: InputAction, bindGroup: "Gamepad" | "Keyboard", T...) -> nil,
	AddKeybinds: (self: InputAction, bindGroup: "Gamepad" | "Keyboard", T...) -> nil,
	RemoveKeybinds: (self: InputAction, bindGroup: "Gamepad" | "Keyboard", T...) -> nil,
	ReplaceKeybinds: (self: InputAction, bindGroup: "Gamepad" | "Keyboard", keybindsTable: { InputObject }) -> nil,
}
type InputType = "Keyboard" | "Gamepad" | "Touch"
type GamepadType = "Ps4" | "Xbox"?
export type InputSource = {
	Type: InputType,
	GamepadType: GamepadType,
	LastGamepadInput: InputObject?,
}

local CUSTOM_GAMEPAD_GUI = true

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local Player: Player = Players.LocalPlayer
local stepped: RBXScriptConnection?

local inputServiceGui: ScreenGui? = Instance.new("ScreenGui")
inputServiceGui.DisplayOrder = 100
inputServiceGui.Name = "InputServiceGui"

local selectionImage: GuiObject?
local hideSelection: ImageLabel?

local lastInputType: string?
local lastGamepadType: string?
local lastGamepadInput: InputObject?

local inputTypeChanged = Instance.new("BindableEvent")

local globalInputService = {
	InputTypeChanged = inputTypeChanged.Event :: RBXScriptSignal,
	GetInputSource = function(self): InputSource
		return {
			Type = self._inputType,
			GamepadType = self._inputType == "Gamepad" and self._gamepadType,
			LastGamepadInput = lastGamepadInput,
		}
	end,

	inputIcons = {
		Ps4 = {
			ButtonX = "122062730815411",
			ButtonA = "99222140491626",
			ButtonB = "139151046418306",
			ButtonY = "124498431294550",
		},
		Xbox = {
			ButtonX = "122267119998385",
			ButtonA = "121295530666976",
			ButtonB = "97330447691033",
			ButtonY = "73181495754569",
		},
		Keyboard = {
			MouseButton1 = "115777151252419",
			MouseButton2 = "126344159018792",
			MouseButton3 = "95452537473335",
			Scroll = "129056272209004",

			A = "101275553943757",
			B = "82125102642552",
			C = "75040199280823",
			D = "136848745869062",
			E = "136402653357293",
			F = "74228350755401",
			G = "139863023567545",
			H = "128507033987187",
			I = "132474088542264",
			J = "102179810274882",
			K = "87814320776721",
			L = "99738826372890",
			M = "121076145919314",
			N = "136011881995276",
			O = "140099094723629",
			P = "110404287194349",
			Q = "119136958738304",
			R = "86806472892566",
			S = "108784305233331",
			T = "96905636160084",
			U = "94844091505145",
			V = "87680637350638",
			W = "102148238829302",
			X = "87163573711492",
			Y = "127900229578238",
			Z = "80586602767548",

			One = "87310485799989",
			Two = "104360287893229",
			Three = "108142578535176",
			Four = "131238976336903",
			Five = "89806329448950",
			Six = "109902722112996",
			Seven = "124839388428121",
			Eight = "81782371502694",
			Nine = "85135646962139",
			Zero = "132714539349368",

			Tab = "116362922317477",
			Backspace = "78379859775356",
			Return = "92998529564469",

			LeftAlt = "87837814972423",
			RightAlt = "87837814972423",
			LeftControl = "106626790058135",
			RightControl = "106626790058135",
			LeftShift = "77318620414643",
			RightShift = "84872227572806",

			Left = "128150224671805",
			Right = "102185023122198",
			Up = "99253643967342",
			Down = "87452731519451",

			F1 = "103476659333916",
			F2 = "118103405706830",
			F3 = "132768899424965",
			F4 = "128049648305911",
			F5 = "79143962195606",
			F6 = "80822468566195",
			F7 = "88851680649058",
			F8 = "99080921834878",
			F9 = "79483779934054",
			F10 = "87514655605900",
			F11 = "122519259304949",
			F12 = "120250003182329",
		},
		Misc = {
			DPadAll = "104088083610808",
			Horizontal = "134923880414479",
			Vertical = "81470201795928",
			DPadLeft = "102626010372615",
			DPadRight = "128897927978505",
			DPadUp = "112547970720772",
			DPadDown = "136246329210868",

			Unknown = "136342675608310",

			ButtonL1 = "97608958968765", -- left bumper
			ButtonL2 = "84837513862254", -- left trigger
			ButtonR1 = "84450330851971",
			ButtonR2 = "70730301952026",
		},
	},

	inputActions = {} :: { InputAction },

	_inputType = "Keyboard" :: InputType,
	_gamepadType = "Xbox" :: GamepadType,
}

local ps4Keys = {
	"ButtonCross",
	"ButtonCircle",
	"ButtonTriangle",
	"ButtonSquare",

	"ButtonR1",
	"ButtonR2",
	"ButtonR3",
	"ButtonL1",
	"ButtonL2",
	"ButtonL3",
	"ButtonOptions",
	"ButtonShare",
}

local xboxKeys = {
	"ButtonA",
	"ButtonB",
	"ButtonX",
	"ButtonY",

	"ButtonLB",
	"ButtonRB",
	"ButtonLT",
	"ButtonRT",
	"ButtonLS",
	"ButtonRS",
	"ButtonStart",
	"ButtonSelect",
}

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

		if image:GetAttribute("InputName") and globalInputService.inputActions[image:GetAttribute("InputName")] then
			iconKey =
				globalInputService.inputActions[image:GetAttribute("InputName")].KeyInputs[globalInputService._inputType][1].Name
		end

		local KEY = image:GetAttribute("Key")
		local BUTTON = image:GetAttribute("Button")
		local INPUT_NAME = image:GetAttribute("InputName")

		if
			(globalInputService._inputType == "Gamepad" and BUTTON)
			or (globalInputService._inputType == "Keyboard" and KEY)
		then
			iconKey = globalInputService._inputType == "Gamepad" and BUTTON or KEY
		elseif INPUT_NAME and globalInputService.inputActions[INPUT_NAME] then
			iconKey = globalInputService.inputActions[INPUT_NAME].KeyInputs[globalInputService._inputType][1].Name
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

	if lastInput.KeyCode == Enum.UserInputType.Touch then
		globalInputService._inputType = "Touch"
		return
	end

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

function globalInputService.CreateJoystick(

	stickImage: string?,
	rimImage: string?,
	activationButton: TextButton?,
	size: number?,
	position: "AtTouch" | "AtCenter"?,
	visibility: "Dynamic" | "Static"?
): GuiJoystick
	local inputBegan = Instance.new("BindableEvent")
	local inputChanged = Instance.new("BindableEvent")
	local inputEnded = Instance.new("BindableEvent")

	local joystick: GuiJoystick = {
		StickImage = stickImage or "",
		RimImage = rimImage or "",
		ImageType = nil,

		Size = size or 0.1,
		Position = position or "AtTouch",
		Visibility = visibility or "Dynamic",
		ActivationButton = activationButton or Instance.new("TextButton"),

		InputBegan = inputBegan.Event,
		InputChanged = inputChanged.Event,
		InputEnded = inputEnded.Event,

		Instance = Instance.new("Frame"),
	}

	local stick = Instance.new("ImageLabel")
	local rim = Instance.new("ImageLabel")
	local onMouseMoved

	local function updateJoystick()
		rim.Size = UDim2.fromScale(joystick.Size, joystick.Size)
		rim.Image = joystick.RimImage
		stick.Image = joystick.StickImage
		stick.ResampleMode = joystick.ImageType or Enum.ResamplerMode.Default
	end

	local proxy = setmetatable({}, {
		__index = joystick,
		__newindex = function(_, key, value)
			local oldValue = joystick[key]
			if oldValue == value then
				return
			end -- No change detected
			joystick[key] = value

			if key ~= "StickImage" and key ~= "RimImage" and key ~= "Size" and key ~= "ImageType" then
				return
			end

			updateJoystick()
		end,
		__metatable = "Locked", -- Prevent external access to the metatable
	})

	joystick.ActivationButton.Parent = joystick.Instance
	joystick.ActivationButton.ZIndex = 2
	joystick.ActivationButton.BackgroundTransparency = 1
	joystick.ActivationButton.TextTransparency = 1

	stick.Parent = rim
	stick.Name = "Stick"
	stick.Size = UDim2.fromScale(1, 1)
	stick.BackgroundTransparency = 1
	stick.AnchorPoint = Vector2.new(0.5, 0.5)
	stick.Position = UDim2.fromScale(0.5, 0.5)

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = rim

	rim.Parent = joystick.Instance
	rim.Name = "Rim"
	rim.BackgroundTransparency = 1
	rim.AnchorPoint = Vector2.new(0.5, 0.5)

	joystick.Instance.Parent = inputServiceGui
	joystick.Instance.Name = "Joystick"
	joystick.Instance.BackgroundTransparency = 1
	joystick.Instance.Size = UDim2.fromScale(1, 1)

	updateJoystick()

	if joystick.Visibility == "Static" then
		rim.Visible = true
	end

	joystick.ActivationButton.MouseButton1Down:Connect(function(initX, initY)
		if joystick.Visibility == "Dynamic" then
			rim.Visible = true
		end

		if joystick.Position == "AtTouch" then
			rim.Position = UDim2.fromOffset(initX, initY - 58)
		elseif joystick.Position == "AtCenter" then
			rim.Position = UDim2.fromOffset(
				joystick.ActivationButton.AbsolutePosition.X,
				joystick.ActivationButton.AbsolutePosition.Y
			)
		end

		inputChanged:Fire(Vector2.zero)

		stick.Position = UDim2.fromScale(0.5, 0.5)

		onMouseMoved = joystick.ActivationButton.MouseMoved:Connect(function(x, y)
			local relativePosition = Vector2.new(x - initX, y - initY)
			local length = relativePosition.Magnitude
			local maxLength = rim.AbsoluteSize.X / 2

			length = math.min(length, maxLength)
			relativePosition = relativePosition.Unit * length

			stick.Position = UDim2.new(
				0,
				relativePosition.X + rim.AbsoluteSize.X / 2,
				0,
				relativePosition.Y + rim.AbsoluteSize.Y / 2
			)

			local inputPosition = (relativePosition / rim.AbsoluteSize.Y) * 2
			inputPosition = Vector2.new(inputPosition.X, -inputPosition.Y)

			inputChanged:Fire(inputPosition)
		end)
	end)

	local function onTouchEnd()
		if onMouseMoved then
			onMouseMoved:Disconnect()
		end

		if joystick.Visibility == "Dynamic" then
			rim.Visible = false
		end

		inputChanged:Fire(Vector2.zero)
		inputEnded:Fire()
	end

	joystick.ActivationButton.MouseButton1Up:Connect(onTouchEnd)
	joystick.ActivationButton.MouseLeave:Connect(onTouchEnd)

	return proxy
end

function globalInputService.CreateInputAction(
	inputName: string,
	func: () -> any?,
	keyboardInputs: { InputObject } | InputObject,
	gamepadInputs: { InputObject } | InputObject?,
	mobileInputType: "Button" | "Joystick"?
): InputAction
	if typeof(keyboardInputs) ~= "table" then
		keyboardInputs = { keyboardInputs }
	end

	if typeof(gamepadInputs) ~= "table" then
		gamepadInputs = { gamepadInputs }
	end

	local mobileJoystick: GuiJoystick?
	local inputIsEnabled = false
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
			local callback = self.Callback
			inputIsEnabled = true

			local allInputs = self.KeyInputs.Keyboard
			for _, input in ipairs(self.KeyInputs.Gamepad) do
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

			if mobileInputType == "Joystick" then
				mobileJoystick = globalInputService.CreateJoystick().InputChanged:Connect(function(position)
					callback(Enum.UserInputState.Change, {
						Position = position,
					})
				end)
			end
		end,

		Disable = function(self: InputAction)
			inputIsEnabled = false
			if self:GetMobileInput() then
				self:GetMobileInput():Destroy()
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
			if mobileInputType == "Button" then
				return ContextActionService:GetButton(self.Name)
			elseif mobileInputType == "Joystick" then
				return mobileJoystick
			end
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
		ReplaceKeybinds = function(
			self: InputAction,
			bindGroup: "Gamepad" | "Keyboard",
			keybindsTable: { InputObject }
		)
			for toReplace, keybind in pairs(keybindsTable) do
				local keybindIndex = table.find(self.KeyInputs[bindGroup], toReplace)
				if not keybindIndex then
					continue
				end

				self.KeyInputs[bindGroup][keybindIndex] = keybind
			end

			self:Refresh()
		end,
	}

	globalInputService.inputActions[inputName] = newInput
	newInput:Enable()

	return newInput
end

function globalInputService.StartGame()
	globalInputService:CheckKeyPrompts()
end

UserInputService.InputBegan:Connect(setInputType)
UserInputService.InputChanged:Connect(setInputType)

inputServiceGui.Parent = Player.PlayerGui

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
