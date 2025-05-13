-- add public vim commands
local codegpt = require("codegpt")
local config = require("codegpt.config")

vim.api.nvim_create_user_command("Chat", function(opts)
	return codegpt.run_cmd(opts)
end, {
	desc = "Start codegpt chat",
	range = true,
	bang = true,
	nargs = "*",
	complete = function(arglead)
		local cmd = {}
		for k in pairs(config.opts.commands) do
			if k:match(arglead) then
				table.insert(cmd, k)
			end
		end
		return cmd
	end,
})

vim.api.nvim_create_user_command("VChat", function(opts)
	return codegpt.run_cmd(opts)
end, {
	desc = "Codegpt chat: force use vertical popup",
	bang = true,
	range = true,
	nargs = "*",
	complete = function(arglead)
		local cmd = {}
		for k in pairs(config.opts.commands) do
			if k:match(arglead) then
				table.insert(cmd, k)
			end
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
