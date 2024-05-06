-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

-- How to get money:  W.GetPlayerMoney()
-- How to give/remove money:  TriggerServerEvent("wild:sv_giveMoney", GetPlayerName(PlayerId()), amount)

Citizen.CreateThread(function()

    -- Gun smith counter in Valentine
    local v = vector3(-281.6, 780.7, 119.5)

	while true do
		Citizen.Wait(1000)
		
        local playerPed = GetPlayerPed(player)
        local playerCoords = GetEntityCoords(playerPed)
        --ShowText("X:".. tostring(playerCoords.x).."|Y:"..tostring(playerCoords.y).."|Z:"..tostring(playerCoords.z))

        local dist = GetDistanceBetweenCoords(playerCoords, v, true)
        
        if dist < 1.0 then
            
            ShowHelpText("Press ~INPUT_ENTER~ to browse shop", 1000)
        end
	end
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

function Start()
    GiveWeaponToPed(
		PlayerPedId(), 
		`WEAPON_MELEE_LANTERN` --[[ Hash ]], 
		1, --ammoCount --[[ integer ]], 
		false, --bForceInHand --[[ boolean ]], 
		false, --bForceInHolster --[[ boolean ]], 
		0, ----attachPoint --[[ integer ]], 
		false,--bAllowMultipleCopies --[[ boolean ]], 
		1, --p7 --[[ number ]], 
		1, --p8 --[[ number ]], 
		`ADD_REASON_DEFAULT`, --addReason --[[ Hash ]], 
		false, --bIgnoreUnlocks --[[ boolean ]], 
		false, --permanentDegradation --[[ number ]], 
		true--p12 --[[ boolean ]]
	)

    --WEAPON::GIVE_WEAPON_TO_PED(iParam0, iVar0, iParam9, bParam2, bParam5, bParam4, bParam11, 0.5f, 1.0f, joaat("ADD_REASON_DEFAULT"), bVar22, fVar25, false);
    --AddItemToInventory(`CONSUMABLE_PEACHES_CAN`, 1)
    AddItemToInventory(`WEAPON_MELEE_LANTERN`, 1)
end
Start()

