local Popup = require("nui.popup")
local Split = require("nui.split")
local Config = require("codegpt.config")
local event = require("nui.utils.autocmd").event
local config = require("codegpt.config")

local M = {}

local popup
local split

local function setup_ui_element(lines, filetype, bufnr, start_row, start_col, end_row, end_col, ui_elem)
	-- mount/open the component
	ui_elem:mount()

	if not (config.persistent_override or config.opts.ui.persistent) then
		-- unmount component when cursor leaves buffer
		ui_elem:on(event.BufLeave, function()
			ui_elem:unmount()
		end)
	end

	-- unmount component when key 'q'
	ui_elem:map("n", vim.g["codegpt_ui_commands"].quit, function()
		ui_elem:unmount()
	end, { noremap = true, silent = true })

	-- set content
	vim.api.nvim_set_option_value("filetype", filetype, { buf = ui_elem.bufnr })
	vim.api.nvim_buf_set_lines(ui_elem.bufnr, 0, 1, false, lines)

	-- replace lines when ctrl-o pressed
	ui_elem:map("n", vim.g["codegpt_ui_commands"].use_as_output, function()
		vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, lines)
		ui_elem:unmount()
	end)

	-- selecting all the content when ctrl-i is pressed
	-- so the user can proceed with another API request
	ui_elem:map("n", vim.g["codegpt_ui_commands"].use_as_input, function()
		vim.api.nvim_feedkeys("ggVG:Chat ", "n", false)
	end, { noremap = false })

	-- mapping custom commands
	for _, command in ipairs(vim.g.codegpt_ui_custom_commands) do
		ui_elem:map(command[1], command[2], command[3], command[4])
	end
end

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

local function create_popup()
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

	popup:update_layout(config.opts.ui.popup_options)

	return popup
end

function M.popup(lines, filetype, bufnr, start_row, start_col, end_row, end_col)
	local popup_type = Config.popup_override or Config.opts.ui.popup_type
	local ui_elem = nil
	if popup_type == "horizontal" then
		ui_elem = create_horizontal()
	elseif popup_type == "vertical" then
		ui_elem = create_vertical()
	else
		ui_elem = create_popup()
	end
	setup_ui_element(lines, filetype, bufnr, start_row, start_col, end_row, end_col, ui_elem)
end

return M
