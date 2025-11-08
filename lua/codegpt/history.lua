---@class History
---@field id integer
---@field messages codegpt.Message[]
---@field last_role? codegpt.Role
local History = {}

-- Set up the __index metamethod to allow inheritance or method lookup
History.__index = History

-- Constructor function for creating new instances of History
---@return History
function History.new(o)
	local self = {}
	setmetatable(self, History)
	o = o or {}

	self.id = os.time() * 1000 + math.random(1, 999)

	self.messages = o.messages or {}

	return self
end

-- Example methods (you can add more as needed)
---@param msg codegpt.Message
function History:add(msg)
	table.insert(self.messages, msg)
end

function History:list()
	return self.messages or {}
end

-- Return the module for use elsewhere
local hist = History.new()

return History
