-- Busted specs for Civ5MCP.JSON.encode

package.path = package.path .. ";./src/?.lua"
require("Civ5MCP_Json")
local encode = Civ5MCP.JSON.encode

describe("Civ5MCP.JSON.encode", function()
    it("encodes simple table with numbers and strings", function()
        local t = { a = 1, b = "x" }
        local out = encode(t)
        assert.is_not_nil(out:find('"a": 1', 1, true))
        assert.is_not_nil(out:find('"b": "x"', 1, true))
        assert.is_true(out:sub(1, 1) == "{")
    end)

    it("encodes nested tables and represents empty table as []", function()
        local t = { player = { name = "Alice", score = 10 }, empty = {} }
        local out = encode(t)
        -- nested object for player
        assert.is_not_nil(out:find('"player":', 1, true))
        assert.is_not_nil(out:find('"name": "Alice"', 1, true))
        -- empty nested table should be represented as [] by the encoder
        assert.is_not_nil(out:find('"empty": []', 1, true))
    end)

    it("escapes quotes, backslashes and newlines in strings", function()
        local t = { s = 'a"b\\c\n' }
        local out = encode(t)
        assert.is_not_nil(out:find('"a\\\"b\\\\c\\n"', 1, true))
    end)

    it("encodes arrays with mixed types", function()
        local t = { list = { "one", "two", 3 } }
        local out = encode(t)
        assert.is_not_nil(out:find('"list": [', 1, true))
        assert.is_not_nil(out:find('"one"', 1, true))
        assert.is_not_nil(out:find('"two"', 1, true))
        assert.is_not_nil(out:find('3', 1, true))
    end)
end)
