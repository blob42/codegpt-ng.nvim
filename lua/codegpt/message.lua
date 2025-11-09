---@alias codegpt.Role
---|'system'
---|'user'
---|'assistant'

---@class codegpt.Chatmsg
---@field role codegpt.Role
---@field content string
local Message = {}

Message.__index = Message

--- create a new message
---@param role codegpt.Role
---@param msg string
---@return codegpt.Chatmsg
function Message.new(role, msg)
	-- Check if role is provided and not nil/empty
	if not role or not msg then
		error("role and message is required")
	end

	local self = { role = role, content = msg }

	setmetatable(self, Message)

	return self
end

function Message:print()
	print(string.format("[%s] %s", self.role, self.content))
end

--- Create a system message
---@param msg string
---@return codegpt.Chatmsg
function Message.System(msg)
	return Message.new("system", msg)
end

--- Create a user message
---@param msg string
---@return codegpt.Chatmsg
function Message.User(msg)
	return Message.new("user", msg)
end

--- Create an assistant message
---@param msg string
---@return codegpt.Chatmsg
function Message.Assistant(msg)
	return Message.new("assistant", msg)
end

return Message
