local codegpt = require("codegpt")
local config = require("codegpt.config")
local Messages = require("codegpt.providers.messages")
local Commands = require("codegpt.commands")

local commands = {}

describe("msg template", function()
	before_each(function()
		codegpt.setup()
	end)

	it("should parse {{filetype}}", function()
		local testcmd = {
			user_message_template = "Filetype is: {{filetype}}",
		}

		codegpt.setup({
			commands = {
				testcmd = testcmd,
			},
		})

		vim.o.filetype = "rust"

		local cmd_opts = Commands.get_cmd_opts("testcmd")
		local messages = Messages.generate_messages("testcmd", cmd_opts, "", "")

		assert(#messages == 2)
		assert(messages[2].content == "Filetype is: rust")
	end)

	it("should parse {{language_instructions}}", function()
		vim.o.filetype = "cpp"
		local testcmd = {
			user_message_template = "foo {{language_instructions}}",
			language_instructions = {
				cpp = "cpp bar instructions",
			},
		}

		codegpt.setup({
			commands = {
				testcmd = testcmd,
			},
		})
		local cmd_opts = Commands.get_cmd_opts("testcmd")
		local messages = Messages.generate_messages("testcmd", cmd_opts, "", "")
		assert(messages[2].content == "foo cpp bar instructions", messages[2])
	end)

	it("should parse {{language}}", function()
		vim.o.filetype = "cpp"
		local testcmd = {
			user_message_template = "foo {{language_instructions}}",
			language_instructions = {
				cpp = "cpp bar instructions",
			},
		}

		codegpt.setup({
			commands = {
				testcmd = testcmd,
			},
		})
		local cmd_opts = Commands.get_cmd_opts("testcmd")
		local messages = Messages.generate_messages("testcmd", cmd_opts, "", "")
		assert(messages[2].content == "foo cpp bar instructions", messages[2])
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

	describe("context vars", function()
		local buf1content = [[
function example()
  -- TODO: implement functionality
  return nil
end
]]
		local buf2content = [[
#include <iostream>
int main() {
    std::cout << "Hello, World!" << std::endl;
    return 0;
}
]]
		local buf1 = vim.api.nvim_create_buf(true, false)
		local buf2 = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_set_option_value("filetype", "rust", { buf = buf1 })
		vim.api.nvim_set_option_value("filetype", "cpp", { buf = buf2 })
		vim.api.nvim_buf_set_lines(buf1, -1, -1, true, vim.split(buf1content, "\n"))
		vim.api.nvim_buf_set_lines(buf2, -1, -1, true, vim.split(buf2content, "\n"))
		local buf1path = "/foo/b-ar/file.rs"
		local buf2path = "/foo/b-ar/file.cpp"
		vim.api.nvim_buf_set_name(buf1, buf1path)
		vim.api.nvim_buf_set_name(buf2, buf2path)

		-- injects content of buffer using the syntax #{bufnr}
		it("parse buffer vars #{n}", function()
			local testcmd = {
				user_message_template = vim.fn.printf("given these files #{%d} and #{%d}Explain in detail", buf1, buf2),
			}
			codegpt.setup({ commands = { testcmd = testcmd } })

			local cmd_opts = Commands.get_cmd_opts("testcmd")
			local messages = Messages.generate_messages("testcmd", cmd_opts, "", "")
			-- print(messages[2].content)
			-- print(string.gsub(messages[2].content, " ", "@"))

			local expected = "given these files \nfile: "
				.. buf1path
				.. "\n```rust\n"
				.. buf1content
				.. "```\n and \nfile: "
				.. buf2path
				.. "\n```cpp\n"
				.. buf2content
				.. "```\nExplain in detail"

			-- print(string.gsub(expected, " ", "@"))
			-- print("---------")
			-- print(expected)

			assert(messages[2].content == expected)
		end)

		it("parse buffer vars #{filepath:n}", function()
			local testcmd = {
				user_message_template = vim.fn.printf(
					"given these files #{%s:%d} and #{%s:%d}Explain in detail",
					buf1path,
					buf1,
					buf2path,
					buf2
				),
			}
			codegpt.setup({ commands = { testcmd = testcmd } })

			local cmd_opts = Commands.get_cmd_opts("testcmd")
			local messages = Messages.generate_messages("testcmd", cmd_opts, "", "")
			-- print(messages[2].content)
			-- print(string.gsub(messages[2].content, " ", "@"))

			local expected = "given these files \nfile: "
				.. buf1path
				.. "\n```rust\n"
				.. buf1content
				.. "```\n and \nfile: "
				.. buf2path
				.. "\n```cpp\n"
				.. buf2content
				.. "```\nExplain in detail"

			-- print("---------")
			-- print(string.gsub(expected, " ", "@"))
			-- print(expected)

			-- assert(true)
			assert(messages[2].content == expected)
		end)

		it('parse register vars ""reg', function()
			local testcmd = {
				user_message_template = 'content of register a: ""a and b: ""b',
			}
			codegpt.setup({ commands = { testcmd = testcmd } })

			-- Set up a mock register value
			vim.fn.setreg("a", "hello world\nthis is a test")
			vim.fn.setreg("b", "second register")

			local cmd_opts = Commands.get_cmd_opts("testcmd")
			local messages = Messages.generate_messages("testcmd", cmd_opts, "", "")

			local expected = "content of register a: hello world\nthis is a test and b: second register"

			assert(messages[2].content == expected)
		end)
	end)
end)
