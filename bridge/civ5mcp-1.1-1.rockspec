package = "Civ5MCP"
version = "1.1-1"
rockspec_format = "3.0"

source = {
  url = ""
}

description = {
  summary = "Civ5MCP Bridge modules",
  detailed = "Lua modules providing the Civ5 MCP bridge functionality.",
  license = "MIT"
}

dependencies = {
  "lua = 5.1",
  "busted >= 2.0-0"
}

test = {
  type = "busted",
}