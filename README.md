# Civ 5 MCP

## Bridge

Game state is at the end of each turn and written to a SQLite database. Each
new game is stored as a new session. The session and turn number are used as the
state's id. The schema is as follows:

```
-- Schema version: 2026-01-10
CREATE TABLE MCP_GameHistory (
    session_id TEXT,
    turn INTEGER,
    data TEXT NOT NULL,
    timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (session_id, turn)
);
```

> [!WARNING]
> The `data` field is a JSON blob that is considered unstable!

The bridge runs in a Lua 5.1.4 sandboxed with a very limited API. The game
exposes [this API][Civ5LuaAPI] and that's about all we can use.

## Build

The modinfo and constants file are generated at build time. `mod_config.json`
describes the mod and files that will be exported in the format Civ 5 expects.

```
# Produces a directory that Civ 5 can read
python3 ./tools/build.py

# Optional: automatically deploy to your Civ 5 MODS folder
./tools/deploy.ps1
```

[Civ5LuaAPI]: https://modiki.civfanatics.com/index.php/Lua_and_UI_Reference_(Civ5)