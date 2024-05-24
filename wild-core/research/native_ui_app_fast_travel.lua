CloseUiappByHash(`fast_travel_menu`)

function OpenFastTravelMenu()
    LaunchUiappByHash(`FAST_TRAVEL_MENU`)

    -- Get or create the data container for the ui app, in this case, FastTravel
    local fastTravelData = DatabindingGetDataContainerFromPath("FastTravel")
    if fastTravelData == 0 then
        fastTravelData = DatabindingAddDataContainerFromPath("", "FastTravel")
    end

    DatabindingAddDataString(fastTravelData, "header", "Menu")
    DatabindingAddDataString(fastTravelData, "subHeader", "Locations")
    DatabindingAddDataString(fastTravelData, "description", "description")
    DatabindingAddDataString(fastTravelData, "subFooter", "Sub footer")
    DatabindingAddDataString(fastTravelData, "bounty", "")
    --DatabindingAddDataString(fastTravelData, "bounty", "You have a bounty")

    local itemList = DatabindingAddUiItemList(fastTravelData, "locationList")
    DatabindingClearBindingArray(itemList)

    -- Dummy data. Should be a json.
    local items = {}

    -- Populate with fake data
    for i=1, 5 do
        table.insert(items, {
            name = "Item #"..tostring(i),
            price =  1.25,
            desc = "Random comment for item #" .. tostring(i)
        })
    end

    -- Looop through the dummy data and add items for each
    for i=1, #items do
        local priceDollars, priceCents = math.modf(items[i].price)

        local item = DatabindingAddDataContainer(fastTravelData, "item"..tostring(i))
        DatabindingAddDataString(item, "dynamic_list_item_raw_text_entry", items[i].name)
        DatabindingAddDataInt(item, "dynamic_list_item_extra_int_field_one_value", math.ceil(priceDollars*100))
        DatabindingAddDataInt(item, "dynamic_list_item_extra_int_field_two_value", math.ceil(priceCents*100))
        DatabindingAddDataHash(item, "dynamic_list_item_event_channel_hash", `FAST_TRAVEL_MENU`)
        DatabindingAddDataBool(item, "dynamic_list_item_enabled", true)
        DatabindingAddDataHash(item, "dynamic_list_item_focus_hash", 42753526)
        DatabindingAddDataHash(item, "dynamic_list_item_select_hash", 42753526) -- selection sound        
        DatabindingAddDataHash(item, "dynamic_list_item_prompt_text", `IB_BUY_NOW`)
        DatabindingAddDataInt(item, "index", i) -- custom data

        DatabindingInsertUiItemToListFromContextStringAlias(itemList, -1, "ft_dynamic_text_and_price", item)
    end

    Citizen.CreateThread(function()
        while IsUiappRunningByHash(`FAST_TRAVEL_MENU`) == 1 do
            N_0x066167c63111d8cf(1.0, 1, 0.0, 1, 0.9) -- Focus zoom

            -- Listen for ui events
            while EventsUiIsPending(`FAST_TRAVEL_MENU`) do
                local msg = DataView.ArrayBuffer(8 * 4)
                msg:SetInt32(0, 0)
                msg:SetInt32(8, 0)
                msg:SetInt32(16, 0)
                msg:SetInt32(24, 0) -- item data container

                if (Citizen.InvokeNative(0x90237103F27F7937, `FAST_TRAVEL_MENU`, msg:Buffer()) ~= 0) then -- EVENTS_UI_PEEK_MESSAGE

                    if msg:GetInt32(0) == `ITEM_FOCUSED` then
                        local index = DatabindingReadDataIntFromParent(msg:GetInt32(24), "index")
                        DatabindingWriteStringFromParent(fastTravelData, "description", items[index].desc)
                    end

                    if msg:GetInt32(0) == `ITEM_SELECTED` then
                        local index = DatabindingReadDataIntFromParent(msg:GetInt32(24), "index")
                        ShowText("Item selected: "..tostring(index))
                    end

                    if msg:GetInt32(16) == `FAST_TRAVEL_UI_EVENT_EXIT` then
                        CloseUiappByHash(`fast_travel_menu`)
                        -- Free up memory?
                        DatabindingRemoveDataEntry(fastTravelData)
                        DatabindingRemoveDataEntry(itemList)
                    end

                    if msg:GetInt32(16) == `FAST_TRAVEL_UI_EVENT_FILTER` then
                        ShowText("Filter")
                    end
                end

                EventsUiPopMessage(`FAST_TRAVEL_MENU`)
            end

            Citizen.Wait(0)
        end
    end)
end

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

        if IsControlJustPressed(0, `INPUT_FRONTEND_DELETE`) then
            OpenFastTravelMenu()
		end
    end
end)