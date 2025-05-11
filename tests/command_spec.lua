local codegpt = require("codegpt")
local config = require("codegpt.config")

local function should_fail(fun)
	local stat = pcall(fun)
	assert(not stat, "Function should have errored")
end

describe("command parsing: ", function()
	before_each(function()
		codegpt.setup({})

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
	end)

	describe(":Chat", function()
		it("should fail with no args and no selection", function()
			should_fail(function()
				vim.cmd(":Chat")
			end)
		end)
	end)
end)
