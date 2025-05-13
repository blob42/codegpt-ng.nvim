local config = require("codegpt.config")
local providers = require("codegpt.providers")
local M = {}

--- default model selection order from highest to lowest priority
--- 1. global model_override (manual selection, always temporary for an nvim session)
--- 2. provider default model
--- 3. global default (opts.models.default)
---@return string name
---@return codegpt.Model model
function M.get_model()
	---@type codegpt.Model
	local result

	local provider_name = vim.fn.tolower(config.opts.connection.api_provider)
	-- local selected = config.model_override or config.opts.models[provider].default or config.opts.models.default
	local selected
	local provider_config = config.opts.models[provider_name]

	-- of provider config is a string, then it must be just a model name
	if type(provider_config) == "string" and #provider_config > 0 then
		return provider_config, nil
	end
	assert(type(provider_config) == "table")

	if provider_config == nil then
		error("no models defined for " .. provider_name)
	end

	selected = config.model_override or provider_config.default or config.opts.models.default
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

	return selected, result
end

---@param alias? string model alias
---@return string name
---@return codegpt.Model model
function M.get_model_by_alias(alias)
	assert(alias and #alias > 0)

	local provider_name = vim.fn.tolower(config.opts.connection.api_provider)
	local provider_config = config.opts.models[provider_name]
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
	local models = providers.get_provider().get_models()
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
	local provider_config = config.opts.models[provider]

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
function M.list_models()
	local remote_models = M.get_remote_models()
	local models = vim.tbl_extend("force", {}, remote_models)

	-- get local defined models
	local used_provider = vim.fn.tolower(config.opts.connection.api_provider)
	local local_models = M.get_local_models(used_provider)
	models = vim.tbl_extend("force", models, local_models)

	if models == nil then
		error("listing models")
	end

	vim.ui.select(models, {
		prompt = "ollama: available models",
		format_item = function(item)
			local display = ""
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
				print("selected <" .. choice.name .. "> (" .. choice.model_source .. " defined)")
			end
		end
	end)
end

function M.select_model()
	local models = providers.get_provider().get_models()
	if models == nil then
		error("querying models")
	end
	vim.ui.select(models, {
		prompt = "ollama: available models",
		format_item = function(item)
			return item.name
		end,
	}, function(choice)
		if choice ~= nil and #choice.name > 0 then
			config.model_override = choice.name
			print("model override = <" .. choice.name .. ">")
		end
	end)
end

return M
