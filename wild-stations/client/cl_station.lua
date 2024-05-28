-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()
wildData = DatabindingGetDataContainerFromPath("wild")

local stations = stationConfig.stations
local prompts = {}
local blips = {}

function SetupStations()
    for i = 1, #stations do
        local station = stations[i]

        for i = 1, #station.booths do
            local prompt = PromptRegisterBegin()
            PromptSetControlAction(prompt, `INPUT_CONTEXT_X`) -- R key
            PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", "Post Office"))
            UiPromptSetHoldMode(prompt, 600)
            UiPromptContextSetPoint(prompt, station.booths[i][1], station.booths[i][2], station.booths[i][3])
            UiPromptContextSetRadius(prompt, 1.0)
            PromptRegisterEnd(prompt)
        
            -- Useful management. Automatically deleted when restarting resource
            W.Prompts.AddToGarbageCollector(prompt)
    
            table.insert(prompts, prompt)
        end


        local blip = BlipAddForCoords(`BLIP_STYLE_SHOP`, station.location[1], station.location[2], station.location[3])
        SetBlipSprite(blip, `blip_post_office`, true)
        SetBlipScale(blip, 0.2)
        SetBlipName(blip, "Station")
        table.insert(blips, blip)
    end    
end
SetupStations()

-- Cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for i=1, #blips do
			local blip = blips[i]
            RemoveBlip(blip)            
        end  
    end
end)

--
-- Menu Commands
--

local bountyPrice = 20.00
function OnPayBounty()
    local difference = -75.0-W.GetPlayerHonor()

    W.AddPlayerHonor(difference+0.001)
    W.DismissBountyHunters()

    TriggerServerEvent("wild:sv_giveMoney", GetPlayerName(PlayerId()), -bountyPrice)
end

--
-- Menu
--

local btnPayBounty = 0

function UpdatePayBountyButton()
    if W.GetPlayerHonor() > -75.0 or W.GetPlayerMoney() < bountyPrice then
        DatabindingAddDataBool(btnPayBounty, "dynamic_list_item_enabled", false)
    else
        DatabindingAddDataBool(btnPayBounty, "dynamic_list_item_enabled", true)
    end
end

CloseUiappByHash(`fast_travel_menu`)
function OpenPostOffice()
    LaunchUiappByHash(`FAST_TRAVEL_MENU`)

    -- Get or create the data container for the ui app, in this case, FastTravel
    local fastTravelData = DatabindingGetDataContainerFromPath("FastTravel")
    if fastTravelData == 0 then
        fastTravelData = DatabindingAddDataContainerFromPath("", "FastTravel")
    end

    DatabindingAddDataString(fastTravelData, "header", "Post Office")
    DatabindingAddDataString(fastTravelData, "subHeader", "Actions")
    DatabindingAddDataString(fastTravelData, "description", "description")
    DatabindingAddDataString(fastTravelData, "subFooter", "Sub footer")
    DatabindingAddDataString(fastTravelData, "bounty", "")

    local itemList = DatabindingAddUiItemList(fastTravelData, "locationList")
    DatabindingClearBindingArray(itemList)

    local priceDollars, priceCents = math.modf(bountyPrice)

    btnPayBounty = DatabindingAddDataContainer(fastTravelData, "btnPayBounty")
    DatabindingAddDataString(btnPayBounty, "dynamic_list_item_raw_text_entry", "Pay Bounty")
    DatabindingAddDataInt(btnPayBounty, "dynamic_list_item_extra_int_field_one_value", math.ceil(priceDollars*100))
    DatabindingAddDataInt(btnPayBounty, "dynamic_list_item_extra_int_field_two_value", math.ceil(priceCents*100))
    DatabindingAddDataHash(btnPayBounty, "dynamic_list_item_event_channel_hash", `FAST_TRAVEL_MENU`)
    DatabindingAddDataHash(btnPayBounty, "dynamic_list_item_focus_hash", 42753526)
    DatabindingAddDataHash(btnPayBounty, "dynamic_list_item_select_hash", 42753526)
    DatabindingAddDataHash(btnPayBounty, "dynamic_list_item_prompt_text", `IB_PAY`)
    DatabindingAddDataInt(btnPayBounty, "index", 0) -- custom data
    UpdatePayBountyButton()

    DatabindingInsertUiItemToListFromContextStringAlias(itemList, -1, "ft_dynamic_text_and_price", btnPayBounty)

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
                        if btnPayBounty == msg:GetInt32(24) then
                            DatabindingWriteStringFromParent(fastTravelData, "description", "Stop bounty hunters from attacking.")
                        end
                    end

                    if msg:GetInt32(0) == `ITEM_SELECTED` then
                        if DatabindingReadDataBoolFromParent(msg:GetInt32(24), "dynamic_list_item_enabled") == 1 then
                            if btnPayBounty == msg:GetInt32(24) then
                                OnPayBounty()
                                UpdatePayBountyButton()
                            end
                        end
                    end

                    if msg:GetInt32(16) == `FAST_TRAVEL_UI_EVENT_EXIT` then
                        RequestUiappTransitionByHash(`fast_travel_menu`, `EXIT`)
                        CloseUiappByHash(`fast_travel_menu`)
                        -- Free up memory?
                        DatabindingRemoveDataEntry(fastTravelData)
                        DatabindingRemoveDataEntry(itemList)
                    end

                    if msg:GetInt32(16) == `FAST_TRAVEL_UI_EVENT_FILTER` then
                        if msg:GetInt32(0) == 703281244 then
                            ShowText("filter forward")
                        end
    
                        if msg:GetInt32(0) == -722926211 then
                            ShowText("filter back")
                        end
                    end
                end

                EventsUiPopMessage(`FAST_TRAVEL_MENU`)
            end

            Citizen.Wait(0)
        end
    end)
end

--
-- Prompt check
--

local waitTime = 1150
Citizen.CreateThread(function()
    while true do    
        Citizen.Wait(waitTime)   
        
        local bAnyPromptActive = false
        for i = 1, #prompts do
            local prompt = prompts[i]

            if PromptIsActive(prompt) then
                bAnyPromptActive = true
                
                if UiPromptGetProgress(prompt) == 1.0 then
                    OpenPostOffice()
                end

                break
            end
        end

        if bAnyPromptActive then
            waitTime = 0
        else
            waitTime = 1150
        end

    end     
end)