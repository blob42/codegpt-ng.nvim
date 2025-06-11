local codegpt = require("codegpt")
local config = require("codegpt.config")

local function should_fail(fun)
	local stat = pcall(fun)
	assert(not stat, "Function should have errored")
end

describe("command parsing: ", function()
	before_each(function()
		codegpt.setup()

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

describe("command options", function()
	before_each(function()
		codegpt.setup()
	end)

	describe("model	params", function()
		it("should have default parameters", function()
			local cmds = require("codegpt.commands")
			local opts = cmds.get_cmd_opts("code_edit")
			assert(opts.temperature)
			assert(opts.max_tokens)
		end)

		it("should elect model params", function()
			codegpt.setup({
				models = {
					default = "gptx",
					openai = {
						gptx = {
							temperature = 0.42,
							max_tokens = 4242,
						},
					},
				},
			})
			local cmds = require("codegpt.commands")
			local opts = cmds.get_cmd_opts("generate")
			assert(opts.temperature == 0.42)
			assert(opts.max_tokens == 4242)
		end)

		it("should elect cmd over model params", function()
			codegpt.setup({
				commands = {
					["code_edit"] = { temperature = 0.41 },
				},
				models = {
					default = "gptx",
					openai = {
						gptx = {
							temperature = 0.42,
							max_tokens = 4242,
						},
					},
				},
			})
			local cmds = require("codegpt.commands")
			local opts = cmds.get_cmd_opts("code_edit")
			assert(opts.temperature == 0.41)
			assert(opts.max_tokens == 4242)
		end)
	end)

	it("should prioritize command model ", function()
		codegpt.setup({
			commands = {
				foocmd = {
					model = "foomodel",
				},
			},
			models = {
				openai = {
					default = "barmodel",
					barmodel = {
						alias = "llamabar",
					},
					foomodel = {
						alias = "llamafoo",
					},
				},
			},
		})
		local cmds = require("codegpt.commands")
		local opts = cmds.get_cmd_opts("foocmd")
		assert(opts.model == "foomodel")
	end)
end)
