local Config = require("codegpt.config")
local Models = require("codegpt.models")
local Api = require("codegpt.api")
local history = require("codegpt.history")
local M = {}

local Commands = require("codegpt.commands")
local Utils = require("codegpt.utils")

local function has_command_args(opts)
	local pattern = "%{%{command_args%}%}"
	return string.find(opts.user_message_template or "", pattern)
		or string.find(opts.system_message_template or "", pattern)
end

function M.get_status(...)
	return Commands.get_status(...)
end

---@param opts vim.api.keyset.create_user_command.command_args
function M.run_cmd(opts)
	if opts.name and opts.name:match("^V") then
		Config.popup_override = "vertical"
	else
		Config.popup_override = nil
	end

	-- bang makes popup persistent until closed
	if opts.bang then
		Config.persistent_override = true
	else
		Config.persistent_override = false
	end

	local command
	local override_cb_type = nil
	if opts.fargs[1] == ">" then
		override_cb_type = "append_lines"
	elseif opts.fargs[1] == "<" then
		override_cb_type = "prepend_lines"
	elseif opts.fargs[1] == "-" then
		override_cb_type = "replace_lines"
	elseif opts.fargs[1] == "." then
		override_cb_type = "insert_lines"
	elseif opts.fargs[1] == "?" then
		override_cb_type = "text_popup"
	elseif opts.fargs[1] == "$" then
		override_cb_type = "code_popup"
	end

	if override_cb_type ~= nil then
		table.remove(opts.fargs, 1) -- Remove the first argument since it's an override indicator
	end

	local text_selection, range = Utils.get_selected_lines(opts)
	local command_args = table.concat(opts.fargs, " ")
	command = opts.fargs[1]


	local cmd_opts, is_stream = Commands.get_cmd_opts(command, override_cb_type)
	if cmd_opts == nil then
		vim.notify("Command not found: " .. command, vim.log.levels.ERROR, {
			title = "CodeGPT",
		})
		return
	end
	if command_args ~= "" then
		if cmd_opts ~= nil and has_command_args(cmd_opts) then
			if cmd_opts.allow_empty_text_selection == false and text_selection == "" then
				command = "chat"
			else
				command_args = table.concat(opts.fargs, " ", 2)
			end
		elseif cmd_opts and 1 == #opts.fargs then
			command_args = ""
		elseif text_selection == "" then
			command = "chat"
		elseif Config.opts.commands[command] == nil then
			command = "code_edit"
		end
	elseif text_selection ~= "" and command_args == "" then
		command = "completion"
	end

	if command == nil or command == "" then
		vim.notify("No command or text selection provided", vim.log.levels.ERROR, {
			title = "CodeGPT",
		})
		return
	end

	Commands.run_cmd(command, cmd_opts, is_stream, command_args, text_selection, range)
end

M.setup = Config.setup
M.select_model = Models.select_model
M.cancel_request = Api.cancel_job
M.stream_on = Api.stream_on
M.stream_off = Api.stream_off
M.debug_prompt = Config.toggle_debug_prompt
M.show_chat = history.show_chat

return M
