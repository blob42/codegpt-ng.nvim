local Utils = require("codegpt.utils")

local Render = {}

local function get_language()
	local filetype = Utils.get_filetype()
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

local function extract_buffer_context(template, command_args)
    local filebuf_re = "#{([/%w%.%-%+]+):(%d+)}"
    local delete_bufre = "#{[/%w%.%-%+]+:%d+}"
    local has_buffers = command_args:match(filebuf_re)
    local buffer_context = ""
    
    if has_buffers then
        buffer_context = "\nEXTRA CONTEXT: \n\n"
    end

    for bufname, bufnr in command_args:gmatch(filebuf_re) do
        if bufnr == nil then
            goto continue
        end
        bufnr = tonumber(bufnr)
        if not vim.api.nvim_buf_is_loaded(bufnr) then
            vim.fn.bufload(bufnr)
        end
       ---@diagnostic disable-next-line
        local buf_content = vim.api.nvim_buf_get_text(bufnr, 0, 0, -1, -1, {})

        buffer_context = buffer_context .. vim.fn.printf("file: %s\n```%s```\n\n", bufname, buf_content)
        ::continue::
    end

	template = template:gsub(delete_bufre, "")
    return template .. buffer_context
end

---@param cmd string
---@param template string
---@param command_args string
---@param cmd_opts table
---@param is_system boolean
function Render.render(cmd, template, command_args, text_selection, cmd_opts, is_system)
	local language = get_language()
	local language_instructions = ""
	if cmd_opts.language_instructions ~= nil then
		language_instructions = cmd_opts.language_instructions[language]
	end

	template = safe_replace(template, "{{filetype}}", Utils.get_filetype())
	template = safe_replace(template, "{{text_selection}}", text_selection)
	template = safe_replace(template, "{{language}}", language)
	template = safe_replace(template, "{{command_args}}", command_args)
	template = safe_replace(template, "{{language_instructions}}", language_instructions)

	-- process non system message (user) with extra context
	if not is_system then
		template = extract_buffer_context(template, command_args, is_system)
	end


	return template
end

return Render
