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
	if provider_config == nil then
		error("no models defined for " .. provider_name)
	end
	selected = config.model_override or provider_config.default or config.opts.models.default

	result = config.opts.models[provider_name][selected]

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

--- List available models
function M.list_models()
	local models = providers.get_provider().get_models()
	if models == nil then
		error("listing models")
	end
	vim.ui.select(models, {
		prompt = "ollama: available models",
		format_item = function(item)
			return item.name
		end,
	}, function(choice)
		if choice ~= nil then
			if choice.name ~= nil and #choice.name > 0 then
				print(choice.name)
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
