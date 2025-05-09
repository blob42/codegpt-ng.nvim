local Config = require("codegpt.config")
local M = {}

local Commands = require("codegpt.commands")
local CommandsList = require("codegpt.commands_list")
local Utils = require("codegpt.utils")

local function has_command_args(opts)
	local pattern = "%{%{command_args%}%}"
	return string.find(opts.user_message_template or "", pattern)
		or string.find(opts.system_message_template or "", pattern)
end

function M.get_status(...)
	return Commands.get_status(...)
end

function M.run_cmd(opts)
	if opts.name and opts.name:match("^V") then
		Config.popup_override = "vertical"
	else
		Config.popup_override = nil
	end

	-- handle bang
	if opts.bang then
		Config.persistent_override = true
	else
		Config.persistent_override = false
	end

	local text_selection, bounds = Utils.get_selected_lines(opts)
	local command_args = table.concat(opts.fargs, " ")

	local command = opts.fargs[1]

	if command_args ~= "" then
		local cmd_opts = CommandsList.get_cmd_opts(command)
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
		elseif vim.g["codegpt_commands"][command] == nil then
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

	Commands.run_cmd(command, command_args, text_selection, bounds)
end

--- List available models
function M.list_models()
	local models = Providers.get_provider().get_models()
	vim.ui.select(models, {
		prompt = "ollama: available models",
		format_item = function(item)
			return item.name
		end,
	}, function(choice)
		if choice.name ~= nil and #choice.name > 0 then
			print(choice.name)
		end
	end)
end

function M.select_model()
	local models = Providers.get_provider().get_models()
	vim.ui.select(models, {
		prompt = "ollama: available models",
		format_item = function(item)
			return item.name
		end,
	}, function(choice)
		if choice ~= nil and #choice.name > 0 then
			Config.model_override = choice.name
			print("model override = <" .. choice.name .. ">")
		end
	end)
end

M.setup = Config.setup

return M
