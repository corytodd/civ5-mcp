std = "min"

-- Civ5 API globals
globals = {
    -- Game state
    "Game",
    "Players",
    "Teams",
    "GameInfo",
    "GameDefines",
    "Locale",
    "PreGame",
    "MapUtilities",
    "Map",

    -- Enums
    "YieldTypes",
    "MinorCivQuestTypes",

    -- Events
    "Events",
    "GameEvents",

    -- Modding API
    "Modding",

    -- Utilities
    "include",
    "print",

    -- Our module (set as read-write)
    "Civ5MCP",

    -- Constants (from generated file)
    "CIV5MCP_MOD_ID",
    "CIV5MCP_MOD_NAME",
    "CIV5MCP_MOD_GAME_RULES",
}

-- Allow unused arguments prefixed with underscore
unused_args = false
self = false
