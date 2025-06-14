local curl = require("plenary.curl")
local Utils = require("codegpt.utils")
local Api = require("codegpt.api")
local Config = require("codegpt.config")
local tokens = require("codegpt.tokens")
local errors = require("codegpt.errors")
local Messages = require("codegpt.providers.messages")

local M = {}

local function get_max_tokens(max_tokens, prompt)
	local total_length = tokens.get_tokens(prompt)

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

	-- max # of tokens to generate
	local max_tokens = get_max_tokens(cmd_opts.max_tokens, messages)
	local model_name, model = models.get_model_for_cmdopts(cmd_opts)

	local model_opts = {}

	-- if model is nil just use model name in query
	if model ~= nil then
		model_opts = vim.tbl_deep_extend("force", model or {}, model.extra_params or {})
		model_opts.extra_params = nil
	end

	-- convert params to ollama api
	model_opts.num_ctx = max_tokens
	model_opts.max_tokens = nil

	model_opts.num_predict = model_opts.max_output_tokens
	model_opts.max_output_tokens = nil

	model_opts.temperature = cmd_opts.temperature

	local request = {
		options = model_opts,
		model = model_name,
		messages = messages,
		stream = is_stream or false,
	}

	return request
end

function M.make_headers()
	return { ["Content-Type"] = "application/json" }
end

function M.handle_response(json, cb)
	if json == nil then
		vim.schedule_wrap(function()
			errors.api_error("ollama", "Empty response")
		end)
	elseif json.done == nil or json.done == false then
		vim.schedule_wrap(function(msg)
			errors.api_error("ollama", msg)
		end)("Incomplete response " .. vim.fn.json_encode(json))
	elseif json.message.content == nil then
		vim.schedule_wrap(function()
			errors.api_error("ollama", "No response")
		end)
	else
		local response_text = json.message.content

		if response_text ~= nil then
			if type(response_text) ~= "string" or response_text == "" then
				vim.schedule_wrap(function()
					errors.api_error("ollama", "No response text " .. type(response_text))
				end)
			else
				local bufnr = vim.api.nvim_get_current_buf()
				if Config.opts.clear_visual_selection then
					vim.api.nvim_buf_set_mark(bufnr, "<", 0, 0, {})
					vim.api.nvim_buf_set_mark(bufnr, ">", 0, 0, {})
				end
				cb(Utils.parse_lines(response_text))
			end
		else
			vim.schedule_wrap(function()
				errors.api_error("ollama", "No text")
			end)
		end
	end
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
			errors.api_error("ollama", _body, _status)
		end)(body, status)
		Api.run_finished_hook()
		return
	end

	if body == nil or body == "" then
		vim.schedule_wrap(function()
			errors.api_error("ollama", "empty response body")
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

---@param payload table payload sent to api
---@param cb fun(response: table) callback that receives a clenary.curl http response
function M.make_call(payload, cb)
	local payload_str = vim.fn.json_encode(payload)
	local url = Config.opts.connection.ollama_base_url:gsub("/$", "") .. "/api/chat"
	local headers = M.make_headers()
	Api.run_started_hook()
	Api.current_job = curl.post(url, {
		body = payload_str,
		headers = headers,
		callback = function(response)
			curl_callback(response, cb, false)
		end,
		on_error = errors.curl_error,
		insecure = Config.opts.connection.allow_insecure,
		proxy = Config.opts.connection.proxy,
	})
end

---@param payload table payload sent to api
---@param stream_cb fun(data: table, job: table) callback to handle the resonse json stream
function M.make_stream_call(payload, stream_cb)
	local payload_str = vim.fn.json_encode(payload)
	local url = Config.opts.connection.ollama_base_url:gsub("/$", "") .. "/api/chat"
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

---@return table[] models list of ollama defined models
function M.get_models()
	local headers = M.make_headers()
	local url = Config.opts.connection.ollama_base_url .. "/api/tags"
	local ok, response = pcall(function()
		return curl.get(url, {
			headers = headers,
			insecure = Config.opts.connection.allow_insecure,
			proxy = Config.opts.connection.proxy,
		})
	end)
	if not ok then
		error("Could not get the Ollama models from " .. url .. "/api/tags.\nError: " .. response)
		return {}
	end
	local ok, json = pcall(vim.json.decode, response.body)
	if not ok then
		error("Could not parse the response from " .. url .. "/v1/models")
		return {}
	end
	local models = vim.fn.extend({}, json.models)
	return models
end

-- function M.choose_model

return M
