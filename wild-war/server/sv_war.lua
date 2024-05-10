local Factions = {}

-- Makes sure all entries have appropriate properties read or created with default values
local function ValidateProps(factionEntry, faction)

    if factionEntry["color"] == nil then
        factionEntry["color"] = 0
    end


    if factionEntry["funds"] == nil then
        factionEntry["funds"] = 0.0
    end

    if factionEntry["tickets"] == nil then
        factionEntry["tickets"] = 0
    end

    if factionEntry["players"] == nil then
        factionEntry["players"] = {}
    end

    if factionEntry["ped_members"] == nil then
        factionEntry["ped_members"] = {}
    end

    if factionEntry["hated"] == nil then
        factionEntry["hated"] = false
    end
end

local function LoadData()
    Factions = json.decode(LoadResourceFile(GetCurrentResourceName(), "factions.json"))

    if Factions == nil then
        Players = {}
    end

    for faction, factionEntry in pairs(Factions) do
        ValidateProps(factionEntry, faction)
    end
end
LoadData()

local function SaveData()
    SaveResourceFile(GetCurrentResourceName(), "factions.json", json.encode(Factions), -1)
end

Citizen.CreateThread(function()
	while true do
        Citizen.Wait(5*1000) -- Save data every five second
        SaveData()
	end
end)

RegisterNetEvent("wild:sv_onLoadFactionData", function()
    TriggerClientEvent("wild:cl_onLoadFactionData", source, Factions)
end)

RegisterNetEvent("wild:sv_joinFaction", function(factionName)
    local playerName = GetPlayerName(source)

    if factionName == nil then
        return
    end

    local faction = Factions[factionName]

    if faction == nil then
        return
    end

    for i = 1, #faction.players do 
        if faction.players[i] == playerName then -- Player already in
            return
        end
    end

    table.insert(faction.players, playerName)

    SaveData()

    TriggerClientEvent("wild:cl_onJoinFaction", source, factionName)
end)


RegisterNetEvent("wild:sv_leaveFaction", function()
    local playerName = GetPlayerName(source)

    for factionName, faction in pairs(Factions) do
        for i = 1, #faction.players do 
            if faction.players[i] == playerName then
                Factions[factionName].players[i] = nil
            end
        end
    end

    SaveData()

    TriggerClientEvent("wild:cl_onLeaveFaction", source)
end)