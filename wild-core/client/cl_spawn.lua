--
-- Spawn Manager
-- A custom implementation of spawnmanager
--

local bPlayerAlreadySpawnedOnce = false

local function ChooseSpawnPoint(deathCoords)
    local coords = deathCoords
    local heading = 0
  
    -- Delete previous search?
    SpawnpointsCancelSearch()

    -- Spawn radius (in meters)
    local spawnRadius = W.Config["respawnRadius"]

    math.randomseed(123)
    local noiseX = math.random() * spawnRadius
    math.randomseed(1234)
    local noiseY = math.random() * spawnRadius

    local floor = GetHeightmapBottomZForPosition(deathCoords.x + noiseX, deathCoords.y + noiseY)
    
    SpawnpointsStartSearch(deathCoords.x + noiseX, deathCoords.y + noiseY, floor, spawnRadius, spawnRadius, 19, 0.5, 5000, 0)

    while SpawnpointsIsSearchComplete() ~= 1 do -- Must be 1, not a bool
        Citizen.Wait(0)
    end

    local nFound = SpawnpointsGetNumSearchResults()

    if nFound == 0 then -- Could not find any spawn points?  Just spawn at death        
        return deathCoords, heading
    end

    local randomIndex = GetRandomIntInRange(0, nFound)
    local x, y, z = Citizen.InvokeNative(0x280C7E3AC7F56E90, randomIndex, Citizen.PointerValueFloat(), Citizen.PointerValueFloat(), Citizen.PointerValueFloat())  --SpawnpointsGetSearchResult(0)
    coords = vector3(x, y, z)

    SpawnpointsCancelSearch()

    return coords, heading    
end

-- function as existing in original R* scripts. Sourced from spawnmanager.
local function FreezePlayer(id, freeze)
    local player = id
    SetPlayerControl(player, not freeze, false)

    local ped = GetPlayerPed(player)

    if not freeze then
        if not IsEntityVisible(ped) then
            SetEntityVisible(ped, true)
        end

        if not IsPedInAnyVehicle(ped) then
            SetEntityCollision(ped, true)
        end

        FreezeEntityPosition(ped, false)
        --SetCharNeverTargetted(ped, false)
        SetPlayerInvincible(player, false)
    else
        if IsEntityVisible(ped) then
            SetEntityVisible(ped, false)
        end

        SetEntityCollision(ped, false)
        FreezeEntityPosition(ped, true)
        --SetCharNeverTargetted(ped, true)
        SetPlayerInvincible(player, true)
        --RemovePtfxFromPed(ped)

        if not IsPedFatallyInjured(ped) then
            ClearPedTasksImmediately(ped)
        end
    end
end

-- A little hack to simulate player joining when restarting the resource
AddEventHandler("onResourceStart", function(resource)
	if resource == GetCurrentResourceName() then
        Citizen.CreateThread(function()
            while GetResourceState(resource) ~= "started" do -- Wait until state changes
                Citizen.Wait(1)
            end
            print("Wild-core has restarted. Trigger sv_updateSourceMap")
            TriggerServerEvent("wild:sv_updateSourceMap")
            SpawnPlayer()
        end)
	end
end)

local bSpawning = false
local bRespawning = false

function SpawnPlayer()
    
    if bSpawning then
        return
    end   

    bSpawning = true

    local playerData = W.GetPlayerData()

    local spawnCoords = vector3(0,0,0)
    local spawnHeading = 0

    -- If spawning for the first time, don't set bPlayerAlreadySpawnedOnce to true yet
    if not bPlayerAlreadySpawnedOnce then   
        spawnCoords = vector3(playerData.position[1], playerData.position[2], playerData.position[3])
        spawnHeading = playerData.position[4]
    else
        -- Respawning
        spawnCoords, heading = ChooseSpawnPoint(GetEntityCoords(PlayerPedId()))
    end

    FreezePlayer(PlayerId(), true)

    --
    -- MODEL
    --

    local model = `player_zero`
    RequestModel(model)

    -- load the model for this spawn
    while not HasModelLoaded(model) do
        RequestModel(model)

        Wait(0)
    end

    -- change the player model. Set preset after spawning
    SetPlayerModel(PlayerId(), model)

    -- release the player model
    SetModelAsNoLongerNeeded(model)
    
    -- RDR3 player model bits
    if N_0x283978a15512b2fe then
        N_0x283978a15512b2fe(PlayerPedId(), true)
    end

    --
    -- Spawn
    --

    -- preload collisions for the spawnpoint
    RequestCollisionAtCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z)

    -- spawn the player
    local playerPed = PlayerPedId()

    -- Ped preset
    EquipMetaPedOutfitPreset(PlayerPedId(), 3, 0)

    --SetEntityCoordsNoOffset(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
    SetEntityCoordsAndHeadingNoOffset(playerPed, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnHeading, 1, 1)

    NetworkResurrectLocalPlayer(spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnHeading, true, true, false)

    -- gamelogic-style cleanup stuff
    ClearPedTasksImmediately(playerPed)
    --SetEntityHealth(ped, 300) -- TODO: allow configuration of this?
    RemoveAllPedWeapons(playerPed) -- TODO: make configurable (V behavior?)
    ClearPlayerWantedLevel(PlayerId())

    
    local time = GetGameTimer()

    while (not HasCollisionLoadedAroundEntity(playerPed) and (GetGameTimer() - time) < 5000) do
        Citizen.Wait(0)
    end

    ShutdownLoadingScreen()

    -- Unfreeze the player
    FreezePlayer(PlayerId(), false)  

    if not bPlayerAlreadySpawnedOnce then -- On first spawn
        bPlayerAlreadySpawnedOnce = true
         -- For compatability with other resources that handle this event
        TriggerEvent('playerSpawned', {
            ["x"] = spawnCoords.x, ["y"] = spawnCoords.y, ["z"] = spawnCoords.z, ["heading"] = 0.0, ["idx"] = 0.0, ["model"] = 0
        })

        TriggerEvent('wild:cl_onPlayerFirstSpawn')
    end    

    
    AnimpostfxStop("death01")
    DoScreenFadeIn(2000)

    bSpawning = false
    bRespawning = false
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(50)

        if not bPlayerAlreadySpawnedOnce and NetworkIsPlayerActive(PlayerId()) then -- First spawning
            SpawnPlayer()
        end

        if IsEntityDead(PlayerPedId()) then -- Respawning
            if not bRespawning then
                bRespawning = true

                local delayDivided = math.floor(W.Config["respawnDelay"]/3)

                AnimpostfxPlay("MP_SuddenDeath")

                Citizen.Wait(delayDivided)

                AnimpostfxPlay("death01")
                AnimpostfxStop("MP_SuddenDeath")

                Citizen.Wait(delayDivided*2)

                DoScreenFadeOut(500)
                Citizen.Wait(500)

                SpawnPlayer()
            end
        end
    end
end)

--
-- Save player position at regular intervals
--

AddEventHandler("wild:cl_onPlayerFirstSpawn", function()
    Citizen.CreateThread(function()
        local interval = W.Config["positionalSaveInterval"]
        while true do
            Citizen.Wait(interval)
    
            local playerPed = PlayerPedId()
            TriggerServerEvent("wild:sv_savePlayerPosition", GetEntityCoords(playerPed), GetEntityHeading(playerPed))
        end
    end) 
end)