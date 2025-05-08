-- taken from https://github.com/olimorris/codecompanion.nvim/blob/12a1f0e8c8512e69d3ed64b7ac179a024794e4e4/lua/codecompanion/utils/tokens.lua
local M = {}

---Calculate the number of tokens in a message
---@param message string The messages string
---@return number The number of tokens in the message
function M.calculate(message)
	-- heuristic: 1 token ≈ 4 characters
	local len = #message
	return math.ceil(len / 4)
end

---Get the total number of tokens in a list of messages
---@param messages table The messages to calculate the number of tokens for.
---@return number The number of tokens in the messages.
function M.get_tokens(messages)
	local tokens = 0
	for _, message in ipairs(messages) do
		tokens = tokens + M.calculate(message.content)
	end
	return tokens
end

return M
