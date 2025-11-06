local Utils = require("codegpt.utils")

local Render = {}

local function get_language(filetype)
	local lang_map = {
		cpp = "C++",
		py = "Python",
		js = "JavaScript",
		ts = "TypeScript",
		rb = "Ruby",
		go = "Go",
		rs = "Rust",
		sh = "Bash",
		tsx = "TypeScript",
		vue = "Vue.js",
		md = "Markdown",
		-- add more language mappings here
	}
	return lang_map[filetype] or filetype
end

local function safe_replace(template, key, value)
	if value == nil then
		return template:gsub(key, "")
	end

	if type(value) == "table" then
		value = table.concat(value, "\n")
	end

	if value then
		-- Replace '%' with '%%' to escape it in the template
		value = value:gsub("%%", "%%%%")
	end

	return template:gsub(key, value)
end

local function clear_cmdline_vars(template)
	--FIX: delete simple bufnr var #{3}
	local delete_register_re = '#{"[%w%d]}'
	local delete_bufre = "#{[/%w%.%-%+]+:%d+}"
	template = template:gsub(delete_register_re, "")
	template = template:gsub(delete_bufre, "")
	return template
end


local function parse_registers(template)
    local register_re = '""([%w%d])'
    template = string.gsub(template, register_re, function(reg)
        return vim.fn.getreg(reg) or ""
    end)
    return template
end


---@param template string
---@return string template
-- parses a buffer variable placeholder of the followiung forms
-- 1. buffer id: #{bufnr}
-- 2. name + buffer id: #{path:bufnr}
local function parse_buffers(template)
	local filebuf_re = "#{([/%w%.%-%+]+):(%d+)}"
	local bufnr_re = "#{(%d+)}"
	local buffer_ctx_tpl = [[

file: %s
```%s%s```
]]

	-- First try to match the file:path format
	for filepath, bufnr in template:gmatch(filebuf_re) do
		if bufnr == nil then
			goto continue
		end
		bufnr = tonumber(bufnr)

		local file_content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local filetype = Utils.get_filetype(bufnr)

		local repl_re = vim.fn.printf("#{(.*:%s)}", bufnr)

		-- replacement content
		local repl_content = vim.fn.printf(
		    buffer_ctx_tpl,
		    filepath,
		    filetype,
			vim.fn.join(file_content, "\n")
		)

		template = template:gsub(repl_re, repl_content)


		::continue::
	end

	-- Then try to match the buffer id format
	for bufnr in template:gmatch(bufnr_re) do
		if bufnr == nil then
			goto continue
		end
		bufnr = tonumber(bufnr)

		local filepath = vim.api.nvim_buf_get_name(bufnr)
		local file_content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local filetype = Utils.get_filetype(bufnr)

		local repl_re = vim.fn.printf("#{(%s)}", bufnr)

		-- replacement content
		local repl_content = vim.fn.printf(
		    buffer_ctx_tpl,
		    filepath,
		    filetype,
			vim.fn.join(file_content, "\n")
		)

		template = template:gsub(repl_re, repl_content)

		::continue::
	end

	return template
end

---@param template string
---@return string
--- Injects dynamic variables into the template such as buffer and registers
local function inject_dynamic_variables(template)
	template = parse_buffers(template)
	template = parse_registers(template)

	return template
end

---@param cmd string
---@param template string
---@param command_args string
---@param cmd_opts table
---@param is_system boolean
function Render.render(cmd, template, command_args, text_selection, cmd_opts, is_system)
	local bufnr = vim.api.nvim_get_current_buf()
	local filetype = Utils.get_filetype(vim.api.nvim_get_current_buf())
	local language = get_language(filetype)
	local language_instructions = ""
	if cmd_opts.language_instructions ~= nil then
		language_instructions = cmd_opts.language_instructions[filetype]
	end

	template = safe_replace(template, "{{command}}", cmd)
	template = safe_replace(template, "{{filetype}}", Utils.get_filetype(bufnr))
	template = safe_replace(template, "{{text_selection}}", text_selection)
	template = safe_replace(template, "{{language}}", language)
	template = safe_replace(template, "{{language_instructions}}", language_instructions)

	template = safe_replace(template, "{{command_args}}", command_args)

	-- process non system message (user) with extra context
	if not is_system then
		template = inject_dynamic_variables(template)
	end
	template = clear_cmdline_vars(template)

	return template
end

return Render
