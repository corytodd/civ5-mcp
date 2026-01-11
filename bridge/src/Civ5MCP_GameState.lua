-- Civ5 MCP Game State Reader
-- Reads current game state from Civ5 API

include("MapUtilities")

Civ5MCP = Civ5MCP or {}

-- Get visible cities for a player
function Civ5MCP.GetVisibleCities(playerID)
    local player = Players[playerID]
    if not player then return {} end

    local cities = {}

    for city in player:Cities() do
        local cityData = {
            name = city:GetName(),
            population = city:GetPopulation(),
            turnsUntilGrowth = city:GetFoodTurnsLeft(),
            isGrowing = city:GetFoodTurnsLeft() > 0,
            isStarving = city:FoodDifference() < 0,

            -- Yields
            yields = {
                food = math.floor(city:GetYieldRate(YieldTypes.YIELD_FOOD) * 100) / 100,
                production = math.floor(city:GetYieldRate(YieldTypes.YIELD_PRODUCTION) * 100) / 100,
                gold = math.floor(city:GetYieldRate(YieldTypes.YIELD_GOLD) * 100) / 100,
                science = math.floor(city:GetYieldRate(YieldTypes.YIELD_SCIENCE) * 100) / 100,
                culture = math.floor(city:GetYieldRate(YieldTypes.YIELD_CULTURE) * 100) / 100,
                faith = math.floor(city:GetYieldRate(YieldTypes.YIELD_FAITH) * 100) / 100
            },

            -- Production
            currentProduction = city:GetProductionNameKey() or "None",
            productionTurnsLeft = city:GetProductionTurnsLeft(),

            -- Specialists
            totalSpecialists = city:GetSpecialistCount(),

            -- Great People progress
            greatPeopleProgress = {
                rate = city:GetGreatPeopleRate(),
                turnsUntilNext = city:GetGreatPeopleRate() > 0 and
                    math.ceil((player:GetGreatPeopleThresholdModifier() - city:GetGreatPeopleProgress()) /
                        city:GetGreatPeopleRate()) or -1
            },

            -- Location
            x = city:GetX(),
            y = city:GetY()
        }

        table.insert(cities, cityData)
    end

    return cities
end

-- Get player info
function Civ5MCP.GetPlayerInfo(playerID)
    local player = Players[playerID]
    if not player then return {} end

    return {
        gold = player:GetGold(),
        goldPerTurn = player:CalculateGoldRate(),
        science = player:GetScience(),
        sciencePerTurn = player:GetScienceTimes100() / 100,
        culture = player:GetJONSCulture(),
        culturePerTurn = player:GetTotalJONSCulturePerTurn(),
        faith = player:GetFaith(),
        faithPerTurn = player:GetTotalFaithPerTurn(),
        happiness = player:GetExcessHappiness(),
        goldenAgeTurns = player:GetGoldenAgeTurns(),
        isGoldenAge = player:IsGoldenAge(),
        goldenAgePoints = player:GetGoldenAgeProgressMeter(),
        goldenAgePointsNeeded = player:GetGoldenAgeProgressThreshold(),
        unitCount = player:GetNumUnits(),
        cityCount = player:GetNumCities(),
        militaryStrength = player:GetMilitaryMight(),
        score = player:GetScore()
    }
end

-- Get tech info
function Civ5MCP.GetTechInfo(playerID)
    local player = Players[playerID]
    if not player then return {} end

    local team = Teams[player:GetTeam()]
    local techs = {
        researched = {},
        currentResearch = nil,
        turnsUntilComplete = 0
    }

    -- Get researched techs
    for tech in GameInfo.Technologies() do
        if team:IsHasTech(tech.ID) then
            table.insert(techs.researched, tech.Type)
        end
    end

    -- Current research
    local currentTech = player:GetCurrentResearch()
    if currentTech and currentTech >= 0 then
        local techInfo = GameInfo.Technologies[currentTech]
        if techInfo then
            techs.currentResearch = techInfo.Type
            techs.turnsUntilComplete = player:GetResearchTurnsLeft()
        end
    end

    return techs
end

-- Get city-state quests
function Civ5MCP.GetCityStateQuests(_playerID)
    -- City-state quests may not be accessible from InGameUIAddin context
    -- Return empty array for now
    return {}
end

-- Get opponents info
function Civ5MCP.GetOpponents()
    -- Not implemented yet
    -- A list of opponent players
    -- name, civilization, relationship status, war/peace status, etc.
    return {}
end

function GetGameDifficulty()
    local diffInfo = GameInfo.HandicapInfos[Players[Game.GetActivePlayer()]:GetHandicapType()]
    return Locale.ConvertTextKey(diffInfo.Description)
end

function GetGameSpeed()
    local speedInfo = GameInfo.GameSpeeds[PreGame.GetGameSpeed()]
    return Locale.ConvertTextKey(speedInfo.Description)
end

function GetMapName()
    local mapScript = PreGame.GetMapScript()
    local mapInfo = MapUtilities.GetBasicInfo(mapScript)
    return Locale.Lookup(mapInfo.Name)
end

function GetMapSize()
    local worldInfo = GameInfo.Worlds[PreGame.GetWorldSize()]
    return Locale.ConvertTextKey(worldInfo.Description)
end

function GetMajorCivCount()
    local count = 0
    for playerID = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
        local pPlayer = Players[playerID]
        if pPlayer and pPlayer:IsAlive() then
            count = count + 1
        end
    end
    return count
end

function GetMinorCivCount()
    local count = 0
    for playerID = GameDefines.MAX_MAJOR_CIVS, GameDefines.MAX_PLAYERS - 1 do
        local pPlayer = Players[playerID]
        if pPlayer and pPlayer:IsMinorCiv() then
            count = count + 1
        end
    end
    return count
end

-- Main function to get complete game state
function Civ5MCP.GetGameState(playerID)
    return {
        turn = Game.GetGameTurn(),
        player = Civ5MCP.GetPlayerInfo(playerID),
        cities = Civ5MCP.GetVisibleCities(playerID),
        tech = Civ5MCP.GetTechInfo(playerID),
        cityStateQuests = Civ5MCP.GetCityStateQuests(playerID),
        opponents = Civ5MCP.GetOpponents(),
        exportTime = os.date("%Y-%m-%d %H:%M:%S")
    }
end

-- Get game setup info
function Civ5MCP.GetGameConfiguration(playerID)
    local player = Players[playerID]
    if not player then return {} end

    return {
        name = player:GetName(),
        civilization = player:GetCivilizationShortDescription(),
        difficulty = GetGameDifficulty(),
        gameSpeed = GetGameSpeed(),
        mapName = GetMapName(),
        mapSize = GetMapSize(),
        majorCivCount = GetMajorCivCount(),
        minorCivCount = GetMinorCivCount()
    }
end
