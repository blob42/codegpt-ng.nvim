---@class codegpt.Config
local M = {}

-- -- Read old config if it exists
-- if vim.g["codegpt_openai_api_provider"] and #vim.g["codegpt_openai_api_provider"] > 0 then
-- 	vim.g["codegpt_api_provider"] = vim.g["codegpt_openai_api_provider"]
-- end

-- clears visual selection after completion
-- vim.g["codegpt_clear_visual_selection"] = true

-- vim.g["codegpt_hooks"] = {
-- 	request_started = nil,
-- 	request_finished = nil,
-- }

-- Border style to use for the popup
-- vim.g["codegpt_popup_border"] = { style = "rounded" }

-- Wraps the text on the popup window, deprecated in favor of codegpt_popup_window_options
-- vim.g["codegpt_wrap_popup_text"] = true

-- vim.g["codegpt_popup_window_options"] = {}

-- set the filetype of a text popup is markdown
-- vim.g["codegpt_text_popup_filetype"] = "markdown"

-- Set the type of ui to use for the popup, options are "popup", "vertical" or "horizontal"
-- vim.g["codegpt_popup_type"] = "popup"

-- Set the height of the horizontal popup
-- vim.g["codegpt_horizontal_popup_size"] = "20%"

-- Set the width of the vertical popup
-- vim.g["codegpt_vertical_popup_size"] = "20%"

vim.g["codegpt_commands_defaults"] = {
	["completion"] = {
		user_message_template = "I have the following {{language}} code snippet: ```{{filetype}}\n{{text_selection}}```\nComplete the rest. Use best practices and write really good documentation. {{language_instructions}} Only return the code snippet and nothing else.",
		language_instructions = {
			cpp = "Use modern C++ features.",
			java = "Use modern Java syntax. Use var when applicable.",
		},
	},
	["generate"] = {
		user_message_template = "Write code in {{language}} using best practices and write really good documentation. {{language_instructions}} Only return the code snippet and nothing else. {{command_args}}",
		language_instructions = {
			cpp = "Use modern C++ features.",
			java = "Use modern Java syntax. Use var when applicable.",
		},
		allow_empty_text_selection = true,
	},
	["code_edit"] = {
		user_message_template = "I have the following {{language}} code: ```{{filetype}}\n{{text_selection}}```\n{{command_args}}. {{language_instructions}} Only return the code snippet and nothing else.",
		language_instructions = {
			cpp = "Use modern C++ syntax.",
		},
	},
	["explain"] = {
		user_message_template = "Explain the following {{language}} code: ```{{filetype}}\n{{text_selection}}``` Explain as if you were explaining to another developer.",
		callback_type = "text_popup",
	},
	["question"] = {
		user_message_template = "I have a question about the following {{language}} code: ```{{filetype}}\n{{text_selection}}``` {{command_args}}",
		callback_type = "text_popup",
	},
	["debug"] = {
		user_message_template = "Analyze the following {{language}} code for bugs: ```{{filetype}}\n{{text_selection}}```",
		callback_type = "text_popup",
	},
	["doc"] = {
		user_message_template = "I have the following {{language}} code: ```{{filetype}}\n{{text_selection}}```\nWrite really good documentation using best practices for the given language. Attention paid to documenting parameters, return types, any exceptions or errors. {{language_instructions}} Only return the code snippet and nothing else.",
		language_instructions = {
			cpp = "Use doxygen style comments for functions.",
			java = "Use JavaDoc style comments for functions.",
		},
	},
	["opt"] = {
		user_message_template = "I have the following {{language}} code: ```{{filetype}}\n{{text_selection}}```\nOptimize this code. {{language_instructions}} Only return the code snippet and nothing else.",
		language_instructions = {
			cpp = "Use modern C++.",
		},
	},
	["tests"] = {
		user_message_template = "I have the following {{language}} code: ```{{filetype}}\n{{text_selection}}```\nWrite really good unit tests using best practices for the given language. {{language_instructions}} Only return the unit tests. Only return the code snippet and nothing else. ",
		callback_type = "code_popup",
		language_instructions = {
			cpp = "Use modern C++ syntax. Generate unit tests using the gtest framework.",
			java = "Generate unit tests using the junit framework.",
		},
	},
	["chat"] = {
		system_message_template = "You are a general assistant to a software developer.",
		user_message_template = "{{command_args}}",
		callback_type = "text_popup",
	},
}

-- Popup commands
vim.g["codegpt_ui_commands"] = {
	quit = "q",
	use_as_output = "<c-o>",
	use_as_input = "<c-i>",
}
vim.g["codegpt_ui_custom_commands"] = {}

---
--- Refactor to idiomatic neovim plugin
---

M.model_override = nil
M.popup_override = nil
M.persistent_override = nil

---@alias provider
---|'ollama'
---|'openai'
---|'azure'
---|'anthropic'
---|'groc'

---@alias CallbackType 'code_popup' | 'replace_lines' | 'text_popup'

---@class codegpt.Model
---@field alias? string An alias for this model
---@field temperature? number 0 -> 1, what sampling temperature to use.
---@field max_tokens? number The maximum number of tokens to use including the prompt tokens.
---@field system_message_template? string Helps set the behavior of the assistant.
---@field user_message_template? string Instructs the assistant.
---@field language_instructions? string A table of filetype => instructions.
---The current buffer's filetype is used in this lookup.
---This is useful trigger different instructions for different languages.
---@field callback_type? CallbackType Controls what the plugin does with the response
---@field params? table Custom parameters to include with this model query
local Model = {}

---@alias ModelDef { [string] : codegpt.Model }

---@alias Hook fun()

---@class codegpt.Connection
---@field chat_completions_url? string OpenAI API compatible API endpoint
---@field openai_api_key? string https://platform.openai.com/account/api-keys
---@field ollama_base_url? string ollama base api url default: http://localhost:11434/api/
---@field api_provider? string Type of provider for the OpenAI API endpoint
---@field proxy? string [protocol://]host[:port] e.g. socks5://127.0.0.1:9999
---@field allow_insecure? boolean Allow insecure connections?

---@class codegpt.UIOptions
---@field popup_border {style:string} Border style to use for the popup
---@field popup_window_options {}
---@field popup_options? table nui.nvim popup options
---@field persistent? boolean Do not close popup window on mouse leave. Useful with vertical and horizontal layouts.
---@field text_popup_filetype string Set the filetype of the text popup
---@field popup_type "popup" | "vertical" | "horizontal" Set the type of ui to use for the popup
---@field horizontal_popup_size string Set the height of the horizontal popup
---@field vertical_popup_size string Set the width of the vertical popup
---@field spinners? string[] Custom list of icons to use for the spinner animation
---@field spinner_speed? number Speed of spinner animation, higher is slower

---@class codegpt.Options
---@field connection codegpt.Connection Connection parameters
---@field ui codegpt.UIOptions display parameters
---@field models? table<provider, ModelDef> Model configs grouped by provider
---@field write_response_to_err_log? boolean Log model answers to error buffer
---@field clear_visual_selection? boolean Clears visual selection after completion
---@field hooks? { request_started?:Hook,  request_finished?:Hook}

---@type codegpt.Options
local defaults = {
	connection = {
		api_provider = "openai",
		chat_completions_url = "https://api.openai.com/v1/chat/completions",
		ollama_base_url = "http://localhost:11434",
		proxy = nil,
		allow_insecure = false,
	},
	ui = {
		popup_border = { style = "rounded" },
		popup_options = nil,
		popup_window_options = {},
		text_popup_filetype = "markdown",
		popup_type = "popup",
		horizontal_popup_size = "20%",
		vertical_popup_size = "20%",
		-- spinners = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
		spinners = { "", "", "", "", "", "" },
		spinner_speed = 80, -- higher is slower
	},
	models = {
		ollama = { ["test"] = { language_instructions = "test" } },
	},
	clear_visual_selection = true,
	hooks = {
		request_started = nil,
		request_finished = nil,
	},
}

---@type codegpt.Options
---@diagnostic disable-next-line
M.opts = {}

---@param options? codegpt.Options
M.setup = function(options)
	M.opts = vim.tbl_deep_extend("force", {}, defaults, options or {})

	-- env takes precedences
	if os.getenv("OPENAI_API_KEY") ~= nil then
		M.opts.connection.openai_api_key = os.getenv("OPENAI_API_KEY")
	end

	-- print(vim.inspect(M.opts))
end

return M
