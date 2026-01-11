-- Civ5 MCP JSON Encoder
-- Simple JSON encoding for game state export

Civ5MCP = Civ5MCP or {}
Civ5MCP.JSON = {}

-- Simple JSON encoder
function Civ5MCP.JSON.encode(val)
    local function escape(s)
        return s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
    end

    local function encodeTable(t, indent)
        local s = "{\n"
        local first = true
        indent = indent or ""
        local newIndent = indent .. "  "

        for k, v in pairs(t) do
            if not first then s = s .. ",\n" end
            first = false
            s = s .. newIndent .. '"' .. tostring(k) .. '": '

            if type(v) == "table" then
                if next(v) == nil then
                    s = s .. "[]"
                elseif type(next(v)) == "number" then
                    -- Array
                    s = s .. "["
                    local arrFirst = true
                    for _i, item in ipairs(v) do
                        if not arrFirst then s = s .. ", " end
                        arrFirst = false
                        if type(item) == "table" then
                            s = s .. "\n" .. newIndent .. "  " .. encodeTable(item, newIndent .. "  ")
                        elseif type(item) == "string" then
                            s = s .. '"' .. escape(item) .. '"'
                        else
                            s = s .. tostring(item)
                        end
                    end
                    s = s .. "\n" .. newIndent .. "]"
                else
                    s = s .. encodeTable(v, newIndent)
                end
            elseif type(v) == "string" then
                s = s .. '"' .. escape(v) .. '"'
            elseif type(v) == "boolean" then
                s = s .. tostring(v)
            elseif type(v) == "number" then
                s = s .. tostring(v)
            elseif v == nil then
                s = s .. "null"
            else
                s = s .. '"' .. escape(tostring(v)) .. '"'
            end
        end

        s = s .. "\n" .. indent .. "}"
        return s
    end

    return encodeTable(val)
end
