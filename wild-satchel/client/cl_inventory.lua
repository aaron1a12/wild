--[[
====================================================================================================

    Native RDR2 Inventory Management
    ================================

    Do not use these yourself. Use Satchel methods instead!

====================================================================================================
]]

function InventoryIsGuidValid(guid)
    if not Citizen.InvokeNative(0xB881CA836CC4B6D4, guid) then
        return false
    else
        return true
    end
end

function _INVENTORY_CREATE_ITEM_COLLECTION(inventoryId, strFilterName, slotId, pOutSize)
    return Citizen.InvokeNative(0x80D78BDC9D88EF07, inventoryId, strFilterName, slotId, pOutSize, Citizen.ResultAsInteger())
end

function _INVENTORY_GET_ITEM_FROM_COLLECTION_INDEX(collectionId, itemIndex, pItemData)
    return Citizen.InvokeNative(0x82FA24C3D3FCD9B7, collectionId, itemIndex, pItemData)
end

function _INVENTORY_GET_FULL_INVENTORY_ITEM_DATA(inventoryId, guid, p2, p3, p4)
    return Citizen.InvokeNative(0x025A1B1FB03FBF61, inventoryId, guid, p2, p3, p4)
end

function InventoryGetItemLocationWithGuid(itemGuid)
    local struct = DataView.ArrayBuffer(256)
    struct:SetInt32(8*9, `SLOTID_NONE`)
    _INVENTORY_GET_FULL_INVENTORY_ITEM_DATA(1, itemGuid, struct:Buffer(), 22, 1)

    local f_14 = struct:GetInt32(8*14)
    local f_21 = struct:GetInt32(8*21)

    if f_21 == 0 then
        return 2 -- satchel ??? idk
    elseif f_21 ~= 0 and f_14 ~= -1 then
        return 0 -- on person?
    elseif f_21 ~= 0 and f_14 == -1 then
        return 1 -- on horse?
    end

    return -1
end

function InventoryGetItemLocationWithHash(itemHash)
    local inventoryGuid, slotId = GetItemInventoryInfo(itemHash)
    local itemGuid = GetInventoryItemGuid(itemHash, inventoryGuid, slotId)

    if InventoryIsGuidValid(itemGuid) then
        return InventoryGetItemLocationWithGuid(itemGuid) 
    end
    
    return -1
end

function GetInventoryItemGuid(item, pGuid, slotId)
	local outGuid = DataView.ArrayBuffer(8 * 13)
	local result = Citizen.InvokeNative(0x886DFD3E185C8A89, 1, pGuid, item, slotId, outGuid:Buffer(), Citizen.ResultAsInteger());

    if result ~= 1 then
        return nil
    end

	return outGuid:Buffer();
end

function GetCharacterInventoryGuid()
    return GetInventoryItemGuid(`CHARACTER`, 0, `SLOTID_NONE`)
end

function GetWardrobeInventoryGuid()
    return GetInventoryItemGuid(`WARDROBE`, GetCharacterInventoryGuid(), `SLOTID_WARDROBE`)
end

function GetWeaponInventoryGuid()
    return GetInventoryItemGuid(`CARRIED_WEAPONS`, GetCharacterInventoryGuid(), `SLOTID_CARRIED_WEAPONS`)
    --return GetInventoryItemGuid(`CARRIED_WEAPONS`, 0, `SLOTID_CARRIED_WEAPONS`)
end

function GetItemGroup(item)
	local info = DataView.ArrayBuffer(8 * 7)
    info:SetInt32(0, 0)
    info:SetInt32(8, 0)
    info:SetInt32(16, 0)
    info:SetInt32(24, 0)
    info:SetInt32(32, 0)
    info:SetInt32(40, 0)
    info:SetInt32(48, 0)

	if false == Citizen.InvokeNative(0xFE90ABBCBFDC13B2, item, info:Buffer()) then
		return 0
    end

	return info:GetInt32(16);
end

-- TODO: Make use of InventoryFitsSlotId(`WEAPON_REVOLVER_CATTLEMAN`, `SLOTID_WEAPON_0`)?
function GetItemInventoryInfo(item)
    -- Default inventory is satchel
    local inventoryGuid = GetCharacterInventoryGuid()
    local slotId = `SLOTID_SATCHEL`

    local group = GetItemGroup(item)

    -- Every weapon item can be placed in 1 of 4 slots ids (e.g., SLOTID_WEAPON_3) that are for that weapon only.
    -- Once a weapon item has been added to a specific slot id, it cannot be added again to that slot. This would not affect other weapons added to the slot id.
    -- The same weapon can be in separate slots at once. Refer to slot_ids.json for more slots

    if group == `WEAPON` then
        inventoryGuid = GetWeaponInventoryGuid()

        -- In the native code, it checks each slot with 0xC97E0D2302382211 to see if the weapon is already in that slot.
        -- We're lazy so we're only going to support placing weapons in one slot: SLOTID_WEAPON_0
        slotId = `SLOTID_WEAPON_0` 
        
    elseif group == `CLOTHING` then
        inventoryGuid = GetWardrobeInventoryGuid()
        slotId = `SLOTID_WARDROBE_LOADOUT_1`

    elseif group == `UPGRADE` then
        if InventoryFitsSlotId(item, `SLOTID_UPGRADE`) == 1 then
            slotId = `SLOTID_UPGRADE`
        end
        
    elseif group == `HORSE` then
        slotId = `SLOTID_ACTIVE_HORSE` -- Unresearched area

    else
        if InventoryFitsSlotId(item, `SLOTID_SATCHEL`) == 1 then
            slotId = `SLOTID_SATCHEL`
        elseif InventoryFitsSlotId(item, `SLOTID_WARDROBE`) == 1 then
            slotId = `SLOTID_WARDROBE`
        elseif InventoryFitsSlotId(item, `SLOTID_CURRENCY`) == 1 then
            slotId = `SLOTID_CURRENCY`
        else
            slotId = GetDefaultItemSlotInfo(item, `CHARACTER`)            
        end
    end

    return inventoryGuid, slotId
end

function AddItemToInventory(item, quantity)
    if ItemdatabaseIsKeyValid(item, 0) == 0 then
		return false
    end

    -- Get the default placement for this item
    local inventoryGuid, slotId = GetItemInventoryInfo(item)
    
    local itemGuid = DataView.ArrayBuffer(8 * 13)

    -- _INVENTORY_ADD_ITEM_WITH_GUID
    local ret = Citizen.InvokeNative(0xCB5D11F9508A928D, 1, itemGuid:Buffer(), inventoryGuid, item, slotId, quantity, `ADD_REASON_DEFAULT`);
    if not ret then return false end

    -- Get the new item guid
    itemGuid = GetInventoryItemGuid(item, inventoryGuid, slotId)

    -- _INVENTORY_EQUIP_ITEM_WITH_GUID. Does not seem to work with weapons
    Citizen.InvokeNative(0x734311E2852760D0, 1, itemGuid, true)

    -- Weapons get added to your horse by default. Here, we equip it manually
    if GetItemGroup(item) == `WEAPON` then
        -- Method A
        -- SET_CURRENT_PED_WEAPON_BY_GUID
        --Citizen.InvokeNative(0x12FB95FE3D579238, PlayerPedId(), itemGuid, 1, 0, 0 ,0)
        --HidePedWeapons(PlayerPedId(), 2, true) -- Go to unarmed. No nead to switch it now.

        -- Method B
        local struct = DataView.ArrayBuffer(256)
        struct:SetInt32(8*9, `SLOTID_NONE`)

        _INVENTORY_GET_FULL_INVENTORY_ITEM_DATA(1, itemGuid, struct:Buffer(), 22, 1)
        
        struct:SetInt32(8*14, 2)
        struct:SetInt32(8*21, 1)

        Citizen.InvokeNative(0xD80A8854DB5CFBA5, 1, itemGuid, struct:Buffer(), 22)

        local opts = DataView.ArrayBuffer(128)
        opts:SetInt32(8*7, `ADD_REASON_DEFAULT`)
        opts:SetInt32(8*8, 1056964608)
        opts:SetInt32(8*9, 1065353216) 
        opts:SetInt32(8*4, item)
        opts:SetInt32(8*0, 0)
        opts:SetInt32(8*6, 1) --attach point?
        opts:SetInt32(8*12, 1)

        local out = DataView.ArrayBuffer(256)
        Citizen.InvokeNative(0xBE7E42B07FD317AC, PlayerPedId(), opts:Buffer(), out:Buffer())
    end

    return true
end

function RemoveItemFromInventory(item, quantity)
    local inventoryGuid, slotId = GetItemInventoryInfo(item)
    local itemGuid = GetInventoryItemGuid(item, inventoryGuid, slotId)
    
    -- _INVENTORY_REMOVE_INVENTORY_ITEM_WITH_GUID
    return Citizen.InvokeNative(0x3E4E811480B3AE79, 1, itemGuid, quantity, `REMOVE_REASON_DEFAULT`)
end

function ClearInventory()
    N_0xe36d4a38d28d9cfb(0)
    N_0x5d6182f3bce1333b(1, `REMOVE_REASON_DEFAULT`)
end

local bannedItems = {
    1259508039, -1406390556, -2048947027, -1455768246, -1733092640, -2035110427, -106768597, 2019377485, -1516555556, 982182330, -630557532, -6419100, 1807503187,
    1018123892, -727924611, -59585102, 1979310863, 85134332, 856970057, 896288156, -921879912, 273608212, 1401465909, 1081037984, 1157009922, 1510719693, -564214310,
    1328661203, -1569615261, 1549070292, 1030402560, -135813381, -351498939, -406091561, -1476503313, -1268909760, 271701509, 889965687, -2081104194, 113006350,
    829903539, -781428855, 1657142792, 173773832, 765412429, -1148732422, 1150701045, -567250635, 2123648621, -1162940149, -1839171917, -857285521, 484521079,
    2144486002, 1866214240, 923904168
}

function IsItemBanned(item)
    for i=1, #bannedItems do
        if bannedItems[i] == item then
            return true
        end
    end

    return false
end

function PickMountForLoad(player)
    local playerPed = GetPlayerPed(player)
    local playerMount = GetMountOwnedByPlayer(player)
    local playerLastMount = GetLastMount(playerPed)

    local finalMount = 0
    local finalDist = 0

    local playerCoords = GetEntityCoords(playerPed)

    if not DoesEntityExist(playerMount) then
        playerMount = 0
    end

    if not DoesEntityExist(playerLastMount) then
        playerLastMount = 0
    end

    if playerMount ~= 0 and playerLastMount ~= 0 then -- We have to choose between mounts

        local playerMountDist = GetVectorDistSqr(playerCoords, GetEntityCoords(playerMount))
        local playerLastMountDist = GetVectorDistSqr(playerCoords, GetEntityCoords(playerLastMount))

        if playerLastMountDist < playerMountDist then
            finalMount = playerLastMount
            finalDist = playerLastMountDist
        else
            finalMount = playerMount
            finalDist = playerMountDist
        end
    else
        if playerLastMount ~= 0 then
            finalMount = playerLastMount
            finalDist = GetVectorDistSqr(playerCoords, GetEntityCoords(playerMount))
        end

        if playerMount ~= 0 then
            finalMount = playerMount
            finalDist = GetVectorDistSqr(playerCoords, GetEntityCoords(playerMount))
        end
    end

    return finalMount, finalDist
end

function GetInventoryWithFilter(itemArray, filter)
    filter = string.lower(filter)

    local pOutSize = DataView.ArrayBuffer(8)
    
    -- RDR2 native filter. Different from our filter
    local strFilter = "ALL"

    local allowedGroups = {}

    if filter == "weapons" then
        allowedGroups = {`weapon`}
        strFilter = "ALL WEAPONS"
    end

    if filter == "provisions" then
        allowedGroups = {`provision`, `consumable`}
        strFilter = "ALL SATCHEL"
    end

    if filter == "consumables" then
        allowedGroups = {`consumable`}
        strFilter = "ALL SATCHEL"
    end

    if filter == "horse food" then
        allowedGroups = {`consumable`}
        strFilter = "ALL SATCHEL"
    end

    function tryAddToArray(itemHash, quantity, iLocation)
        local itemUi = GetItemUiFallback(itemHash)

        -- See catalog_sp.ymt
        local info = DataView.ArrayBuffer(8 * 7)
        Citizen.InvokeNative(0xFE90ABBCBFDC13B2, itemHash, info:Buffer())
        local group = info:GetInt32(16) -- weapon, provision, consumable, etc
        local category = info:GetInt32(8) -- Note that categories are actually a subset of "group"
        
        local bIsAllowed = false

        if filter == "all" then
            if itemUi.textureId ~= 0 then
                bIsAllowed = true
            end
        else
            for i=1, #allowedGroups do
                if allowedGroups[i] == group then
                    bIsAllowed = true 
                    break
                end
            end

            if filter == "hunting" and category == 235313564  then
                bIsAllowed = true
            end
        end

        if group == `ammo` then
            bIsAllowed = false
        end

        if InventoryFitsSlotId(itemHash, 'SLOTID_SATCHEL') == 0 and InventoryFitsSlotId(itemHash, 'SLOTID_WEAPON_0') == 0 then
            --bIsAllowed = false
        end

        if IsItemBanned(itemHash) then
            bIsAllowed = false
        end

        if filter == "horse food" then
            
            if IsHorseFood(itemHash) then
                bIsAllowed = true
            else
                bIsAllowed = false
            end
        end

        if bIsAllowed then 
            table.insert(itemArray, {
                item = itemHash, quantity = quantity, ui = itemUi, location = iLocation
            })
        end
    end

    -- Filter options: "ALL", "ALL SATCHEL", "ALL HORSES", "ALL COACHES", "ALL MOUNTS", "ALL CLOTHING", "ALL WEAPONS", "ALL SATCHEL EXCLUDING CLOTHING", "ALL EXCLUDING CLOTHING"
    local collection = _INVENTORY_CREATE_ITEM_COLLECTION(1, strFilter, `SLOTID_NONE`, pOutSize:Buffer())


    if collection > -1 then
        local count = pOutSize:GetInt32(0)
        for i=0, count-1 do
            if not IsItemBanned(itemHash) then
                local itemData = DataView.ArrayBuffer(128)
                _INVENTORY_GET_ITEM_FROM_COLLECTION_INDEX(collection, i, itemData:Buffer())

                local structSize = itemData:GetUint8(3) -- usually 128
                local itemHash = itemData:GetInt32(8*4)
                local slotId = itemData:GetInt32(8*9)
                local equipped = itemData:GetUint8(8*10) -- usually 1
                local quantity = itemData:GetInt32(8*11)

                tryAddToArray(itemHash, quantity, InventoryGetItemLocationWithGuid(itemData:Buffer()))
            end
        end
    end

    InventoryReleaseItemCollection(collection)

    --
    -- Physical horse items
    --

    local mount, mountDist = PickMountForLoad(PlayerId())
    local bHasPelts = false

    if mount ~= 0 and mountDist < 30.0 then

        -- Get items

        -- TODO: investigate FIND_ALL_ATTACHED_CARRIABLE_ENTITIES (0xB5ACE8B23A438EC0) or
        -- GET_CARRIED_ATTACHED_INFO_FOR_SLOT (0x608BC6A6AACD5036) to get other side stowed items?
        local entityStowed = GetFirstEntityPedIsCarrying(mount)
        local entityAsItem = GetCarriableFromEntity(entityStowed)

        if not (GetIsAnimal(entityStowed) == 0 and GetIsAnimal(entityStowed) == 0) then
            if IsEntityAPed(entityStowed) then
                local carcass = GetSatchelCarcassFromPed(entityStowed)
                tryAddToArray(carcass, 1, 1)
            end
        end

        -- Search for pelts

        local pelts = {}

        for i = 0, 99 do
            local pelt = GetPeltFromHorse(mount, i)
            
            if pelt ~= 0 then

                if not pelts[pelt] then
                    pelts[pelt] = 0
                end

                pelts[pelt] = pelts[pelt] + 1 
            else
                break
            end
        end

        -- Add the pelts
        for pelt, quantity in pairs(pelts) do
            tryAddToArray(pelt, quantity, 1)
        end
    end

    return itemArray
end

function InventoryGetInventoryItemEquippedInSlot(guid, slotId)
    return Citizen.InvokeNative(0x033EE4B89F3AC545, 1, guid, slotId)
end

--[[
Citizen.CreateThread(function()
    


    for k in pairs(slotIds) do
        local slotId = slotIds[k]
        if type(slotIds[k]) == "string" then
            slotId = GetHashKey(slotId)
        end

        if InventoryFitsSlotId(`weapon_rifle_varmint`, slotId) == 1 then
            --print("Fits slot: " ..tostring(slotIds[k]))
        end
    end

    AddItemToInventory(`consumable_peaches_can`, 1)
    --RemoveItemFromInventory(`consumable_peaches_can`, 3)
    --local success = AddItemToInventory(`weapon_rifle_varmint`, 1)
end)]]