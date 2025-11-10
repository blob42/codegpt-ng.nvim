---@module 'plenary.job'

local Popup = require("nui.popup")
local Split = require("nui.split")
local Config = require("codegpt.config")
local event = require("nui.utils.autocmd").event
local api = vim.api

local M = {}

local popup
local split
local current_stream = {
	lines = {},
	content = "",
	update_scheduled = false,
}

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

-- single state for popup ui (no stream)
local popup_ui

---@param job Job
---@param lines string[]
---@param filetype string
---@param range Range4
function M.popup(job, lines, filetype, bufnr, range)
	local start_row, start_col, end_row, end_col = unpack(range)
	if job ~= nil and job.is_shutdown then
		return
	end
	local ui_elem = popup_ui
	if popup_ui == nil then
		ui_elem = create_window()
		popup_ui = ui_elem

		-- mount/open the component
		ui_elem:mount()
	else
		ui_elem:show()
	end

	if not (Config.persistent_override or Config.opts.ui.persistent) then
		-- unmount component when cursor leaves buffer
		ui_elem:on(event.BufLeave, function()
			ui_elem:hide()
		end)
	end

	-- unmount component when key 'q'
	ui_elem:map("n", Config.opts.ui.mappings.quit, function()
		ui_elem:hide()
	end, { noremap = true, silent = true })
	--
	-- cancel job if actions.cancel is called
	ui_elem:map("n", Config.opts.ui.mappings.cancel, function()
		job:shutdown()
	end, { noremap = true, silent = true })

	-- set content
	api.nvim_set_option_value("filetype", filetype, { buf = ui_elem.bufnr })
	api.nvim_buf_set_lines(ui_elem.bufnr, 0, 1, false, lines)

	-- replace lines when ctrl-o pressed
	ui_elem:map("n", Config.opts.ui.mappings.use_as_output, function()
		api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, lines)
		ui_elem:hide()
	end)

	-- selecting all the content when ctrl-i is pressed
	-- so the user can proceed with another API request
	ui_elem:map("n", Config.opts.ui.mappings.use_as_input, function()
		api.nvim_feedkeys("ggVG:Chat ", "n", false)
	end, { noremap = false })

	-- mapping custom commands
	for _, command in ipairs(Config.opts.ui.mappings.custom) do
		ui_elem:map(command[1], command[2], command[3], command[4])
	end
end

local streaming = false
local stream_ui_elem = nil
local streaming_done = false
M.canceled_stream = false

---@param job Job
function M.popup_stream(job, stream, filetype, bufnr, start_row, start_col, end_row, end_col)
	job:add_on_exit_callback(function()
		if M.canceled_stream and stream_ui_elem ~= nil then
			vim.defer_fn(function()
				api.nvim_buf_set_lines(stream_ui_elem.bufnr, 0, -1, false, {})
				current_stream.lines = {}
				current_stream.content = ""
			end, 100)
			M.canceled_stream = false
		end
		streaming = false
	end)

	if not streaming then
		streaming = true
		if stream_ui_elem == nil then
			stream_ui_elem = create_window()
			-- mount/open the component
			stream_ui_elem:mount()
		else
			stream_ui_elem:show()
		end

		if streaming_done then
			api.nvim_buf_set_lines(stream_ui_elem.bufnr, 0, -1, false, {})
			streaming_done = false
		end

		if not (Config.persistent_override or Config.opts.ui.persistent) then
			-- unmount component when cursor leaves buffer
			stream_ui_elem:on(event.BufLeave, function()
				job:shutdown()
				streaming = false
				stream_ui_elem:hide()
			end)
		end

		-- hide component when key 'q'
		stream_ui_elem:map("n", Config.opts.ui.mappings.quit, function()
			job:shutdown()
			streaming = false
			stream_ui_elem:hide()
		end, { noremap = true, silent = true })

		-- cancel job if actions.cancel is called
		stream_ui_elem:map("n", Config.opts.ui.mappings.cancel, function()
			job:shutdown()
			streaming = false
		end, { noremap = true, silent = true })

		-- replace lines when ctrl-o pressed
		stream_ui_elem:map("n", Config.opts.ui.mappings.use_as_output, function()
			api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, lines)
			ui_elem:hide()
		end)

		-- selecting all the content when ctrl-i is pressed
		-- so the user can proceed with another API request
		stream_ui_elem:map("n", Config.opts.ui.mappings.use_as_input, function()
			api.nvim_feedkeys("ggVG:Chat ", "n", false)
		end, { noremap = false })

		api.nvim_set_option_value("filetype", filetype, { buf = stream_ui_elem.bufnr })
		api.nvim_set_option_value("wrap", true, { win = stream_ui_elem.winid })
		api.nvim_set_option_value("conceallevel", 0, { win = stream_ui_elem.winid })

		current_stream.content = ""
		current_stream.update_scheduled = false
		current_stream.lines = {}
	end

	if stream_ui_elem == nil then
		error("creating stream window")
	end

	if stream == nil and #current_stream.content > 0 then
		if #current_stream.content > 0 then
			local lines = vim.split(current_stream.content, "\n")
			api.nvim_buf_set_lines(stream_ui_elem.bufnr, -2, -1, false, lines)

			-- only move curosr if stream is active
			if streaming then
				local nlines = api.nvim_buf_line_count(stream_ui_elem.bufnr)
				if api.nvim_win_get_cursor(0)[1] ~= nlines then
					api.nvim_win_set_cursor(stream_ui_elem.winid, { nlines, 0 })
				end
			end
		end

		streaming = false
		return
	end

	if stream == nil or #stream == 0 then
		return
	end
	local data = stream:gsub("^data: ", "", 1)
	local payload = {}
	if not stream:match("DONE") then
		_, payload = pcall(function()
			return vim.fn.json_decode(data)
		end)
	end

	-- Ollama stream format:
	-- {"model":"qwen3-coder:30b-a3b-xs","created_at":"2025-11-01T16:18:39.344140114Z","message":{"role":"assistant","content":"Here"},"done":false}
	-- {"model":"qwen3-coder:30b-a3b-xs","created_at":"2025-11-01T16:18:39.353522498Z","message":{"role":"assistant","content":"'s"},"done":false}
	--
	-- OpenAI stream format:
	-- data: {"choices":[{"finish_reason":null,"index":0,"delta":{"content":"\t"}}],"created":1762014260,"id":"chatcmpl-dLoo8TonbY5vOHOru12fbVkrm1YISDsy","model":"qwen3-fast","system_fingerprint":"b6907-2101f19aa","object":"chat.completion.chunk"}
	-- data: {"choices":[{"finish_reason":null,"index":0,"delta":{"content":"\treturn"}}],"created":1762014260,"id":"chatcmpl-dLoo8TonbY5vOHOru12fbVkrm1YISDsy","model":"qwen3-fast","system_fingerprint":"b6907-2101f19aa","object":"chat.completion.chunk"}

	local content = ""
	if Config.opts.connection.api_provider == "ollama" then
		if payload.done then
			local remainder = current_stream.content
			vim.defer_fn(function()
				api.nvim_buf_set_text(stream_ui_elem.bufnr, -1, -1, -1, -1, { "", remainder })
				streaming = false
				streaming_done = true
			end, 100)
			return
		end
		content = payload.message.content or ""
	else
		-- Handle OpenAI streaming format
		content = ""
		if payload.choices and #payload.choices > 0 then
			local finish = payload.choices[1].finish_reason
			if finish == "stop" then
				local remainder = current_stream.content
				vim.defer_fn(function()
					api.nvim_buf_set_text(stream_ui_elem.bufnr, -1, -1, -1, -1, { "", remainder })
					streaming = false
					streaming_done = true
				end, 100)
				return
			end
			local delta = payload.choices[1].delta
			if delta then
				-- Check for both content and reasoning_content
				local content_to_add = ""
				if delta.content ~= nil and delta.content ~= vim.NIL then
					content_to_add = delta.content
					-- TODO: boilerplate for handling reasoning content
					-- TODO: more efficient text stream algorithm with vim gui loop
					-- elseif delta.reasoning_content ~= nil and delta.reasoning_content ~= vim.NIL then
					-- 	content_to_add = delta.reasoning_content
				end

				if content_to_add ~= "" then
					content = content_to_add
				end
			end
		end
	end

	if #content > 0 then
		local content_lines = vim.split(content, "\n")
		if #content_lines == 1 then
			current_stream.content = current_stream.content .. content_lines[1]
		elseif #content_lines > 1 then
			if #current_stream.content > 0 then
				current_stream.content = current_stream.content .. content_lines[1]
				table.insert(current_stream.lines, current_stream.content)
				current_stream.content = ""
			end
			for line in vim.iter(content_lines):skip(1) do
				table.insert(current_stream.lines, line)
			end
		end

		if not current_stream.update_scheduled then
			current_stream.update_scheduled = true
			vim.schedule(function()
				if not streaming then
					current_stream.update_scheduled = false
					return
				end

				api.nvim_buf_set_lines(stream_ui_elem.bufnr, -1, -1, false, current_stream.lines)
				current_stream.lines = {}

				if streaming then
					local nlines = api.nvim_buf_line_count(stream_ui_elem.bufnr)
					if api.nvim_win_get_cursor(0)[1] ~= nlines then
						api.nvim_win_set_cursor(stream_ui_elem.winid, { nlines, 0 })
					end
				end

				current_stream.update_scheduled = false
			end)
		end
	end
end

return M
