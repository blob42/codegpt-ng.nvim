local Render = require("codegpt.template_render")
local Message = require("codegpt.message")
local history = require("codegpt.history").get()

--- A chat session
---@class codegpt.Messages
---@field id integer unique id for this chat
---@field messages codegpt.Chatmsg[]
local Messages = {}
Messages.__index = Messages

--- Creates a new Messages object with the given messages
---@param ... codegpt.Chatmsg One or more messages
---@return codegpt.Messages
function Messages.new(...)
	local self = {}
	setmetatable(self, Messages)

	self.messages = {}
	self.id = os.time() * 1000 + math.random(1, 999)

	local args = { ... }
	if #args > 0 then
		self.messages = vim.list_extend(self.messages, args)
	end

	return self
end

function Messages:list()
	return self.messages
end

---@param msg codegpt.Chatmsg
function Messages:add(msg)
	assert(msg ~= nil)
	assert(type(msg.role) == "string", "msg.role must be a string")
	assert(
		msg.role == "system" or msg.role == "assistant" or msg.role == "user",
		"Invalid role: expected 'system', 'assistant', or 'user'"
	)
	table.insert(self.messages, msg)
end

---@param command string
---@param cmd_opts codegpt.CommandOpts
---@param command_args string
---@param text_selection string
---@return codegpt.Chatmsg[] messages
function Messages.generate_messages(command, cmd_opts, command_args, text_selection)
	local system_message =
		Render.render(command, cmd_opts.system_message_template, command_args, text_selection, cmd_opts, true)
	local user_message =
		Render.render(command, cmd_opts.user_message_template, command_args, text_selection, cmd_opts, false)
	if cmd_opts.append_string then
		user_message = user_message .. " " .. cmd_opts.append_string
	end

	local messages = Messages.new()

	if system_message ~= nil and system_message ~= "" then
		messages:add(Message.System(system_message))
	end

	if cmd_opts.chat_history then
		for _, msg in ipairs(cmd_opts.chat_history) do
			messages:add(msg)
		end
	end

	if user_message ~= nil and user_message ~= "" then
		messages:add(Message.User(user_message))
	end

	history:push(messages)
	return messages:list()
end

-- local msgs = Messages.new()
-- msgs()
-- msgs:add({ role = "system" })
-- print(vim.inspect(msgs.messages))
return Messages
