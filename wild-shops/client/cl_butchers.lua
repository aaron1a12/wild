-- Some inventory flags
local ITEM_FLAG_IS_MEAT = (1 << 24)
local ITEM_FLAG_IS_PELT = (1 << 20) -- MUST CONFIRM
local ITEM_FLAG_IS_PELT_2 = (1 << 20) -- MUST CONFIRM
local ITEM_FLAG_IS_PELT_3 = (1 << 19) -- MUST CONFIRM
local ITEM_FLAG_QUALITY_RUINED = (1 << 27)
local ITEM_FLAG_QUALITY_POOR = (1 << 28)
local ITEM_FLAG_QUALITY_NORMAL = (1 << 29)
local ITEM_FLAG_QUALITY_PRISTINE = (1 << 30)
local ITEM_FLAG_LEGENDARY = (1 << 2)

--
-- Butcher Areas
--

local butcherLocations = shopConfig.butcherLocations

function SetupButchers()
    for i = 1, #butcherLocations do

        local location = butcherLocations[i]
        local butcherParams = {}
        butcherParams.Model = location[5]
        butcherParams.DefaultCoords = vector3(location[1], location[2], location[3])
        butcherParams.DefaultHeading = location[4]
        butcherParams.SaveCoordsAndHeading = false
        butcherParams.Blip = 0
        butcherParams.BlipName = "Butcher"

        function butcherParams:onActivate(ped, bOwned)
            butcherParams.Ped = ped
            
            if bOwned then
                EquipMetaPedOutfitPreset(butcherParams.Ped, location[6], false)   
            end

            butcherParams.Blip = BlipAddForEntity(`BLIP_STYLE_FRIENDLY`, butcherParams.Ped)

            SetBlipSprite(butcherParams.Blip, `blip_shop_butcher`, true)
            SetBlipScale(butcherParams.Blip, 0.2)
            SetBlipName(butcherParams.Blip, butcherParams.BlipName)
        end

        function butcherParams:onDeactivate()
            RemoveBlip(butcherParams.Blip)
        end

        table.insert(location, butcherParams)

        W.NpcManager:EnsureNpcExists("shops_butcher_" .. tostring(i), butcherParams)
    end    
end
SetupButchers()


function PickMountForLoad(player)
    local playerPed = GetPlayerPed(player)
    local playerMount = GetMountOwnedByPlayer(player)
    local playerLastMount = GetLastMount(playerPed)

    local finalMount = 0
    local finalDist = 0

    local playerCoords = GetEntityCoords(playerPed)

    if not DoesEntityExist(playerMount) then
        playerMount = 0
    end

    if not DoesEntityExist(playerLastMount) then
        playerLastMount = 0
    end

    if playerMount ~= 0 and playerLastMount ~= 0 then -- We have to choose between mounts

        local playerMountDist = GetVectorDistSqr(playerCoords, GetEntityCoords(playerMount))
        local playerLastMountDist = GetVectorDistSqr(playerCoords, GetEntityCoords(playerLastMount))

        if playerLastMountDist < playerMountDist then
            finalMount = playerLastMount
            finalDist = playerLastMountDist
        else
            finalMount = playerMount
            finalDist = playerMountDist
        end
    else
        if playerLastMount ~= 0 then
            finalMount = playerLastMount
            finalDist = GetVectorDistSqr(playerCoords, GetEntityCoords(playerMount))
        end

        if playerMount ~= 0 then
            finalMount = playerMount
            finalDist = GetVectorDistSqr(playerCoords, GetEntityCoords(playerMount))
        end
    end

    return finalMount, finalDist
end

local function CalculatePeltPrice(peltId)
    local pelt = shopConfig.pelts[tostring(peltId)]

    if pelt == nil then
        return 0.50
    end

	return pelt[2]
end

local function IsPelt(entity)
    if GetIsCarriablePelt(entity) then 
        local peltId = GetCarriableFromEntity(entity)
        if shopConfig.pelts[tostring(peltId)] ~= nil then
            return true
        end
    end
    return false
end

local function CalculatePrice(entity)
    local finalPrice = math.random(0, 100) / 100 -- Random cents starting rate

    if IsPelt(entity) then -- large pelt item
        local peltId = GetCarriableFromEntity(entity)
        finalPrice = finalPrice + CalculatePeltPrice(peltId)
    else
        math.randomseed(GetGameTimer()/7)
        local prices = shopConfig.butcherPrices[W.GetPedModelName(entity)]
    
        if prices == nil then
            prices = shopConfig.butcherPrices["default"]
        end
    
        local rating = GetPedDamageCleanliness(entity)
    
        if rating == 0 then
            finalPrice = finalPrice + prices[1]
        end
    
        if rating == 1 then
            finalPrice = finalPrice + prices[2]
        end
    
        if rating == 2 then
            finalPrice = finalPrice + prices[3]
        end
    end

	return finalPrice
end

local currentLocation = nil
local butcherPed = 0
local butcherCam = 0
local butcherCamPos = vector3(0,0,0)
local bStallOpen = false

function OpenStall()
    if W.Satchel then
        W.Satchel.Open(true)
        bStallOpen = true

        ClearPedTasks(butcherPed)

        --W.PlayAmbientSpeech(butcherPed, "HOWS_IT_GOING")
        local butcherCoords = vector3(currentLocation[1], currentLocation[2], currentLocation[3])

        butcherCamPos = RotateVectorYaw(vector3(0, 1, 0), currentLocation[4])
        butcherCamPos = butcherCamPos * 1.1
        butcherCamPos = butcherCamPos + butcherCoords
        butcherCamPos = butcherCamPos + vector3(0,0, 0.5)

        TaskLookAtCoord(butcherPed, butcherCamPos.x, butcherCamPos.y, butcherCamPos.z, 5000, 0, 51, false)
        TaskGoToCoordAnyMeans(butcherPed, currentLocation[1], currentLocation[2], currentLocation[3], 1.0, 0, false, 524419, -1.0)
        --TaskGoToCoordWhileAimingAtCoord(butcherPed, currentLocation[1], currentLocation[2], currentLocation[3], butcherCamPos.x, butcherCamPos.y, butcherCamPos.z, 1.5, 1, 0.5, 1082130432, 1, 1, 0, `FIRING_PATTERN_BURST_FIRE`, 0)

        Citizen.CreateThread(function()
            local bReached = false
            while bStallOpen and not bReached do
                Citizen.Wait(0)

                if GetVectorDistSqr(GetEntityCoords(butcherPed), butcherCoords) < 0.2 then
                    bReached = true
                end
            end

            TaskTurnPedToFaceCoord(butcherPed, butcherCamPos.x, butcherCamPos.y, butcherCamPos.z, 10000)
        end)

        local lookAt = RotateVectorYaw(vector3(0.02, 1, 0), currentLocation[4])
        lookAt = lookAt + vector3(0,0,0.49) + butcherCoords

        local rot = GetLookAtRotation(butcherCamPos, lookAt)
        butcherCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", butcherCamPos.x, butcherCamPos.y, butcherCamPos.z, rot.x, 0.0, rot.z, 60.0, false, 0)
        SetCamActive(butcherCam, true)
        RenderScriptCams(true, false, 0, true, true, 0)
    else
        ShowHelpText("Satchel not available", 2000)
    end
end

function CloseStall()
    bStallOpen = false

    RenderScriptCams(false, false, 0, true, true, 0)
    SetCamActive(butcherCam, false)
    DestroyCam(butcherCam, true)
end


function PlayGesture(ped, dict, clip)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(100)
    end
    
    TaskPlayAnim(ped, dict, clip, 8.0, -8.0, 2000, (1 << 3) | (1 << 22), 0.0, false, 0, false, 0, false)
end

local reactionTime = 0
AddEventHandler("wild:cl_onSell", function(item, quantity)
    if W.Satchel then
        math.randomseed(GetGameTimer()/7)

        local totalSale = W.Satchel.GetItemValue(item) * quantity
        TriggerServerEvent("wild:sv_giveMoney", GetPlayerName(PlayerId()), totalSale)

        -- See catalog_sp.ymt
        local info = DataView.ArrayBuffer(8 * 7)
        Citizen.InvokeNative(0xFE90ABBCBFDC13B2, item, info:Buffer())
        local group = info:GetInt32(16) -- weapon, provision, consumable, etc
        local category = info:GetInt32(8) -- Note that categories are actually a subset of "group"

        --
        -- Butcher reaction
        --

        if GetGameTimer()-reactionTime < 3000 then
            return
        end

        reactionTime = GetGameTimer()

        local pool = {}
        local line = ""

        local gesturePool = {}
        local gesture = {"", ""}
        
        if category == 235313564 then -- seems to be animal item category. 
            
            local bIsMeat = (InventoryIsInventoryItemFlagEnabled(item, ITEM_FLAG_IS_MEAT)==1)
            local bIsRuined = (InventoryIsInventoryItemFlagEnabled(item, ITEM_FLAG_QUALITY_RUINED)==1)
            local bIsPoor = (InventoryIsInventoryItemFlagEnabled(item, ITEM_FLAG_QUALITY_POOR)==1)
            local bIsNormal = (InventoryIsInventoryItemFlagEnabled(item, ITEM_FLAG_QUALITY_NORMAL)==1)
            local bIsPerfect = (InventoryIsInventoryItemFlagEnabled(item, ITEM_FLAG_QUALITY_PRISTINE)==1)
            local bIsLegendary = (InventoryIsInventoryItemFlagEnabled(item, ITEM_FLAG_LEGENDARY)==1)
            local bIsPelt = (InventoryGetInventoryItemIsAnimalPelt(item)==1)


            if bIsPelt and bIsPerfect and CanPlayAmbientSpeech(butcherPed, "BUY_QUALITY_PELT") then
                --GREET_POINT_OUT_PELT
                table.insert(pool, "BUY_QUALITY_PELT")
            end

            if bIsPerfect and not bIsPelt then
                if CanPlayAmbientSpeech(butcherPed, "BUY_NICE_KILL") then
                    table.insert(pool, "BUY_NICE_KILL")
                end     
                
                if CanPlayAmbientSpeech(butcherPed, "BUY_QUALITY_ITEM") then
                    table.insert(pool, "BUY_QUALITY_ITEM")
                end

                table.insert(gesturePool, {"ai_gestures@gen_male@standing@silent@rt_hand", "silent_neutral_punctuate_f_001"})
                table.insert(gesturePool, {"ai_gestures@gen_male@standing@speaker@no_hat", "silent_neutral_bow_l_001"})
            end

            if bIsNormal and CanPlayAmbientSpeech(butcherPed, "BUY_AVERAGE_ITEM") then
                table.insert(pool, "BUY_AVERAGE_ITEM")
                table.insert(gesturePool, {"ai_gestures@gen_male@standing@speaker", "neutral_punctuate_fr_003"})
                table.insert(gesturePool, {"ai_gestures@gen_male@standing@speaker", "empathise_nod_f_001"})
                table.insert(gesturePool, {"ai_gestures@gen_male@standing@speaker", "positive_nod_f_003"})
                table.insert(gesturePool, {"ai_gestures@gen_male@standing@speaker", "positive_nod_f_004"})
            end

            if bIsPoor or bIsRuined then
                if CanPlayAmbientSpeech(butcherPed, "BUY_COMMON_ITEM") then
                    table.insert(pool, "BUY_COMMON_ITEM")
                end
        
                if CanPlayAmbientSpeech(butcherPed, "BUY_MESSY_KILL") then
                    table.insert(pool, "BUY_MESSY_KILL")
                end
        
                if CanPlayAmbientSpeech(butcherPed, "BUY_POOR_ITEM") then
                    table.insert(pool, "BUY_POOR_ITEM")
                end

                table.insert(gesturePool, {"ai_gestures@gen_male@standing@speaker", "negative_headshake_f_004"})
                table.insert(gesturePool, {"ai_gestures@gen_male@standing@silent@rt_hand", "silent_surprised_react_f_001"})
                table.insert(gesturePool, {"ai_gestures@gen_male@standing@silent@rt_hand", "silent_negative_disagree_l_002"})
            end
        else
            table.insert(gesturePool, {"ai_gestures@gen_male@standing@speaker", "neutral_punctuate_fr_003"})
            table.insert(gesturePool, {"ai_gestures@gen_male@standing@speaker", "empathise_nod_f_001"})
            table.insert(gesturePool, {"ai_gestures@gen_male@standing@speaker", "positive_nod_f_003"})
            table.insert(gesturePool, {"ai_gestures@gen_male@standing@speaker", "positive_nod_f_004"})

            if math.random() < 0.25 then
                if CanPlayAmbientSpeech(butcherPed, "CHAT_SHOPKEEPER_GOSSIP") then
                    table.insert(pool, "CHAT_SHOPKEEPER_GOSSIP")
                end
        
                if CanPlayAmbientSpeech(butcherPed, "CHAT_LOCAL_AREA") then
                    table.insert(pool, "CHAT_SHOPKEEPER_GOSSIP")
                end
        
                if CanPlayAmbientSpeech(butcherPed, "CHAT_1907") then
                    table.insert(pool, "CHAT_1907")
                end
            end
        end

        -- Pick random
        if #pool > 0 then
            line = pool[math.random(#pool)]
        end

        -- Pick random
        if #gesturePool > 0 then
            gesture = gesturePool[math.random(#gesturePool)]
        end
    
        W.PlayAmbientSpeech(butcherPed, line)   
        PlayGesture(butcherPed, gesture[1], gesture[2])

        TaskLookAtCoord(butcherPed, butcherCamPos.x, butcherCamPos.y, butcherCamPos.z-1.0, -1, 1, 51, false)  
        Citizen.Wait(1000)
        TaskLookAtCoord(butcherPed, butcherCamPos.x, butcherCamPos.y, butcherCamPos.z, 3000, 1, 51, false)        
              
    end
end)

AddEventHandler("wild:cl_onMenuClosing", function(menu)
    if menu == "satchel" then
        CloseStall()
    end
end)





local promptGroup = GetRandomIntInRange(1, 0xFFFFFF)
local prompt = 0
local helpLastTime = 0
local waitTime = 10

Citizen.CreateThread(function()   
    while true do
        Citizen.Wait(waitTime)
    
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        local bInValidAreas = false
        local currentLocationCoords = nil

        for i = 1, #butcherLocations do
            currentLocationCoords = vector3(butcherLocations[i][1], butcherLocations[i][2], butcherLocations[i][3])
            
            -- Squared dist for optimization
            local distSqr = GetVectorDistSqr(playerCoords, currentLocationCoords)

            if distSqr*0.1 < 2.0 then
                bInValidAreas = true
                currentLocation = butcherLocations[i]
                break
            end
        end

        local bButcherIsAvailable = false

        if bInValidAreas then
            butcherPed = currentLocation[7].Ped           
            
            if DoesEntityExist(butcherPed) then
                if not IsPedDeadOrDying(butcherPed) then
                    local butcherCoords = GetEntityCoords(butcherPed)
                    local distSqr = GetVectorDistSqr(butcherCoords, currentLocationCoords)
    
                    if distSqr < 100.0 then
                        bButcherIsAvailable = true
                    end
                end
            end 
            
            carriedEntity = GetFirstEntityPedIsCarrying(playerPed)

            -- Pelts on horse
            bHasPelts = false
            local mount, mountDist = PickMountForLoad(PlayerId())
        
            if mount ~= 0 and mountDist < 30.0 then
                if GetPeltFromHorse(mount, 0) ~= 0 then
                    bHasPelts = true
                end
            end
        end

        --[[if bInValidAreas and bButcherIsAvailable and carriedEntity == 0 then
            if (GetGameTimer() - helpLastTime > 20000) then
                helpLastTime = GetGameTimer()
    
                ShowHelpText("To sell here, you must carry the large items and keep your pelts nearby", 10000)
            end
        end]]

        if bInValidAreas and bButcherIsAvailable then         
            waitTime = 0

            if prompt == 0 then -- Create prompt
                prompt = PromptRegisterBegin()
                PromptSetControlAction(prompt, `INPUT_CONTEXT_X`) -- R key
                PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", "Sell Items"))
                UiPromptSetHoldMode(prompt, 200)
                PromptSetGroup(prompt, promptGroup, 0) 
                PromptRegisterEnd(prompt)
            
                -- Useful management. Automatically deleted when restarting resource
                W.Prompts.AddToGarbageCollector(prompt)    
            end

            PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, "LITERAL_STRING", "Butcher"))

            if UiPromptGetProgress(prompt) == 1.0 then
                W.Prompts.RemoveFromGarbageCollector(prompt)
                PromptDelete(prompt)
                prompt = 0

                OpenStall()

                --[[local price = 0.0
                
                -- Carried large item
                if carriedEntity ~= 0 then
                    price = price + CalculatePrice(carriedEntity)
                end

                -- Pelts on horse
                local mount = PickMountForLoad(PlayerId())

                if mount ~= 0 then
                    -- Search for pelts
                    for i = 0, 99 do
                        local peltId = GetPeltFromHorse(mount, i)
                        
                        if peltId ~= 0 then
                            price = price + CalculatePeltPrice(peltId)
                            ClearPeltFromHorse(mount, peltId)
                        else
                            break
                        end
                    end
                end]]

                -- Action

                local playerCoords = GetEntityCoords(PlayerPedId())

                
                --TaskReact(butcherPed, PlayerPedId(), playerCoords.x, playerCoords.y, playerCoords.z, "Default_Shocked", 10.0, 3.0, 4)



                --
            
                --[[if carriedEntity ~= 0 then
                    --TriggerServerEvent('wild:shops:sv_playAmbSpeech', PedToNet(butcherPed), GetBuyLine(butcherPed, carriedEntity))
                    DeleteEntity(carriedEntity)
                    carriedEntity = 0
                else
                    
                end]]
                
                Citizen.Wait(1*1000) -- too soon?
            end

        elseif prompt ~=0 then
            W.Prompts.RemoveFromGarbageCollector(prompt)
            PromptDelete(prompt)
            prompt = 0
            waitTime = 10
        end
    end
end)

RegisterNetEvent("wild:shops:cl_onPlayAmbSpeech")
AddEventHandler("wild:shops:cl_onPlayAmbSpeech", function(pedNet, line)
	local ped = NetToPed(pedNet)
	PlayAmbientSpeechFromEntity(ped, "", line, "speech_params_force", 0)
end)

--[[RegisterCommand('animal', function() 
	local x, y, z = table.unpack(GetEntityCoords(GetPlayerPed(PlayerId()), false))

    local model = `A_C_Cow`

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

RegisterCommand('deer', function() 
	local x, y, z = table.unpack(GetEntityCoords(GetPlayerPed(PlayerId()), false))

    local model = `A_C_Deer_01`

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
end, false)]]