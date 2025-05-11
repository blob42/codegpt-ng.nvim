local Popup = require("nui.popup")
local Split = require("nui.split")
local config = require("codegpt.config")
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
			size = config.opts.ui.horizontal_popup_size,
		})
	end

	return split
end

local function create_vertical()
	if not split then
		split = Split({
			relative = "editor",
			position = "right",
			size = config.opts.ui.vertical_popup_size,
		})
	end

	return split
end

local function create_floating()
	if not popup then
		local window_options = config.opts.ui.popup_window_options
		if window_options == nil then
			window_options = {}
		end

		local popupOpts = {
			enter = true,
			focusable = true,
			border = config.opts.ui.popup_border,
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

	popup:update_layout(config.opts.ui.popup_options)

	return popup
end

local function create_window()
	local popup_type = config.popup_override or config.opts.ui.popup_type
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

function M.popup(lines, filetype, bufnr, start_row, start_col, end_row, end_col)
	local ui_elem = create_window()
	-- mount/open the component
	ui_elem:mount()

	if not (config.persistent_override or config.opts.ui.persistent) then
		-- unmount component when cursor leaves buffer
		ui_elem:on(event.BufLeave, function()
			ui_elem:unmount()
		end)
	end

	-- unmount component when key 'q'
	ui_elem:map("n", config.opts.ui.actions.quit, function()
		ui_elem:unmount()
	end, { noremap = true, silent = true })

	-- set content
	vim.api.nvim_set_option_value("filetype", filetype, { buf = ui_elem.bufnr })
	vim.api.nvim_buf_set_lines(ui_elem.bufnr, 0, 1, false, lines)

	-- replace lines when ctrl-o pressed
	ui_elem:map("n", config.opts.ui.actions.use_as_output, function()
		vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, lines)
		ui_elem:unmount()
	end)

	-- selecting all the content when ctrl-i is pressed
	-- so the user can proceed with another API request
	ui_elem:map("n", config.opts.ui.actions.use_as_input, function()
		vim.api.nvim_feedkeys("ggVG:Chat ", "n", false)
	end, { noremap = false })

	-- mapping custom commands
	for _, command in ipairs(config.opts.ui.actions.custom) do
		ui_elem:map(command[1], command[2], command[3], command[4])
	end
end

---@type boolean
local stream_start = true
local stream_ui_elem = nil

--FIXME: this callback is called for each stream inputs so multiple calls are
--done. Should be created once at reception of first stream
function M.popup_stream(stream, filetype, bufnr, start_row, start_col, end_row, end_col)
	if stream_start then
		stream_ui_elem = create_window()

		-- mount/open the component
		stream_ui_elem:mount()

		if not (config.persistent_override or config.opts.ui.persistent) then
			-- unmount component when cursor leaves buffer
			stream_ui_elem:on(event.BufLeave, function()
				stream_ui_elem:unmount()
			end)
		end

		-- unmount component when key 'q'
		stream_ui_elem:map("n", config.opts.ui.actions.quit, function()
			stream_ui_elem:unmount()
		end, { noremap = true, silent = true })

		vim.api.nvim_set_option_value("filetype", filetype, { buf = stream_ui_elem.bufnr })
		vim.api.nvim_set_option_value("wrap", true, { win = stream_ui_elem.winid })

		stream_start = false
	end

	if stream_ui_elem == nil then
		error("creating stream window")
	end

	local lines = {}
	if stream == nil and #buffer > 0 then
		table.insert(lines, buffer)
		buffer = ""
	else
		local payload = vim.fn.json_decode(stream)
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
