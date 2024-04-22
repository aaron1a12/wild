local Players = {}

local function LoadData()
    Players = json.decode(LoadResourceFile(GetCurrentResourceName(), "players.json"))

    if Players == nil then
        Players = {}
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
        Players[playerName] = {
            ["money"] = 0.0
        }
    end

    SaveData()
end)

RegisterNetEvent('wild:sv_onPlayerSpawned', function()
    local playerName = GetPlayerName(source)
    TriggerClientEvent("wild:cl_onPlayerSpawned", source, Players[playerName])
end)