# codegpt-ng.nvim

**codegpt-ng** is a minimalist AI plugin for neovim centered around a command based workflow. It has full support for Ollama, OpenAI, Azure, Anthropic and Groc APIs. You can easilly define new commands, custom prompts with a template system, and model configurations without Lua code. 

This is a fork of the original **CodeGPT** repository from github user **@dpayne**.
All credit goes to him for the initial work.

This fork does the following:

- **Full support for Ollama and OpenAI API** 
- **Streaming mode** for real-time popup responses
- [**New table-based configuration**](#example-configuration) instead of global variables
- [**New commands**](#other-available-commands) and added support to the `%` range modifier
- **Ability to cancel** current request.
- **UI Query and select** local or remote model
- **Strips thinking tokens** from replies if the model forgets to use codeblocks
- **New callback types**: `insert_lines` and `prepend_lines`
- **Model definition inheritance**: Define models that inherit other model parameters
- **Refactored** for idiomatic Lua and neovim plugin style
- **Simplified command definition** with explicit configuration specification
- **Chat History**: Add example messages in a command definition
- **Tests with plenary library**
- **Fixed statusline** integration

Although this fork introduces breaking changes and a substantial rewrite, I've tried to preserve the original project's minimalist spirit — a tool that connects to AI APIs without getting in the way. The goal remains to provide simple, code-focused interactions that stay lightweight and unobtrusive, letting developers leverage LLMs while maintaining control over their workflow.

In particular, the model definition flow was carefully designed to quickly add custom model profiles for specific cases and easily switch between them or assign them to custom commands.

**[How Does It Compare To X](./doc/how-does-it-compare-to.md)**

**[Demo](#commands)**

**[Configuration](#configuration)**

**[Command Definition](#configuration)**

**[Model Specification](#model-specification)**

**[Templates](#templates)**

**[Example Config](#example-configuration)**



## Installation

* The plugins 'plenary' and 'nui' are also required.

Installing with Lazy.

```lua
{
  "blob42/codegpt-ng.nvim",
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
  },
  opts = {
    -- configuration here
  }
}
```

Installing with Packer.

```lua
use({
   "blob42/codegpt-ng.nvim",
   requires = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
   },
   config = function()
      require("codegpt").setup({
        -- Configuration here
      })
   end
})
```

## Commands

The top-level command is `:Chat`. The behavior is different depending on whether text is selected and/or arguments are passed.

### Completion

* `:Chat` with text selection will trigger the `completion` command, ChatGPT will try to complete the selected code snippet.
<div align="center">
  <p>
    <video controls muted src="https://github.com/user-attachments/assets/1c26404e-5c3b-4729-ba03-83454c53de91"></video>
  </p>
</div>

### Code Edit

* `:Chat some instructions` with text selection and command args will invoke the `code_edit` command.

<div align="center">
  <p>
    <video controls muted src="https://github.com/user-attachments/assets/e6eee3b7-2725-4a57-840e-e410a7446e75"></video>
  </p>
</div>

### Code Commands 

* `:Chat <command>`: if there is only one argument and that argument matches a command, it will invoke that command with the given text selection.


Here are a few example commands to illustrate it:

#### Doc

* `:Chat doc` generates documentation blocks and prepends it to the selected text.
* Use `codegpt.select_model()` to quickly select different models with `vim.ui.select`

<div align="center">
  <video controls muted src="https://github.com/user-attachments/assets/c9fb8d6f-af29-4344-b464-be33042567bf"></video>
</div>

#### Tests

In the below example `:Chat tests` will attempt to write units for the selected code.

<div align="center">
  <video controls muted src="https://github.com/user-attachments/assets/b185184b-82ec-4e7f-9e59-39bb44e7e7fa"></video>
</div>

#### Question

* Ask question about the selected text file. This demo also showcases using the `%` range modifier to use all the buffer as selection.

<div align="center">
  <video controls muted src="https://github.com/user-attachments/assets/3fe709ee-7014-43d4-b2be-232bf86621fb"></video>
</div>

### Chat Mode (Streaming)

* `:Chat hello world` without any text selection will trigger the `chat` command.
* Streaming can be toggled in the config

Note: you have to input at least two words otherwise it would be considered as a codegpt command.

<div align="center">
  <video controls muted src="https://github.com/user-attachments/assets/119d5104-a772-44ab-b624-b6b52510ada2"></video>
</div>

#### Other available commands:

- Range character `%Chat` to select all buffer.
- `:VChat`: to temporary enforce the vertical layout.
- `Chat!`: To make popup window persistent when the cursor leaves.

Here is the full list of predefined command actions:

| command      | input | Description |
|--------------|---- |------------------------------------|
| completion |  text selection | Will ask ChatGPT to complete the selected code. |
| code_edit  |  text selection + command args | Will ask ChatGPT to apply the given instructions (the command args) to the selected code. |
| explain  |  text selection | Will ask ChatGPT to explain the selected code. |
| question  |  text selection | Will pass the commands args to ChatGPT and return the answer in a text popup. |
| debug  |  text selection | Will pass the code selection to ChatGPT analyze it for bugs, the results will be in a text popup. |
| doc  |  text selection | Will ask ChatGPT to document the selected code. |
| opt  |  text selection | Will ask ChatGPT to optimize the selected code. |
| tests  |  text selection | Will ask ChatGPT to write unit tests for the selected code. |
| chat  |  command args | Will pass the given command args to ChatGPT and return the response in a popup. |

## Configuration

### Global Configuration

```lua
require("codegpt").setup({
  api = {
    provider = "openai",  -- or "Ollama", "Azure", etc.
    openai_api_key = vim.fn.getenv("OPENAI_API_KEY"),
    chat_completions_url = "https://api.openai.com/v1/chat/completions",
  },
  models { 
    -- model definitions
  },
  commands = {
    -- Command defaults
  },
  ui = {
    -- UI configuration
  },
  hooks = {
    -- Status hooks
  },
  clear_visual_selection = true,
})
```

### Overriding Command Definitions

The configuration table `commands` can be used to override command configurations.

```lua
commands = {
  completion = {
    model = "gpt-3.5-turbo",
    user_message_template = "This is a template...",
    callback_type = "replace_lines",
  },
  tests = {
    language_instructions = { java = "Use TestNG framework" },
  }
}
```

### Custom Commands

Custom commands can be added to the `commands` table.

```lua
commands = {
  modernize = {
    user_message_template = "Modernize the code...",
    language_instructions = { cpp = "..." }
  }
}
```

### Model Specification

The `models` table defines available LLM models for each provider. Models are
organized by provider type and can inherit parameters from other models.

```lua
  models = {
    default = "gpt-3.5-turbo",              -- Global default model
    ollama = {
      default = "gemma3:1b",                -- Ollama default model
      ['qwen3:4b'] = {
        alias = "qwen3",                    -- Alias to call this model
        max_tokens = 8192,
        temperature = 0.8,
        append_string = '/no_thinking', -- Custom string to append to the prompt
      },
    },
    openai = {
      ["gpt-3.5-turbo"] = {
        alias = "gpt35",
        max_tokens = 4096,
        temperature = 0.8,
      },
    },
  }
```

#### Inheritance

Models can inherit parameters from other models using the `from` field. For example:
```lua
    ["gpt-foo"] = {
      from = "gpt-3.5-turbo",  -- Inherit from openai's default
      temperature = 0.7,       -- Override temperature
    }
```

#### Aliases

Use `alias` to create shorthand names for models.

#### Override defaults

Specify model parameters like `max_tokens`, `temperature`, and `append_string`
to customize behavior. see `lua/codegpt/config.lua` file for the full config specification.

#### Model Selection

- Call `:lua codegpt.select_model()` to interactively choose a model via UI.

### UI Configuration

```lua
ui = {
  popup_type = "popup",  -- or "horizontal", "vertical"
  text_popup_filetype = "markdown",
  mappings = {
    quit = "q",
    use_as_output = "<c-o>",
  },
  popup_options = {
    relative = "editor",
    position = "50%",
    size = { width = "80%", height = "80%" },
  },
  popup_border = { style = "rounded" },
  popup_window_options = { wrap = true, number = true },
}
```

### Status Hooks

```lua
hooks = {
  request_started = function() vim.cmd("hi StatusLine ctermfg=yellow") end,
  request_finished = function() vim.cmd("hi StatusLine ctermfg=NONE") end,
}
```

## Templates

You can use macros inside the user/system message templates when defining a command. 

The `system_message_template` and `user_message_template` can contain the following macros:

| macro | description |
|------|-------------|
| `{{filetype}}` | The `filetype` of the current buffer. |
| `{{text_selection}}` | The selected text in the current buffer. |
| `{{language}}` | The name of the programming language in the current buffer. |
| `{{command_args}}` | Everything passed to the command as an argument, joined with spaces. |
| `{{language_instructions}}` | The found value in the `language_instructions` map. |

### Template Examples

Here is are a few examples to demonstrate how to use them:

```lua
  commands = {
  --- other commands
    cli_helpgen = {
      system_message_template = 'You are a documentation assistant to a software developer. Generate documentation for a CLI app using the --help flag style, including usage and options. Only output the help text and nothing else.',
      user_message_template = 'App name and usage:\n\n```{{filetype}}\n{{text_selection}}```\n. {{command_args}}. . {{language_instructions}}',
      model = 'codestral',
      language_instructions = {
        python = 'Use a standard --help flag style, including usage and options, with example usage if needed.',
      },
    },
    rs_mod_doc = {
      system_message_template = 'You are a Rust documentation assistant. Given the provided source code, add appropriate module-level documentation that goes at the top of the file. Use the `//!` comment format and example sections as necessary. Include explanations for what each function in the module.',
      user_message_template = 'Source code:\n```{{filetype}}\n{{text_selection}}\n```\n. {{command_args}}. Generate the doc using module level rust comments `//!` ',
    },

    -- dummy command to showcase the use of chat_history
    acronym = {
      system_message_template = 'You are a helpful {{filetype}} programming assistant that abbreviates identifiers and variables..',
      user_message_template = 'abbreviate ```{{filetype}}\n{{text_selection}}```\n {{command_args}}',
      chat_history = {
        { role = 'user', content = 'abbreviate `configure_user_script`' },
        { role = 'assistant', content = 'c_u_s' },
        { role = 'user', content = 'abbreviate ```lua\nlocal = search_common_pattern = {}```\n' },
        { role = 'assistant', content = 'local = s_c_p = {}' },
      },
    },
```

## Callback Types

| name      | Description |
|--------------|----------|
| text_popup   | Will display the result in a text popup window. |
| code_popup   | Will display the results in a popup window with the filetype set to the filetype of the current buffer. |
| replace_lines | Replaces the current lines with the response. If no text is selected, it will insert the response at the cursor. |
| insert_lines  | Inserts the response after the current cursor line without replacing any existing text. |
| prepend_lines | Inserts the response before the current lines. If no text is selected, it will insert the response at the beginning of the buffer. |

## Example Configuration

```lua
require("codegpt").setup({
  -- Connection settings for API providers
  connection = {
    api_provider = "openai",                -- Default API provider
    openai_api_key = vim.fn.getenv("OPENAI_API_KEY"),
    chat_completions_url = "https://api.openai.com/v1/chat/completions", -- Default OpenAI endpoint
    ollama_base_url = "http://localhost:11434",  -- Ollama base URL
    proxy = nil,                            -- Can also be set with $http_proxy environment variable
    allow_insecure = false,                 -- Disable insecure connections by default
  },

  -- UI configuration for popups
  ui = {
    stream_output = false,                  -- Disable streaming by default
    popup_border = { style = "rounded", padding = { 0, 1 } },  -- Default border style
    popup_options = nil,                    -- No additional popup options
    text_popup_filetype = "markdown",       -- Default filetype for text
popups
    popup_type = "popup",                   -- Default popup type
    horizontal_popup_size = "20%",          -- Default horizontal size
    vertical_popup_size = "20%",            -- Default vertical size
    spinners = { "", "", "", "", "", "" },  -- Default spinner icons
    spinner_speed = 80,                     -- Default spinner speed
    actions = {
      quit = "q",                           -- Quit key
      use_as_output = "<c-o>",              -- Use as output key
      use_as_input = "<c-i>",               -- Use as input key
      cancel = "<c-c>", 		    -- cancel current request
      custom = nil,                         -- table. with custom actions
    },
  },

  -- Model configurations grouped by provider
  models = {
    default = "gpt-3.5-turbo",              -- Global default model
    ollama = {
      default = "gemma3:1b",                -- Ollama default model
      ['qwen3:4b'] = {
        alias = "qwen3",                    -- Alias to call this model
        max_tokens = 8192,
        temperature = 0.8,
        append_string = '/no_think',		-- Custom string to append to the prompt
      },
    },
    openai = {
      ["gpt-3.5-turbo"] = {
        alias = "gpt35",
        max_tokens = 4096,
        temperature = 0.8,
      },
    },
  },

  -- General options
  clear_visual_selection = true,            -- Clear visual selection when the command starts

  -- Custom hooks
  hooks = {
    request_started = nil,                  --  
    request_finished = nil,                 -- 
  },

  commands = {
    -- Add you custom commands here. Example:
    doc = {
      language_instructions = { python = "Use Google style docstrings" },
      max_tokens = 1024,
    },
    modernize = {
      user_message_template = "I have the following {{language}} code: ```{{filetype}}\n{{text_selection}}```\nModernize the above code. Use current best practices. Only return the code snippet and comments. {{language_instructions}}",
      language_instructions = {
        cpp = "Use modern C++ syntax. Use auto where possible. Do not import std. Use trailing return type. Use the c++11, c++14, c++17, and c++20 standards where applicable.",
      },
    }
  },

  -- Global defaults for all models
  global_defaults = {
    max_tokens = 4096,
    temperature = 0.7,
    number_of_choices = 1,
    system_message_template = "You are a {{language}} coding assistant.",
    user_message_template = "",
    callback_type = "replace_lines",
    allow_empty_text_selection = false,
    extra_params = {},
    max_output_tokens = nil,
  },
})

```

## External API

- `setup({config})`: setup plugin
- `select_model()`: list local defined and remote available models 
- `cancel_request()`: Cancel ongoing request


## License

Copyright (c) 2025 - Chakib Benziane <contact@blob42.xyz>

This project is licensed under the terms of the AGPL3 license.

A copy of the license is distributed with the source code of this project.


## Credit

Darby Payne (@dpayne) <darby.payne@gmail.com> the original creator. 

And all contributors

