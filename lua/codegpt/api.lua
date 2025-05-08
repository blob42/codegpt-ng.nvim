local Config = require("codegpt.config")

local Api = {}

CODEGPT_CALLBACK_COUNTER = 0

local status_index = 0
local progress_bar_dots = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function Api.get_status(...)
	if CODEGPT_CALLBACK_COUNTER > 0 then
		status_index = status_index + 1
		if status_index > #progress_bar_dots then
			status_index = 1
		end
		return progress_bar_dots[status_index]
	else
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
