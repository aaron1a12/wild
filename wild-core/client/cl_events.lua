--
-- Shared Event Functionality
--

W.Events = {}
W.EventHandlerMap = {}

-- Source: https://github.com/femga/rdr3_discoveries/tree/master/AI/EVENTS
-- TODO: Add all events
W.EventDataInfo = {
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
}

function W.Events.AddHandler(evtHash, handler)
    if W.EventHandlerMap[evtHash] == nil then
        W.EventHandlerMap[evtHash] = {}
    end

    table.insert(W.EventHandlerMap[evtHash], handler)
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
                            table.insert(data, dataStruct[label](dataStruct, 8 * i))
                        end

                        -- Pass the data to the handlers
                        for _, handler in pairs(W.EventHandlerMap[event]) do
                            handler(data)
                        end
                    end
                end
            end
        end
    end     
end)