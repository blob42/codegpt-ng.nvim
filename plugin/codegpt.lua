-- add public vim commands
require("codegpt.config")
local CodeGptModule = require("codegpt")

vim.api.nvim_create_user_command("Chat", function(opts)
	return CodeGptModule.run_cmd(opts)
end, {
	range = true,
	bang = true,
	nargs = "*",
	complete = function()
		local cmd = {}
		for k in pairs(vim.g["codegpt_commands_defaults"]) do
			table.insert(cmd, k)
		end
		for k in pairs(vim.g["codegpt_commands"] or {}) do
			table.insert(cmd, k)
		end
		return cmd
	end,
})

vim.api.nvim_create_user_command("VChat", function(opts)
	return CodeGptModule.run_cmd(opts)
end, {
	desc = "Use vertical popup in popup callbacks",
	bang = true,
	range = true,
	nargs = "*",
	complete = function()
		local cmd = {}
		for k in pairs(vim.g["codegpt_commands_defaults"]) do
			table.insert(cmd, k)
		end
		for k in pairs(vim.g["codegpt_commands"] or {}) do
			table.insert(cmd, k)
		end
		return cmd
	end,
})

vim.api.nvim_create_user_command("CodeGPTStatus", function(opts)
	print(CodeGptModule.get_status(opts))
end, {
	range = true,
	nargs = "*",
})
