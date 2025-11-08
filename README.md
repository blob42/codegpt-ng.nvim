# Introduction

**Codegpt-ng** is a minimalistic Neovim plugin designed for efficient, command-line-driven workflows. Built with vimway principles in mind, it supports OpenAI and Ollama APIs seamlessly, enabling powerful code assistance through intuitive [cmdline-mode](https://neovim.io/doc/user/cmdline.html) interactions.

<!-- panvimdoc-ignore-start -->

This [is a fork](docs/fork.md) of the original **CodeGPT** repository from github user **@dpayne**. Credit goes to him for the initial work.

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment 

This is a fork of the original **CodeGPT** repository from github user
**@dpayne**. All credit goes to him for the initial work.

-->

#### Features Overview

* Create custom commands using intuitive Lua table definitions.

* Personalize prompts with flexible [templates](#templates), [context-injection](#context-injection) buffer content and register into the prompt context.

* Configure and tailor models to suit specific workflows or preferences.

* API hooks for advanced code based customization.


<!-- panvimdoc-ignore-start -->


**[How Does It Compare To X](./doc/how-does-it-compare-to.md)**

**[Demo](#commands)**

**[Configuration](#configuration)**

**[Command Definition](#override-commands)**

**[Model Params](#models)**

**[Templates](#templates)**

**[Example Config](#example-configuration)**


<!-- panvimdoc-ignore-end -->

# Installation

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

# Usage

The main way to call codegpt is through the top-level command `:Chat`. Optionally followed by a {command} and {arguments} (see [Commands](#commands)). 

The behavior is different depending on whether text is selected and/or arguments are passed.

The output is displayed using on of the builtin |codegpt-callback-types|.

The most common callback types are |codegpt-text_popup| and |codegpt-code_popup| which open a popup (or window) and display the LLM response. The response is streamed in real time unless the {config.ui.stream_output} is False.

For any of the following command, if the command accepts a visual selection it will also accept [cmdline-ranges][1]

## Completion

(visual selection) :Chat 
: Triggers the [completion](#completion) command
with a text selection. ie. Asks the LLM
to complete the code snippet.

<div align="center">
  <p>
    <video controls muted src="https://github.com/user-attachments/assets/1c26404e-5c3b-4729-ba03-83454c53de91"></video>
  </p>
</div>

## Code Edit

:[range]Chat {instructions...}
: Invokes the [code_edit](#code_edit) command with
the selected snippet and given
instructions.

<div align="center">
  <p>
    <video controls muted src="https://github.com/user-attachments/assets/e6eee3b7-2725-4a57-840e-e410a7446e75"></video>
  </p>
</div>

Note: if the first token of the instruction is an existing [command](#builtin) it will trigger that command instead.

## Chat Mode

:Chat {instructions...}
: Without any text selection will trigger
the `chat` command. Streaming can be
toggled on/off [configuration](#configuration).

Note: you have to input at least two words otherwise it would be considered as a codegpt command.

<div align="center">
  <video controls muted src="https://github.com/user-attachments/assets/119d5104-a772-44ab-b624-b6b52510ada2"></video>
</div>

# Commands

Use `:Chat <command> {arguments}` to explicitly call a codegpt command.  If there is no {arguments} and {command} matches a command, it will invoke that command with the given text selection. 

For example calling `:Chat tests` will attempt to write units for the selected code using the builtin `tests` command. [commands-builtin](#builtin)

Calling `:Chat tests use foomock library` will also call the `tests` command but will include the instruction: `use foomock library` as arguments to that command.

<!-- panvimdoc-ignore-start -->

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

Ask question about the selected text file. This demo also showcases using the `%` range modifier to use all the buffer as selection.

<div align="center">
  <video controls muted src="https://github.com/user-attachments/assets/3fe709ee-7014-43d4-b2be-232bf86621fb"></video>
</div>

<!-- panvimdoc-ignore-end -->

## Builtin

completion
: `input: selection`
  Completes the selected code

code_edit
: `input: selection [ + args ]`
  Applies the given instructions
(the command args) to the selected code

explain
: `input: selection`
  Explains the selected code

question
: `input: selection + args`
  Passes the commands args to LLM and
returns the answer in a text popup.

debug
: `input: selection`
  Analyzes the code selection for bugs.
Shows results will be in a text popup.

doc
: `input: selection`
  Documents the selected code

opt
: `input: selection`
  Optimizes the selected code

tests
: `input: selection + args`
  Writes unit tests for the selected code

chat
: `input: args`
  Passes the given command args to LLM
and returns the response in a popup

proofread
: `input: selection [ + args ]`
  Asks LLM to review the provided code
selection/buffer



# Context Injection

Enhance your command-line experience by injecting contextual Vim variables—such as open buffers and registers—directly into prompts using the `:Chat` command or within templates.

## Buffers
Use `#{bufnr}` to insert the content of a buffer. 

Type `#{%<TAB>` to trigger a menu of currently open buffers, expanding into `#{path:bufnr}` in the command-line.

## Registers
Insert register contents via `""x`, where `x` is the register name. This dynamically expands the register’s value in place.

### Example:

```vim
:Chat summarize #{%<TAB>  -- selection via autocomplete menu

-- References main.c buffer in the prompt
:Chat mycommnd take into consideration #{main.c:2}

--Inserts content of register `a` as context
:'<,'>Chat fix this code given the context in: ""a
```

## Modifiers

### Ranges

You can use any vim [cmdline-ranges][1] modifier. For example using the `:%` range as in `%<COMMAND>` will call the command using the content of the current buffer as context.

Using a visual range selection and calling the `:Chat` commands will insert the selected text as context if the `{{text_selection}}` placeholder is used by the command's template.

NOTE: the `cmdline` will look like `:'<,'>Chat ...`

### Other

:VChat
: Like `:Chat` but use a the vertical
layout.

:Chat!
: Make the popup window persistent.
It will not close when the cursor
leaves.

- `:VChat`: to temporary enforce the vertical layout.
- `Chat!`: To make popup window persistent when the cursor leaves.

## Custom Commands

The {commands} |codegpt-config| table can be used to override the builtin
default commands or to define new commands.

```lua
  require("codegpt").setup({
    --- 
    commands = {
      -- override the completion and tests commands
      completion = {
	model = "gpt-3.5-turbo",
	user_message_template = "This is a template...",
	callback_type = "replace_lines",
      },
      tests = {
	language_instructions = { java = "Use TestNG framework" },
      },

      -- define a new `mondernize' command
      modernize = {
	user_message_template = "Modernize the code...",
	language_instructions = { cpp = "..." }
      }
    }
    ---
  })
```

# Configuration

## Global

```lua
require("codegpt").setup({
  connection = {
    api_provider = "openai",  -- or "Ollama", "Azure", etc.
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

## Override Commands

The configuration table `commands` can be used to override existing commands or create new ones.
The overridden commands are merged with the default configuration.

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


## Models

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

	-- Custom string to append to the prompt
        append_string = '/no_thinking', 
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

### Inheritance

Models can inherit parameters from other models using the `from` field. For example:
```lua
    ["gpt-foo"] = {
      from = "gpt-3.5-turbo",  -- Inherit from openai's default
      temperature = 0.7,       -- Override temperature
    }
```

### Aliases

Use `alias` to create shorthand names for models.

```lua
    ["gpt-foo"] = {
      temperature = 1
      alias = "foo"
    },
    ["gpt-bar"] = {
      from = "foo",  -- Inherit from openai's default
      temperature = 0.7,       -- Override temperature
    }
```

### Override defaults

Specify model parameters like `max_tokens`, `temperature`, and `append_string`
to customize behavior. see `lua/codegpt/config.lua` file for the full config specification.

### Interactive Model Selection

- Call `:lua codegpt.select_model()` to interactively choose a model via UI.

## UI 

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

## Status Hooks

```lua
hooks = {
  request_started = function() vim.cmd("hi StatusLine ctermfg=yellow") end,
  request_finished = function() vim.cmd("hi StatusLine ctermfg=NONE") end,
}
```

# Templates

You can use macros inside the user/system message templates when defining a command. 

The `system_message_template` and `user_message_template` can contain the following macros:

{{filetype}}
: The `filetype` of the current buffer

 {{text_selection}}
: The selected text in the current buffer                             

 {{language}}
: The name of the programming language in
 the current buffer          

 {{command_args}}
: Everything passed to the command as an
 argument, joined with spaces 

 {{command}}
: The command (first token after `:Chat`)

 {{language_instructions}}
: The found value in the 
 `language_instructions` map                  


## Examples

Here is are a few examples to demonstrate how to use them:

```lua
  commands = {
  --- other commands
    cli_helpgen = {
      system_message_template = 'You are a documentation assistant to a \
      software developer. Generate documentation for a CLI app using the \
      --help flag style, including usage and options. \
      Only output the help text and nothing else',

      user_message_template = 'Details about app:\n\n```{{filetype}}\n \
	{{text_selection}}```\n. {{command_args}}. {{language_instructions}}',

      model = 'gemma3:27b',

      language_instructions = {
	python = 'Use a standard --help flag style, including usage and \
	  options, with example usage if needed'.
      },
    },
    rs_mod_doc = {

      system_message_template = 'You are a Rust documentation assistant. \
      Given the provided source code, add appropriate module-level \
      documentation that goes at the top of the file. Use the `//!` \
      comment format and example sections as necessary. Include \
      explanations for what each function in the module.',

      user_message_template = 'Source
      code:\n```{{filetype}}\n{{text_selection}}\n```\n. {{command_args}}.
      Generate the doc using module level rust comments `//!` ',
    },

    -- dummy command to showcase the use of chat_history
    acronym = {
      system_message_template = 'You are a helpful {{filetype}} \
      programming assistant that abbreviates identifiers and variables..',
      user_message_template = 'abbr \
      ```{{filetype}}\n{{text_selection}}```\n {{command_args}}',
      chat_history = {
        { role = 'user', content = 'abbreviate `configure_user_script`' },
        { role = 'assistant', content = 'c_u_s' },
        {
	  role = 'user',
	  content = 'abbr ```lua\nlocal = search_common_pattern = {}```\n'
	},
        { role = 'assistant', content = 'local = s_c_p = {}' },
      },
    },
```

# Callback Types

text_popup
: Displays the result in a text popup
window. 

code_popup
: Displays the results in a popup window
with the filetype set to the filetype
of the current buffer. 

replace_lines
: Replaces the current lines with the
response. If no text is selected, it
will insert the response at the cursor. 


insert_lines
: Inserts the response after the current
cursor line without replacing any
existing text. 


prepend_lines
: Inserts the response before the current
lines. If no text is selected, it will
insert the response at the beginning of
the buffer. 

# Mappings

The following default mappings are available inside a codegpt popup / window.
You can customize them using the {mappings} table.

\<C-c\> or q
: Cancel the current request

\<C-o\>
: Use popup buffer content as output to
replace the selected text when the
command was called.

\<C-i\>
: Use the popup content as input to a new
LLM request.


# Example Configuration

```lua
require("codegpt").setup({
  -- Connection settings for API providers
  connection = {
    api_provider = "openai",                -- Default API provider
    openai_api_key = vim.fn.getenv("OPENAI_API_KEY"),

   -- Default OpenAI endpoint
    chat_completions_url = "https://api.openai.com/v1/chat/completions",

    ollama_base_url = "http://localhost:11434",  -- Ollama base URL

    -- Can also be set with $http_proxy environment variable
    proxy = nil,                            

    -- Disable insecure connections by default
    allow_insecure = false,                 
  },

  -- UI configuration for popups
  ui = {
    stream_output = false,                  -- Disable streaming by default
    popup_border = {
      style = "rounded",
      padding = { 0, 1 }
    },  -- Default border style

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

	-- Custom string appended to the prompt
        append_string = '/no_think',		
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

  -- Clear visual selection when the command starts
  clear_visual_selection = true,            

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
      user_message_template = "I have the following {{language}} code: \
      ```{{filetype}}\n{{text_selection}}```\nModernize the above code. \
      Use current best practices. Only return the code snippet \
      and comments. {{language_instructions}}",

      language_instructions = {
        cpp = "Use modern C++ syntax. Use auto where possible. \
	Do not import std. Use trailing return type. \
	Use the c++11, c++14, c++17, and c++20 standards where applicable.",
      },
    }
  },

  -- Global defaults for all models
  global_defaults = {
    max_tokens = 4096,
    temperature = 0.7,
    number_of_choices = 1,
    system_message_template = "You are a {{language}} coding assistant.",
    user_message_template = "{{command}} {{command_args}}
	    ```{{language}}\n{{text_selection}}\n```\n",
    callback_type = "replace_lines",
    allow_empty_text_selection = false,
    extra_params = {},
    max_output_tokens = nil,
  },
})

```

# Lua API

* `setup({config})`: Setup the plugin with configuration options.
* `select_model()`: List local defined and remote available models for selection.
* `cancel_request()`: Cancel an ongoing request or job.
* `stream_on()`: Enable streaming output for responses.
* `stream_off()`: Disable streaming output for responses.
* `debug_prompt()`: Toggle debug prompt feature to aid
in debugging or development.

# License

Copyright (c) 2025 - Chakib Benziane <contact@blob42.xyz>

This project is licensed under the terms of the AGPL3 license.

A copy of the license is distributed with the source code of this project.


<!-- panvimdoc-ignore-start -->

# Credit

Darby Payne (@dpayne) <darby.payne@gmail.com> the original creator. 

And all contributors

<!-- panvimdoc-ignore-end -->

---
[1]:https://neovim.io/doc/user/cmdline.html#_4.-ex-command-line-ranges
