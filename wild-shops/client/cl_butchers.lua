
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

local function GetBuyLine(speaker, entity)
    math.randomseed(GetGameTimer()/7)

    local pool = {}
    local line = ""

    local rating = GetPedDamageCleanliness(entity)

    if GetIsCarriablePelt(entity) then -- large pelt items have no damage cleanliness
        local peltId = GetCarriableFromEntity(entity)
        local pelt = shopConfig.pelts[tostring(peltId)]

        if pelt ~= nil then
            local nameBegin = string.sub(pelt[1] ,1,4)

            if nameBegin == "Poor" then
                rating = 0
            end

            if nameBegin == "Good" then
                rating = 1
            end

            if nameBegin == "Perf" then
                rating = 2
            end

            if nameBegin == "Lege" then
                rating = 2
            end
        end
    end

    if rating == 0 then
        if CanPlayAmbientSpeech(speaker, "BUY_COMMON_ITEM") then
            table.insert(pool, "BUY_COMMON_ITEM")
        end

        if CanPlayAmbientSpeech(speaker, "BUY_MESSY_KILL") then
            table.insert(pool, "BUY_MESSY_KILL")
        end

        if CanPlayAmbientSpeech(speaker, "BUY_POOR_ITEM") then
            table.insert(pool, "BUY_POOR_ITEM")
        end
    end

    if rating == 1 then
        if CanPlayAmbientSpeech(speaker, "BUY_AVERAGE_ITEM") then
            table.insert(pool, "BUY_AVERAGE_ITEM")
        end
    end

    if rating == 2 then
        if CanPlayAmbientSpeech(speaker, "BUY_NICE_KILL") then
            table.insert(pool, "BUY_NICE_KILL")
        end     
        
        if CanPlayAmbientSpeech(speaker, "BUY_QUALITY_ITEM") then
            table.insert(pool, "BUY_QUALITY_ITEM")
        end   
    end


    if math.random() < 0.20 then
        if CanPlayAmbientSpeech(speaker, "CHAT_SHOPKEEPER_GOSSIP") then
            table.insert(pool, "CHAT_SHOPKEEPER_GOSSIP")
        end

        if CanPlayAmbientSpeech(speaker, "CHAT_LOCAL_AREA") then
            table.insert(pool, "CHAT_SHOPKEEPER_GOSSIP")
        end

        if CanPlayAmbientSpeech(speaker, "CHAT_1907") then
            table.insert(pool, "CHAT_1907")
        end
    end

	-- Pick random
	if #pool > 0 then
		line = pool[math.random(#pool)]
	end

    return line
end

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
        local currentLocation = nil
        local currentLocationCoords = nil

        for i = 1, #butcherLocations do
            currentLocationCoords = vector3(butcherLocations[i][1], butcherLocations[i][2], butcherLocations[i][3])
            
            -- Squared dist for optimization
            local distSqr = GetVectorDistSqr(playerCoords, currentLocationCoords)

            if distSqr*0.1 < 1.0 then
                bInValidAreas = true
                currentLocation = butcherLocations[i]
                break
            end
        end

        local bButcherIsAvailable = false
        local butcherPed = 0

        if bInValidAreas then
            butcherPed = currentLocation[7].Ped           
            
            if DoesEntityExist(butcherPed) then
                if not IsPedDeadOrDying(butcherPed) then
                    local butcherCoords = GetEntityCoords(butcherPed)
                    local distSqr = GetVectorDistSqr(butcherCoords, currentLocationCoords)
    
                    if distSqr < 1.0 then
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

        if bInValidAreas and bButcherIsAvailable and carriedEntity == 0 then
            if (GetGameTimer() - helpLastTime > 20000) then
                helpLastTime = GetGameTimer()
    
                ShowHelpText("To sell here, you must carry the large items and keep your pelts nearby", 10000)
            end
        end

        if bInValidAreas and bButcherIsAvailable and (carriedEntity ~=0 or bHasPelts) then         
            waitTime = 0

            if prompt == 0 then -- Create prompt
                prompt = PromptRegisterBegin()
                PromptSetControlAction(prompt, `INPUT_CONTEXT_X`) -- R key
                PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", "Sell Items"))
                UiPromptSetHoldMode(prompt, 1000)
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

                local price = 0.0
                
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
                end

                -- Action

                local playerCoords = GetEntityCoords(PlayerPedId())
                TaskReact(butcherPed, PlayerPedId(), playerCoords.x, playerCoords.y, playerCoords.z, "Default_Curious", 1.0, 10.0, 4)

                TriggerServerEvent("wild:sv_giveMoney", GetPlayerName(PlayerId()), price)
            
                if carriedEntity ~= 0 then
                    TriggerServerEvent('wild:shops:sv_playAmbSpeech', PedToNet(butcherPed), GetBuyLine(butcherPed, carriedEntity))
                    DeleteEntity(carriedEntity)
                    carriedEntity = 0
                else
                    W.PlayAmbientSpeech(butcherPed, "BUY_QUALITY_PELT")
                end
                
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