local Render = require("codegpt.template_render")
local M = {}

---@alias codegpt.Role
---|'system'
---|'user'
---|'assistant'

---@class codegpt.Message
---@field role string
---@field msg string
local Message = {}

Message.__index = Message

-- ---@alias codegpt.Messages codegpt.Message[]
--
-- ---@type codegpt.Messages
-- local Messages = {}

--- create a new message
---@param role codegpt.Role
---@param msg string
---@return codegpt.Message
function Message.new(role, msg)
	-- Check if role is provided and not nil/empty
	if not role or not msg then
		error("role and message is required")
	end

	local self = { role = role, msg = msg }

	setmetatable(self, Message)

	return self
end

function Message:print()
	print(string.format("[%s] %s", self.role, self.msg))
end

--- Create a system message
---@param msg string
---@return codegpt.Message
function Message.System(msg)
	return Message.new("system", msg)
end

--- Create a user message
---@param msg string
---@return codegpt.Message
function Message.User(msg)
	return Message.new("user", msg)
end

--- Create an assistant message
---@param msg string
---@return codegpt.Message
function Message.Assistant(msg)
	return Message.new("assistant", msg)
end

---@param command string
---@param cmd_opts codegpt.CommandOpts
---@param command_args string
---@param text_selection string
---@return codegpt.Message[] messages
function M.generate_messages(command, cmd_opts, command_args, text_selection)
	local system_message =
		Render.render(command, cmd_opts.system_message_template, command_args, text_selection, cmd_opts, true)
	local user_message =
		Render.render(command, cmd_opts.user_message_template, command_args, text_selection, cmd_opts, false)
	if cmd_opts.append_string then
		user_message = user_message .. " " .. cmd_opts.append_string
	end

	local messages = {}

	if system_message ~= nil and system_message ~= "" then
		table.insert(messages, { role = "system", content = system_message })
	end

	if cmd_opts.chat_history then
		for _, msg in ipairs(cmd_opts.chat_history) do
			table.insert(messages, msg)
		end
	end

	if user_message ~= nil and user_message ~= "" then
		table.insert(messages, { role = "user", content = user_message })
	end

	return messages
end

local msg = Message.new("system", "random system message")
msg:print()

local sysmsg = Message.System("hello system prompt")
sysmsg:print()

return M
