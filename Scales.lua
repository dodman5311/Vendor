export type Scale = {
	LastCheck: boolean,
	Contents: {},
	--[[
	1 Default
]]
	Threshold: number,
	Check: (self: Scale) -> boolean,
	Add: (self: Scale, index: string | number?, value: any?) -> boolean,
	Remove: (self: Scale, index: string | number?) -> boolean,
	Changed: RBXScriptSignal<...boolean>,
}

local scales = {
	activeScales = {},
}

local function getSize(list: {})
	local count = 0
	for _, _ in pairs(list) do
		count += 1
	end
	return count
end

local function checkForSignal(scale: Scale, changedEvent: BindableEvent)
	local isOverThreshold: boolean = scale:Check()

	if scale.LastCheck ~= isOverThreshold then
		changedEvent:Fire(isOverThreshold)
	end

	scale.LastCheck = isOverThreshold

	return isOverThreshold
end

function scales.new(index: string?): Scale
	local changedEvent = Instance.new("BindableEvent")

	local scale: Scale = {
		LastCheck = false,
		Contents = {},
		Threshold = 1,
		Check = function(self: Scale)
			local weight = getSize(self.Contents)
			local isOverThreshold = weight >= self.Threshold

			return isOverThreshold
		end,
		Add = function(self: Scale, index: string | number?, value: any?)
			if index then
				self.Contents[index] = value or true
			else
				table.insert(self.Contents, value or true)
			end

			return checkForSignal(self, changedEvent)
		end,
		Remove = function(self: Scale, index: string | number?)
			index = index or 1

			if typeof(index) == "number" then
				table.remove(self.Contents, index)
			else
				self.Contents[index] = nil
			end

			return checkForSignal(self, changedEvent)
		end,

		Changed = changedEvent.Event,
	}

	if index then
		scales.activeScales[index] = scale
	end

	return scale
end

return scales
