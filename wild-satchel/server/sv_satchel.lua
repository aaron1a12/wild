local PlayerInventories = {}

local function LoadData()
    PlayerInventories = json.decode(LoadResourceFile(GetCurrentResourceName(), "player_inventories.json"))

    if PlayerInventories == nil then
        PlayerInventories = {}
    end
end
LoadData()

local function SaveData()
    SaveResourceFile(GetCurrentResourceName(), "player_inventories.json", json.encode(PlayerInventories), -1)
end


RegisterNetEvent('wild:sv_getPlayerInventory', function(strPlayerName)
    if PlayerInventories[strPlayerName] == nil then
        PlayerInventories[strPlayerName] = {}
        SaveData()
    end

    TriggerClientEvent('wild:sv_onReceivePlayerInventory', source, PlayerInventories[strPlayerName])
end)


RegisterNetEvent('wild:satchel:cl_add', function(item, quantity)
    local playerName = GetPlayerName(source)

    if PlayerInventories[playerName][item] == nil then
        PlayerInventories[playerName][item] = 0
    end

    PlayerInventories[playerName][item] = PlayerInventories[playerName][item] + quantity

    SaveData()
end)


RegisterNetEvent('wild:satchel:cl_remove', function(item, quantity)
    local playerName = GetPlayerName(source)


    if PlayerInventories[playerName][item] == nil then
        PlayerInventories[playerName][item] = 0
    end

    PlayerInventories[playerName][item] = PlayerInventories[playerName][item] - quantity

    if PlayerInventories[playerName][item] < 1 then
        PlayerInventories[playerName][item] = nil
    end

    SaveData()
end)




RegisterNetEvent('wild:sv_dumpBuffer', function(buffer, size)
    SaveResourceFile(GetCurrentResourceName(), "buffer.dat", buffer, size)
end)





local catalog = {}

RegisterNetEvent('wild:sv_addToCatalog', function(key, itemData)
    catalog[key] = itemData
end)

RegisterCommand('save', function() 
	SaveResourceFile(GetCurrentResourceName(), "inventory_catalog.json", json.encode(catalog), -1)
end, false)