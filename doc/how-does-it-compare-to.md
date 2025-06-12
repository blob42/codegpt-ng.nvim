
## Rationale

There are dozens of vim/neovim AI plugins, but I've always favored the minimalist design and efficient workflow of the original `CodeGPT.nvim` plugin. When I noticed the project was no longer actively maintained, I began patching it to meet my needs. Eventually, I decided to fork the project and clean up the codebase, adding documentation for new features in hopes of helping others who value simplicity and speed.

My workflow is heavily focused on Ollama, so most testing has been done with the Ollama API and OpenAI-compatible endpoints. Contributions are always welcome.

## How Does It Compare To X

The goal of `codegpt-ng` is not to outperform other plugins or replicate the functionality of tools like Copilot or Cursor. Instead, it prioritizes minimalism and seamless integration with Vim's native capabilities. Review the demos to see if this approach aligns with your coding style.

### Key Differentiators

- **Templates**: The standout feature of `codegpt-ng` is its powerful [template system](../README.md#templates), enabling users to define custom commands quickly without writing Lua code.

---

### CodeCompanion

CodeCompanion aims to deliver a full AI-first development experience akin to Cursor, offering a wide array of features. While this may suit some users, I find many of these features unnecessary or easily achievable on `codegpt-ng` with minimal overhead and cognitive load. For developers who prefer lightweight tools with high customizability, `codegpt-ng` is a better fit.

---

### Ollama.nvim

- **Recommended for**: Users seeking an Ollama management interface alongside AI capabilities.
- **codegpt-ng's Advantage**: Full Ollama compatibility with the flexibility to switch models, define custom configurations, and tailor parameter mixes for specific commands or use cases—all without requiring additional plugins or complex setups.
