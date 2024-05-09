PlayerHorses = {}

local function LoadData()
    PlayerHorses = json.decode(LoadResourceFile(GetCurrentResourceName(), "player_horses.json"))

    if PlayerHorses == nil then
        PlayerHorses = {}
    end

    --[[for ownerName, horse in pairs(PlayerHorses) do
        ValidateProps(horse)
    end]]
end
LoadData()

local function SaveData()
    SaveResourceFile(GetCurrentResourceName(), "player_horses.json", json.encode(PlayerHorses), -1)
end

Citizen.CreateThread(function()
	while true do
        Citizen.Wait(60*1000) -- Save data every 1 minute
        SaveData()
	end
end)


RegisterNetEvent("wild:sv_addMount", function(mountInfo)
    local playerName = GetPlayerName(source)

    PlayerHorses[playerName] = mountInfo
    SaveData()
end)

RegisterNetEvent("wild:sv_getMountInfo", function()
    local playerName = GetPlayerName(source)

    local mountInfo = PlayerHorses[playerName]

    if mountInfo == nil then
        mountInfo = {}
    end

    TriggerClientEvent("wild:cl_onReceiveMountInfo", source, mountInfo)
end)

RegisterNetEvent("wild:sv_deleteMount", function()
    local playerName = GetPlayerName(source)

    if PlayerHorses[playerName] ~= nil then
        PlayerHorses[playerName] = nil
        SaveData()
    end
end)