-- add public vim commands
local codegpt = require("codegpt")
local config = require("codegpt.config")

vim.api.nvim_create_user_command("Chat", function(opts)
	return codegpt.run_cmd(opts)
end, {
	range = true,
	bang = true,
	nargs = "*",
	complete = function()
		local cmd = {}
		for k in pairs(config.opts.commands) do
			table.insert(cmd, k)
		end
		return cmd
	end,
})

vim.api.nvim_create_user_command("VChat", function(opts)
	return codegpt.run_cmd(opts)
end, {
	desc = "Use vertical popup in popup callbacks",
	bang = true,
	range = true,
	nargs = "*",
	complete = function()
		local cmd = {}
		for k in pairs(config.opts.commands) do
			table.insert(cmd, k)
		end
		return cmd
	end,
})

vim.api.nvim_create_user_command("CodeGPTStatus", function(opts)
	print(codegpt.get_status(opts))
end, {
	range = true,
	nargs = "*",
})
