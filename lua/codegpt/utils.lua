local config = require("codegpt.config")
local M = {}

---@param mode string
---@return boolean
local function is_visual_mode(mode)
	return mode == "v" or mode == "V" or mode == "^V"
end

function M.get_filetype()
	local bufnr = vim.api.nvim_get_current_buf()
	return vim.api.nvim_get_option_value("filetype", { buf = bufnr })
end

---@return Range4 range
function M.get_visual_selection()
	local bufnr = vim.api.nvim_get_current_buf()

	local mode = vim.fn.mode()
	local is_visual = is_visual_mode(mode)

	local start_pos, end_pos
	if is_visual then
		-- If we're in visual mode, use 'v' and '.'
		start_pos = vim.api.nvim_buf_get_mark(bufnr, "v")
		end_pos = vim.api.nvim_buf_get_mark(bufnr, ".")
	else
		-- Fallback to marks if not in visual mode
		start_pos = vim.api.nvim_buf_get_mark(bufnr, "<")
		end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")
	end

	if start_pos[1] == end_pos[1] and start_pos[2] == end_pos[2] then
		return { 0, 0, 0, 0 }
	end

	local start_row = start_pos[1] - 1
	local start_col = start_pos[2]

	local end_row = end_pos[1] - 1
	local end_col = end_pos[2] + 1

	if vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, true)[1] == nil then
		return { 0, 0, 0, 0 }
	end

	local start_line_length = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, true)[1]:len()
	start_col = math.min(start_col, start_line_length)

	local end_line_length = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, true)[1]:len()
	end_col = math.min(end_col, end_line_length)

	return { start_row, start_col, end_row, end_col }
end

---@alias bounding_box [number,number,number,number]

---@param opts table options passed by nvim_create_user_command to the callback
---@return string text selected text string
---@return Range4 range text range
function M.get_selected_lines(opts)
	local bufnr = vim.api.nvim_get_current_buf()
	local start_row, start_col, end_row, end_col
	if (opts.line2 - opts.line1 + 1) == vim.api.nvim_buf_line_count(bufnr) then
		start_row, start_col, end_row, end_col = 0, 0, -1, -1
	else
		start_row, start_col, end_row, end_col = unpack(M.get_visual_selection())
	end

	local lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
	return table.concat(lines, "\n"), { start_row, start_col, end_row, end_col }
end

---@param lines string[]
function M.prepend_lines(lines)
	local bufnr = vim.api.nvim_get_current_buf()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(bufnr, line - 1, line - 1, false, lines)
end

---@param lines string[]
function M.insert_lines(lines)
	local bufnr = vim.api.nvim_get_current_buf()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(bufnr, line, line, false, lines)
	vim.api.nvim_win_set_cursor(0, { line + #lines, 0 })
end

---@param lines string[]
---@param bufnr integer
---@param range Range4
function M.replace_lines(lines, bufnr, range)
	local start_row, start_col, end_row, end_col = unpack(range)
	vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, lines)
end

---@param lines string[]
---@param start_token string
---@param stop_token string
function M.strip_reasoning(lines, start_token, stop_token)
	local stripped = {}
	local in_think = false
	for _, line in ipairs(lines) do
		if line:match("^" .. start_token) then
			in_think = true
		elseif line:match("^" .. stop_token) then
			in_think = false
		elseif not in_think then
			table.insert(stripped, line)
		end
	end

	if stripped[1] == "" then
		table.remove(stripped, 1)
	end

	return stripped
end

---@param lines string[]
local function get_code_block(lines)
	local code_block = {}
	local in_code_block = false
	for _, line in ipairs(lines) do
		if line:match("^```") then
			in_code_block = not in_code_block
		elseif in_code_block then
			table.insert(code_block, line)
		end
	end
	return code_block
end

---@param lines string[]
local function contains_code_block(lines)
	for _, line in ipairs(lines) do
		if line:match("^```") then
			return true
		end
	end
	return false
end

---@param lines string[]
function M.trim_to_code_block(lines)
	if contains_code_block(lines) then
		return get_code_block(lines)
	end
	return lines
end

---@param response_text string
function M.parse_lines(response_text)
	if config.opts.write_response_to_err_log then
		error("ChatGPT response: \n" .. response_text .. "\n")
	end

	return vim.fn.split(vim.trim(response_text), "\n")
end

---@param bufnr integer
---@param start_row integer
---@param end_row integer
---@param new_lines string[]
function M.fix_indentation(bufnr, start_row, end_row, new_lines)
	local original_lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, true)
	local min_indentation = math.huge
	local original_identation = ""

	-- Find the minimum indentation of any line in original_lines
	for _, line in ipairs(original_lines) do
		local indentation = string.match(line, "^%s*")
		if #indentation < min_indentation then
			min_indentation = #indentation
			original_identation = indentation
		end
	end

	-- Change the existing lines in new_lines by adding the old identation
	for i, line in ipairs(new_lines) do
		new_lines[i] = original_identation .. line
	end
end

---@param lines string[]
function M.remove_trailing_whitespace(lines)
	for i, line in ipairs(lines) do
		lines[i] = line:gsub("%s+$", "")
	end
	return lines
end

M.get_accurate_tokens = function(messages)
	return false, 0
end

---@param max_context_length integer
---@param messages table[]
function M.fail_if_exceed_context_window(max_context_length, messages)
	local ok, total_length = M.get_accurate_tokens(vim.fn.json_encode(messages))

	if not ok then
		for _, message in ipairs(messages) do
			total_length = total_length + string.len(message.content)
			total_length = total_length + string.len(message.role)
		end
	end

	if total_length >= max_context_length then
		error("Total length of messages exceeds max context length: " .. total_length .. " > " .. max_context_length)
	end
end

return M
