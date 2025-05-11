local M = {}

---@param provider string
---@param msg string
---@param status? number
function M.api_error(provider, msg, status)
	vim.notify(provider .. ": " .. (status or "") .. " " .. msg, vim.log.levels.ERROR)
end

function M.err(msg)
	vim.notify(msg, vim.log.levels.ERROR)
end

return M
