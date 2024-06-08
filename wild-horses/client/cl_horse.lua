--
-- HORSE
--

local mount = 0
local mountBlip = 0

local mountInfo = nil

local helpLastTime = 0

local brushPrompt = 0
local feedPrompt = 0
local bRunningTask = false

function CreatePlayerHorse()
    local playerPed = GetPlayerPed(PlayerId())
    local pX, pY, pZ = table.unpack(GetEntityCoords(playerPed, false))
    local x, y, z = 0
    
    --
    -- Start a spawnpoint search
    --

    -- Delete previous search?
    SpawnpointsCancelSearch()

    -- Spawn radius (in meters)
    local spawnRadius = 100.0 --100.0

    math.randomseed(123)
    local noiseX = math.random() * spawnRadius
    math.randomseed(1234)
    local noiseY = math.random() * spawnRadius

    local floor = GetHeightmapBottomZForPosition(pX + noiseX, pY + noiseY)
    
    SpawnpointsStartSearch(pX + noiseX, pY + noiseY, floor, spawnRadius, spawnRadius, 19, 0.5, 5000, 0)

    while SpawnpointsIsSearchComplete() ~= 1 do -- Must be 1, not a bool
        Citizen.Wait(0)
    end

    local nFound = SpawnpointsGetNumSearchResults()

    if nFound == 0 then -- Could not find any spawn points?  Just spawn at player        
        x = pX
        x = pY
        z = floor
    else
        local randomIndex = GetRandomIntInRange(0, nFound)
        x, y, z = Citizen.InvokeNative(0x280C7E3AC7F56E90, randomIndex, Citizen.PointerValueFloat(), Citizen.PointerValueFloat(), Citizen.PointerValueFloat())  --SpawnpointsGetSearchResult(0)
    end

    SpawnpointsCancelSearch()

    --
    -- Create ped
    --

    if x == nil or x == 0 then
        x = pX + 1.0
        x = pY
        z = floor
    end

    local model = mountInfo[1]

    RequestModel(model)

    while not HasModelLoaded(model) do
        RequestModel(model)
        Citizen.Wait(0)
    end

    mount = CreatePed(model, x, y+1.0, z, 45.0, true, true, true)
    SetEntityInvincible(mount, true)
    SetPedKeepTask(mount)
    SetPedAsNoLongerNeeded(mount)

    SetRandomOutfitVariation(mount)
    SetPedRandomComponentVariation(mount, 1)

    EquipMetaPedOutfit(mount, mountInfo[2])
    SetHorseGender(mount, false)
    
    if mountInfo[2] == 4035792208 then -- Lantern
        EquipMetaPedOutfit(mount, 2169370957)
    end


    UpdatePedVariation(mount, false, true, true, true, false)

    --
    -- Horse stuff
    --

    SetMountForPlayerPed(mount, PlayerPedId())

    --SetPedConfigFlag(mount, 412, false) --disable horse prompts

    -- Prompt stuff

    local group = UiPromptGetGroupIdForTargetEntity(mount)    

    brushPrompt = PromptRegisterBegin()
    PromptSetControlAction(brushPrompt, `INPUT_INTERACT_HORSE_BRUSH`)
    PromptSetText(brushPrompt, VarString(10, 'LITERAL_STRING', "Brush"))
    PromptSetEnabled(brushPrompt, 0)
    PromptSetVisible(brushPrompt, 0)
    PromptSetStandardMode(brushPrompt, 1)
    PromptSetGroup(brushPrompt, group)
    PromptRegisterEnd(brushPrompt)

    feedPrompt = PromptRegisterBegin()
    PromptSetControlAction(feedPrompt, `INPUT_INTERACT_HORSE_FEED`)
    PromptSetText(feedPrompt, VarString(10, 'LITERAL_STRING', "Feed"))
    PromptSetEnabled(feedPrompt, 0)
    PromptSetVisible(feedPrompt, 0)
    PromptSetStandardMode(feedPrompt, 1)
    PromptSetGroup(feedPrompt, group)
    PromptRegisterEnd(feedPrompt)

    W.Prompts.AddToGarbageCollector(brushPrompt)  
    W.Prompts.AddToGarbageCollector(feedPrompt)  
    

    -- Blip stuff

    mountBlip = BlipAddForEntity(`BLIP_STYLE_PLAYER_HORSE`, mount)

    SetBlipSprite(mountBlip, `blip_horse_owned_active`, true)
    SetBlipScale(mountBlip, 0.2)
    SetBlipName(mountBlip, "Horse")


    Citizen.CreateThread(function()
        while mount ~= 0 do
            Citizen.Wait(1000)

            if IsPedInWrithe(mount) then
                BlipAddModifier(mountBlip, `BLIP_MODIFIER_HORSE_REVIVE`)
            else
                BlipRemoveModifier(mountBlip, `BLIP_MODIFIER_HORSE_REVIVE`)
            end

            if mount ~=0 and not DoesEntityExist(mount) then
                ReleasePedVisibilityTracking(mount)
                RemoveBlip(mountBlip)
                mount = 0
            end

            if mount ~=0 and IsPedDeadOrDying(mount) then
                Citizen.Wait(4000)

                ShowHelpText("Your horse has died.", 5000)
                TriggerServerEvent("wild:sv_deleteMount")

                local corpse = mount
                mount = 0 
                ReleasePedVisibilityTracking(mount)
                RemoveBlip(mountBlip)

                Citizen.Wait(60*1000)
                DeletePed(corpse)
            else

                --[[local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local mountCoords = GetEntityCoords(mount)
                local dist = GetVectorDistSqr(playerCoords, mountCoords)

                if dist < 7.6 then]]
                
                local closeMount = Citizen.InvokeNative(0x0501D52D24EA8934, 1, Citizen.ResultAsInteger())

                if mount == closeMount then
                    PromptSetVisible(brushPrompt, 1)
                    PromptSetVisible(feedPrompt, 1)                 

                    -- Motivation of 1.0 means super agitated towards player
                    if GetPedMotivation(mount, 3, playerPed) < 0.001 and not bRunningTask then
                        PromptSetEnabled(brushPrompt, 1)
                        PromptSetEnabled(feedPrompt, 1)
                    else
                        PromptSetEnabled(brushPrompt, 0)
                        PromptSetEnabled(feedPrompt, 0)
                    end
                else
                    PromptSetVisible(horseCargoPrompt, 0)
                    PromptSetVisible(brushPrompt, 0)
                    PromptSetVisible(feedPrompt, 0)
                end                    
                     
                
            end

        end
    end)  
    
    SetEntityInvincible(mount, false)
end

AddEventHandler("wild:cl_onNewPlayerPed", function()  
    if mount == 0 then
        return
    end

    if not DoesEntityExist(mount) then
        return
    end

    SetMountForPlayerPed(mount, PlayerPedId())
end)


AddEventHandler("EVENT_PED_ANIMAL_INTERACTION", function(data)  
    local humanPed = data[1]
    local animalPed = data[2]

    if humanPed ~= PlayerPedId() then
        return
    end

    if data[3] == 391681984 then
        local model = GetEntityModel(humanPed)

        if model == `player_zero` or model == `player_three` then
            if IsHorseMale(animalPed) then
                W.PlayAmbientSpeech(humanPed, "PET_HORSE_MALE")
            else
                W.PlayAmbientSpeech(humanPed, "PET_HORSE_FEMALE")
            end
        else
            W.PlayAmbientSpeech(humanPed, "GREET_GENERAL_FAMILIAR")
        end
    end

    if data[3] == 637277148 then
        bRunningTask = false
    end
end)

AddEventHandler("EVENT_CALM_PED", function(data)  
    local calmer = data[1]
    local model = GetEntityModel(calmer)

    if model ~= `player_zero` and model ~= `player_three` then
        W.PlayAmbientSpeech(calmer, "WHOA")
    end
end)

function OnWhistle()
    local playerPed = GetPlayerPed(PlayerId())

    if mount == 0 then

        mountInfo = RequestMountInfo()

        if #mountInfo == 0 then
            if (GetGameTimer() - helpLastTime > 10000) then
                helpLastTime = GetGameTimer()
    
                ShowHelpText("You have no horse", 3000)
            end
        else
            CreatePlayerHorse()
        end
    else
        local dist = GetVectorDistSqr(GetEntityCoords(playerPed), GetEntityCoords(mount))

        -- Models, other than Arthur or John, don't whistle when near their
        if dist < 100.0 then
            local model = GetEntityModel(playerPed)
            if model ~= `player_zero` and model ~= `player_three` then
                TaskWhistleAnim(PlayerPedId(), 869278708, `UNSPECIFIED`)
            end            
        end

        TaskGoToEntity(mount, playerPed, -1, 2.5, 1.5, 0, 0)
        --TaskFollowAndConverseWithPed(mount, playerPed, 0, 0, 2.25, 2.75, 8, 0.0, 0.0, 1069547520, 1073741824)
        --TaskGoToWhistle(mount, playerPed, 3)

        BlipRemoveModifier(mountBlip, `BLIP_MODIFIER_PLAYER_HORSE_IN_RANGE_WHISTLE`)
        BlipAddModifier(mountBlip, `BLIP_MODIFIER_PLAYER_HORSE_IN_RANGE_WHISTLE`)

        Citizen.Wait(1000)
        BlipRemoveModifier(mountBlip, `BLIP_MODIFIER_PLAYER_HORSE_IN_RANGE_WHISTLE`)

    end
end

function OnBrush()
    bRunningTask = true
    TaskAnimalInteraction(PlayerPedId(), mount, `Interaction_Brush`, `P_BRUSHHORSE02X`, 0)

    SetTimeout(5000, function()
        bRunningTask = false
        ClearPedBloodDamage(mount)
        ClearPedDamageDecalByZone(mount, 10, "ALL")
        ClearPedEnvDirt(mount)

        SetAttributeBaseRank(mount, ePedAttribute.SA_DIRTINESSSKIN, 0)
        SetAttributePoints(mount, ePedAttribute.SA_DIRTINESSSKIN, 0)
    end)
end

function OnFeed(item)
    if W.Satchel then

        local horseFoodItems = {}

        if item then
            table.insert(horseFoodItems, {item=item, quantity=1})
        else
            horseFoodItems = W.Satchel.GetInventoryWithFilter("horse food")
        end

        -- Pick a random item for food
        if #horseFoodItems > 0 then
            math.randomseed(GetGameTimer()/7)

            -- food.item, food.quantity
            local food = horseFoodItems[math.random(#horseFoodItems)]

            if food.quantity > 0 then
                bRunningTask = true

                -- Note: in all RDR2 scripts, INTERACTION_FOOD uses no model. Perhaps they add it manually and rely on HasAnimEventFired?
                TaskAnimalInteraction(PlayerPedId(), mount, `INTERACTION_FOOD`, 0, 0) --INTERACTION_FOOD, INTERACTION_INJECTION_QUICK, INTERACTION_OINTMENT, INTERACTION_BRUSH  `p_apple01x`
            
                Citizen.Wait(1)


                local start = GetGameTimer()
                while GetGameTimer()-start < 5000 and not HasAnimEventFired(PlayerPedId(), `INTERACT`) do
                    Citizen.Wait(0)
                end

                if HasAnimEventFired(PlayerPedId(), `INTERACT`) then
                    bRunningTask = false
                    SetAttributePoints(mount, ePedAttribute.PA_HEALTH, GetMaxAttributePoints(mount, ePedAttribute.PA_HEALTH))
                    SetAttributePoints(mount, ePedAttribute.PA_STAMINA, GetMaxAttributePoints(mount, ePedAttribute.PA_STAMINA))
            
                    SetAttributeCoreValue(mount, 0, 200)
                    SetAttributeCoreValue(mount, 1, 200)
                    SetEntityHealth(mount, GetMaxAttributePoints(mount, ePedAttribute.PA_HEALTH), 0)
                    RestorePedStamina(mount, 100.0)

                    W.Satchel.RemoveItem(food.item, 1)
                end
            end
        end
    else
        ShowHelpText("No satchel for food", 5000)
    end
end


function OnFollow()
    TaskWhistleAnim(PlayerPedId(), 869278708, `UNSPECIFIED`)

    ClearPedTasks(mount, true, true)
    TaskFollowAndConverseWithPed(mount, PlayerPedId(), 0, 0, 2.25, 2.75, 8, 0.0, 0.0, 1069547520, 1073741824)
end

function OnStay()
    W.PlayAmbientSpeech(PlayerPedId(), "WHOA")

    ClearPedTasks(mount, true, true)
    TaskStandStill(mount, -1)
end

function OnFlee()
    --  --GET_AWAY_FROM_ME
    W.PlayAmbientSpeech(PlayerPedId(), "GET_AWAY_FROM_ME")  --
    Citizen.Wait(1000)
    ClearPedTasks(mount, true, true)
    TaskFleePed(mount, PlayerPedId(), 4, 524292, -1082130432, -1, 0)
end


Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1200)	

        -- Hide native brush and feed
        ModifyPlayerUiPrompt(PlayerId(), 49, 0, 1)
        ModifyPlayerUiPrompt(PlayerId(), 50, 0, 1)

        ModifyPlayerUiPrompt(PlayerId(), 28, 0, 1) -- PP_HORSE_ITEMS
        ModifyPlayerUiPrompt(PlayerId(), 45, 0, 0) -- PP_HORSE_WEAPONS_HOLD
        ModifyPlayerUiPrompt(PlayerId(), 46, 0, 0) -- PP_HORSE_WEAPONS
        ModifyPlayerUiPrompt(PlayerId(), 47, 0, 0) -- PP_HORSE_PROXIMITY_INTERACT
	end
end)


AddEventHandler("REQUEST_BRUSH_HORSE", OnBrush)

AddEventHandler("REQUEST_FEED_HORSE", function(item)
    OnFeed(item)
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)	
        local playerPed = PlayerPedId()

		if IsControlJustPressed(0, `INPUT_WHISTLE`) then
            OnWhistle()
        end

        if IsControlJustPressed(0, `INPUT_INTERACT_HORSE_BRUSH`) and not IsPedOnMount(playerPed) then
            OnBrush()
        end

        if IsControlJustPressed(0, `INPUT_INTERACT_HORSE_FEED`) and not IsPedOnMount(playerPed) then
            OnFeed()
        end

        if IsControlJustPressed(0, `INPUT_HORSE_COMMAND_FOLLOW`) then
            OnFollow()
        end

        if IsControlJustPressed(0, `INPUT_HORSE_COMMAND_STAY`) then
            OnStay()
        end

        if IsControlJustPressed(0, `INPUT_HORSE_COMMAND_FLEE`) then
            OnFlee()
        end
	end
end)


AddEventHandler("wild:cl_onUpdateFaction", function(faction)
    if mount ~= 0 then
        if DoesEntityExist(mount) then
            SetPedRelationshipGroupHash(mount, GetPedRelationshipGroupHash(PlayerPedId()))
        end
    end
end)

-- Cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        RemoveBlip(mountBlip)
        DeletePed(mount)
    end
end)

