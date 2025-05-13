local utils = require("codegpt.utils")

describe("parsing llm response", function()
	it("should extract code from reasoning", function()
		local input = [[
<think>
Okay, the user is asking how to get the first element of an array in Lua, and they just want the code. Let me think.

In Lua, arrays are actually tables. So, if they have a table, say myTable, the first element is at index 1. So, the code would be myTable[1]. But I should make sure to mention that Lua uses 1-based indexing. Also, maybe they need to check if the table is not empty. But the user didn't mention handling empty tables, so maybe just the straightforward code. Let me confirm the syntax. Yes, table indexing starts at 1. So the answer is simply accessing the first index. I should provide that as the code example.
</think>

```lua
local firstElement = myTable[1]
```
]]
		local expected = "local firstElement = myTable[1]"

		local stripped = utils.trim_to_code_block(vim.split(input, "\n"))
		assert.equals(expected, vim.fn.join(stripped, "\n"))
	end)

	it("should strip reasoning", function()
		local input = [[
<think>
Okay, the user is asking how to get the first element of an array in Lua, and they just want the code. Let me think.

In Lua, arrays are actually tables. So, if they have a table, say myTable, the first element is at index 1. So, the code would be myTable[1]. But I should make sure to mention that Lua uses 1-based indexing. Also, maybe they need to check if the table is not empty. But the user didn't mention handling empty tables, so maybe just the straightforward code. Let me confirm the syntax. Yes, table indexing starts at 1. So the answer is simply accessing the first index. I should provide that as the code example.
</think>

```lua
local firstElement = myTable[1]
```
]]
		local expected = [[
```lua
local firstElement = myTable[1]
```
]]

		local stripped = utils.strip_reasoning(vim.split(input, "\n"), "<think>", "</think>")
		assert(vim.deep_equal(vim.split(expected, "\n"), stripped))
	end)
end)
