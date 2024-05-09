-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

shopConfig = json.decode(LoadResourceFile(GetCurrentResourceName(), "shops.json"))

-- How to get money:  W.GetPlayerMoney()
-- How to give/remove money:  TriggerServerEvent("wild:sv_giveMoney", GetPlayerName(PlayerId()), amount)

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

local function CalculatePrice(entity)
	math.randomseed(GetGameTimer()/7)

    local prices = shopConfig.butcherPrices[W.GetPedModelName(entity)]

    if prices == nil then
        prices = shopConfig.butcherPrices["default"]
    end

    local finalPrice = math.random(0, 100) / 100 -- Random cents starting rate

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

	return finalPrice
end

local function GetBuyLine(speaker, entity)
    math.randomseed(GetGameTimer()/7)

    local pool = {}
    local line = ""

    local rating = GetPedDamageCleanliness(entity)

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

local prompt = 0
local helpLastTime = 0

Citizen.CreateThread(function()   
    while true do
        Citizen.Wait(10)
    
        local playerCoords = GetEntityCoords(PlayerPedId())
        
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
            butcherPed = currentLocation[5].Ped
            
            if DoesEntityExist(butcherPed) then
                if not IsPedDeadOrDying(butcherPed) then
                    local butcherCoords = GetEntityCoords(butcherPed)
                    local distSqr = GetVectorDistSqr(butcherCoords, currentLocationCoords)
    
                    if distSqr < 1.0 then
                        bButcherIsAvailable = true
                    end
                end
            end            
        end

        carriedEntity = GetFirstEntityPedIsCarrying(PlayerPedId())

        if bInValidAreas and bButcherIsAvailable and carriedEntity == 0 then
            if (GetGameTimer() - helpLastTime > 10000) then
                helpLastTime = GetGameTimer()
    
                ShowHelpText("You can only sell to the butcher if you're carrying", 3000)
            end
        end

        if bInValidAreas and bButcherIsAvailable and carriedEntity ~=0 then
        
            if prompt == 0 then -- Create prompt
                prompt = PromptRegisterBegin()
                PromptSetControlAction(prompt, `INPUT_CONTEXT_X`) -- R key
                PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", "Sell"))
                UiPromptSetHoldMode(prompt, 1000)
                PromptRegisterEnd(prompt)
            
                -- Useful management. Automatically deleted when restarting resource
                W.Prompts.AddToGarbageCollector(prompt)         
            end

            if UiPromptGetProgress(prompt) == 1.0 then
                PromptDelete(prompt)
                prompt = 0

                -- Action

                local playerCoords = GetEntityCoords(PlayerPedId())
                TaskReact(butcherPed, PlayerPedId(), playerCoords.x, playerCoords.y, playerCoords.z, "Default_Curious", 1.0, 10.0, 4)

                local price = CalculatePrice(carriedEntity)

                TriggerServerEvent("wild:sv_giveMoney", GetPlayerName(PlayerId()), price)
                TriggerServerEvent('wild:shops:sv_playAmbSpeech', PedToNet(butcherPed), GetBuyLine(butcherPed, carriedEntity))

                DeleteEntity(carriedEntity)
                carriedEntity = 0

                Citizen.Wait(1*1000) -- too soon?
            end

        elseif prompt ~=0 then
            PromptDelete(prompt)
            prompt = 0
        end
    end
end)

RegisterNetEvent("wild:shops:cl_onPlayAmbSpeech")
AddEventHandler("wild:shops:cl_onPlayAmbSpeech", function(pedNet, line)
	local ped = NetToPed(pedNet)
	PlayAmbientSpeechFromEntity(ped, "", line, "speech_params_force", 0)
end)