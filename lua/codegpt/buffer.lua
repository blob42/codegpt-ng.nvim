--- Manages the display of codegpt main chat buffer.

local api = vim.api

---@alias codegpt.BufferType
---|'codegpt-prompt'
---|'codegpt'

---@class codegpt.Buffer
---@field id integer buffer id
local Buffer = {}
Buffer.__index = Buffer

Buffer._singletons = {
	["codegpt-prompt"] = nil,
	["codegpt"] = nil,
}

--- Checks if a buffer is currently displayed in any window.
---@param bufnr number The buffer number to check.
---@return number The window ID if the buffer is displayed, otherwise -1.
local function buf_displayed(bufnr)
	for _, winid in ipairs(api.nvim_list_wins()) do
		if api.nvim_win_is_valid(winid) and api.nvim_win_get_buf(winid) == bufnr then
			return winid
		end
	end

	return -1
end

--- Clears all lines from the buffer.
function Buffer:clear()
	api.nvim_buf_set_lines(self.id, 0, -1, false, {})
end

--- Displays the specified buffer in a split window if it is not already visible.
--- If the buffer has never been displayed, creates a new window.
---@param bufnr number The buffer number to display.
local function display_buf(bufnr)
	local winid = buf_displayed(bufnr)
	local winopts = {
		wrap = true,
		relativenumber = false,
		number = false,
	}
	if winid > 0 then
		api.nvim_set_current_win(winid)
		return
	end

	local opts = {
		split = "right",
	}
	winid = api.nvim_open_win(bufnr, true, opts)
	for key, val in pairs(winopts) do
		api.nvim_set_option_value(key, val, { win = winid })
	end
end

---@param type codegpt.BufferType type of buffer
---@return codegpt.Buffer buffer
function Buffer.create(type)
	if Buffer._singletons[type] ~= nil then
		return Buffer._singletons[type]
	else
		assert(type ~= nil)
		local buf = api.nvim_create_buf(false, false)

		-- FIX: use markdown treesitter highlihgting with custom filetype
		local bufopts = {
			filetype = type,
			syntax = "markdown",
			buftype = "nofile",
		}

		for key, val in pairs(bufopts) do
			api.nvim_set_option_value(key, val, { buf = buf })
		end

		-- --WIP: using prompt buffer
		if type == "codegpt-prompt" then
			api.nvim_set_option_value("buftype", "prompt", { buf = buf })
			vim.fn.prompt_setcallback(buf, function(text)
				-- print(text)
				-- print(vim.inspect(vim.fn.prompt_getprompt(buf)))
				local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
				local cmd = lines[#lines - 1]
				print(cmd)
				table.remove(lines, #lines - 1)
				api.nvim_buf_set_lines(buf, 0, -1, false, lines)
				-- local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
				-- print(vim.inspect(lines))
			end)
		end

		local self = {
			id = buf,
		}
		setmetatable(self, Buffer)
		Buffer._singletons[type] = self
		return self
	end
end

---@param lines string[]
function Buffer:set_lines(lines)
	api.nvim_buf_set_lines(self.id, 0, -1, false, lines)
end

function Buffer.prompt()
	return Buffer.create("codegpt-prompt")
end

---@return codegpt.Buffer chat_buffer
function Buffer.chat()
	return Buffer.create("codegpt")
end

function Buffer:show()
	display_buf(self.id)
end

-- local b = Buffer.new()
-- print(vim.inspect(b.id))

return Buffer
