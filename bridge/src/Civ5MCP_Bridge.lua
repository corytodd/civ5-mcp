-- Civ5 MCP Bridge
-- Main entry point for MCP game state exporter

include("Civ5MCP_Constants.lua")
include("Civ5MCP_Json.lua")
include("Civ5MCP_GameState.lua")

Civ5MCP = Civ5MCP or {}

local g_UserData = nil
local g_SessionID = nil

-- Generate a unique session ID for this game
local function GenerateSessionID()
    local player = Players[Game.GetActivePlayer()]
    local playerName = player and player:GetName() or "Unknown"
    local gameStartTurn = Game.GetStartTurn()
    local timestamp = os.date("%Y%m%d_%H%M%S")

    return string.format("%s_%s_T%d", timestamp, playerName:gsub("%s+", "_"), gameStartTurn)
end

-- Initialize database tables
local function InitializeDatabase()
    if g_UserData then
        return -- Already initialized
    end

    g_UserData = Modding.OpenUserData(MOD_NAME, Modding.GetActivatedModVersion(MOD_ID))

    for _ in g_UserData.Query([[
        CREATE TABLE IF NOT EXISTS MCP_GameHistory(
            session_id TEXT,
            turn INTEGER,
            data TEXT NOT NULL,
            timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (session_id, turn)
        );
    ]]) do end

    for _ in g_UserData.Query([[
        CREATE TABLE IF NOT EXISTS MCP_GameConfiguration (
            session_id TEXT PRIMARY KEY,
            data TEXT NOT NULL
        );
    ]]) do end

    for _ in g_UserData.Query([[
        CREATE VIEW current_game_state AS
        SELECT
            session_id,
            turn,
            data,
            timestamp
        FROM MCP_GameHistory
        ORDER BY timestamp DESC
        LIMIT 1;
    ]]) do end

    g_SessionID = GenerateSessionID()

    print(string.format("MCP: Database initialized with session ID: %s", g_SessionID))
end

local function SaveGameConfiguration()
    local playerID = Game.GetActivePlayer()
    if playerID == -1 then return end

    if not g_UserData then
        InitializeDatabase()
        assert(g_UserData, "Failed to initialize MCP database")
    end

    local gameMeta = Civ5MCP.GetGameConfiguration(playerID)
    local jsonString = Civ5MCP.JSON.encode(gameMeta)
    local escapedJson = jsonString:gsub("'", "''")
    local escapedSessionID = tostring(g_SessionID):gsub("'", "''")
    local insertMetaQuery = string.format([[
        INSERT INTO MCP_GameConfiguration(session_id, data)
        VALUES('%s', '%s');
    ]], escapedSessionID:gsub("'", "''"), escapedJson)

    for _ in g_UserData.Query(insertMetaQuery) do end

    print(string.format("MCP: Game setup saved for session ID: %s", g_SessionID))
end

-- Main export function
local function ExportGameState()
    local playerID = Game.GetActivePlayer()
    if playerID == -1 then return end

    if not g_UserData then
        InitializeDatabase()
        assert(g_UserData, "Failed to initialize MCP database")
    end

    print("MCP: Exporting game state...", os.clock())

    local gameState = Civ5MCP.GetGameState(playerID)
    local jsonString = Civ5MCP.JSON.encode(gameState)
    local turn = Game.GetGameTurn()

    -- Escape single quotes for SQL by doubling them
    local escapedJson = jsonString:gsub("'", "''")
    local escapedSessionID = tostring(g_SessionID):gsub("'", "''")

    local insertQuery = string.format(
        "INSERT INTO MCP_GameHistory(session_id, turn, data) VALUES('%s', %d, '%s')",
        escapedSessionID, turn, escapedJson)

    local success, err = pcall(function()
        for _ in g_UserData.Query(insertQuery) do end
    end)

    if success then
        print(string.format("MCP: Game state exported for session %s, turn %d", g_SessionID, turn), os.clock())
    else
        print(string.format("MCP: Failed to export - %s", tostring(err)))
    end
end

-- Hook into player's (the human one) turn
GameEvents.PlayerDoTurn.Add(function(playerID)
    if playerID == Game.GetActivePlayer() then
        ExportGameState()
    end
end)

-- Hook into game initialization
Events.SequenceGameInitComplete.Add(function()
    print("Loading ", os.clock(), [[

   _____ _         _____   __  __  _____ _____
  / ____(_)       | ____| |  \/  |/ ____|  __ \
 | |     ___   __ | |__   | \  / | |    | |__) |
 | |    | \ \ / / |___ \  | |\/| | |    |  ___/
 | |____| |\ V /   ___) | | |  | | |____| |
  \_____|_| \_/   |____/  |_|  |_|\_____|_|
]])

    -- TODO: how to detect new game vs loaded game?
    ExportGameState()
    SaveGameConfiguration()
    print("MCP: Game State Bridge loaded successfully!", os.clock())
end)

print("MCP: Bridge initialized")
