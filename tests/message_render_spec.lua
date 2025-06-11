local codegpt = require("codegpt")
local config = require("codegpt.config")
local Messages = require("codegpt.providers.messages")
local Commands = require("codegpt.commands")

describe("message templates", function()
	before_each(function()
		codegpt.setup()
	end)

	it("should render default system msg", function()
		vim.o.filetype = "lua"
		codegpt.setup({})
		local cmd_opts = Commands.get_cmd_opts("completion")

		local messages = Messages.generate_messages("completion", cmd_opts, "", "")

		assert(#messages == 2)
		local default_systpl = config.opts.global_defaults.system_message_template
		assert(messages[1].role == "system")
		assert(messages[1].content == default_systpl:gsub("{{language}}", "lua"))
	end)

	it("should render user msg", function()
		local testcmd = {
			user_message_template = "Foo user message",
		}
		codegpt.setup({
			commands = {
				testcmd = testcmd,
			},
		})
		local cmd_opts = Commands.get_cmd_opts("testcmd")

		vim.o.filetype = "lua"

		local messages = Messages.generate_messages("testcmd", cmd_opts, "", "")

		assert(#messages == 2)
		local default_systpl = config.opts.global_defaults.system_message_template
		assert(messages[1].role == "system")
		assert(messages[1].content == default_systpl:gsub("{{language}}", "lua"))
		assert(messages[2].content == testcmd.user_message_template)
	end)

	it("should handle message history", function()
		local testcmd = {
			user_message_template = "Foo user message",
			---@type codegpt.Chatmsg[]
			chat_history = {
				{ role = "user", content = "Hist user msg" },
				{ role = "assistant", content = "Hist assistant response" },
			},
		}
		codegpt.setup({
			commands = {
				testcmd = testcmd,
			},
			global_defaults = {
				system_message_template = "Default system message",
			},
		})
		local cmd_opts = Commands.get_cmd_opts("testcmd")

		local messages = Messages.generate_messages("testcmd", cmd_opts, "", "")

		assert(#messages == 4)
		assert(messages[1].role == "system")
		assert(messages[1].content == "Default system message")
		assert(messages[2].role == "user")
		assert(messages[2].content == "Hist user msg")
		assert(messages[3].role == "assistant")
		assert(messages[3].content == "Hist assistant response")
		assert(messages[4].role == "user")
		assert(messages[4].content == "Foo user message")
	end)
end)
