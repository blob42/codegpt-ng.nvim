--- saves runtime chat sessions in history buffer
--- optionally: periodic backup to disk
--- on load, preloads history from disk
local Buffer = require("codegpt.buffer")

local M = {}

---@class codegpt.History
---@field sessions codegpt.Messages[]
---@field cur_session? codegpt.Messages pointer to current session
local History = {}
History.__index = History

---@type codegpt.History?
M.history = nil

function History.new()
	if M.history ~= nil then
		return M.history
	end
	local self = {
		sessions = {},
	}
	setmetatable(self, History)
	M.history = self
	return self
end

---@param session codegpt.Messages
function History:push(session)
	assert(session ~= nil)
	assert(#session.messages > 0)
	table.insert(self.sessions, session)
	self.cur_session = session
end

---@return codegpt.Messages? session returns last session
function History:current()
	return self.cur_session
end

function M.get()
	return History.new()
end

---@param msg codegpt.Chatmsg
function M.add_msg(msg)
	local current = M.history:current()
	if current ~= nil then
		current:add(msg)
	end
end

function M.show_chat()
	local chat = Buffer.chat()
	local hist = M.history
	if hist == nil then
		print("no history")
		return
	end
	local lines = {}
	local ai_tpl = "# %s:\n%s\n"
	local user_tpl = "## %s:\n%s\n"
	if #hist.sessions > 0 then
		for _, msg in ipairs(hist.sessions[#hist.sessions].messages) do
			local content = ""
			if msg.role == "system" or msg.role == "assistant" then
				content = vim.fn.printf(ai_tpl, msg.role:upper(), msg.content)
			else
				content = vim.fn.printf(user_tpl, msg.role:upper(), msg.content)
			end
			vim.list_extend(lines, vim.split(content, "\n"))
			-- print(vim.inspect(msg.role))
			-- print(vim.inspect(msg.content))
		end
		chat:set_lines(lines)
		chat:show()
	end
end

M.history = History.new()

M.reset = function()
	M.history = nil
end

return M
