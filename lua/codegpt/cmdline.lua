local config = require("codegpt.config")

local M = {}

M.complete_func = function(arglead, cmdline, pos)
	local cmd = {}
	local tokens = vim.split(cmdline, "%s+")

	-- handle main commands
	if #tokens < 3 then
		for k in pairs(config.opts.commands) do
			if k:match(arglead) then
				table.insert(cmd, k)
			end
		end

	-- list all available variables
	else
		-- autocomplete list open files (listed buffers) using #{%token}
		if arglead:match("#{%%%w*") then
			local bufnrs = vim.tbl_filter(function(b)
				if 1 ~= vim.fn.buflisted(b) then
					return false
				end
				return true
			end, vim.api.nvim_list_bufs())

			if not next(bufnrs) then
				return
			end

			local bufs = vim.tbl_map(function(bufid)
				local name = vim.api.nvim_buf_get_name(bufid)
				local parts = vim.split(name, "%/")
				local path
				if #parts <= 2 then
					path = vim.fn.join(parts, "/")
				else
					local stripped = vim.list_slice(parts, #parts - 1, #parts)
					path = ".../" .. vim.fn.join(stripped, "/")
				end
				return "#{" .. path .. ":" .. bufid .. "}"
			end, bufnrs)
			cmd = vim.list_extend(cmd, bufs)
		end
	end
	return cmd
end

return M
