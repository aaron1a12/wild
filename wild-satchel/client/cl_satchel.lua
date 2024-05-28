-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

function OnStart()
    W.UI.DestroyMenuAndData("satchel")

    Citizen.Wait(1000)
    W.UI.CreateMenu("satchel", true)

    
    W.UI.CreatePage("satchel", "root", "Satchel", "Provisions", 1, 4); -- Update subtitle:  W.UI.SetElementTextByClass("warMenu", "menuSubtitle", "Not in faction")
    W.UI.SetMenuRootPage("satchel", "root");

   --[[for i=1, 10 do
        local params = {}
        params.icon = "item_textures/consumable_medicine.png";
        params.description = "Item description";
        params.action = function()
        end
    
        W.UI.CreatePageItem("satchel", "root", 0, params);
    end]]
end
OnStart()



function OpenSatchel()
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


RegisterCommand('iguana', function() 
	local x, y, z = table.unpack(GetEntityCoords(GetPlayerPed(PlayerId()), false))

    local model = `A_C_Rat_01`

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
                local item = lootList[i]
                ShowInventoryToast(item)
            end

            --
            -- Add to satchel inventory
            -- TODO: make persistent.
            --

            -- When skinning, we don't want to add to the inventory the actual pelt we're carrying.
            -- However, the carried entity only registers after two ticks so we'll wait here.
            Citizen.Wait(1)

            local carriedEntity = GetFirstEntityPedIsCarrying(playerPed)
            local carriedPelt = 0

            if carriedEntity ~= 0 then
                if GetIsCarriablePelt(carriedEntity) then
                    carriedPelt = GetCarriableFromEntity(carriedEntity)
                    
                end
            end

            for i=1, #lootList do
                local catalogItem = itemCatalogSp[lootList[i]]

                if carriedPelt == lootList[i] then
                    -- Skip this item since it is a carriable.
                    goto skip
                end
    
                local params = {}
                params.icon = "item_textures/"..tostring(catalogItem[2])..".png";
                params.description = catalogItem[1];
                params.action = function()
                end
            
                W.UI.CreatePageItem("satchel", "root", 0, params);
                :: skip ::
            end

		end
	end
end)