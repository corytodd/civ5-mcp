std = "min"

-- Civ5 API globals
globals = {
    -- Game state
    "Game",
    "Players",
    "Teams",
    "GameInfo",
    "GameDefines",

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
    "MOD_ID",
    "MOD_NAME"
}

-- Allow unused arguments prefixed with underscore
unused_args = false
self = false