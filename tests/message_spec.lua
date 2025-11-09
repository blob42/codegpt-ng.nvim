local Message = require("codegpt.message")
local Messages = require("codegpt.messages")

describe("Message types", function()
	it("system", function()
		local sys = Message.System("foo system message")
		assert(vim.deep_equal(sys, {
			role = "system",
			content = "foo system message",
		}))
	end)

	it("assistant", function()
		local assistant = Message.Assistant("foo assistant message")
		assert(vim.deep_equal(assistant, {
			role = "assistant",
			content = "foo assistant message",
		}))
	end)

	it("user", function()
		local user = Message.User("foo user message")
		assert(vim.deep_equal(user, {
			role = "user",
			content = "foo user message",
		}))
	end)
end)

describe("Messages", function()
	describe("have unique id", function()
		it("should generate a unique id for each instance", function()
			local msg1 = Messages.new()
			local msg2 = Messages.new()

			assert.not_equal(msg1.id, msg2.id)
		end)

		it("should assign a random value to the id field", function()
			local msgs = Messages.new()

			assert.is_number(msgs.id)
			assert(msgs.id >= os.time() * 1000 + 1)
			assert(msgs.id <= os.time() * 1000 + 999)
		end)
	end)

	describe("add method", function()
		it("adds system messages correctly", function()
			local msgs = Messages.new()
			local sys = Message.System("system message")
			msgs:add(sys)

			assert.equal(1, #msgs.messages)
			assert.equal("system", msgs.messages[1].role)
			assert.equal("system message", msgs.messages[1].content)
		end)

		it("adds user messages correctly", function()
			local msgs = Messages.new()
			local user = Message.User("user message")
			msgs:add(user)

			assert.equal(1, #msgs.messages)
			assert.equal("user", msgs.messages[1].role)
			assert.equal("user message", msgs.messages[1].content)
		end)

		it("adds assistant messages correctly", function()
			local msgs = Messages.new()
			local assistant = Message.Assistant("assistant response")
			msgs:add(assistant)

			assert.equal(1, #msgs.messages)
			assert.equal("assistant", msgs.messages[1].role)
			assert.equal("assistant response", msgs.messages[1].content)
		end)

		it("preserves order when adding multiple messages", function()
			local msgs = Messages.new()

			-- Add messages in specific order
			msgs:add(Message.System("system message"))
			msgs:add(Message.User("user message"))
			msgs:add(Message.Assistant("assistant message"))

			-- Verify the internal list has 3 items and correct roles/content
			assert.equal(3, #msgs.messages)
			assert.equal("system", msgs.messages[1].role)
			assert.equal("user", msgs.messages[2].role)
			assert.equal("assistant", msgs.messages[3].role)

			-- Verify content of each message
			assert.equal("system message", msgs.messages[1].content)
			assert.equal("user message", msgs.messages[2].content)
			assert.equal("assistant message", msgs.messages[3].content)
		end)

		it("handles empty message list correctly", function()
			local msgs = Messages.new()
			assert.equal(0, #msgs.messages)
		end)

		it("handles mixed message types correctly", function()
			local msgs = Messages.new()

			-- Add various message types with specific content
			msgs:add(Message.System("system message"))
			msgs:add(Message.User("user message 1"))
			msgs:add(Message.Assistant("assistant response 1"))
			msgs:add(Message.User("user message 2"))

			-- Filter out system messages and verify order of user/assistant
			local filtered = {}
			for _, msg in ipairs(msgs.messages) do
				if msg.role ~= "system" then
					table.insert(filtered, msg)
				end
			end

			-- Verify the number of filtered messages
			assert.equal(3, #filtered)

			-- Verify roles and content of each message
			assert.equal("user", filtered[1].role)
			assert.equal("user message 1", filtered[1].content)

			assert.equal("assistant", filtered[2].role)
			assert.equal("assistant response 1", filtered[2].content)

			assert.equal("user", filtered[3].role)
			assert.equal("user message 2", filtered[3].content)
		end)
	end)
end)
