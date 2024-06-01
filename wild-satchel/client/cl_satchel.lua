PlayerInventory = nil
_playerInventory = nil

RegisterNetEvent("wild:sv_onReceivePlayerInventory", function(newInventory)
    _playerInventory = newInventory	
end)

function RefreshPlayerInventory()
    TriggerServerEvent("wild:sv_getPlayerInventory", GetPlayerName(PlayerId()))

    while _playerInventory == nil do
        Citizen.Wait(0)
    end

    PlayerInventory = _playerInventory
    _playerInventory = nil
end

function GetItemModel(item)
	local info = NewItemInfo()

	if false == ItemdatabaseIsKeyValid(item, 0) then
        print("ERROR: ItemdatabaseIsKeyValid is not valid")
		return 0
    end

	if false == Citizen.InvokeNative(0xFE90ABBCBFDC13B2, item, info:Buffer()) then
        print("ERROR: ItemdatabaseFilloutItemInfo returned error")
		return 0
    end

	return info:GetInt32(32);
end

function SatchelAddItem(item, quantity, bNoUpdate)
    if not ItemdatabaseIsKeyValid(item, 0) then
		return false
    end

    if quantity < 1 then
        return false
    end

    -- Initial population of satchel should have bNoUpdate=true to avoid saving on start.
    if not(bNoUpdate == true) then
        -- Add to our inventory first
        local key = tostring(item)

        -- Update current quantity

        if PlayerInventory[key] == nil then
            PlayerInventory[key] = 0
        end
        
        PlayerInventory[key] = PlayerInventory[key] + quantity

        -- Do the same on the server
        TriggerServerEvent("wild:satchel:cl_add", key, quantity)
        
        ShowInventoryToast(item, true)
    end

    -- Add to native inventory
    AddItemToInventory(item, quantity)

    return true
end
W.RegisterExport("Satchel", "AddItem", SatchelAddItem)


function SatchelRemoveItem(item, quantity)
    if not ItemdatabaseIsKeyValid(item, 0) then
		return false
    end

    if quantity < 1 then
        return false
    end

    -- Add to our inventory first
    local key = tostring(item)

    -- Update current quantity

    if PlayerInventory[key] == nil then
        PlayerInventory[key] = 0
    end
    
    PlayerInventory[key] = PlayerInventory[key] - quantity

    if PlayerInventory[key] < 1 then
        PlayerInventory[key] = nil
    end

    -- Do the same on the server
    TriggerServerEvent("wild:satchel:cl_remove", key, quantity)
    
    ShowInventoryToast(item, false)

    -- Remove from native inventory
    RemoveItemFromInventory(item, quantity)

    return true
end
W.RegisterExport("Satchel", "AddItem", SatchelAddItem)





function OnStart()
    -- Make sure we start clean
    ClearInventory()

   --------------------
    W.UI.DestroyMenuAndData("satchel")

    Citizen.Wait(1000)
    W.UI.CreateMenu("satchel", true)

    W.UI.CreatePage("satchel", "grid", "Satchel", "Provisions", 1, 4);
    W.UI.SetMenuRootPage("satchel", "grid");
    
    RefreshPlayerInventory()

    for itemHash in pairs(PlayerInventory) do
        quantity = PlayerInventory[itemHash]
        itemHash = tonumber(itemHash)

        SatchelAddItem(itemHash, quantity, true)
    end    
end
OnStart()

--[[
    -- https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/ItemDatabaseItemFlags
     -- ITEM_FLAG_QUALITY_PRISTINE
]]

function RepopulateGrid()
    W.UI.DestroyPage("satchel", "grid")
    Citizen.Wait(100)
    W.UI.CreatePage("satchel", "grid", "Satchel", "Provisions", 1, 4);

    local gridItems = GetInventoryWithFilter("ALL")

    for i=1, #gridItems do
        local gridItem = gridItems[i]

        local sellPrice = 0.00;

        --[[
            struct ItemSellPrices
            {
                string key;
                int quantity;
                string costtype;
                array<struct ItemCostDef> items;
                array<struct ItemUnlocksDef> unlocks;
            };
        ]]
        local struct = DataView.ArrayBuffer(128)
        struct:SetInt32(0, 0) -- 816454899, unknown hash, all sellable catalog items have it
        struct:SetInt32(8, 0) -- 1, quantity ?
        struct:SetInt32(16, 0) -- 1400824947, costtype hash
        struct:SetInt32(24, 0) -- 1, quantity ?
        struct:SetInt32(32, 10)
        struct:SetInt32(40, 0) -- sell award? It's CURRENCY_CASH 99% of the time
        struct:SetInt32(48, 0) -- award amount (cash amount)

        if Citizen.InvokeNative(0x7A62A2EEDE1C3766, gridItem.item, `SELL_SHOP_DEFAULT`, struct:Buffer()) == 1 then -- use ItemdatabaseFilloutAcquireCost for items that don't sell (weapons, peaches, etc)
            if struct:GetInt32(40) == `CURRENCY_CASH` then
                sellPrice = struct:GetInt32(48) / 100
            end            
        end
            
        local params = {}
        params.icon = "item_textures/"..tostring(gridItem.ui.textureId)..".png";
        params.description = gridItem.ui.name .. " (x"..tostring(gridItem.quantity)..")";
        params.detail = gridItem.ui.description .. "\n\nSells for $"..FormatMoney(sellPrice);

        -- Interesting places for ref: generic_multibite_item.c, generic_single_use_item.c, generic_smoking_item.c, generic_document_inspection.c (SET_CUSTOM_TEXTURES_ON_OBJECT)
        params.action = function()  
            bEdible = false

            if GetItemGroup(gridItem.item) == `provision` then
                if InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 24)) == 1 then
                    bEdible = true
                end
            end

            if GetItemGroup(gridItem.item) == `consumable` then
                bEdible = true
            end

            if bEdible then
                local playerPed = PlayerPedId()
                RequestAnimDict("mech_inventory@eating@canned_food@cylinder@d8-2_h10-5")
                while not HasAnimDictLoaded("mech_inventory@eating@canned_food@cylinder@d8-2_h10-5") do
                    Wait(100)
                end
                TaskPlayAnim(playerPed, "mech_inventory@eating@canned_food@cylinder@d8-2_h10-5", "left_hand", 8.0, -8.0, -1, 1 << 4 | 1 << 3 | 1 << 16, 0.0, false, 0, false, "UpperBodyFixup_filter", false)
            end            
        end
    
        W.UI.CreatePageItem("satchel", "grid", "item_"..gridItem.item, params);
        --ShowInventoryToast(item.item, true)
    end

end

function OpenSatchel()
    RepopulateGrid()
    W.UI.OpenMenu("satchel", true)
end



Citizen.CreateThread(function()
    while true do   
        Citizen.Wait(0)  

        if IsControlJustPressed(0, "INPUT_OPEN_SATCHEL_MENU") and not bOutfitLock then
            local prompt = 0

            -- Create prompt
            if prompt == 0 then
                prompt = PromptRegisterBegin()
                PromptSetControlAction(prompt, GetHashKey("INPUT_OPEN_SATCHEL_MENU")) -- L key
                PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", "Satchel"))
                UiPromptSetHoldMode(prompt, 100)
                UiPromptSetAttribute(prompt, 2, true) 
                UiPromptSetAttribute(prompt, 4, true) 
                UiPromptSetAttribute(prompt, 9, true) 
                UiPromptSetAttribute(prompt, 10, true) -- kPromptAttrib_NoButtonReleaseCheck. Immediately becomes pressed
                UiPromptSetAttribute(prompt, 17, true) -- kPromptAttrib_NoGroupCheck. Allows to appear in any active group
                PromptRegisterEnd(prompt)

                Citizen.CreateThread(function()
                    Citizen.Wait(100)

                    while UiPromptGetProgress(prompt) ~= 0.0 and UiPromptGetProgress(prompt) ~= 1.0 do   
                        Citizen.Wait(0)
                    end

                    if UiPromptGetProgress(prompt) == 1.0 then
                        OpenSatchel()
                    end

                    PromptDelete(prompt)
                    prompt = 0

                    Citizen.Wait(1000)
                end)
            end
        end
    end
end)


-- Picking up objects in the world to place in satchel
W.Events.AddHandler(`EVENT_INVENTORY_ITEM_PICKED_UP`, function(data)
    local inventoryItemHash = data[1]
    local entityPickedModel = data[2]
    local iItemWasUsed = data[3]
    local iItemWasBought = data[4]
    local entityPicked = data[5]

    ShowText("Item pickup")
end)

-- Triggers when skinning or looting peds
W.Events.AddHandler(`EVENT_LOOT_COMPLETE`, function(data)
	local playerPed = PlayerPedId()

	local looterPed = data[1]
	local ped = data[2]
	local success = data[3]

	if looterPed == playerPed and success == 1 then
		if GetMetaPedType(ped) == 3 then -- animal = 3

            local lootList = W.GetPedLoot(ped)

            for i=1, #lootList do
                if InventoryGetInventoryItemIsAnimalPelt(lootList[i]) ~= 1 then -- skip carriable pelts that belong on horses
                    SatchelAddItem(lootList[i], 1)
                end
            end
		end
	end
end)



RegisterCommand('iguana', function() 
	local x, y, z = table.unpack(GetEntityCoords(GetPlayerPed(PlayerId()), false))

    local model = `A_C_Iguana_01`

    RequestModel(model)

    while not HasModelLoaded(model) do
        RequestModel(model)
        Citizen.Wait(0)
    end

    local ped = CreatePed(model, x, y+1.0, z, 45.0, true, true, true)
    SetEntityInvincible(ped, true)
    SetPedKeepTask(ped)
    SetPedAsNoLongerNeeded(ped)
    SetRandomOutfitVariation(ped)

    SetEntityHealth(ped, 0)
end, false)

RegisterCommand('chocolate', function() 
	SatchelAddItem(`consumable_chocolate_bar`, 5)
end, false)

RegisterCommand('gunoil', function() 
	SatchelAddItem(`kit_gun_oil`, 5)
end, false)

--[[
    
    local registry = json.decode(LoadResourceFile(GetCurrentResourceName(), "catalog.json"))

    for i=1, #registry do
        registry[i] = tonumber(registry[i])

        

        local itemUiData = GetItemUiData(registry[i])

        local info = NewItemInfo()
        Citizen.InvokeNative(0xFE90ABBCBFDC13B2, registry[i], info:Buffer())

        

        local category = info:GetInt32(8)
        local group = info:GetInt32(16)

        

        print(group)

        if group == 0 then
            goto skip
        end

        if (group == `CLOTHING` and category ~= 0x851ebbd3) or group == `EMOTE` or group == `UPGRADE` then
            goto skip
        end

        if itemUiData.name == "" or itemUiData.name == " " then
            goto skip
        end        

        print("Adding " .. itemUiData.name .. ", ("..tostring(i).." of "..tostring(#registry)..")...")

        TriggerServerEvent("wild:sv_addToCatalog", registry[i], {
            itemUiData.name, itemUiData.description, GetHashKey(itemUiData.textureId), itemUiData.textureDict
        })

        :: skip ::
        Citizen.Wait(0)
    end
]]
