local history = require("codegpt.history")
local messages = require("codegpt.messages")
local message = require("codegpt.message")

describe("history", function()
	before_each(function()
		history.reset()
	end)

	it("should create a new history instance", function()
		local hist = history.get()
		assert.is_table(hist)
		assert.is_table(hist.sessions)
	end)

	it("should push a session to history", function()
		local hist = history.get()
		local msg1 = message.User("Hello")
		local msg2 = message.Assistant("Hi there!")
		local session = messages.new(msg1, msg2)

		hist:push(session)

		assert.is_equal(1, #hist.sessions)
		assert.is_equal(session.id, hist.sessions[1].id)
	end)

	it("should push multiple sessions to history", function()
		local hist = history.get()
		local msg1 = message.User("Hello")
		local msg2 = message.Assistant("Hi there!")
		local session1 = messages.new(msg1, msg2)

		hist:push(session1)

		local msg3 = message.User("How are you?")
		local msg4 = message.Assistant("I'm good, thanks!")
		local session2 = messages.new(msg3, msg4)

		hist:push(session2)

		assert.is_equal(2, #hist.sessions)
		assert.is_equal(session2.id, hist.sessions[2].id)
	end)

	it("should not allow empty sessions", function()
		local hist = history.get()
		local session = messages.new()

		assert.has_error(function()
			hist:push(session)
		end)
	end)

	it("should not allow nil sessions", function()
		local hist = history.get()

		assert.has_error(function()
			hist:push(nil)
		end)
	end)

	it("should preserve session order (LIFO)", function()
		local hist = history.get()
		local msg1 = message.User("Hello")
		local msg2 = message.Assistant("Hi there!")
		local session1 = messages.new(msg1, msg2)

		hist:push(session1)

		local msg3 = message.User("How are you?")
		local msg4 = message.Assistant("I'm good, thanks!")
		local session2 = messages.new(msg3, msg4)

		hist:push(session2)

		assert.is_equal(session2.id, hist.sessions[2].id)
	end)

	it("should handle multiple pushes correctly", function()
		local hist = history.get()
		local msg1 = message.User("Hello")
		local msg2 = message.Assistant("Hi there!")
		local session1 = messages.new(msg1, msg2)

		hist:push(session1)

		local msg3 = message.User("How are you?")
		local msg4 = message.Assistant("I'm good, thanks!")
		local session2 = messages.new(msg3, msg4)

		hist:push(session2)

		assert.equal(2, #hist.sessions)
		assert.equal(hist.sessions[#hist.sessions].messages[2].content, "I'm good, thanks!")
	end)
end)
