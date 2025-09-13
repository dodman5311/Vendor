local ReplicatedStorage = game:GetService("ReplicatedStorage")
local signal = require(ReplicatedStorage.Packages.Signal)

export type Scale = {
	LastCheck : boolean,
	Contents: {},
	--[[
	1 Default
]]
	Threshold: number,
	Check: (self: Scale) -> boolean,
	Add: (self: Scale, index: string | number?, value: any?) -> boolean,
	Remove: (self: Scale, index: string | number?) -> boolean,
	Changed: signal.Signal<boolean>,
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

local function checkForSignal(scale: Scale)
	local isOverThreshold : boolean = scale:Check()

	if scale.LastCheck ~= isOverThreshold then
		scale.Changed:Fire(isOverThreshold)
	end

	scale.LastCheck = isOverThreshold

	return isOverThreshold
end

function scales.new(index: string?): Scale
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

			return checkForSignal(self)
		end,
		Remove = function(self: Scale, index: string | number?)
			index = index or 1

			if typeof(index) == "number" then
				table.remove(self.Contents, index)
			else
				self.Contents[index] = nil
			end

			return checkForSignal(self)
		end,

		Changed = signal.new(),
	}

	if index then
		scales.activeScales[index] = scale
	end

	return scale
end

return scales
