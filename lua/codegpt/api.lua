local Config = require("codegpt.config")

local M = {}

local CODEGPT_CALLBACK_COUNTER = 0
---@type Job
M.current_job = nil

local status_index = 0
local timer = vim.uv.new_timer()

local function start_spinner_timer()
	assert(timer ~= nil)
	timer:start(
		0,
		100,
		vim.schedule_wrap(function()
			vim.cmd("redrawstatus")
		end)
	)
end

---@return string
function M.get_status(...)
	local spinners = Config.opts.ui.spinners or { "", "", "", "", "", "" }
	local spinner_speed = Config.opts.ui.spinner_speed or 80
	local ms = vim.uv.hrtime() / 1000000
	local frame = math.floor(ms / spinner_speed) % #spinners

	if CODEGPT_CALLBACK_COUNTER > 0 then
		status_index = status_index + 1
		if status_index == 1 then
			start_spinner_timer()
		end
		return spinners[frame + 1]
	else
		assert(timer ~= nil)
		if timer:is_active() then
			timer:stop()
		end
		status_index = 0
		return ""
	end
end

function M.run_started_hook()
	if Config.opts.hooks.request_started ~= nil then
		Config.opts.hooks.request_started()
	end

	CODEGPT_CALLBACK_COUNTER = CODEGPT_CALLBACK_COUNTER + 1
end

function M.run_finished_hook()
	if CODEGPT_CALLBACK_COUNTER > 0 then
		CODEGPT_CALLBACK_COUNTER = CODEGPT_CALLBACK_COUNTER - 1
	end
	if CODEGPT_CALLBACK_COUNTER <= 0 then
		if Config.opts.hooks.request_finished ~= nil then
			Config.opts.hooks.request_finished()
		end
	end
end

function M.cancel_job()
	if M.current_job ~= nil then
		M.current_job:shutdown()
		M.run_finished_hook()
	end
end

return M
