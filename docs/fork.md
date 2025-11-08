## About this fork 

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
- And many more features 

Although this fork introduces breaking changes and a substantial rewrite, I've tried to preserve the original project's minimalist spirit — a tool that connects to AI APIs without getting in the way. The goal remains to provide simple, code-focused interactions that stay lightweight and unobtrusive, letting developers leverage LLMs while maintaining control over their workflow.

In particular, the model definition flow was carefully designed to quickly add custom model profiles for specific cases and easily switch between them or assign them to custom commands.
