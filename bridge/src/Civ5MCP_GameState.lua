-- Civ5 MCP Game State Reader
-- Reads current game state from Civ5 API
-- The golden rule to remember is to not provide oracles into hidden information.
-- Only provide information that the human player would reasonably know.

include("MapUtilities")

Civ5MCP = Civ5MCP or {}

-- Get all plots within a city's borders
-- Reads current game state from Civ5 API

Civ5MCP = Civ5MCP or {}

-- Get plots for a city
function Civ5MCP.GetCityPlots(city, playerID)
    local plots = {}
    local tilesOwned = 0
    local tilesWorked = 0

    -- Cities can work tiles within 3 hexes
    for i = 0, city:GetNumCityPlots() - 1 do
        local plot = city:GetCityIndexPlot(i)
        if plot and plot:GetOwner() == playerID then
            tilesOwned = tilesOwned + 1

            local isWorked = city:IsWorkingPlot(plot)
            if isWorked then
                tilesWorked = tilesWorked + 1
            end

            local plotData = {
                x = plot:GetX(),
                y = plot:GetY(),
                isWorked = isWorked,
                yields = {
                    food = plot:CalculateYield(YieldTypes.YIELD_FOOD, true),
                    production = plot:CalculateYield(YieldTypes.YIELD_PRODUCTION, true),
                    gold = plot:CalculateYield(YieldTypes.YIELD_GOLD, true),
                    science = plot:CalculateYield(YieldTypes.YIELD_SCIENCE, true),
                    culture = plot:CalculateYield(YieldTypes.YIELD_CULTURE, true),
                    faith = plot:CalculateYield(YieldTypes.YIELD_FAITH, true)
                },
                terrain = GameInfo.Terrains[plot:GetTerrainType()].Type,
                feature = plot:GetFeatureType() >= 0 and GameInfo.Features[plot:GetFeatureType()].Type or nil,
                improvement = plot:GetImprovementType() >= 0 and GameInfo.Improvements[plot:GetImprovementType()].Type or
                    nil,
                resource = plot:GetResourceType() >= 0 and GameInfo.Resources[plot:GetResourceType()].Type or nil,
                resourceType = plot:GetResourceType() >= 0 and
                    GameInfo.Resources[plot:GetResourceType()].ResourceClassType or nil

            }
            table.insert(plots, plotData)
        end
    end

    return plots, tilesOwned, tilesWorked
end

-- Get all cities for a player
function Civ5MCP.GetCitiesByPlayer(playerID)
    local player = Players[playerID]
    if not player then return {} end

    local cities = {}

    for city in player:Cities() do
        local plots, plotsOwned, plotsWorked = Civ5MCP.GetCityPlots(city, playerID)

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
            -- TODO: this function will crash when starting from non-ancient era
            greatPeopleProgress = {
                rate = city:GetGreatPeopleRate(),
                turnsUntilNext = city:GetGreatPeopleRate() > 0 and
                    math.ceil((player:GetGreatPeopleThresholdModifier() - city:GetGreatPeopleProgress()) /
                        city:GetGreatPeopleRate()) or -1
            },

            -- Location
            x = city:GetX(),
            y = city:GetY(),

            -- TODO: Plots
            -- Consider an isOverlapped flag if tile _could_ be worked by another city
            plotOwned = plotsOwned,
            plotsWorked = plotsWorked,
            unemployedCitizens = math.max(0, city:GetPopulation() - plotsWorked - city:GetSpecialistCount()),
            plots = plots
        }

        table.insert(cities, cityData)
    end

    return cities
end

-- Get global player info (as opposed to city-specific)
function Civ5MCP.GetInfoByPlayer(playerID)
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

-- Get tech info by player
function Civ5MCP.GetTechInfoByPlayer(playerID)
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
            techs.turnsUntilComplete = player:GetResearchTurnsLeft(currentTech, true)
        end
    end

    return techs
end

-- TODO: Get city-state quests
function Civ5MCP.GetCityStateQuests(_playerID)
    -- City-state quests may not be accessible from InGameUIAddin context
    -- Return empty array for now
    return {}
end

-- TODO: Get opponents info
function Civ5MCP.GetOpponents()
    -- Not implemented yet
    -- A list of opponent players _currently known to the human player_
    -- name, civilization, relationship status, war/peace status, etc.
    return {}
end

-- Return game difficulty as string
function Civ5MCP.GetGameDifficulty()
    local diffInfo = GameInfo.HandicapInfos[Players[Game.GetActivePlayer()]:GetHandicapType()]
    return Locale.ConvertTextKey(diffInfo.Description)
end

-- Return game speed as string
function Civ5MCP.GetGameSpeed()
    local speedInfo = GameInfo.GameSpeeds[PreGame.GetGameSpeed()]
    return Locale.ConvertTextKey(speedInfo.Description)
end

-- Return map name as string
function Civ5MCP.GetMapName()
    local mapScript = PreGame.GetMapScript()
    local mapInfo = MapUtilities.GetBasicInfo(mapScript)
    return Locale.Lookup(mapInfo.Name)
end

-- Return map size as string
function Civ5MCP.GetMapSize()
    local worldInfo = GameInfo.Worlds[PreGame.GetWorldSize()]
    return Locale.ConvertTextKey(worldInfo.Description)
end

-- Return number of major civilizations in the game
function Civ5MCP.GetMajorCivCount()
    local count = 0
    for playerID = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
        local pPlayer = Players[playerID]
        if pPlayer and pPlayer:IsAlive() then
            count = count + 1
        end
    end
    return count
end

-- Return number of minor civilizations (city-states) in the game
function Civ5MCP.GetMinorCivCount()
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
        player = Civ5MCP.GetInfoByPlayer(playerID),
        cities = Civ5MCP.GetCitiesByPlayer(playerID),
        tech = Civ5MCP.GetTechInfoByPlayer(playerID),
        cityStateQuests = Civ5MCP.GetCityStateQuests(playerID),
        opponents = Civ5MCP.GetOpponents(),
        exportTime = os.date("%Y-%m-%d %H:%M:%S")
    }
end

-- Get game setup info. This is slow to call; use sparingly.
function Civ5MCP.GetGameConfiguration(playerID)
    local player = Players[playerID]
    if not player then return {} end

    return {
        name = player:GetName(),
        civilization = player:GetCivilizationShortDescription(),
        difficulty = Civ5MCP.GetGameDifficulty(),
        gameSpeed = Civ5MCP.GetGameSpeed(),
        mapName = Civ5MCP.GetMapName(),
        mapSize = Civ5MCP.GetMapSize(),
        majorCivCount = Civ5MCP.GetMajorCivCount(),
        minorCivCount = Civ5MCP.GetMinorCivCount()
    }
end
