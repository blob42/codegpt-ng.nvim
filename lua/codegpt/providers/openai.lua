local curl = require("plenary.curl")
local Utils = require("codegpt.utils")
local Api = require("codegpt.api")
local Config = require("codegpt.config")
local tokens = require("codegpt.tokens")
local errors = require("codegpt.errors")
local Messages = require("codegpt.messages")
local history = require("codegpt.history")
local Message = require("codegpt.message")

-- TODO: handle streaming mode

local M = {}

local function get_max_tokens(max_tokens, messages)
	local total_length = tokens.get_tokens(messages)

	if total_length >= max_tokens then
		error("Total length of messages exceeds max_tokens: " .. total_length .. " > " .. max_tokens)
	end

	return max_tokens - total_length
end

---@param command string
---@param cmd_opts codegpt.CommandOpts
---@param command_args string
---@param text_selection string
---@param is_stream? boolean
function M.make_request(command, cmd_opts, command_args, text_selection, is_stream)
	local models = require("codegpt.models")
	local messages = Messages.generate_messages(command, cmd_opts, command_args, text_selection)

	local max_tokens = cmd_opts.max_tokens
	if cmd_opts.max_output_tokens ~= nil then
		Utils.fail_if_exceed_context_window(cmd_opts.max_tokens, messages)
		max_tokens = cmd_opts.max_output_tokens
	elseif not cmd_opts.fixed_max_tokens then
		max_tokens = get_max_tokens(cmd_opts.max_tokens, messages)
	end

	local model_name, model = models.get_model_for_cmdopts(cmd_opts)

	local request = {
		temperature = cmd_opts.temperature,
		n = cmd_opts.number_of_choices,
		model = model_name,
		messages = messages,
		max_tokens = max_tokens,
		stream = is_stream or false,
	}

	if model ~= nil then
		request = vim.tbl_extend("force", request, model.extra_params or {}, cmd_opts.extra_params or {})
	end
	return request
end

---@param response table plenary.curl http response
---@param cb? fun(lines: string)
---@param is_stream boolean
local function curl_callback(response, cb, is_stream)
	local status = response.status
	local body = response.body
	if status ~= 200 then
		body = body:gsub("%s+", " ")
		vim.schedule_wrap(function(_body, _status)
			errors.api_error("openai", _body, _status)
		end)(body, status)
		Api.run_finished_hook()
		return
	end

	if body == nil or body == "" then
		vim.schedule_wrap(function()
			errors.api_error("openai", "empty response body")
		end)
		Api.run_finished_hook()
		return
	end

	if not is_stream then
		vim.schedule_wrap(function(msg)
			local json = vim.fn.json_decode(msg)
			M.handle_response(json, cb)
		end)(body)
	end

	Api.run_finished_hook()
end

function M.make_headers()
	local token = Config.opts.connection.openai_api_key
	if not token then
		error(
			"OpenAIApi Key not found, set in vim with 'codegpt_openai_api_key' or as the env variable 'OPENAI_API_KEY'"
		)
	end

	return { Content_Type = "application/json", Authorization = "Bearer " .. token }
end

function M.handle_response(json, cb)
	if json == nil then
		vim.schedule_wrap(function()
			errors.api_error("openai", "Empty response")
		end)
	elseif json.error then
		print("Error: " .. json.error.message)
		vim.schedule_wrap(function(msg)
			errors.api_error("openai", msg)
		end)("Error: " .. json.error.message)
	elseif not json.choices or 0 == #json.choices or not json.choices[1].message then
		vim.schedule_wrap(function(msg)
			errors.api_error("openai", msg)
		end)("Error: " .. vim.fn.json_encode(json))
	else
		local response_text = json.choices[1].message.content

		if response_text ~= nil then
			if type(response_text) ~= "string" or response_text == "" then
				vim.schedule_wrap(function()
					errors.api_error("openai", "No response text " .. type(response_text))
				end)
			else
				local bufnr = vim.api.nvim_get_current_buf()
				if Config.opts.clear_visual_selection then
					vim.api.nvim_buf_set_mark(bufnr, "<", 0, 0, {})
					vim.api.nvim_buf_set_mark(bufnr, ">", 0, 0, {})
				end
				history.add_msg(Message.Assistant(response_text))
				cb(Utils.parse_lines(response_text))
			end
		else
			vim.schedule_wrap(function()
				errors.api_error("openai", "No message")
			end)
		end
	end
end

---@param payload table payload sent to api
---@param stream_cb fun(data: table, job: table) callback to handle the resonse json stream
function M.make_stream_call(payload, stream_cb)
	local payload_str = vim.fn.json_encode(payload)
	local url = Config.opts.connection.chat_completions_url .. "/chat/completions"
	local headers = M.make_headers()
	Api.run_started_hook()
	Api.current_job = curl.post(url, {
		body = payload_str,
		headers = headers,
		stream = function(error, data, job)
			if error ~= nil then
				vim.schedule_wrap(function(err)
					vim.notify(err, vim.log.levels.ERROR)
				end)(error)
			end
			vim.schedule_wrap(function(dat, jb)
				stream_cb(dat, jb)
			end)(data, job)
		end,
		callback = function(response)
			curl_callback(response, nil, true)
			Api.run_finished_hook()
		end,
		on_error = errors.curl_error,
		insecure = Config.opts.connection.allow_insecure,
		proxy = Config.opts.connection.proxy,
	})
end

function M.make_call(payload, cb)
	local payload_str = vim.fn.json_encode(payload)
	local url = Config.opts.connection.chat_completions_url .. "/chat/completions"
	local headers = M.make_headers()
	Api.run_started_hook()
	Api.current_job = curl.post(url, {
		body = payload_str,
		headers = headers,
		callback = function(response)
			curl_callback(response, cb)
		end,
		on_error = errors.curl_error,
		insecure = Config.opts.connection.allow_insecure,
		proxy = Config.opts.connection.proxy,
	})
end

function M.get_models()
	local url = Config.opts.connection.chat_completions_url .. "/models"
	local ok, response = pcall(function()
		return curl.get(url, {
			insecure = Config.opts.connection.allow_insecure,
			proxy = Config.opts.connection.proxy,
		})
	end)
	if not ok then
		error("Could not retrieve models from " .. url .. ".\nError: " .. response)
		return {}
	end
	local ok, json = pcall(vim.json.decode, response.body)
	if not ok then
		error("Could not parse the response from " .. url)
		return {}
	end
	local models = {}
	for _, model in ipairs(json.data) do
		table.insert(models, {
			name = model.id,
		})
	end
	return models
end

return M
