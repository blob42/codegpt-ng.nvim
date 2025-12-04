---@module 'plenary.curl'

local Utils = require("codegpt.utils")
local Ui = require("codegpt.ui")
local Providers = require("codegpt.providers")
local Api = require("codegpt.api")
local Config = require("codegpt.config")
local models = require("codegpt.models")
local history = require("codegpt.history")

local M = {}

---@param job Job
---@param stream string
---@param bufnr integer
---@param range Range4
local text_popup_stream = function(job, stream, bufnr, range)
	local popup_filetype = Config.opts.ui.text_popup_filetype
	Ui.popup_stream(job, stream, popup_filetype, bufnr, range)
end

---@param job Job
---@param lines string[]
---@param bufnr integer
---@param range Range4
local function replacement(job, lines, bufnr, range)
	local start_row, _, end_row, _ = unpack(range)
	lines = Utils.strip_reasoning(lines, "<think>", "</think>")
	lines = Utils.trim_to_code_block(lines)
	lines = Utils.remove_trailing_whitespace(lines)
	Utils.fix_indentation(bufnr, start_row, end_row, lines)
	-- if the buffer is not valid, open a popup. This can happen when the user closes the previous popup window before the request is finished.
	if vim.api.nvim_buf_is_valid(bufnr) ~= true then
		Ui.popup(job, lines, Utils.get_filetype(bufnr), bufnr, range)
	else
		return lines
	end
end

M.CallbackTypes = {
	-- Display text in a popup window (streamed or non-streamed)
	["text_popup_stream"] = text_popup_stream,
	-- Display text in a popup window with optional range and buffer
	["text_popup"] = function(job, lines, bufnr, range)
		local popup_filetype = Config.opts.ui.text_popup_filetype
		Ui.popup(job, lines, popup_filetype, bufnr, range)
	end,
	-- Display code in a popup window after trimming and fixing indentation
	["code_popup"] = function(job, lines, bufnr, range)
		local start_row, _, end_row, _ = unpack(range)
		lines = Utils.trim_to_code_block(lines)
		Utils.fix_indentation(bufnr, start_row, end_row, lines)
		Ui.popup(job, lines, Utils.get_filetype(bufnr), bufnr, range)
	end,
	-- Replace lines in the buffer at the specified range
	["replace_lines"] = function(job, lines, bufnr, range)
		lines = replacement(job, lines, bufnr, range)
		Utils.replace_lines(lines, bufnr, range)
	end,
	-- Insert lines at cursor position
	["insert_lines"] = function(job, lines, bufnr, range)
		lines = replacement(job, lines, bufnr, range)
		Utils.insert_lines(lines)
	end,

	-- Append lines after selection
	["append_lines"] = function(job, lines, bufnr, range)
		lines = replacement(job, lines, bufnr, range)
		Utils.append_lines(lines, bufnr, range)
	end,

	-- Prepend lines before the current selection or cursor position
	["prepend_lines"] = function(job, lines, bufnr, range)
		lines = replacement(job, lines, bufnr, range)
		Utils.prepend_lines(lines)
	end,
	-- Custom callback (user-defined behavior)
	["custom"] = nil,
}

--- Combines the final command arguments before the api call.
--- NOTE!: This function is called recursively in order do determine the final
--- command parameters.
---@param cmd string
---@param cb_override string? overriden callback type
---@return table opts parsed options
---@return boolean is_stream streaming enabled
local function get_cmd_opts(cmd, cb_override)
	local opts = Config.opts.commands[cmd]
	-- print(vim.inspect(opts))
	local cmd_defaults = Config.opts.global_defaults
	local is_stream = false

	local model
	if opts ~= nil and opts.model then
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
			(
				(Config.opts.ui.stream_output and opts.callback_type == "text_popup")
				or opts.callback_type == "text_popup_stream"
			) and (opts.stream_output ~= false and Config.stream_override ~= false)
		then
			opts.callback = text_popup_stream
			is_stream = true
		else
			opts.callback_type = cb_override or opts.callback_type
			opts.callback = M.CallbackTypes[cb_override or opts.callback_type]
		end
	end

	return opts, is_stream
end

---@param command string
---@param cmd_opts table
---@param is_stream boolean
---@param command_args string
---@param text_selection string
---@param range Range4
function M.run_cmd(command, cmd_opts, is_stream, command_args, text_selection, range)
	local provider = Providers.get_provider()

	local bufnr = vim.api.nvim_get_current_buf()
	local new_callback = nil

	if is_stream then
		new_callback = function(stream, job)
			cmd_opts.callback(job, stream, bufnr, range)
		end
	else
		new_callback = function(lines, job) -- called from Provider.handle_response
			cmd_opts.callback(job, lines, bufnr, range)
		end
	end

	local request = provider.make_request(command, cmd_opts, command_args, text_selection, is_stream)
	if Config.debug_prompt then
		history.show_chat()
		return
	end
	if is_stream then
		provider.make_stream_call(request, new_callback)
	else
		provider.make_call(request, new_callback)
	end
end

---@return string
function M.get_status(...)
	return Api.get_status(...)
end

M.get_cmd_opts = get_cmd_opts

return M
