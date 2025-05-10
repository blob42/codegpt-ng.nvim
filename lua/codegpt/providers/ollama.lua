local curl = require("plenary.curl")
local Render = require("codegpt.template_render")
local Utils = require("codegpt.utils")
local Api = require("codegpt.api")
local Config = require("codegpt.config")
local Tokens = require("codegpt.tokens")

local M = {}

local selected_model = nil

local function generate_messages(command, cmd_opts, command_args, text_selection)
	local system_message =
		Render.render(command, cmd_opts.system_message_template, command_args, text_selection, cmd_opts)
	local user_message = Render.render(command, cmd_opts.user_message_template, command_args, text_selection, cmd_opts)

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

function M.make_request(command, cmd_opts, command_args, text_selection)
	-- NOTE Do not use the system message for now
	local messages = generate_messages(command, cmd_opts, command_args, text_selection)

	-- max # of tokens to generate
	local max_tokens = get_max_tokens(cmd_opts.max_tokens, messages)

	local request = {
		-- TODO!: test that params are sent, debug ollama api
		options = {
			temperature = cmd_opts.temperature,
			num_ctx = max_tokens,
		},
		-- max_tokens = max_tokens,
		model = Config.model_override or cmd_opts.model,
		messages = messages,
		stream = Config.opts.ui.stream_output,
	}

	return request
end

function M.make_headers()
	return { ["Content-Type"] = "application/json" }
end

function M.handle_response(json, cb)
	if json == nil then
		print("Response empty")
	elseif json.done == nil or json.done == false then
		print("Response is incomplete " .. vim.fn.json_encode(json))
	elseif json.message.content == nil then
		print("Error: No response")
	else
		local response_text = json.message.content

		if response_text ~= nil then
			if type(response_text) ~= "string" or response_text == "" then
				print("Error: No response text " .. type(response_text))
			else
				local bufnr = vim.api.nvim_get_current_buf()
				if Config.opts.clear_visual_selection then
					vim.api.nvim_buf_set_mark(bufnr, "<", 0, 0, {})
					vim.api.nvim_buf_set_mark(bufnr, ">", 0, 0, {})
				end
				cb(Utils.parse_lines(response_text))
			end
		else
			print("Error: No text")
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
		print("Error: " .. status .. " " .. body)
		return
	end

	if body == nil or body == "" then
		print("Error: No body")
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
			vim.defer_fn(function()
				vim.notify("curl error: " .. err.message, vim.log.levels.ERROR)
			end, 0)
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
			-- curl_callback(response, nil, true)
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

---@return table models list of ollama defined models
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
