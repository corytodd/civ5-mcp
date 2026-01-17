-- Civ5 MCP Bridge
-- Main entry point for MCP game state exporter

include("Civ5MCP_Constants.lua")
include("Civ5MCP_Json.lua")
include("Civ5MCP_GameState.lua")
include("Civ5MCP_GameRules.lua")

Civ5MCP = Civ5MCP or {}

local g_UserData = nil
local g_SessionID = nil

-- Load session id from game save or return a unique session ID if not found
local function GetSessionID()
    local keySessionId = "Civ5MCP_session_id"
    local saveData = Modding.OpenSaveData()
    if not saveData then
        print("MCP: Unable to open save data for session ID retrieval")
        return nil
    end

    local sessionID = saveData.GetValue(keySessionId)

    if sessionID then
        sessionID = tostring(sessionID)
        print("MCP: Retrieved session ID from save data:", sessionID)
    else
        -- Create a new session ID based on player name and start turn
        local player = Players[Game.GetActivePlayer()]
        local playerName = player and player:GetName() or "Unknown"
        local timestamp = os.date("%Y%m%d_%H%M%S")

        sessionID = string.format("%s_%s", timestamp, playerName:gsub("%s+", "_"))
        saveData.SetValue(keySessionId, sessionID)
        print("MCP: Generated new session ID:", sessionID)
    end
    return sessionID
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
        CREATE TABLE IF NOT EXISTS MCP_GameRules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rule_text TEXT NOT NULL
        );
    ]]) do end

    g_SessionID = GetSessionID()

    print(string.format("MCP: Database initialized"))
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
    ]], escapedSessionID, escapedJson)

    for _ in g_UserData.Query(insertMetaQuery) do end

    print(string.format("MCP: Game setup saved for session ID: %s", g_SessionID))
end

local function SaveGameRules()
    if not g_UserData then
        InitializeDatabase()
        assert(g_UserData, "Failed to initialize MCP database")
    end

    -- This is a one time save; clear existing rules first
    for _ in g_UserData.Query("DELETE FROM MCP_GameRules;") do end
    local escapedRules = MOD_GAME_RULES:gsub("'", "''")
    local insertRulesQuery = string.format([[
        INSERT INTO MCP_GameRules(rule_text)
        VALUES('%s');
    ]], escapedRules)
    for _ in g_UserData.Query(insertRulesQuery) do end

    print("MCP: Game rules saved to database")
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

    ExportGameState()
    SaveGameConfiguration()
    SaveGameRules()
    print("MCP: Game State Bridge loaded successfully!", os.clock())
end)

print("MCP: Bridge initialized")
