--
-- Shared Event Functionality
--

-- Source: https://github.com/femga/rdr3_discoveries/tree/master/AI/EVENTS
-- TODO: Add all events
W.EventDataInfo = {
    [`EVENT_PLAYER_ESCALATED_PED`] = {
        name = "EVENT_PLAYER_ESCALATED_PED",
        size = 2,
        members = {"Int32", "Int32"} -- player ped id | escalated ped id
    }, 
    [`EVENT_CALM_PED`] = {
        name = "EVENT_CALM_PED",
        size = 4,
        members = {"Int32", "Int32", "Int32", "Int32"} -- calmer ped id | mount ped id | CalmTypeId | isFullyCalmed
    }, 
    [`EVENT_CARRIABLE_UPDATE_CARRY_STATE`] = {
        name = "EVENT_CARRIABLE_UPDATE_CARRY_STATE",
        size = 5,
        members = {"Int32", "Int32", "Int32", "Int32", "Int32"} --  CarriableEntityId | PerpitratorEntityId | CarrierEntityId | IsOnHorse | IsOnGround
    },
    [`EVENT_CRIME_CONFIRMED`] = {
        name = "EVENT_CRIME_CONFIRMED",
        size = 3,
        members = {"Int32", "Int32", "Int32"} -- crime type hash | criminal ped id | witness
    },
    [`EVENT_ENTITY_BROKEN`] = {
        name = "EVENT_ENTITY_BROKEN",
        size = 9,
        members = {"Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Float32", "Float32", "Float32"}
    },
    [`EVENT_ENTITY_DAMAGED`] = {
        name = "EVENT_ENTITY_DAMAGED",
        size = 9,
        members = {"Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Float32", "Float32", "Float32"} --| entity | object (or ped id) that caused damage | weaponHash | ammo | damage amount | unknown | coord z | coord y | coord z
    },
    [`EVENT_ENTITY_DESTROYED`] = {
        name = "EVENT_ENTITY_DESTROYED",
        size = 9,
        members = {"Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Float32", "Float32", "Float32"} --| entity | object (or ped id) that caused damage | weaponHash | ammo | damage amount | unknown | coord z | coord y | coord z
    },
    [`EVENT_INVENTORY_ITEM_PICKED_UP`] = {
        name = "EVENT_INVENTORY_ITEM_PICKED_UP",
        size = 5,
        members = {"Int32", "Int32", "Int32", "Int32", "Int32"} -- inventory item hash | picked up entity model | isItemWasUsed | isItemWasBought | picked up entity id
    },
    [`EVENT_INVENTORY_ITEM_REMOVED`] = {
        name = "EVENT_INVENTORY_ITEM_REMOVED",
        size = 1,
        members = {"Int32"} -- inventory item hash
    },
    [`EVENT_ITEM_PROMPT_INFO_REQUEST`] = {
        name = "EVENT_ITEM_PROMPT_INFO_REQUEST",
        size = 2,
        members = {"Int32", "Int32"} -- entity id, requesting prompt info | inventory item hash
    },
    [`EVENT_LOOT_COMPLETE`] = {
        name = "EVENT_LOOT_COMPLETE",
        size = 3,
        members = {"Int32", "Int32", "Int32"} -- looter, ped, success
    },
    [`EVENT_LOOT`] = {
        name = "EVENT_LOOT",
        size = 36,
        members = {"Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32", "Int32"}
    },
    [`EVENT_ENTITY_EXPLOSION`] = {
        name = "EVENT_ENTITY_EXPLOSION",
        size = 6,
        members = {"Int32", "Int32", "Int32", "Float32", "Float32", "Float32"} -- ped id who did explosion | unknown | weaponhash | explosion coord x | explosion coord y | explosion coord z
     }, 
    [`EVENT_INVENTORY_ITEM_PICKED_UP`] = {
        name = "EVENT_INVENTORY_ITEM_PICKED_UP",
        size = 5,
        members = {"Int32", "Int32", "Int32", "Int32", "Int32"} -- inventory item hash | picked up entity model | isItemWasUsed | isItemWasBought | picked up entity id
    },
    [`EVENT_PED_CREATED`] = {
        name = "EVENT_PED_CREATED",
        size = 1,
        members = {"Int32"}
    },
    [`EVENT_PED_DESTROYED`] = {
        name = "EVENT_PED_DESTROYED",
        size = 1,
        members = {"Int32"}
    },
    [`EVENT_PED_ANIMAL_INTERACTION`] = {
        name = "EVENT_PED_ANIMAL_INTERACTION",
        size = 3,
        members = {"Int32", "Int32", "Int32"} -- ped | animal ped | interaction type hash
    },
    [`EVENT_PLAYER_PROMPT_TRIGGERED`] = {
        name = "EVENT_PLAYER_PROMPT_TRIGGERED",
        size = 10,
        members = {"Int32", "Int32", "Int32", "Int32", "Float32", "Float32", "Float32", "Int32", "Int32", "Int32"} -- prompt type id | unknown | target entity id | unknown (??? discovered inventory item) | player coord x | player coord y | player  coord z | discoverable entity type id ( list ) | unknown | kit_emote_action hash ( list )
    },
    [`EVENT_PLAYER_COLLECTED_AMBIENT_PICKUP`] = {
        name = "EVENT_PLAYER_COLLECTED_AMBIENT_PICKUP",
        size = 8,
        members = {"Int32", "Int32", "Int32", "Int32","Int32", "Int32", "Int32", "Int32"} -- pickup name hash | unknown (??? pickup entity id) | player id | pickup model hash | unknown | unknown | collected inventory item quantity | inventory item hash
    },
}

Citizen.CreateThread(function()
    while true do 
        
        local size = GetNumberOfEvents(0) -- SCRIPT_EVENT_QUEUE_AI)

        for i = 0, size - 1 do
            if size > 0 then
                local event = GetEventAtIndex(0, i)

                if W.EventDataInfo[event] then
                    local dataInfo = W.EventDataInfo[event]                    
                    local dataSize = dataInfo.size
                    local dataStruct = DataView.ArrayBuffer(dataSize * 8)

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

                    TriggerEvent(dataInfo.name, data)                    
                end
            end
        end

        Citizen.Wait(0)
    end     
end)