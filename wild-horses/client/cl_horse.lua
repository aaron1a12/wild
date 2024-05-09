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
    local spawnRadius = 5.0

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

    -- Wait until the mount has attributes
    while GetMaxAttributePoints(mount, ePedAttribute.PA_HEALTH) == 0 do
        Citizen.Wait(0)
    end

    SetMountSecurityEnabled(mount, false)
    SetPlayerOwnsMount(PlayerId(), mount)
    SetPedAsSaddleHorseForPlayer(PlayerId(), mount)
    SetPedActivePlayerHorse(PlayerId(), mount)

    --
    -- as in R* scripts (player_horse.c)
    -- 

    ClearActiveAnimalOwner(mount, 0)

    SetPedOwnsAnimal(PlayerPedId(), mount, false) -- Enables rearing
    SetPedPersonality(mount, `PLAYER_HORSE`)

    SetAnimalIsWild(mount, false)

    SetPedConfigFlag(mount, 324, true) -- Unknown condition
    SetPedConfigFlag(mount, 211, true)
    SetPedConfigFlag(mount, 208, true)
    SetPedConfigFlag(mount, 209, true)
    SetPedConfigFlag(mount, 400, true)
    SetPedConfigFlag(mount, 297, true)
    SetPedConfigFlag(mount, 136, false)
    SetPedConfigFlag(mount, 312, false)
    SetPedConfigFlag(mount, 113, false)
    SetPedConfigFlag(mount, 301, false)
    SetPedConfigFlag(mount, 277, true)
    SetPedConfigFlag(mount, 319, true)
    SetPedConfigFlag(mount, 6, true)

    SetAnimalTuningBoolParam(mount, 25, false) -- ATB_FlockEnablePavementGraph
    SetAnimalTuningBoolParam(mount, 24, false) -- ATB_FlockEnableFlee

    --
    -- Custom (not R*)
    --

    --SetPedConfigFlag(mount, 297, true) --PCF_ForceInteractionLockonOnTargetPed
    SetPedConfigFlag(mount, 300, false) -- PCF_DisablePlayerHorseLeading
    SetPedConfigFlag(mount, 312, true) -- PCF_DisableHorseGunshotFleeResponse
    --SetPedConfigFlag(mount, 442, true) -- disable flee
    --SetPedConfigFlag(mount, 444, false) -- disable flee horse by player ??
    SetPedConfigFlag(mount, 546, false) -- PCF_IgnoreOwnershipForHorseFeedAndBrush
    SetPedConfigFlag(mount, 594, false) -- Wild horse

    --
    -- Max out all ranks/points
    --

    SetAttributeBaseRank(mount, ePedAttribute.PA_HEALTH, GetMaxAttributeRank(mount, ePedAttribute.PA_HEALTH))
    SetAttributeBaseRank(mount, ePedAttribute.PA_STAMINA, GetMaxAttributeRank(mount, ePedAttribute.PA_STAMINA))
    SetAttributeBaseRank(mount, ePedAttribute.PA_SPECIALABILITY, GetMaxAttributeRank(mount, ePedAttribute.PA_SPECIALABILITY))
    SetAttributeBaseRank(mount, ePedAttribute.PA_COURAGE, GetMaxAttributeRank(mount, ePedAttribute.PA_COURAGE))
    SetAttributeBaseRank(mount, ePedAttribute.PA_AGILITY, GetMaxAttributeRank(mount, ePedAttribute.PA_AGILITY))
    SetAttributeBaseRank(mount, ePedAttribute.PA_SPEED, GetMaxAttributeRank(mount, ePedAttribute.PA_SPEED))
    SetAttributeBaseRank(mount, ePedAttribute.PA_ACCELERATION, GetMaxAttributeRank(mount, ePedAttribute.PA_ACCELERATION))
    SetAttributeBaseRank(mount, ePedAttribute.PA_BONDING, GetMaxAttributeRank(mount, ePedAttribute.PA_BONDING))
    SetAttributeBaseRank(mount, ePedAttribute.SA_BODYWEIGHT, GetMaxAttributeRank(mount, ePedAttribute.SA_BODYWEIGHT))
    SetAttributeBaseRank(mount, ePedAttribute.MTR_STRENGTH, GetMaxAttributeRank(mount, ePedAttribute.MTR_STRENGTH))
    SetAttributeBaseRank(mount, ePedAttribute.MTR_GRIT, GetMaxAttributeRank(mount, ePedAttribute.MTR_GRIT))
    SetAttributeBaseRank(mount, ePedAttribute.MTR_INSTINCT, GetMaxAttributeRank(mount, ePedAttribute.MTR_INSTINCT))
    SetAttributeBaseRank(mount, ePedAttribute.SA_DIRTINESSSKIN, 0) -- clean
    SetAttributePoints(mount, ePedAttribute.PA_HEALTH, GetMaxAttributePoints(mount, ePedAttribute.PA_HEALTH))
    SetAttributePoints(mount, ePedAttribute.PA_STAMINA, GetMaxAttributePoints(mount, ePedAttribute.PA_STAMINA))
    SetAttributePoints(mount, ePedAttribute.PA_SPECIALABILITY, GetMaxAttributePoints(mount, ePedAttribute.PA_SPECIALABILITY))
    SetAttributePoints(mount, ePedAttribute.PA_COURAGE, GetMaxAttributePoints(mount, ePedAttribute.PA_COURAGE))
    SetAttributePoints(mount, ePedAttribute.PA_AGILITY, GetMaxAttributePoints(mount, ePedAttribute.PA_AGILITY))
    SetAttributePoints(mount, ePedAttribute.PA_SPEED, GetMaxAttributePoints(mount, ePedAttribute.PA_SPEED))
    SetAttributePoints(mount, ePedAttribute.PA_ACCELERATION, GetMaxAttributePoints(mount, ePedAttribute.PA_ACCELERATION))
    SetAttributePoints(mount, ePedAttribute.PA_BONDING, GetMaxAttributePoints(mount, ePedAttribute.PA_BONDING))
    SetAttributePoints(mount, ePedAttribute.SA_BODYWEIGHT, GetMaxAttributePoints(mount, ePedAttribute.SA_BODYWEIGHT))
    SetAttributePoints(mount, ePedAttribute.MTR_STRENGTH, GetMaxAttributePoints(mount, ePedAttribute.MTR_STRENGTH))
    SetAttributePoints(mount, ePedAttribute.MTR_GRIT, GetMaxAttributePoints(mount, ePedAttribute.MTR_GRIT))
    SetAttributePoints(mount, ePedAttribute.MTR_INSTINCT, GetMaxAttributePoints(mount, ePedAttribute.MTR_INSTINCT))
    SetAttributePoints(mount, ePedAttribute.SA_DIRTINESSSKIN, 0) -- clean

    --
    -- as in R* scripts (net_stable_mount.c)
    -- 
    
    SetPedConfigFlag(PlayerPedId(), 561, true) -- PCF_EnableHorseCollectPlantInteractionInMP

    SetPedCanBeLassoed(mount, false)
    RequestPedVisibilityTracking(mount)
    SetPedShouldIgnoreAvoidanceVolumes(mount, 1)
    SetPedConfigFlag(mount, 400, true)
    SetPedConfigFlag(mount, 208, true)
    SetPedConfigFlag(mount, 209, true)
    SetPedConfigFlag(mount, 297, true)
    SetPedConfigFlag(mount, 277, true)
    SetPedConfigFlag(mount, 230, true)
    SetPedConfigFlag(mount, 324, true)
    SetPedConfigFlag(mount, 319, true)
    SetPedLassoHogtieFlag(mount, 0, false)

    SetPedConfigFlag(mount, 388, false) --PCF_DisableFatallyWoundedBehaviour

    SetPedShouldIgnoreAvoidanceVolumes(mount, 2)
    SetPedRelationshipGroupHash(mount, GetPedRelationshipGroupHash(PlayerPedId()))

    SetTransportConfigFlag(mount, 6, 0)
    SetTransportConfigFlag(mount, 3, 0)

    SetPlayerOwnsMount(PlayerId(), mount)
    SetPlayerMountStateActive(PlayerId(), true)
    --SetPedAsTempPlayerHorse(PlayerId(), mount)

    SetMountBondingLevel(mount, GetMaxAttributeRank(mount, ePedAttribute.PA_BONDING))
    CompendiumHorseBonding(mount, GetMaxAttributeRank(mount, ePedAttribute.PA_BONDING))


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

                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local mountCoords = GetEntityCoords(mount)
                local dist = GetVectorDistSqr(playerCoords, mountCoords)

                if dist < 7.6 then
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
                    PromptSetVisible(brushPrompt, 0)
                    PromptSetVisible(feedPrompt, 0)
                end                    
                     
                
            end

        end
    end)  
    
    SetEntityInvincible(mount, false)
end



W.Events.AddHandler(`EVENT_PED_ANIMAL_INTERACTION`, function(data)
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

W.Events.AddHandler(`EVENT_CALM_PED`, function(data)
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

function OnFeed()
    bRunningTask = true
    TaskAnimalInteraction(PlayerPedId(), mount, `Interaction_Food`, `p_apple01x`, 0)

    SetTimeout(5000, function()
        bRunningTask = false
        ClearPedBloodDamage(mount)
        ClearPedDamageDecalByZone(mount, 10, "ALL")
        ClearPedEnvDirt(mount)

        SetAttributePoints(mount, ePedAttribute.PA_HEALTH, GetMaxAttributePoints(mount, ePedAttribute.PA_HEALTH))
        SetAttributePoints(mount, ePedAttribute.PA_STAMINA, GetMaxAttributePoints(mount, ePedAttribute.PA_STAMINA))

        SetAttributeCoreValue(mount, 0, 100)
        SetAttributeCoreValue(mount, 1, 100)
        SetEntityHealth(mount, 100, 0)
        RestorePedStamina(mount, 100.0)
    end)
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

        ModifyPlayerUiPrompt(PlayerId(), 49, 0, 1)
        ModifyPlayerUiPrompt(PlayerId(), 50, 0, 1)


        ModifyPlayerUiPrompt(PlayerId(), 28, 0, 0) -- PP_HORSE_ITEMS
        ModifyPlayerUiPrompt(PlayerId(), 45, 0, 0) -- PP_HORSE_WEAPONS_HOLD
        ModifyPlayerUiPrompt(PlayerId(), 46, 0, 0) -- PP_HORSE_WEAPONS
        ModifyPlayerUiPrompt(PlayerId(), 47, 0, 0) -- PP_HORSE_PROXIMITY_INTERACT
	end
end)

local foo = 0

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)	
		if IsControlJustPressed(0, `INPUT_WHISTLE`) then
            OnWhistle()
        end

        if IsControlJustPressed(0, `INPUT_INTERACT_HORSE_BRUSH`) then
            OnBrush()
        end

        if IsControlJustPressed(0, `INPUT_INTERACT_HORSE_FEED`) then
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

-- Cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        RemoveBlip(mountBlip)
        DeletePed(mount)
    end
end)