local Api = require("codegpt.api")
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

function M.curl_error(err)
	if err.exit ~= nil then
		vim.defer_fn(function()
			vim.notify("curl error: " .. err.message, vim.log.levels.ERROR)
		end, 0)
	end
	Api.run_finished_hook()
end

return M
