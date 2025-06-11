local Render = require("codegpt.template_render")
local M = {}

---@param command string
---@param cmd_opts codegpt.CommandOpts
---@param command_args string
---@param text_selection string
function M.generate_messages(command, cmd_opts, command_args, text_selection)
	local system_message =
		Render.render(command, cmd_opts.system_message_template, command_args, text_selection, cmd_opts)
	local user_message = Render.render(command, cmd_opts.user_message_template, command_args, text_selection, cmd_opts)
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

return M
