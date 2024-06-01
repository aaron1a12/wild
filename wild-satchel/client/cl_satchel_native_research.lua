function OpenSatchel()

    --TASK::TASK_PLAY_ANIM(Global_34, func_3189(bParam0->f_61), func_3190(bParam0->f_61), 8f, -8f, -1, 67108880, 0f, false, 4096, false, "Satchel_Only_filter", false);


    --LaunchUiappByHash(`satchel`)
    LaunchUiappByHashWithEntry(`satchel`, `INGAME`)

    -- Get or create the data container for the ui app, in this case, Satchel
    local satchelData = DatabindingGetDataContainerFromPath("Satchel")
    if satchelData == 0 then
        print("creating satchel")
        satchelData = DatabindingAddDataContainerFromPath("", "Satchel")
    end

    DatabindingAddDataBool(satchelData, "FolderEmpty", false)

    

    local selectedData = DatabindingAddDataContainer(satchelData, "Selected")
    DatabindingAddDataHash(selectedData, "Name", 0)
    DatabindingAddDataHash(selectedData, "Category", 0)
    DatabindingAddDataInt(selectedData, "DefaultCategoryIndex", 0)
    DatabindingAddDataInt(selectedData, "CategoryIndex", 0)
    DatabindingAddDataInt(selectedData, "CategoryCount", 0) -- enables category switch if > 1
    DatabindingAddDataString(selectedData, "IndexDescription", "[1 of ???]")
    DatabindingAddDataString(selectedData, "Tip", "[tip]")
    N_0x9d21b185abc2dbc4(selectedData, "effects", 0, 0)
    DatabindingAddDataHash(selectedData, "Folder", 0)

    -- Exists before we make it??
    local satchelCategoryItemsData = DatabindingGetDataContainerFromPath("satchel_category_items")
    local satchelMenuItemsData = DatabindingGetDataContainerFromPath("satchel_menu_items")
    local satchelListItemsData = DatabindingGetDataContainerFromPath("satchel_list_items")
    

    DatabindingSetTemplatedUiItemListSize(satchelListItemsData, 3)
    DatabindingSetTemplatedUiItemListSize(satchelMenuItemsData, 3)


    local collectionsList = DatabindingAddUiItemList(satchelData, "Collections")

    local playerDat = DatabindingAddDataContainer(collectionsList, "player")
    DatabindingAddDataHash(playerDat, "label", `SATCHEL_TITLE`)
    DatabindingInsertUiItemToListFromContextHashAlias(collectionsList, -1, -1287062382, playerDat)


    local menuList = DatabindingAddUiItemList(satchelMenuItemsData, "List")
    local item = DatabindingAddDataContainer(satchelData, "fooba2r")
    DatabindingInsertUiItemToListFromContextStringAlias(menuList, -1, "ft_dynamic_text_and_price", item)

    Citizen.CreateThread(function()
        while IsUiappRunningByHash(`satchel`) == 1 do

            -- Listen for ui events
            while EventsUiIsPending(`satchel`) do
                local msg = DataView.ArrayBuffer(8 * 4)
                msg:SetInt32(0, 0)
                msg:SetInt32(8, 0)
                msg:SetInt32(16, 0)
                msg:SetInt32(24, 0) -- item data container

                if (Citizen.InvokeNative(0x90237103F27F7937, `satchel`, msg:Buffer()) ~= 0) then -- EVENTS_UI_PEEK_MESSAGE

                    if msg:GetInt32(0) == `ITEM_FOCUSED` then
                        ShowText("Focus")
                    end

                    if msg:GetInt32(0) == `ITEM_SELECTED` then
                        ShowText("Select")
                    end

                    if msg:GetInt32(16) == `SATCHEL_UI_EVENT_EXIT` then
                    end

                    if msg:GetInt32(16) == `SATCHEL_UI_EVENT_FILTER` then
                        ShowText("Filter")
                    end
                end

                EventsUiPopMessage(`satchel`)
            end

            Citizen.Wait(0)
        end

        DatabindingRemoveDataEntry(satchelData)
        DatabindingRemoveDataEntry(selectedData)
        DatabindingRemoveDataEntry(collectionsList)
        DatabindingRemoveDataEntry(menuList)
        
        
    end)
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
                UiPromptSetHoldMode(prompt, 750)
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