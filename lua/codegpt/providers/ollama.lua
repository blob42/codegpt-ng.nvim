local curl = require("plenary.curl")
local Render = require("codegpt.template_render")
local Utils = require("codegpt.utils")
local Api = require("codegpt.api")
local Config = require("codegpt.config")
local Tokens = require("codegpt.tokens")
local errors = require("codegpt.errors")

local M = {}

---@param cmd_opts codegpt.CommandOpts
local function generate_messages(command, cmd_opts, command_args, text_selection)
	local system_message =
		Render.render(command, cmd_opts.system_message_template, command_args, text_selection, cmd_opts)
	local user_message = Render.render(command, cmd_opts.user_message_template, command_args, text_selection, cmd_opts)
	if cmd_opts.append_string then
		user_message = user_message .. " " .. cmd_opts.append_string
	end

	local messages = {}
	if system_message ~= nil and system_message ~= "" then
		table.insert(messages, { role = "system", content = system_message })
	end

	if user_message ~= nil and user_message ~= "" then
		table.insert(messages, { role = "user", content = user_message })
	end

	return messages
end

local function get_max_tokens(max_tokens, prompt)
	local total_length = Tokens.get_tokens(prompt)

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

	local messages = generate_messages(command, cmd_opts, command_args, text_selection)

	local model_name, model = models.get_model()
	local model_opts = model or {}

	assert(model_name and #model_name > 0, "undefined model")

	-- max # of tokens to generate
	local max_tokens = get_max_tokens(cmd_opts.max_tokens, messages)

	-- ollama uses num_ctx
	model_opts.num_ctx = max_tokens
	model_opts.max_tokens = nil

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
				print("No response text " .. type(response_text))
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
	curl.post(url, {
		body = payload_str,
		headers = headers,
		callback = function(response)
			curl_callback(response, cb, false)
		end,
		on_error = function(err)
			vim.schedule_wrap(function(msg)
				errors.err("curl: " .. msg)
			end)(err.message)
			Api.run_finished_hook()
		end,
		insecure = Config.opts.connection.allow_insecure,
		proxy = Config.opts.connection.proxy,
	})
end

---@param payload table payload sent to api
---@param stream_cb fun(data: table) callback to handle the resonse json stream
function M.make_stream_call(payload, stream_cb)
	local payload_str = vim.fn.json_encode(payload)
	local url = Config.opts.connection.ollama_base_url:gsub("/$", "") .. "/api/chat"
	local headers = M.make_headers()
	Api.run_started_hook()
	curl.post(url, {
		body = payload_str,
		headers = headers,
		stream = function(error, data)
			if error ~= nil then
				vim.schedule_wrap(function(err)
					vim.notify(err, vim.log.levels.ERROR)
				end)(error)
			end
			-- stream_cb(data)
			vim.schedule_wrap(function(msg)
				stream_cb(msg)
			end)(data)
		end,
		callback = function(response)
			curl_callback(response, nil, true)
			Api.run_finished_hook()
		end,
		on_error = function(err)
			vim.defer_fn(function()
				vim.notify("curl error: " .. err.message, vim.log.levels.ERROR)
			end, 0)
			Api.run_finished_hook()
		end,
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
	-- print(vim.inspect(json))
	local models = {}
	for _, model in ipairs(json.models) do
		table.insert(models, 0, model)
	end
	return models
end

-- function M.choose_model

return M
