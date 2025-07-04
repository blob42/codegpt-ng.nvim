local Config = require("codegpt.config")
local Providers = require("codegpt.providers")
local M = {}

function M.get_model_by_name(name)
	local provider_name = vim.fn.tolower(Config.opts.connection.api_provider)
	local provider_config = Config.opts.models[provider_name]

	if type(provider_config) == "string" and #provider_config > 0 then
		return provider_config, nil
	end

	assert(type(provider_config) == "table")

	if provider_config == nil then
		error("no models defined for " .. provider_name)
	end

	local selected = name
	local result = provider_config[selected]

	if result == nil then
		for model_name, model in pairs(provider_config) do
			if model.alias == selected then
				result = model
				selected = model_name
				break
			end
		end
	end

	-- (optional) inherit a parent model
	if result ~= nil and result.from ~= nil and #result.from > 0 then
		local parent_name, parent = M.get_model_by_name(result.from)
		if parent ~= nil then
			result = vim.tbl_deep_extend("force", parent, result)
			selected = parent_name
		end
	end

	return selected, result
end
--- default model selection order from highest to lowest priority
--- 1. global model_override (manual selection, always temporary for an nvim session)
--- 2. provider default model
--- 3. global default (opts.models.default)
---@return string name
---@return codegpt.Model model
function M.get_model()
	---@type codegpt.Model
	local result

	local provider_name = vim.fn.tolower(Config.opts.connection.api_provider)
	-- local selected = config.model_override or config.opts.models[provider].default or config.opts.models.default
	local selected
	local provider_config = Config.opts.models[provider_name]

	-- of provider config is a string, then it must be just a model name
	if type(provider_config) == "string" and #provider_config > 0 then
		return provider_config, nil
	end
	assert(type(provider_config) == "table")

	if provider_config == nil then
		error("no models defined for " .. provider_name)
	end

	selected = Config.model_override or provider_config.default or Config.opts.models.default
	assert(type(selected) == "string")

	result = provider_config[selected]

	-- try to get model by alias
	if result == nil then
		for name, model in pairs(provider_config) do
			if model.alias == selected then
				result = model
				selected = name
				break
			end
		end
	end

	-- (optional) inherit a parent model
	if result ~= nil and result.from ~= nil and #result.from > 0 then
		local parent_name, parent = M.get_model_by_name(result.from)
		if parent ~= nil then
			result = vim.tbl_deep_extend("force", parent, result)
			selected = parent_name
		end
	end

	return selected, result
end

---@param alias? string model alias
---@return string name
---@return codegpt.Model model
function M.get_model_by_alias(alias)
	assert(alias and #alias > 0)

	local provider_name = vim.fn.tolower(Config.opts.connection.api_provider)
	local provider_config = Config.opts.models[provider_name]
	if provider_config == nil then
		error("no models defined for " .. provider_name)
	end

	for name, model in pairs(provider_config) do
		if model.alias == alias then
			return name, model
		end
	end
	return "", nil
end

---@return table[]
function M.get_remote_models()
	local models = Providers.get_provider().get_models()
	if models ~= nil then
		models = vim.tbl_map(function(remote)
			remote.model_source = "remote"
			return remote
		end, models)
	else
		return {}
	end
	return models
end

---@param provider string
---@return table[] models list of locally defined models
function M.get_local_models(provider)
	local provider_config = Config.opts.models[provider]

	-- models defined by name only are skipped since they must be a remote one
	if type(provider_config) == "string" then
		return {}
	end

	assert(type(provider_config) == "table")

	local models = {}
	for name, model in pairs(provider_config) do
		if name == "default" then
			goto continue
		end
		model.model_source = "local"
		model.name = name
		table.insert(models, model)
		::continue::
	end

	return models
end

--- List available models
function M.select_model()
	local remote_models = M.get_remote_models()
	local models = vim.tbl_extend("force", {}, remote_models)

	-- get local defined models
	local used_provider = vim.fn.tolower(Config.opts.connection.api_provider)
	local local_models = M.get_local_models(used_provider)
	models = vim.fn.extend(models, local_models)

	if models == nil then
		error("listing models")
	end

	vim.ui.select(models, {
		prompt = "ollama: available models",
		format_item = function(item)
			local display = ""
			if item.name == Config.model_override then
				display = "(*) "
			end
			if item.model_source == "local" then
				display = "[L] "
			elseif item.model_source == "remote" then
				display = "[R] "
			end
			if item.alias then
				display = display .. "(" .. item.alias .. ") "
			end
			return display .. item.name
		end,
	}, function(choice)
		if choice ~= nil then
			if choice.name ~= nil and #choice.name > 0 then
				Config.model_override = choice.name
				print("model override = <" .. choice.name .. "> (" .. choice.model_source .. " defined)")
			end
		end
	end)
end

---@param cmd_opts table
---@return string name
---@return table? model
function M.get_model_for_cmdopts(cmd_opts)
	local model_name, model
	if cmd_opts.model ~= nil and Config.model_override == nil then
		model_name, model = M.get_model_by_name(cmd_opts.model)
	else
		model_name, model = M.get_model()
	end
	assert(model_name and #model_name > 0, "undefined model")

	return model_name, model
end

return M
