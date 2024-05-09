--
-- Server version of W
--

W = {}

exports("Get", function()
    return W
end)


local Players = {}
local PlayerSources = {}

function W.GetPlayerSourceCoords()
    local coordMap = {}

    for name, player in pairs(Players) do

        if PlayerSources[name] ~= nil then
            local coord = vector3(player.position[1], player.position[2], player.position[3])
            local source = PlayerSources[name]
            coordMap[source] = coord
        end
    end

    return coordMap
end


-- Makes sure all player entries have appropriate properties read or created with default values
local function ValidatePlayerProps(playerEntry)
    if playerEntry["money"] == nil then
        playerEntry["money"] = 0.0
    end

    if playerEntry["position"] == nil then
        playerEntry["position"] = {-136.0, -20.0, 96.0, 0.0} -- Horseshoe overlook
    end

    if playerEntry["world"] == nil then
        playerEntry["world"] = `world`
    end
end

local function LoadData()
    print("Loading data...")
    Players = json.decode(LoadResourceFile(GetCurrentResourceName(), "players.json"))

    if Players == nil then
        Players = {}
    end

    for playerName, playerEntry in pairs(Players) do
        ValidatePlayerProps(playerEntry)
    end
end

local function SaveData()
    SaveResourceFile(GetCurrentResourceName(), "players.json", json.encode(Players), -1)
end

local function OnStartUp()
    LoadData()
end
OnStartUp()

Citizen.CreateThread(function()
	while true do
        Citizen.Wait(1000*60) -- Save data every minute
        SaveData()
	end
end)


AddEventHandler('playerJoining', function ()
    local playerName = GetPlayerName(source)

    -- New players
    if Players[playerName] == nil then
        Players[playerName] = {}

        ValidatePlayerProps(Players[playerName])
    end

    -- Save the source so we can map names to sources later
    PlayerSources[playerName] = source

    SaveData()
end)

-- Only used when restarting resource.
-- It's a fix since 'playerJoining' won't fire if already joined
RegisterNetEvent("wild:sv_updateSourceMap")
AddEventHandler('wild:sv_updateSourceMap', function()
    local playerName = GetPlayerName(source)
    PlayerSources[playerName] = source
end)

RegisterNetEvent("wild:sv_getPlayerData")
AddEventHandler('wild:sv_getPlayerData', function(strPlayerName)
    TriggerClientEvent("wild:cl_onReceivePlayerData", source, Players[strPlayerName])
end)

RegisterNetEvent("wild:sv_onPlayerFirstSpawn")
AddEventHandler('wild:sv_onPlayerFirstSpawn', function()
    local playerName = GetPlayerName(source)
    
    TriggerClientEvent("wild:cl_onPlayerFirstSpawn", source, Players[playerName])
end)

RegisterNetEvent("wild:sv_savePlayerPosition")
AddEventHandler("wild:sv_savePlayerPosition", function(coords, heading)
    local playerName = GetPlayerName(source)

    Players[playerName]["position"] = {
        coords.x, coords.y, coords.z, heading
    }

    SaveData()
end)

RegisterNetEvent("wild:sv_giveMoney")
AddEventHandler("wild:sv_giveMoney", function(strPlayerName, fAmount)
    local newTotal = Players[strPlayerName]["money"] + fAmount
    Players[strPlayerName]["money"] = newTotal

    TriggerClientEvent("wild:cl_onUpdateMoney", PlayerSources[strPlayerName], newTotal)
    SaveData()
end)

RegisterNetEvent("wild:sv_dumpIpls")
AddEventHandler("wild:sv_dumpIpls", function(ipls)
    SaveResourceFile(GetCurrentResourceName(), "ipls.json", json.encode(ipls), -1)
    TriggerClientEvent("wild:cl_dumpIplsDone", source)
end)

RegisterNetEvent("wild:sv_setPlayerKeyValue")
AddEventHandler("wild:sv_setPlayerKeyValue", function(strPlayerName, key, value)
    Players[strPlayerName][key] = value
    SaveData()
end)
--
-- Auto-restart resources (glitchy)
--

--AddEventHandler("onResourceStart", function(resource)   
	--if resource == GetCurrentResourceName() then

        --print("wild-core 'started'. ")

        --Citizen.CreateThread(function()
        --    while GetResourceState(resource) ~= "started" do -- Wait until state changes
        --        Citizen.Wait(1)
        --    end

            -- Even though we've "started," it still won't register to other resources
            -- so wait a little more
        --    Citizen.Wait(100)

            -- wild-core has fully restarted

            -- Start resources that depend on wild-core
            --print("Starting resources...")
            --StartResource("wild-interact")
            --StartResource("wild-war")
       -- end)
        
	--end
--end)


AddEventHandler('onResourceStop', function(resourceName)
end)

RegisterNetEvent('wild:sv_playAmbSpeech', function(pedNet, line)
    TriggerClientEvent('wild:cl_onPlayAmbSpeech', -1, pedNet, line)
end)