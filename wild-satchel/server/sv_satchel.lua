local PlayerInventories = {}

local function LoadData()
    local _playerInventories = json.decode(LoadResourceFile(GetCurrentResourceName(), "player_inventories.json"))

    if _playerInventories == nil then
        _playerInventories = {}
    end

    -- Replace all keys with number versions
    for playerName, inventory in pairs(_playerInventories) do

        PlayerInventories[playerName] = {}

        for item, data in pairs(inventory) do
            PlayerInventories[playerName][tonumber(item)] = data
        end
        
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
        PlayerInventories[playerName][item] = {0, 0}
    end

    local inventoryItem = PlayerInventories[playerName][item]
    inventoryItem[1] = inventoryItem[1] + quantity

    SaveData()
end)


RegisterNetEvent('wild:satchel:cl_updateItem', function(item, data)
    local playerName = GetPlayerName(source)

    if PlayerInventories[playerName][item] == nil then
        PlayerInventories[playerName][item] = {0, 0}
    end

    local inventoryItem = PlayerInventories[playerName][item]
    inventoryItem[1] = data[1]
    inventoryItem[2] = data[2]

    if inventoryItem[1] < 1 then
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

RegisterNetEvent('wild:satchel:cl_setItemPickable', function(objNetId)
    TriggerClientEvent('wild:satchel:cl_setItemPickable', -1, objNetId)
end)

RegisterNetEvent('wild:sv_triggerPuking', function(pedId)
    TriggerClientEvent('wild:cl_triggerPuking', -1, pedId)
end)
