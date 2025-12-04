--- saves runtime chat sessions in history buffer
--- optionally: periodic backup to disk
--- on load, preloads history from disk
local Buffer = require("codegpt.buffer")
local Config = require("codegpt.config")

local M = {}

local logfile_path = vim.fn.stdpath("log") .. "/codegpt.log"

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

local function format_message(msg)
	local template = msg.role == "system" and "# %s:\n%s\n" or "## %s:\n%s\n"
	return vim.fn.printf(template, msg.role:upper(), msg.content)
end

function M.show_chat()
	local chat = Buffer.chat()
	local hist = M.history

	if not hist then
		print("no history")
		return
	end

	if #hist.sessions == 0 then
		return
	end

	local lines = {}
	local last_session = hist.sessions[#hist.sessions]

	for _, msg in ipairs(last_session.messages) do
		local formatted_content = format_message(msg)
		vim.list_extend(lines, vim.split(formatted_content, "\n"))
	end

	chat:set_lines(lines)
	chat:show()
end

-- logs the last chat session to logfile
function M.log_chat_to_file()
	local logfile = io.open(logfile_path, "w+")
	if not logfile then
		print("Error: Could not open log file for writing")
		return
	end

	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	logfile:write("=== Chat Session Log - " .. timestamp .. " ===\n")

	local last_session = M.history.sessions[#M.history.sessions]
	for _, msg in ipairs(last_session.messages) do
		local formatted_content = format_message(msg)
		logfile:write(formatted_content)
	end

	logfile:write("\n")
	logfile:close()
end

M.history = History.new()

M.reset = function()
	M.history = nil
end

return M
