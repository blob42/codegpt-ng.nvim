local OpenAIProvider = require("codegpt.providers.openai")
local AzureProvider = require("codegpt.providers.azure")
local AnthropicProvider = require("codegpt.providers.anthropic")
local OllaMaProvider = require("codegpt.providers.ollama")
local GroqProvider = require("codegpt.providers.groq")
local Config = require("codegpt.config")

local M = {}

M.available = {
	openai = OpenAIProvider,
	ollama = OllaMaProvider,
	groc = GroqProvider,
	anthropic = AnthropicProvider,
	azure = AzureProvider,
}

function M.get_provider()
	local provider = vim.fn.tolower(Config.opts.connection.api_provider)

	if provider == "openai" then
		return OpenAIProvider
	elseif provider == "azure" then
		return AzureProvider
	elseif provider == "anthropic" then
		return AnthropicProvider
	elseif provider == "ollama" then
		return OllaMaProvider
	elseif provider == "groq" then
		return GroqProvider
	else
		error("Provider not found: " .. provider)
	end
end

return M
