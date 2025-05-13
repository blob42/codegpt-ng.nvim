local Utils = require("codegpt.utils")
local Ui = require("codegpt.ui")
local Providers = require("codegpt.providers")
local Api = require("codegpt.api")
local Config = require("codegpt.config")
local models = require("codegpt.models")

local M = {}

local text_popup_stream = function(stream, bufnr, start_row, start_col, end_row, end_col)
	local popup_filetype = Config.opts.ui.text_popup_filetype
	Ui.popup_stream(stream, popup_filetype, bufnr, start_row, start_col, end_row, end_col)
end

M.CallbackTypes = {
	["text_popup_stream"] = text_popup_stream,
	["text_popup"] = function(lines, bufnr, start_row, start_col, end_row, end_col)
		local popup_filetype = Config.opts.ui.text_popup_filetype
		Ui.popup(lines, popup_filetype, bufnr, start_row, start_col, end_row, end_col)
	end,
	["code_popup"] = function(lines, bufnr, start_row, start_col, end_row, end_col)
		lines = Utils.trim_to_code_block(lines)
		Utils.fix_indentation(bufnr, start_row, end_row, lines)
		Ui.popup(lines, Utils.get_filetype(), bufnr, start_row, start_col, end_row, end_col)
	end,
	["replace_lines"] = function(lines, bufnr, start_row, start_col, end_row, end_col)
		lines = Utils.strip_reasoning(lines, "<think>", "</think>")
		lines = Utils.trim_to_code_block(lines)
		lines = Utils.remove_trailing_whitespace(lines)
		Utils.fix_indentation(bufnr, start_row, end_row, lines)
		if vim.api.nvim_buf_is_valid(bufnr) == true then
			Utils.replace_lines(lines, bufnr, start_row, start_col, end_row, end_col)
		else
			-- if the buffer is not valid, open a popup. This can happen when the user closes the previous popup window before the request is finished.
			Ui.popup(lines, Utils.get_filetype(), bufnr, start_row, start_col, end_row, end_col)
		end
	end,
	["custom"] = nil,
}

--- Combines the final command arguments before the api call.
--- NOTE!: This function is called recursively in order do determine the final
--- command parameters.
---@param cmd string
---@return table opts parsed options
---@return boolean is_stream streaming enabled
local function get_cmd_opts(cmd)
	local opts = Config.opts.commands[cmd]
	-- print(vim.inspect(opts))
	local cmd_defaults = Config.opts.global_defaults
	local is_stream = false

	local model
	if opts.model then
		_, model = models.get_model_by_name(opts.model)
	else
		_, model = models.get_model()
	end

	---@type codegpt.CommandOpts
	--- options priority heighest->lowest: cmd options, model options, global
	opts = vim.tbl_extend("force", cmd_defaults, model or {}, opts or {})

	if type(opts.callback_type) == "function" then
		opts.callback = opts.callback_type
	else
		if
			(Config.opts.ui.stream_output and opts.callback_type == "text_popup")
			or opts.callback_type == "test_popup_stream"
		then
			opts.callback = text_popup_stream
			is_stream = true
		else
			opts.callback = M.CallbackTypes[opts.callback_type]
		end
	end

	return opts, is_stream
end

---@param command string
---@param command_args string
---@param text_selection string
---@param bounds bounding_box
function M.run_cmd(command, command_args, text_selection, bounds)
	local provider = Providers.get_provider()
	local cmd_opts, is_stream = get_cmd_opts(command)
	if cmd_opts == nil then
		vim.notify("Command not found: " .. command, vim.log.levels.ERROR, {
			title = "CodeGPT",
		})
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local new_callback = nil

	if is_stream then
		new_callback = function(stream)
			cmd_opts.callback(stream, bufnr, unpack(bounds))
		end
	else
		new_callback = function(lines) -- called from Provider.handle_response
			cmd_opts.callback(lines, bufnr, unpack(bounds))
		end
	end

	local request = provider.make_request(command, cmd_opts, command_args, text_selection, is_stream)
	if is_stream then
		provider.make_stream_call(request, new_callback)
	else
		provider.make_call(request, new_callback)
	end
end

function M.get_status(...)
	return Api.get_status(...)
end

M.get_cmd_opts = get_cmd_opts

return M
