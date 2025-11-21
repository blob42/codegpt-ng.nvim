-- add public vim commands
local codegpt = require("codegpt")
local cmdline = require("codegpt.cmdline")

local chat_cmd_opts = {
	desc = "Start codegpt chat",
	range = true,
	bang = true,
	nargs = "*",
	complete = cmdline.complete_func,
}
vim.api.nvim_create_user_command("Chat", function(opts)
	return codegpt.run_cmd(opts)
end, chat_cmd_opts)

vim.api.nvim_create_user_command("C", function(opts)
	return codegpt.run_cmd(opts)
end, chat_cmd_opts)

vim.api.nvim_create_user_command("VChat", function(opts)
	return codegpt.run_cmd(opts)
end, {
	desc = "Codegpt chat: force use vertical popup",
	bang = true,
	range = true,
	nargs = "*",
	complete = cmdline.complete_func,
})

vim.api.nvim_create_user_command("CodeGPTStatus", function(opts)
	print(codegpt.get_status(opts))
end, {
	range = true,
	nargs = "*",
})

vim.treesitter.language.register("markdown", { "codegpt", "codegpt-prompt" })
