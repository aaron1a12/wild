--disquse version

local function getGuidFromItemId(inventoryId, itemData, category, slotId) 
    local outItem = DataView.ArrayBuffer(8 * 13)
 
    if not itemData then
        itemData = 0
    end
 
    local success = Citizen.InvokeNative("0x886DFD3E185C8A89", inventoryId, itemData, category, slotId, outItem:Buffer()) --InventoryGetGuidFromItemid
    if success then
        return outItem:Buffer() --Seems to not return anythign diff. May need to pull from native above
    else
        return nil
    end
end
 
local function addWardrobeInventoryItem(itemName, slotHash)
    local itemHash = GetHashKey(itemName)
    local addReason = GetHashKey("ADD_REASON_DEFAULT")
    local inventoryId = 1
 
    -- _ITEMDATABASE_IS_KEY_VALID
    local isValid = Citizen.InvokeNative("0x6D5D51B188333FD1", itemHash, 0) --ItemdatabaseIsKeyValid
    if not isValid then
        return false
    end
 
    local characterItem = getGuidFromItemId(inventoryId, nil, GetHashKey("CHARACTER"), `SLOTID_NONE`)
    if not characterItem then
        return false
    end
 
    local wardrobeItem = getGuidFromItemId(inventoryId, characterItem, GetHashKey("WARDROBE"), `SLOTID_WARDROBE`)
    if not wardrobeItem then
        return false 
    end
 
    local itemData = DataView.ArrayBuffer(8 * 13)
 
    -- _INVENTORY_ADD_ITEM_WITH_GUID
    local isAdded = Citizen.InvokeNative("0xCB5D11F9508A928D", inventoryId, itemData:Buffer(), wardrobeItem, itemHash, slotHash, 1, addReason);
    if not isAdded then 
        return false
    end
 
    -- _INVENTORY_EQUIP_ITEM_WITH_GUID
    local equipped = Citizen.InvokeNative("0x734311E2852760D0", inventoryId, itemData:Buffer(), true);
    return equipped;
end
 
local function givePlayerWeapon(weaponName, attachPoint)
    local addReason = GetHashKey("ADD_REASON_DEFAULT");
    local weaponHash = GetHashKey(weaponName);
    local ammoCount = 100;
 
    -- RequestWeaponAsset
    Citizen.InvokeNative("0x72D4CB5DB927009C", weaponHash, 0, true);
 
    Wait(1000)
    -- GIVE_WEAPON_TO_PED
    Citizen.InvokeNative("0x5E3BDDBCB83F3D84", PlayerPedId(), weaponHash, ammoCount, true, false, attachPoint, true, 0.0, 0.0, addReason, true, 0.0, false);
end




Citizen.CreateThread(function()
    --[[if getGuidFromItemId(1, nil, GetHashKey("CHARACTER"), 0xA1212100) then
        print("success")
    end
    addWardrobeInventoryItem("WEAPON_REVOLVER_CATTLEMAN", 0xA1212100);]]
end)




-- Credit to TuffyTown for their research, https://www.rdr2mods.com/profile/7229-tuffytown/
-- Example use: AddItemToInventory(`CONSUMABLE_PEACHES_CAN`, 1)
function NewGuid()
    local struct = DataView.ArrayBuffer(8 * 4)
    struct:SetInt32(0, 0)
    struct:SetInt32(8, 0)
    struct:SetInt32(16, 0)
    struct:SetInt32(24, 0)
    return struct
end

function NewSlotInfo()
    local guid = NewGuid()

    local struct = DataView.ArrayBuffer(8 * 8)
    -- Begin guid memmber
    struct:SetInt32(0, guid:GetInt32(0))
    struct:SetInt32(8, guid:GetInt32(8))
    struct:SetInt32(16, guid:GetInt32(16))
    struct:SetInt32(24, guid:GetInt32(24))
    -- end guid member

    struct:SetInt32(32, 0) -- int f_1;
    struct:SetInt32(40, 0) -- int f_2;
    struct:SetInt32(48, 0) -- int f_3;
    struct:SetInt32(56, 0) -- int slotId

    struct.GetGuid = function()
        return guid:Buffer()
    end

    struct.SetGuid = function(newGuid)
        struct:SetInt32(0, newGuid:GetInt32(0))
        struct:SetInt32(8, newGuid:GetInt32(8))
        struct:SetInt32(16, newGuid:GetInt32(16))
        struct:SetInt32(24, newGuid:GetInt32(24))
    end

    return struct
end

function NewItemInfo()
    local struct = DataView.ArrayBuffer(8 * 6)
    struct:SetInt32(0, 0)
    struct:SetInt32(8, 0)
    struct:SetInt32(16, 0)
    struct:SetInt32(24, 0)
    struct:SetInt32(32, 0)
    struct:SetInt32(40, 0)
    struct:SetInt32(48, 0)
    return struct
end

function NewStruct(size)
    local struct = DataView.ArrayBuffer(8 * size)
    local offset = 0
    for i=1, size do
        struct:SetInt32(offset, 0)
        offset = offset + 8
    end
    return struct
end

function GetPlayerInventoryItemGUID(item, pGuid, slotId)
	local outGuid = NewGuid()
	local result = Citizen.InvokeNative(0x886DFD3E185C8A89, 1, pGuid, item, slotId, outGuid:Buffer(), Citizen.ResultAsInteger());

    if result ~= 1 then
        print("ERROR: Failed to execute INVENTORY_GET_GUID_FROM_ITEMID")
    end

	return outGuid;
end

-- Gets an item's GUID from the inventory
function GetPlayerInventoryGUID()
    return GetPlayerInventoryItemGUID(`CHARACTER`, NewGuid():Buffer(), `SLOTID_NONE`);
end

-- Gets an item's group hash (eInvItemGroup)
function GetItemGroup(item)
	local info = NewItemInfo()

	if false == ItemdatabaseIsKeyValid(item, 0) then
        print("ERROR: ItemdatabaseIsKeyValid is not valid")
		return 0
    end

	if false == Citizen.InvokeNative(0xFE90ABBCBFDC13B2, item, info:Buffer()) then
        print("ERROR: ItemdatabaseFilloutItemInfo returned error")
		return 0
    end

	return info:GetInt32(16);
end

-- Gets an item's slot info data
function GetItemSlotInfo(item)
    local slotInfo = NewSlotInfo()

    slotInfo:SetGuid(GetPlayerInventoryGUID())
    slotInfo:SetInt32(56, `SLOTID_SATCHEL`)

    local group = GetItemGroup(item)
    
    if group == `CLOTHING` then
        if Citizen.InvokeNative(0x780C5B9AE2819807, item, `SLOTID_WARDROBE`) then -- _INVENTORY_FITS_SLOT_ID
            slotInfo:SetGuid( GetPlayerInventoryItemGUID(`WARDROBE`, slotInfo:GetGuid(), `SLOTID_WARDROBE`) )
            slotInfo:SetInt32(56, GetDefaultItemSlotInfo(item, `WARDROBE`))
        else
            slotInfo:SetInt32(56, GetDefaultItemSlotInfo(item, `SLOTID_WARDROBE`))
        end
    elseif group == `WEAPON` then
        slotInfo:SetGuid( GetPlayerInventoryItemGUID(`CARRIED_WEAPONS`, GetPlayerInventoryGUID():Buffer(), `SLOTID_CARRIED_WEAPONS`) )

        if Citizen.InvokeNative(0x780C5B9AE2819807, item, `SLOTID_WEAPON_0`) then
            slotInfo:SetInt32(56, `SLOTID_WEAPON_0`)
        end

        if Citizen.InvokeNative(0x780C5B9AE2819807, item, `SLOTID_WEAPON_1`) then
            slotInfo:SetInt32(56, `SLOTID_WEAPON_1`)
        end
    elseif group == `HORSE` then
        slotInfo:SetInt32(56, `SLOTID_ACTIVE_HORSE`)
    elseif group == `EMOTE` then
    elseif group == `UPGRADE` then
        if Citizen.InvokeNative(0x780C5B9AE2819807, item, `SLOTID_UPGRADE`) then 
            slotInfo:SetInt32(56, `SLOTID_UPGRADE`)
        end
    else
        if Citizen.InvokeNative(0x780C5B9AE2819807, item, `SLOTID_SATCHEL`) then 
            slotInfo:SetInt32(56, `SLOTID_SATCHEL`)
        elseif Citizen.InvokeNative(0x780C5B9AE2819807, item, `SLOTID_WARDROBE`) then 
            slotInfo:SetInt32(56, `SLOTID_WARDROBE`)
        else
            slotInfo:SetInt32(56, GetDefaultItemSlotInfo(item, `CHARACTER`))
        end
    end

    return slotInfo
end

-- Adds an item to the player inventory via GUID
function AddItemWithGUID(item, guid, slotInfo, quantity, addReason)

    if false == Citizen.InvokeNative(0xB881CA836CC4B6D4, slotInfo:GetGuid()) then
        print("INVALID GUID")
        return false
    end

    if false == Citizen.InvokeNative(0xCB5D11F9508A928D, 1, guid:Buffer(), slotInfo:GetGuid(), item, slotInfo:GetInt32(56), quantity, addReason) then
        print("FAILED TO ADD TO INVENTORY")
        return false
    end

	return true;
end

-- Adds an item to the player inventory via hash
-- This is the main function you will be calling to add items to your inventory
function AddItemToInventory(item, quantity)
	local slotInfo = GetItemSlotInfo(item);
	local guid = GetPlayerInventoryItemGUID(item, slotInfo:GetGuid(), slotInfo:GetInt32(56));
	return AddItemWithGUID(item, guid, slotInfo, quantity, `ADD_REASON_DEFAULT`);
end


function _INVENTORY_IS_GUID_VALID(guid)
    if not Citizen.InvokeNative(0xB881CA836CC4B6D4, guid) then
        return false
    else
        return true
    end
end

function _INVENTORY_ADD_ITEM_WITH_GUID(inventoryId, guid1, guid2, item, inventoryItemSlot, quantity, addReason)
    local ret = Citizen.InvokeNative(
        0xCB5D11F9508A928D, inventoryId, guid1, guid2, item, inventoryItemSlot, quantity, addReason
    )

    if not ret then return false else return true end 
end

function INVENTORY_GET_CHILDREN_IN_SLOT_COUNT(inventoryId, guid, slotId)
    return Citizen.InvokeNative(0x033EE4B89F3AC545, inventoryId, guid, slotId)
end

function _INVENTORY_GET_INVENTORY_ITEM_EQUIPPED_IN_SLOT(inventoryId, guid, slotId)
    return Citizen.InvokeNative(0x033EE4B89F3AC545, inventoryId, guid, slotId)
end

function _INVENTORY_EQUIP_ITEM_WITH_GUID(inventoryId, guid, bEquipped)
    return Citizen.InvokeNative(0x734311E2852760D0, inventoryId, guid, bEquipped)
end

function _INVENTORY_REMOVE_INVENTORY_ITEM_WITH_GUID(inventoryId, guid, quantity, removeReason)
    return Citizen.InvokeNative(0x3E4E811480B3AE79, inventoryId, guid, quantity, removeReason)
end



-- Every weapon item can be placed in 1 of 4 slots ids (SLOTID_WEAPON_0) that are for that weapon only.
-- Once a weapon item has been added to a specific slot id, it cannot be added again to that slot. This would not affect other weapons added to the slot id.

Citizen.CreateThread(function()
    AddItemToInventory(`consumable_peaches_can`, 1)
    --print(getGuidFromItemId(1, 0, category, slotId) )

    slotIds = json.decode(LoadResourceFile(GetCurrentResourceName(), "slot_ids.json"))

    print(0x3711A8A8 == `CARRIED_WEAPONS`)

    local horseWeaponsInventoryGUID = 0

    for k in pairs(slotIds) do
        local slotId = slotIds[k]
        if type(slotIds[k]) == "string" then
            slotId = GetHashKey(slotId)
        end

        if InventoryFitsSlotId(`weapon_rifle_varmint`, slotId) == 1 then
            print("Fits slot: " ..tostring(slotIds[k]))
        end
    end

 

    
    

     
    local weaponItem = getGuidFromItemId(1, GetPlayerInventoryGUID():Buffer(), `CARRIED_WEAPONS`, `SLOTID_CARRIED_WEAPONS`)
    if not weaponItem then
        print("woes")
        return false 
    end

    

    for i=0, 12 do
        --itemData:SetInt32(8*i, 65) 
    end

    local itemData = DataView.ArrayBuffer(8 * 13)

    --
    -- WORKING MAGIC
    --
 
    -- _INVENTORY_ADD_ITEM_WITH_GUID
    --local isAdded = Citizen.InvokeNative("0xCB5D11F9508A928D", 1, itemData:Buffer(), weaponItem, `WEAPON_REVOLVER_CATTLEMAN`, `SLOTID_WEAPON_3`, 1, `ADD_REASON_DEFAULT`);
    local isAdded = _INVENTORY_ADD_ITEM_WITH_GUID(1, itemData:Buffer(), weaponItem, `weapon_rifle_varmint`, `SLOTID_WEAPON_0`, 1, `ADD_REASON_DEFAULT`)

    if isAdded then 
        itemData = GetPlayerInventoryItemGUID(`weapon_rifle_varmint`, weaponItem, `SLOTID_WEAPON_0`)
        _INVENTORY_EQUIP_ITEM_WITH_GUID(1, itemData:Buffer(), true)

        Citizen.InvokeNative(0x12FB95FE3D579238, PlayerPedId(), itemData:Buffer(), 1, 0, 0 ,0)
        HidePedWeapons(PlayerPedId(), 2, true)

        --Citizen.InvokeNative(0xD61D5E1AD9876DEB, PlayerPedId(), `weapon_rifle_varmint`, itemData:Buffer(), 0, 0, 0, -1082130432)

        --print(_INVENTORY_REMOVE_INVENTORY_ITEM_WITH_GUID(1, itemData:Buffer(), 1, `REMOVE_REASON_DEFAULT`))
        

        TriggerServerEvent("wild:sv_dumpBuffer", itemData:Buffer(), 8 * 13)
        print("Item added to inventory")
    else
        print("Failed to add item")
    end


    --_INVENTORY_GET_INVENTORY_ITEM_EQUIPPED_IN_SLOT
    print(INVENTORY_GET_CHILDREN_IN_SLOT_COUNT(1, weaponItem, `SLOTID_WEAPON_0`))



        --GetPlayerInventoryItemGUID(`CHARACTER`, NewGuid():Buffer(), `SLOTID_NONE`)
    local carriedWeaponsInventoryGUID = GetPlayerInventoryItemGUID(`CARRIED_WEAPONS`, GetPlayerInventoryGUID():Buffer(), `SLOTID_CARRIED_WEAPONS`)
    if _INVENTORY_IS_GUID_VALID(carriedWeaponsInventoryGUID:Buffer()) then
       -- print("valid guid")
    end


    --local itemGuid = NewStruct(32)

    --INVENTORY_GET_GUID_FROM_ITEMID
    --local result = Citizen.InvokeNative(0x886DFD3E185C8A89, 1, carriedWeaponsInventoryGUID:Buffer(), `WEAPON_REVOLVER_CATTLEMAN`, `SLOTID_WEAPON_1`, itemGuid:Buffer(), Citizen.ResultAsInteger());
    --print(result)
end)


RegisterCommand('inv', function() 
	print(InventoryIsInventoryItemEquipped(1, `weapon_rifle_varmint`, false))
end, false)


--TriggerServerEvent("wild:sv_dumpBuffer", info:Buffer(), 512)