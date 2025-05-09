local Config = require("codegpt.config")

local Api = {}

CODEGPT_CALLBACK_COUNTER = 0

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

function Api.get_status(...)
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

function Api.run_started_hook()
	if Config.opts.hooks.request_started ~= nil then
		Config.opts.hooks.request_started()
	end

	CODEGPT_CALLBACK_COUNTER = CODEGPT_CALLBACK_COUNTER + 1
end

function Api.run_finished_hook()
	CODEGPT_CALLBACK_COUNTER = CODEGPT_CALLBACK_COUNTER - 1
	if CODEGPT_CALLBACK_COUNTER <= 0 then
		if Config.opts.hooks.request_finished ~= nil then
			Config.opts.hooks.request_finished()
		end
	end
end

return Api
