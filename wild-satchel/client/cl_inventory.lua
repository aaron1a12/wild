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
        slotId = `SLOTID_WEAPON_0` 
    end

    if group == `CLOTHING` then
        inventoryGuid = GetWardrobeInventoryGuid()
        slotId = `SLOTID_WARDROBE_LOADOUT_1`
    end

    if group == `UPGRADE` then
        slotId = `SLOTID_UPGRADE`
    end

    return inventoryGuid, slotId
end

function AddItemToInventory(item, quantity)
    if not ItemdatabaseIsKeyValid(item, 0) then
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

-- Filter options: "ALL", "ALL SATCHEL", "ALL HORSES", "ALL COACHES", "ALL MOUNTS", "ALL CLOTHING", "ALL WEAPONS", "ALL SATCHEL EXCLUDING CLOTHING", "ALL EXCLUDING CLOTHING"
function GetInventoryWithFilter(filter)
    local itemArray = {}
    local pOutSize = DataView.ArrayBuffer(8)
    
    local collection = _INVENTORY_CREATE_ITEM_COLLECTION(1, filter, `SLOTID_NONE`, pOutSize:Buffer())

    if collection > -1 then
        local count = pOutSize:GetInt32(0)
        for i=0, count-1 do

            local itemData = DataView.ArrayBuffer(128)
            _INVENTORY_GET_ITEM_FROM_COLLECTION_INDEX(collection, i, itemData:Buffer())

            local structSize = itemData:GetUint8(3) -- usually 128
            local itemHash = itemData:GetInt32(8*4)
            local slotId = itemData:GetInt32(8*9)
            local equipped = itemData:GetUint8(8*10) -- usually 1
            local quantity = itemData:GetInt32(8*11)

            local itemUi = GetItemUiFallback(itemHash)

            -- The inventory may contain alot of weird stuff.
            -- Simplest way to test if a valid inventory item is to check for we have a texture for it.
            if itemUi.textureId ~= 0 then 
                table.insert(itemArray, {
                    item = itemHash, quantity = quantity, ui = itemUi, location = InventoryGetItemLocationWithGuid(itemData:Buffer()) 
                })
            end
        end
    end

    InventoryReleaseItemCollection(collection)
    return itemArray
end

function InventoryGetInventoryItemEquippedInSlot(guid, slotId)
    return Citizen.InvokeNative(0x033EE4B89F3AC545, 1, guid, slotId)
end

--[[
Citizen.CreateThread(function()
    slotIds = json.decode(LoadResourceFile(GetCurrentResourceName(), "slot_ids.json"))


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