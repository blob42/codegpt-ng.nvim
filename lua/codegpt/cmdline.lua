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
		if arglead:match("#{%%%w*") then
			-- list all
			local bufs = vim.tbl_filter(function(bufid)
				return vim.api.nvim_buf_is_loaded(bufid) and bufid ~= 0
			end, vim.api.nvim_list_bufs())

			bufs = vim.tbl_map(function(bufid)
				return "#{" .. vim.api.nvim_buf_get_name(bufid) .. ":" .. bufid .. "}"
			end, bufs)
			cmd = vim.list_extend(cmd, bufs)
		end
	end
	return cmd
end

return M
