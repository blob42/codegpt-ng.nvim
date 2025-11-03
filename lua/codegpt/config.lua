---@class codegpt.Config
local M = {}

---@class codegpt.Chatmsg
---@field role "system"|"user"|"assistant"
---@field content string

---@class codegpt.CommandOpts
---@field user_message_template? string
---@field language_instructions? table<string, string> language instruction in the form lang = instruction
---@field allow_empty_text_selection? boolean allows running the command without text selection
---@field callback_type? codegpt.CallbackType
---@field temperature? number Custom temperature for this command
---@field max_tokens? number Custom max_tokens for this command
---@field append_string? string String to append to prompt -- ex: /no_think
---@field model? string Model to always use with this command
---@field chat_history? codegpt.Chatmsg[]
---@field stream_output? string override output streaming for this command
---@field [string] any -- merged command parameters

---@type { [string]: codegpt.CommandOpts }
local default_commands = {
	completion = {
		user_message_template = "I have the following {{language}} code snippet: ```{{filetype}}\n{{text_selection}}```\nComplete the rest. Use best practices and write really good documentation. {{language_instructions}} Only return the code snippet and nothing else.",
		language_instructions = {
			cpp = "Use modern C++ features.",
			java = "Use modern Java syntax. Use var when applicable.",
		},
	},
	generate = {
		user_message_template = "Write code in {{language}} using best practices and write really good documentation. {{language_instructions}} Only return the code snippet and nothing else. {{command_args}}",
		language_instructions = {
			cpp = "Use modern C++ features.",
			java = "Use modern Java syntax. Use var when applicable.",
		},
		allow_empty_text_selection = true,
	},
	code_edit = {
		user_message_template = "I have the following {{language}} code: ```{{filetype}}\n{{text_selection}}```\n{{command_args}}. {{language_instructions}} Only return the code snippet and nothing else.",
		language_instructions = {
			cpp = "Use modern C++ syntax.",
		},
	},
	explain = {
		user_message_template = "Explain the following {{language}} code: ```{{filetype}}\n{{text_selection}}``` Explain as if you were explaining to another developer.",
		callback_type = "text_popup",
	},
	question = {
		user_message_template = "I have a question about the following {{language}} code: ```{{filetype}}\n{{text_selection}}``` {{command_args}}",
		callback_type = "text_popup",
	},
	debug = {
		user_message_template = "Analyze the following {{language}} code for bugs: ```{{filetype}}\n{{text_selection}}```",
		callback_type = "text_popup",
	},
	doc = {
		user_message_template = "I have the following {{language}} code: ```{{filetype}}\n{{text_selection}}```\nWrite really good documentation using best practices for the given language. Attention paid to documenting parameters, return types, any exceptions or errors. {{language_instructions}} Only return the documentation snippet and nothing else.",
		language_instructions = {
			cpp = "Use doxygen style comments for functions.",
			java = "Use JavaDoc style comments for functions.",
		},
		callback_type = "prepend_lines",
	},
	opt = {
		user_message_template = "I have the following {{language}} code: ```{{filetype}}\n{{text_selection}}```\nOptimize this code. {{language_instructions}} Only return the code snippet and nothing else.",
		language_instructions = {
			cpp = "Use modern C++.",
		},
	},
	tests = {
		user_message_template = "I have the following {{language}} code: ```{{filetype}}\n{{text_selection}}```\nWrite really good unit tests using best practices for the given language. {{language_instructions}} Only return the unit tests. Only return the code snippet and nothing else. ",
		callback_type = "code_popup",
		language_instructions = {
			cpp = "Use modern C++ syntax. Generate unit tests using the gtest framework.",
			java = "Generate unit tests using the junit framework.",
		},
	},
	chat = {
		system_message_template = "You are a general assistant to a software developer.",
		user_message_template = "{{command_args}}",
		callback_type = "text_popup",
	},
	proofread = {
		callback_type = "text_popup",
		system_message_template = "You are a {{filetype}} code proofreading assistant. Review the provided code snippet for errors, potential improvements, and best practices. Consider style, correctness, and idiomatic usage. Follow any additional instructions provided by the user.",
		user_message_template = "I have the following code snippet to review: ```{{filetype}} {{text_selection}}```. Please proofread it for errors and provide feedback. Additional instructions: {{command_args}}",
	},
}

M.model_override = nil -- override model to use
M.popup_override = nil
M.persistent_override = nil

---@alias codegpt.ProviderType
---|'ollama'
---|'openai'
---|'azure'
---|'anthropic'
---|'groc'

---@alias codegpt.CallbackCustom
---| fun(lines: string, bufnr: number,  start_row?: number, \
--- start_col?: number, end_row?: number, end_col?: number)
--- custom callback function. receives the output from the LLM model `lines`, the `bufnr` where the command or selection was made, and the coordinates of the visual selection if any or nil values

---@alias codegpt.CallbackType
---| "text_popup" # simple text popup
---| "test_popup_stream" # popup with streaming
---| "code_popup" # code only popup with corresponding filetype
---| "replace_lines" # replace selected text
---| "insert_lines" # insert below cursor position
---| "prepend_lines" # insert above cursor position
---| codegpt.CallbackCustom

---@class codegpt.Model
---@field alias? string An alias for this model
---@field max_tokens? number The maximum number of tokens to use including the prompt tokens.
---@field fixed_max_tokens? boolean Disable max_token calculation heuristics
---@field temperature? number 0 -> 1, what sampling temperature to use.
---@field number_of_choices? number OpenAI `n' chat completion choices
---@field max_output_tokens? number An upper bound for the number of tokens that can be generated for a response, including visible output tokens and reasoning tokens.
---@field system_message_template? string Helps set the behavior of the assistant.
---@field user_message_template? string Instructs the assistant.
---@field language_instructions? string A table of filetype => instructions.
---The current buffer's filetype is used in this lookup.
---This is useful trigger different instructions for different languages.
---@field callback_type? codegpt.CallbackType Controls what the plugin does with the response
---@field extra_params? table Custom parameters to include with this model query
---@field append_string? string String to append to prompt -- ex: /no_think
---@field from? string (optional) Name of parent model to inherit params from

---@alias ModelDef { [string] : codegpt.Model | string }

---@alias Hook fun()

---@class codegpt.Connection
---@field chat_completions_url? string OpenAI API compatible API endpoint
---@field openai_api_key? string | nil Defaults to the value of the `OPENAI_API_KEY` environment variable. Get one here: https://platform.openai.com/account/api-keys
---@field ollama_base_url? string ollama base api url default: http://localhost:11434/api/
---@field api_provider? codegpt.ProviderType Type of provider for the OpenAI API endpoint
---@field proxy? string [protocol://]host[:port] e.g. socks5://127.0.0.1:9999
---@field allow_insecure? boolean Allow insecure connections?

---@class codegpt.UIOptions
---@field popup_border? {style:string} Border style to use for the popup
---@field popup_window_options? {}
---@field popup_options? table nui.nvim popup options
---@field persistent? boolean Do not close popup window on mouse leave. Useful with vertical and horizontal layouts.
---@field mappings? table | {custom?: table} -- ui key mappings
---@field text_popup_filetype string Set the filetype of the text popup
---@field popup_type? "popup" | "vertical" | "horizontal" Set the type of ui to use for the popup
---@field horizontal_popup_size? string Set the height of the horizontal popup
---@field vertical_popup_size? string Set the width of the vertical popup
---@field spinners? string[] Custom list of icons to use for the spinner animation
---@field spinner_speed? number Speed of spinner animation, higher is slower
---@field stream_output? boolean Use streaming mode

---@class codegpt.Options
---@field connection codegpt.Connection Connection parameters
---@field ui codegpt.UIOptions display parameters
---@field models? table<codegpt.ProviderType, ModelDef> | {default: string} Model configs grouped by provider
---@field write_response_to_err_log? boolean Log model answers to error buffer
---@field clear_visual_selection? boolean Clears visual selection after completion
---@field hooks? { request_started?:Hook,  request_finished?:Hook}
---@field commands table<string, codegpt.CommandOpts> available codegpt commands
---@field global_defaults? table -- global defaults for all models takes the least precedence

---@type codegpt.Options
local defaults = {
	connection = {
		api_provider = "openai",
                openai_api_key = os.getenv("OPENAI_API_KEY"),
		chat_completions_url = "https://api.openai.com/v1/chat/completions",
		ollama_base_url = "http://localhost:11434",
		proxy = nil,
		allow_insecure = false,
	},
	ui = {
		stream_output = false,
		popup_border = { style = "rounded", padding = { 0, 1 } },
		popup_options = nil,
		popup_window_options = {},
		text_popup_filetype = "markdown",
		popup_type = "popup",
		horizontal_popup_size = "20%",
		vertical_popup_size = "20%",
		-- spinners = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
		spinners = { "", "", "", "", "", "" },
		spinner_speed = 80, -- higher is slower
		mappings = {
			quit = "q", -- key to quit the popup
			use_as_output = "<c-o>", -- key to use the popup content as output and replace the original lines
			use_as_input = "<c-i>", -- key to use the popup content as input for a new API request
			cancel = "<c-c>", -- cancel current request
			custom = {}, -- define your custom mappings here
		},
	},
	models = {
		default = "gpt-3.5-turbo", -- global default model
		ollama = {
			default = "gemma3:1b", -- provider level default model. model definition must exist
		},
		openai = {
			["gpt-3.5-turbo"] = {
				alias = "gpt35",
				max_tokens = 4096,
				temperature = 0.8,
			},
		},
	},
	clear_visual_selection = true,
	hooks = {
		request_started = nil,
		request_finished = nil,
	},
	commands = default_commands,

	-- general global defaults used as fallback if not defined elsewhere
	global_defaults = {
		max_tokens = 4096,
		temperature = 0.7,
		number_of_choices = 1,
		system_message_template = "You are a {{language}} coding assistant.",
		user_message_template = "",
		callback_type = "replace_lines",
		allow_empty_text_selection = false,
		extra_params = {}, -- extra parameters sent to the API
		max_output_tokens = nil,
	},
}

---@type codegpt.Options
---@diagnostic disable-next-line
M.opts = {}

---@param options? codegpt.Options
M.setup = function(options)
	M.opts = vim.tbl_deep_extend("force", {}, defaults, options or {})

	-- print(vim.inspect(M.opts))
end

return M

-- vim: wrap
