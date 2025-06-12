---@module 'plenary.job'

local Popup = require("nui.popup")
local Split = require("nui.split")
local Config = require("codegpt.config")
local event = require("nui.utils.autocmd").event

local M = {}

local popup
local split
local buffer = ""

local function create_horizontal()
	if not split then
		split = Split({
			relative = "editor",
			position = "bottom",
			size = Config.opts.ui.horizontal_popup_size,
		})
	end

	return split
end

local function create_vertical()
	if not split then
		split = Split({
			relative = "editor",
			position = "right",
			size = Config.opts.ui.vertical_popup_size,
		})
	end

	return split
end

local function create_floating()
	if not popup then
		local window_options = Config.opts.ui.popup_window_options
		if window_options == nil then
			window_options = {}
		end

		local popupOpts = {
			enter = true,
			focusable = true,
			border = Config.opts.ui.popup_border,
			position = "50%",
			size = {
				width = "80%",
				height = "60%",
			},
		}

		if not vim.tbl_isempty(window_options) then
			popupOpts.win_options = window_options
		end

		popup = Popup(popupOpts)
	end

	popup:update_layout(Config.opts.ui.popup_options)

	return popup
end

local function create_window()
	local popup_type = Config.popup_override or Config.opts.ui.popup_type
	local ui_elem = nil
	if popup_type == "horizontal" then
		ui_elem = create_horizontal()
	elseif popup_type == "vertical" then
		ui_elem = create_vertical()
	else
		ui_elem = create_floating()
	end

	return ui_elem
end

---@param job Job
---@param lines string[]
---@param filetype string
---@param range Range4
function M.popup(job, lines, filetype, bufnr, range)
	local start_row, start_col, end_row, end_col = unpack(range)
	if job ~= nil and job.is_shutdown then
		return
	end
	local ui_elem = create_window()
	-- mount/open the component
	ui_elem:mount()

	if not (Config.persistent_override or Config.opts.ui.persistent) then
		-- unmount component when cursor leaves buffer
		ui_elem:on(event.BufLeave, function()
			ui_elem:unmount()
		end)
	end

	-- unmount component when key 'q'
	ui_elem:map("n", Config.opts.ui.mappings.quit, function()
		ui_elem:unmount()
	end, { noremap = true, silent = true })
	--
	-- cancel job if actions.cancel is called
	ui_elem:map("n", Config.opts.ui.mappings.cancel, function()
		job:shutdown()
	end, { noremap = true, silent = true })

	-- set content
	vim.api.nvim_set_option_value("filetype", filetype, { buf = ui_elem.bufnr })
	vim.api.nvim_buf_set_lines(ui_elem.bufnr, 0, 1, false, lines)

	-- replace lines when ctrl-o pressed
	ui_elem:map("n", Config.opts.ui.mappings.use_as_output, function()
		vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, lines)
		ui_elem:unmount()
	end)

	-- selecting all the content when ctrl-i is pressed
	-- so the user can proceed with another API request
	ui_elem:map("n", Config.opts.ui.mappings.use_as_input, function()
		vim.api.nvim_feedkeys("ggVG:Chat ", "n", false)
	end, { noremap = false })

	-- mapping custom commands
	for _, command in ipairs(Config.opts.ui.mappings.custom) do
		ui_elem:map(command[1], command[2], command[3], command[4])
	end
end

local streaming = false
local stream_ui_elem = nil

---@param job Job
function M.popup_stream(job, stream, filetype, bufnr, start_row, start_col, end_row, end_col)
	if job ~= nil and job.is_shutdown then
		streaming = false
		return
	end
	if not streaming then
		buffer = ""
		streaming = true
		stream_ui_elem = create_window()

		-- mount/open the component
		stream_ui_elem:mount()

		if not (Config.persistent_override or Config.opts.ui.persistent) then
			-- unmount component when cursor leaves buffer
			stream_ui_elem:on(event.BufLeave, function()
				job:shutdown()
				streaming = false
				stream_ui_elem:unmount()
			end)
		end

		-- unmount component when key 'q'
		stream_ui_elem:map("n", Config.opts.ui.mappings.quit, function()
			job:shutdown()
			streaming = false
			stream_ui_elem:unmount()
		end, { noremap = true, silent = true })

		-- cancel job if actions.cancel is called
		stream_ui_elem:map("n", Config.opts.ui.mappings.cancel, function()
			job:shutdown()
			streaming = false
		end, { noremap = true, silent = true })

		vim.api.nvim_set_option_value("filetype", filetype, { buf = stream_ui_elem.bufnr })
		vim.api.nvim_set_option_value("wrap", true, { win = stream_ui_elem.winid })
	end

	if stream_ui_elem == nil then
		error("creating stream window")
	end

	local lines = {}
	if stream == nil and #buffer > 0 then
		table.insert(lines, buffer)
		buffer = ""
		streaming = false
	elseif stream == nil then
		streaming = false
		return
	else
		local ok, payload = pcall(function()
			return vim.fn.json_decode(stream)
		end)
		if not ok then
			streaming = false
			return
		end
		local content = payload.message.content
		local content_lines = vim.split(content, "\n")
		if #content_lines == 1 then
			buffer = buffer .. content_lines[1]
		elseif #content_lines > 1 then
			if #buffer > 0 then
				buffer = buffer .. content_lines[1]
				table.insert(lines, buffer)
				buffer = ""
			end

			for line in vim.iter(content_lines):skip(1) do
				table.insert(lines, line)
			end
		end
	end
	if #lines > 0 then
		vim.api.nvim_buf_set_lines(stream_ui_elem.bufnr, -2, -1, false, lines)
	end
	local nlines = vim.api.nvim_buf_line_count(stream_ui_elem.bufnr)
	vim.api.nvim_win_set_cursor(stream_ui_elem.winid, { nlines, 0 })
end

return M
