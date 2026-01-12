# Civ 5 MCP

Connect your Civ 5 game to an agent using MCP. This mod creates an IPC channel
between your game session and an exposes the context in format that can be
consumed by your agent.

The spirit of this mod is to provide access only to what a human player would
reasonable know. For example, we try to not leak the location of wonders or
unmet players. The scope of the context is focused on making a super-advisor
to help you get better at this game.

The project is composed of two pieces. The game mod, aka the Bridge, and the
MCP server. You must use both in order to to use this mod.

> [!NOTE]
> This has only been tested on Brave New World on Windows.

## Trying this out

1. Download the latest release and unzip the contents to your MODS directory.
Typically this is 
`%USERPROFILE%\Documents\My Games\Sid Meier's Civilization 5\MODS`.
  - The directory should look like
```
MODS/
  Civ5MCP_Bridge (v VERSION)/
      Civ5MCP_Bridge.modinfo
      ... a bunch of .lua files ...
```
2. Launch your game
3. Selects MODS
4. Check the little button to enable this mod
5. Configure your game
6. Configure your agent to run `server/civ5_mcp_server.py`
7. Enjoy

## Development

### Build

The modinfo and constants file are generated at build time. `mod_config.json`
describes the mod and files that will be exported in the format Civ 5 expects.

```
# All targets have a docker- variant, e.g. make docker-lint

# Get nagged
make lint

# Run unit tests
make test

# Produces a directory that Civ 5 can read
make build

# Optional: automatically deploy to your Civ 5 MODS folder
./tools/deploy.ps1
```

### Versioning

The lua rockspec and Civ version formats are different. Civ wants to see a
string without any dots or dashes. Therefore, the Civ version will strip off
the revision and concat the major.minor into `major * 10 + minor`.

## Bridge

Game state is at the start of each turn and written to a SQLite database. Each
new game is stored as a new session. The session and turn number are used as the
state's id. Turn history and the initial game configuration are stored using
this session id. The schemas are as follows:

```
-- Schema version: 2026-01-10
CREATE TABLE MCP_GameHistory (
    session_id TEXT,
    turn INTEGER,
    data TEXT NOT NULL,
    timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (session_id, turn)
);

CREATE TABLEMCP_GameConfiguration (
    session_id TEXT PRIMARY KEY,
    data TEXT NOT NULL
);
```

> [!WARNING]
> The `data` field is a JSON blob that is considered unstable!

The bridge runs in a Lua 5.1.4 sandboxed with a very limited API. The game
exposes [this API][Civ5LuaAPI] and that's about all we can use.


## Running the Server

```
cd server

# Test that the server can be launched
uv run civ5_mcp_server.py
```

If you don't see any errors, you can add this server to something like Claude
using a config similar to this. If uv fails to launch, try using `uv`'s venv
python binary directly.

```
{
  "mcpServers": {
    "civ5": {
      "command": "uv",
      "args": ["run", "path/to/civ5_mcp_server.py"],
    }
  }
}
```

[Civ5LuaAPI]: https://modiki.civfanatics.com/index.php/Lua_and_UI_Reference_(Civ5)
