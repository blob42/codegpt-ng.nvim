local codegpt = require("codegpt")
local config = require("codegpt.config")
local models = require("codegpt.models")

local function should_fail(fun)
	local stat = pcall(fun)
	assert(not stat, "Function should have errored")
end

describe("provider", function()
	it("should fail for incorrect providder", function()
		codegpt.setup({
			connection = {
				api_provider = "foo",
			},
		})
		should_fail(function()
			local providers = require("codegpt.providers")
			providers.get_provider()
		end)
	end)
	it("should pass for correct providder", function()
		codegpt.setup({
			connection = {
				api_provider = "openai",
			},
		})
		local providers = require("codegpt.providers")
		assert(providers.get_provider())
	end)
	it("should fail for wrong providder", function()
		codegpt.setup({
			connection = {
				api_provider = "foo",
			},
		})
		should_fail(function()
			local providers = require("codegpt.providers")
			assert(providers.get_provider())
		end)
	end)
end)

describe("models selection", function()
	before_each(function()
		config.model_override = nil
		codegpt.setup()
	end)

	it("should have a default model", function()
		local _, model = models.get_model()
		assert(model, "no default model")
		assert.is_table(model)
	end)

	it("should prioritize override", function()
		codegpt.setup({
			connection = {
				api_provider = "ollama",
			},
			models = {
				ollama = {
					foomodel = {
						alias = "llamaqwen",
					},
				},
			},
		})
		config.model_override = "foomodel"
		local name, model = models.get_model()
		assert(name == "foomodel")
		assert(vim.deep_equal(model, { alias = "llamaqwen" }))
	end)

	it("should prioritize provider default over global default", function()
		codegpt.setup({
			connection = {
				api_provider = "openai",
			},
			models = {
				openai = {
					default = "foomodel",
					foomodel = {
						alias = "llamaqwen",
					},
				},
			},
		})
		local name, model = models.get_model()
		assert(name == "foomodel")
		assert(vim.deep_equal(model, { alias = "llamaqwen" }))
	end)

	it("should handle global default", function()
		codegpt.setup({
			connection = {
				api_provider = "openai",
			},
			models = {
				openai = {
					default = "gpt4-o",
					["gpt4-o"] = {
						alias = "gpt4o",
					},
				},
			},
		})
		local name, model = models.get_model()
		assert(name == "gpt4-o")
		assert(vim.deep_equal(model, { alias = "gpt4o" }))
	end)

	describe("should get model by alias", function()
		before_each(function()
			codegpt.setup({
				connection = {
					api_provider = "openai",
				},
				models = {
					openai = {
						default = "gpt4-o",
						["gpt4-o"] = {
							alias = "gpt4o",
						},
						["gpt-foo"] = {
							alias = "foo",
						},
					},
				},
			})
		end)

		it("find model with alias", function()
			local name, model = models.get_model_by_alias("foo")
			assert(name == "gpt-foo")
		end)

		it("get nil if not found", function()
			local name, model = models.get_model_by_alias("bar")
			assert(name == "")
			assert(model == nil)
		end)

		should_fail(function()
			model.get_model_by_alias("")
		end)
	end)

	it("should get default model by alias", function()
		codegpt.setup({
			connection = {
				api_provider = "openai",
			},
			models = {
				openai = {
					default = "gpt4o",
					["gpt4-o"] = {
						alias = "gpt4o",
					},
				},
			},
		})

		local name, model = models.get_model()
		assert(name == "gpt4-o")
	end)

	it("should inherit a model definition", function()
		codegpt.setup({
			connection = {
				api_provider = "openai",
			},
			models = {
				openai = {
					default = "fbar",
					foo = {
						temperature = 0.5,
						max_tokens = 420,
					},
					foobar = {
						alias = "fbar",
						from = "foo",
						temperature = 1,
						append_string = "/no_think",
					},
					bar = {
						from = "fbar",
						temperature = 0,
					},
				},
			},
		})
		local _, model = models.get_model()
		assert(vim.deep_equal(model, {
			temperature = 1,
			alias = "fbar",
			from = "foo",
			max_tokens = 420,
			append_string = "/no_think",
		}))

		local name, model = models.get_model_by_name("fbar")
		assert(vim.deep_equal(model, {
			temperature = 1,
			alias = "fbar",
			from = "foo",
			max_tokens = 420,
			append_string = "/no_think",
		}))

		-- name of inherting model should take precedence
		assert(name == "foobar")

		local name, model = models.get_model_by_name("bar")
		assert(vim.deep_equal(model, {
			temperature = 0,
			alias = "fbar",
			from = "fbar",
			max_tokens = 420,
			append_string = "/no_think",
		}))
		assert(name == "bar")
	end)
end)
