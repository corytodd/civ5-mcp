#!/usr/bin/env python3
"""
Civ5 MCP Server
Exposes Civ 5 game state via Model Context Protocol
"""

import json
import sqlite3
import os
import subprocess
import tomllib
from pathlib import Path
from typing import Any, Optional
from mcp.server.models import InitializationOptions
from mcp.server import NotificationOptions, Server
from mcp.server.stdio import stdio_server
from mcp import types

# TODO: learn db version from mod config
# Path to Civ5 modding database
CIV5_DB_PATH = (
    Path.home()
    / "Documents"
    / "My Games"
    / "Sid Meier's Civilization 5"
    / "ModUserData"
    / "Civ5 MCP Bridge-12.db"
)

def _git_version_suffix() -> str:
    repo = Path(__file__).parent
    try:
        sha = subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=repo, stderr=subprocess.DEVNULL,
        ).decode().strip()
        dirty = subprocess.call(
            ["git", "diff", "--quiet"],
            cwd=repo, stderr=subprocess.DEVNULL,
        ) != 0
        return f"+{sha}{'dirty' if dirty else ''}"
    except Exception:
        return ""

_pyproject = tomllib.loads((Path(__file__).parent / "pyproject.toml").read_text())
SERVER_VERSION = _pyproject["project"]["version"] + _git_version_suffix()

# MCP Server instance
app = Server("civ5-mcp")


class Civ5GameStateDB:
    """Interface to Civ 5 game state database"""

    def __init__(self, db_path: Path):
        self.db_path = db_path

    def _connect(self) -> sqlite3.Connection:
        """Create database connection"""
        if not self.db_path.exists():
            raise FileNotFoundError(f"Database not found at {self.db_path}")
        return sqlite3.connect(str(self.db_path))

    def get_latest_session(self) -> Optional[str]:
        """Get the most recent session ID"""
        with self._connect() as conn:
            cursor = conn.execute(
                """
                SELECT session_id
                FROM MCP_GameHistory
                ORDER BY timestamp DESC
                LIMIT 1
            """
            )
            row = cursor.fetchone()
            return row[0] if row else None

    def get_current_state(self, session_id: Optional[str] = None) -> Optional[dict]:
        """Get the latest game state for a session"""
        if not session_id:
            session_id = self.get_latest_session()
            if not session_id:
                return None

        with self._connect() as conn:
            cursor = conn.execute(
                """
                SELECT data, turn, timestamp
                FROM MCP_GameHistory
                WHERE session_id = ?
                ORDER BY turn DESC
                LIMIT 1
            """,
                (session_id,),
            )
            row = cursor.fetchone()

            if not row:
                return None

            game_state = json.loads(row[0])
            game_state["_session_id"] = session_id
            game_state["_db_turn"] = row[1]
            game_state["_db_timestamp"] = row[2]
            return game_state

    def get_history(
        self, session_id: Optional[str] = None, limit: int = 100
    ) -> list[dict]:
        """Get game history for a session"""
        if not session_id:
            session_id = self.get_latest_session()
            if not session_id:
                return []

        with self._connect() as conn:
            cursor = conn.execute(
                """
                SELECT data, turn, timestamp
                FROM MCP_GameHistory
                WHERE session_id = ?
                ORDER BY turn DESC
                LIMIT ?
            """,
                (session_id, limit),
            )

            history = []
            for row in cursor.fetchall():
                state = json.loads(row[0])
                state["_session_id"] = session_id
                state["_db_turn"] = row[1]
                state["_db_timestamp"] = row[2]
                history.append(state)

            return history

    def list_sessions(self) -> list[dict]:
        """List all available game sessions"""
        with self._connect() as conn:
            cursor = conn.execute(
                """
                SELECT
                    session_id,
                    MIN(turn) as start_turn,
                    MAX(turn) as end_turn,
                    COUNT(*) as turn_count,
                    MAX(timestamp) as last_updated
                FROM MCP_GameHistory
                GROUP BY session_id
                ORDER BY last_updated DESC
            """
            )

            sessions = []
            for row in cursor.fetchall():
                sessions.append(
                    {
                        "session_id": row[0],
                        "start_turn": row[1],
                        "end_turn": row[2],
                        "turn_count": row[3],
                        "last_updated": row[4],
                    }
                )

            return sessions

    def get_turn_state(
        self, turn: int, session_id: Optional[str] = None
    ) -> Optional[dict]:
        """Get game state for a specific turn"""
        if not session_id:
            session_id = self.get_latest_session()
            if not session_id:
                return None

        with self._connect() as conn:
            cursor = conn.execute(
                """
                SELECT data, timestamp
                FROM MCP_GameHistory
                WHERE session_id = ? AND turn = ?
            """,
                (session_id, turn),
            )
            row = cursor.fetchone()

            if not row:
                return None

            game_state = json.loads(row[0])
            game_state["_session_id"] = session_id
            game_state["_db_turn"] = turn
            game_state["_db_timestamp"] = row[1]
            return game_state

    def get_game_configuration(
        self, session_id: Optional[str] = None
    ) -> Optional[dict]:
        """Get game configuration for a session"""
        if not session_id:
            session_id = self.get_latest_session()
            if not session_id:
                return None
        with self._connect() as conn:
            cursor = conn.execute(
                """
                SELECT data
                FROM MCP_GameConfiguration
                WHERE session_id = ?
                ORDER BY rowid DESC
                LIMIT 1
            """,
                (session_id,),
            )
            row = cursor.fetchone()
            if not row:
                return None
            return json.loads(row[0])

    def get_game_rules(self) -> Optional[dict]:
        """Get game rules"""
        with self._connect() as conn:
            cursor = conn.execute(
                """
                SELECT rule_text
                FROM MCP_GameRules
                LIMIT 1
            """
            )
            row = cursor.fetchone()
            if not row:
                return None
            return {"rules": [line for line in row[0].splitlines() if line.strip()]}


# Global database instance
db = Civ5GameStateDB(CIV5_DB_PATH)


_PROP_SESSION_ID = {
    "type": "string",
    "description": "Optional session ID. If not provided, uses the most recent session.",
}
_PROP_INCLUDE_ALL_PLOTS = {
    "type": "boolean",
    "description": "Include all map plots (caution: expensive). By default only worked, improved, or resource plots are returned.",
}


def _strip_nulls(obj):
    if isinstance(obj, dict):
        return {k: _strip_nulls(v) for k, v in obj.items() if v is not None and v is not False}
    if isinstance(obj, list):
        return [_strip_nulls(v) for v in obj]
    return obj


def _json_response(data) -> list[types.TextContent]:
    return [types.TextContent(type="text", text=json.dumps(_strip_nulls(data)))]


def _normalize_plots(state: dict, include_all: bool = False) -> dict:
    """Hoist all plot data into a shared top-level map keyed by 'x,y'.
    Cities and units reference plots by key. City plots are inserted first
    as they carry yields; unit visible plots fill in any unseen tiles."""
    shared: dict[str, dict] = {}

    for city in state.get("cities", []):
        filtered = []
        for p in city.pop("plots", []):
            if not include_all and not (p.get("isWorked") or p.get("resource") or p.get("improvement")):
                continue
            key = f"{p['x']},{p['y']}"
            shared[key] = {
                "terrain": p.get("terrain"),
                "feature": p.get("feature"),
                "improvement": p.get("improvement"),
                "resource": p.get("resource"),
                "resourceType": p.get("resourceType"),
                "yields": p.get("yields"),
            }
            filtered.append({"key": key, "isWorked": p.get("isWorked")})
        city["plots"] = filtered

    for unit in state.get("units", []):
        keys = []
        for p in unit.pop("visiblePlots", []):
            key = f"{p['x']},{p['y']}"
            if key not in shared:
                shared[key] = {
                    "terrain": p.get("terrain"),
                    "feature": p.get("feature"),
                    "improvement": p.get("improvement"),
                    "unitOnPlot": p.get("unitOnPlot"),
                    "owner": p.get("owner"),
                }
            keys.append(key)
        unit["visiblePlotKeys"] = keys

    state["visiblePlots"] = shared
    return state


@app.list_tools()
async def list_tools() -> list[types.Tool]:
    """List available MCP tools"""
    return [
        types.Tool(
            name="get_current_game_state",
            description="Get the current/latest game state from Civ 5",
            inputSchema={
                "type": "object",
                "properties": {
                    "session_id": _PROP_SESSION_ID,
                    "include_all_plots": _PROP_INCLUDE_ALL_PLOTS,
                },
            },
        ),
        types.Tool(
            name="get_game_history",
            description="Get historical game states for analysis and comparison",
            inputSchema={
                "type": "object",
                "properties": {
                    "session_id": _PROP_SESSION_ID,
                    "limit": {
                        "type": "number",
                        "description": "Maximum number of turns to retrieve (default: 10)",
                    },
                    "include_all_plots": _PROP_INCLUDE_ALL_PLOTS,
                },
            },
        ),
        types.Tool(
            name="list_game_sessions",
            description="List all available game sessions with metadata",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="get_turn_state",
            description="Get game state for a specific turn number",
            inputSchema={
                "type": "object",
                "properties": {
                    "turn": {
                        "type": "number",
                        "description": "Turn number to retrieve",
                    },
                    "session_id": _PROP_SESSION_ID,
                    "include_all_plots": _PROP_INCLUDE_ALL_PLOTS,
                },
                "required": ["turn"],
            },
        ),
        types.Tool(
            name="get_game_configuration",
            description="Get the game configuration and setup information",
            inputSchema={
                "type": "object",
                "properties": {
                    "session_id": _PROP_SESSION_ID,
                },
            },
        ),
        types.Tool(
            name="get_game_rules",
            description="Get the game rules to give context",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="get_server_info",
            description="Get the MCP server version and database path",
            inputSchema={"type": "object", "properties": {}},
        ),
    ]


@app.call_tool()
async def call_tool(name: str, arguments: Any) -> list[types.TextContent]:
    """Handle tool calls"""

    try:
        if name == "get_current_game_state":
            session_id = arguments.get("session_id")
            state = db.get_current_state(session_id)

            if not state:
                return [
                    types.TextContent(
                        type="text",
                        text="No game state found. Make sure Civ 5 is running with the MCP mod enabled.",
                    )
                ]

            return _json_response(_normalize_plots(state, arguments.get("include_all_plots", False)))

        elif name == "get_game_history":
            session_id = arguments.get("session_id")
            limit = arguments.get("limit", 10)
            history = db.get_history(session_id, limit)

            if not history:
                return [types.TextContent(type="text", text="No game history found.")]

            include_all = arguments.get("include_all_plots", False)
            return _json_response([_normalize_plots(s, include_all) for s in history])

        elif name == "list_game_sessions":
            sessions = db.list_sessions()

            if not sessions:
                return [types.TextContent(type="text", text="No game sessions found.")]

            return _json_response(sessions)

        elif name == "get_turn_state":
            turn = arguments["turn"]
            session_id = arguments.get("session_id")
            state = db.get_turn_state(turn, session_id)

            if not state:
                return [
                    types.TextContent(
                        type="text", text=f"No state found for turn {turn}"
                    )
                ]

            return _json_response(_normalize_plots(state, arguments.get("include_all_plots", False)))

        elif name == "get_game_configuration":
            session_id = arguments.get("session_id")
            config = db.get_game_configuration(session_id)

            if not config:
                return [
                    types.TextContent(
                        type="text",
                        text="No game configuration found. Make sure Civ 5 is running with the MCP mod enabled.",
                    )
                ]

            return _json_response(config)

        elif name == "get_game_rules":
            rules = db.get_game_rules()
            if not rules:
                return [
                    types.TextContent(
                        type="text",
                        text="No game rules found. Make sure Civ 5 is running with the MCP mod enabled.",
                    )
                ]

            return _json_response(rules)

        elif name == "get_server_info":
            return _json_response({
                "server_version": SERVER_VERSION,
                "db_path": str(CIV5_DB_PATH),
                "db_exists": CIV5_DB_PATH.exists(),
            })

        else:
            return [types.TextContent(type="text", text=f"Unknown tool: {name}")]

    except Exception as e:
        return [types.TextContent(type="text", text=f"Error: {str(e)}")]


async def main():
    """Run the MCP server"""
    async with stdio_server() as (read_stream, write_stream):
        await app.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="civ5-mcp",
                server_version=SERVER_VERSION,
                capabilities=app.get_capabilities(
                    notification_options=NotificationOptions(),
                    experimental_capabilities={},
                ),
            ),
        )


if __name__ == "__main__":
    import asyncio

    asyncio.run(main())
