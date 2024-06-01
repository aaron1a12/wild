--
-- Shared Event Functionality
--

W.Events = {}
W.EventHandlerMap = {}

-- Source: https://github.com/femga/rdr3_discoveries/tree/master/AI/EVENTS
-- TODO: Add all events
W.EventDataInfo = {
    [`EVENT_PLAYER_ESCALATED_PED`] = {
        size = 2,
        members = {"Int32", "Int32"} -- player ped id | escalated ped id
    }, 
    [`EVENT_CALM_PED`] = {
        size = 4,
        members = {"Int32", "Int32", "Int32", "Int32"} -- calmer ped id | mount ped id | CalmTypeId | isFullyCalmed
    }, 
    [`EVENT_CARRIABLE_UPDATE_CARRY_STATE`] = {
        size = 5,
        members = {"Int32", "Int32", "Int32", "Int32", "Int32"} --  CarriableEntityId | PerpitratorEntityId | CarrierEntityId | IsOnHorse | IsOnGround
    },
    [`EVENT_CRIME_CONFIRMED`] = {
        size = 3,
        members = {"Int32", "Int32", "Int32"} -- crime type hash | criminal ped id | witness
    },
    [`EVENT_ENTITY_BROKEN`] = {
        size = 9,
        members = {"Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Float32", "Float32", "Float32"}
    },
    [`EVENT_ENTITY_DAMAGED`] = {
        size = 9,
        members = {"Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Float32", "Float32", "Float32"} --| entity | object (or ped id) that caused damage | weaponHash | ammo | damage amount | unknown | coord z | coord y | coord z
    },
    [`EVENT_ENTITY_DESTROYED`] = {
        size = 9,
        members = {"Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Float32", "Float32", "Float32"} --| entity | object (or ped id) that caused damage | weaponHash | ammo | damage amount | unknown | coord z | coord y | coord z
    },
    [`EVENT_INVENTORY_ITEM_PICKED_UP`] = {
        size = 5,
        members = {"Int32", "Int32", "Int32", "Int32", "Int32"} -- inventory item hash | picked up entity model | isItemWasUsed | isItemWasBought | picked up entity id
    },
    [`EVENT_LOOT_COMPLETE`] = {
        size = 3,
        members = {"Int32", "Int32", "Int32"} -- looter, ped, success
    },
    [`EVENT_ENTITY_EXPLOSION`] = {
        size = 6,
        members = {"Int32", "Int32", "Int32", "Float32", "Float32", "Float32"} -- ped id who did explosion | unknown | weaponhash | explosion coord x | explosion coord y | explosion coord z
     }, 
    [`EVENT_INVENTORY_ITEM_PICKED_UP`] = {
        size = 5,
        members = {"Int32", "Int32", "Int32", "Int32", "Int32"} -- inventory item hash | picked up entity model | isItemWasUsed | isItemWasBought | picked up entity id
    },
    [`EVENT_PED_ANIMAL_INTERACTION`] = {
        size = 3,
        members = {"Int32", "Int32", "Int32"} -- ped | animal ped | interaction type hash
    },
    [`EVENT_PLAYER_PROMPT_TRIGGERED`] = {
        size = 10,
        members = {"Int32", "Int32", "Int32", "Int32", "Float32", "Float32", "Float32", "Int32", "Int32", "Int32"} -- prompt type id | unknown | target entity id | unknown (??? discovered inventory item) | player coord x | player coord y | player  coord z | discoverable entity type id ( list ) | unknown | kit_emote_action hash ( list )
    }
}

function W.Events.AddHandler(evtHash, handler)
    if W.EventHandlerMap[evtHash] == nil then
        W.EventHandlerMap[evtHash] = {}
    end

    local resource = GetInvokingResource()

    if resource == nil then
        resource = GetCurrentResourceName()
    end

    if W.EventHandlerMap[evtHash][resource] == nil then
        W.EventHandlerMap[evtHash][resource] = {}
    end

    table.insert(W.EventHandlerMap[evtHash][resource], handler)
end

Citizen.CreateThread(function()
    while true do    
        Citizen.Wait(0)   
        
        local size = GetNumberOfEvents(0) -- SCRIPT_EVENT_QUEUE_AI)

        for i = 0, size - 1 do
            if size > 0 then
                
                local event = GetEventAtIndex(0, i)

                if W.EventHandlerMap[event] ~= nil then -- We have handlers

                    local dataInfo = W.EventDataInfo[event]

                    if dataInfo == nil then
                        print("Unsupported event. Investigate by invoking native 0x57EC5FA4D4D6AFCA and test for valid dataSize values (size = dataStruct member count)")
                    else                        
                        local dataSize = dataInfo.size
                        local dataStruct = DataView.ArrayBuffer(128)

                        for i = 0, dataSize - 1 do
                            dataStruct:SetInt32(8 * i, 0) -- Set all members to zero
                        end

                        -- Retrieve the data, passing the pointer to our buffer
                        Citizen.InvokeNative(0x57EC5FA4D4D6AFCA, 0, i, dataStruct:Buffer(), dataSize)

                        -- Simple lua array
                        local data = {}

                        -- Copy the data struct members
                        for i = 0, dataSize - 1 do
                            -- Insert function named after member data type. E.g., "GetInt32", "GetFloat32", etc
                            local label = "Get" .. dataInfo.members[i + 1]
                            local dataMember = dataStruct[label](dataStruct, 8 * i)
                            table.insert(data, dataMember)
                        end

                        -- Pass the data to the handlers
                        for resourceName, resourceHandlers in pairs(W.EventHandlerMap[event]) do
                            for _, handler in pairs(resourceHandlers) do
                                handler(data)
                            end
                        end

                    end
                end
            end
        end
    end     
end)

-- The garbage collection
AddEventHandler('onResourceStop', function(resourceName)
    for evtHash, resources in pairs(W.EventHandlerMap) do
        resources[resourceName] = {}
        collectgarbage("collect")
    end
end)