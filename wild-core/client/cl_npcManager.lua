W.NpcManager = {}

--[[ 
==================================================================================
    ClientPool["dutch_at_camp"] = {
        ["Managed"] = false,
        ["Ped"] = 0,
        ["Params"] = {...}

    }
==================================================================================
]]

W.NpcManager.ClientPool = {}

local _coords = nil
local _heading = nil

local function GetNpcCoords(name)
    TriggerServerEvent("wild:npcManager:sv_getCoords", name)

    while _coords == nil or _heading == nil do
        Citizen.Wait(0)
    end

    local coords = _coords
    local heading = _heading
    _coords = nil
    _heading = nil

    return coords, heading
end
RegisterNetEvent("wild:npcManager:cl_getCoords")
AddEventHandler("wild:npcManager:cl_getCoords", function(coords, heading)
	_coords = coords
    _heading = heading
end)


--[[
    How to use EnsureNpcExists()
    ============================

    **Must be called on all clients to register callbacks**

    local params = {}
    params.Model = "cs_dutch"
    params.DefaultCoords = vector3(-128.393, -32.657, 96.175)
    params.DefaultHeading = 267.4
    params.CullMinDistance = 40.0
    params.CullMaxDistance = 50.0
    params.SaveCoordsAndHeading = false
    params.OnActive = function(ped, coords, bOwned)
        if bOwned then
            EquipMetaPedOutfitPreset(ped, 0, false)    
            TaskWanderInArea(ped, coords.x, coords.y, coords.z,  5.0, 10, 10, 1)
        end
    end

    NpcManager:EnsureNpcExists("dutch_at_camp", params)
]]
function W.NpcManager:EnsureNpcExists(uniqueName, params)
    -- Update the params so we can use the callbacks

    local resource = GetInvokingResource()
    W.NpcManager.ClientPool[uniqueName] = {
        ["Managed"] = false,
        ["Ped"] = 0,
        ["Params"] = params,
        ["Resource"] = resource
    }

    if params.DefaultCoords == nil then
        params.DefaultCoords = GetEntityCoords(PlayerPedId())
    end

    if params.DefaultHeading == nil then
        params.DefaultHeading = 0.0
    end

    if params.CullMinDistance == nil then
        params.CullMinDistance = 45.0
    end

    if params.CullMaxDistance == nil then
        params.CullMaxDistance = 50.0
    end

    if params.SaveCoordsAndHeading == nil then
        params.SaveCoordsAndHeading = false
    end

    TriggerServerEvent("wild:npcManager:sv_ensure",
    resource,
    uniqueName,
    params.DefaultCoords,
    params.DefaultHeading,
    params.SaveCoordsAndHeading)

    Citizen.Wait(0)

    if params.SaveCoordsAndHeading == true then
        local retCoords, retHeading = GetNpcCoords(uniqueName)

        params.DefaultCoords = retCoords
        params.DefaultHeading = retHeading
    end    
end

RegisterNetEvent("wild:npcManager:cl_onCreatedPed")
AddEventHandler("wild:npcManager:cl_onCreatedPed", function(name, netId)
    local params = W.NpcManager.ClientPool[name].Params
    local ped = NetToPed(netId)
    
    W.NpcManager.ClientPool[name].Ped = ped
    params.Ped = ped

    if params.OnActivate ~= nil then
        local bOwned = NetworkHasControlOfEntity(ped)
        params:OnActivate(ped, bOwned)
    end
end)

RegisterNetEvent("wild:npcManager:cl_onDeletePed")
AddEventHandler("wild:npcManager:cl_onDeletePed", function(name)
    local params = W.NpcManager.ClientPool[name].Params

    W.NpcManager.ClientPool[name].Ped = 0
    params.Ped = 0

    if params.OnDeactivate ~= nil then
        params:OnDeactivate()
    end
end)


local bHaltManagement = false
local bAllocationEverOccurred = false

-- For when server sends us our official "bucket" of npcs to manage
RegisterNetEvent("wild:npcManager:cl_receiveBucket")
AddEventHandler("wild:npcManager:cl_receiveBucket", function(npcBucket)
    for name, npc in pairs(W.NpcManager.ClientPool) do

        -- Is name in the npc bucket?
        local bFound = false
        for i = 1, #npcBucket do
            if npcBucket[i] == name then
                bFound = true
                break
            end
        end

        if bFound then
            npc.Managed = true

            -- Does the ped already exist?
            if DoesEntityExist(npc.Ped) then
                NetworkRequestControlOfEntity(npc.Ped)
	
                local timeOut = 5000
                while timeOut > 0 and not NetworkHasControlOfEntity(npc.Ped) do
                    Wait(50)
                    timeOut = timeOut - 50
                end

                if not NetworkHasControlOfEntity(npc.Ped) then
                    ShowText("ERROR: Managing ped with no control of it!")
                end
            end
        else
            npc.Managed = false
        end
    end

    print("Received bucket. The following npcs are now managed:")

    for name, npc in pairs(W.NpcManager.ClientPool) do
        if npc.Managed then
            print(name)
        end
    end

    bHaltManagement = false
    bAllocationEverOccurred = true
end)

-- For when server requests we halt management
RegisterNetEvent("wild:npcManager:cl_halt")
AddEventHandler("wild:npcManager:cl_halt", function()
    bHaltManagement = true
    TriggerServerEvent("wild:npcManager:sv_halted")
end)

function W.NpcManager:ManageNow()
    --[[
        local allPlayerCoords = {}
        for _, ped in ipairs(GetGamePool('CPed')) do
		if IsPedAPlayer(ped) then
            table.insert(allPlayerCoords, GetEntityCoords(ped))
        end
    end]]

    -- For each Npc
    for name, npc in pairs(W.NpcManager.ClientPool) do

        if npc.Managed then

            local pedCoords = npc.Params.DefaultCoords
            local pedHeading = npc.Params.DefaultHeading

            local bExists = DoesEntityExist(npc.Ped)

            if bExists then
                pedCoords = GetEntityCoords(npc.Ped)
                pedHeading = GetEntityHeading(npc.Ped)
            end

            local bShouldCreate = false
            local nOutsideMaxCull = 0
            local nPlayerCount = 0
            --local closestPlayer = nil
            local smallestDist = 99999999.9 -- should be max float

            -- For each player
            for i, player in ipairs(GetActivePlayers()) do
                nPlayerCount = nPlayerCount + 1

                --
                -- If outside everyone's max cull distance, destroy. If inside anyone's min cull distance, create.
                --

                local dist = GetVectorDist(pedCoords, GetEntityCoords(GetPlayerPed(player)))

                if dist < smallestDist then
                    --closestPlayer = src
                    smallestDist = dist
                end

                if not bExists and not bShouldCreate then
                    if dist < npc.Params.CullMinDistance then
                        bShouldCreate = true
                    end
                end

                if bExists then
                    if dist > npc.Params.CullMaxDistance then
                        nOutsideMaxCull = nOutsideMaxCull + 1
                    end
                end            
            end

            if bShouldCreate then -- Create ped

                -- Fetch last coords
                if npc.Params.SaveCoordsAndHeading then
                    local retCoords, retHeading = GetNpcCoords(name)
                    pedCoords = retCoords
                    pedHeading = retHeading
                end
            
                RequestModel(npc.Params.Model)
            
                while not HasModelLoaded(npc.Params.Model) do
                    Wait(0)
                end
            
                RequestCollisionAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
                local ped = CreatePed(npc.Params.Model, pedCoords.x, pedCoords.y, pedCoords.z - 0.75, pedHeading, true)
                --EquipMetaPedOutfitPreset(ped, 0, false)
                SetEntityAsMissionEntity(npc.Ped, true, true)
            
                local netId = PedToNet(ped)
                SetNetworkIdExistsOnAllMachines(netId, true)
            
                -- Remotely trigger all callbacks
                TriggerServerEvent("wild:npcManager:sv_onCreatedPed", name, netId)

                SetModelAsNoLongerNeeded(npc.Params.Model)
                --SetEntityAsNoLongerNeeded(ped)

                -- Makes ped not walk away when set as no longer needed
                SetPedKeepTask(npc.Ped, true)

                
                NetworkRequestControlOfEntity(npc.Ped)
	
                local timeOut = 5000
                while timeOut > 0 and not NetworkHasControlOfEntity(npc.Ped) do
                    Wait(50)
                    timeOut = timeOut - 50
                end

                if not NetworkHasControlOfEntity(npc.Ped) then
                    print("Failed to gain control of entity!")
                end
            

            elseif nOutsideMaxCull == nPlayerCount then -- Outside of everybody's cull range

                SetEntityAsNoLongerNeeded(npc.Ped)
                DeletePed(npc.Ped)

                -- Remotely trigger all callbacks
                TriggerServerEvent('wild:npcManager:sv_onDeletePed', name, pedCoords, pedHeading)
                
            end

        end -- of if npc.Managed
    end -- end npc iteration
end


Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)

        if not bHaltManagement then
            W.NpcManager:ManageNow()
        end
    end
end)


-- Save persistent peds
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(6000)

        -- For each Npc
        for name, npc in pairs(W.NpcManager.ClientPool) do
            if npc.Params.SaveCoordsAndHeading then
                if DoesEntityExist(npc.Ped) then
                    pedCoords = GetEntityCoords(npc.Ped)
                    pedHeading = GetEntityHeading(npc.Ped)

                    TriggerServerEvent('wild:npcManager:sv_updateNpc', name, pedCoords, pedHeading)
                    Citizen.Wait(1200)
                end
            end
        end
    end
end)


-- Request a redistribution of npc buckets for management when spawning for the first time
AddEventHandler("wild:cl_onPlayerFirstSpawn", function()
    Citizen.Wait(5000)

    -- When a client ensures and the npc already exists, no reallocation occurs to prevent
    -- multiple reallocations happening at once. However, if a new player joins an existing
    -- session and ensures existing npcs, still no reallocation will occur.

    if not bAllocationEverOccurred then
        TriggerServerEvent('wild:npcManager:sv_reallocate')
    end
end)


-- The garbage collection
AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then

        for name, npc in pairs(W.NpcManager.ClientPool) do
            if npc.Resource == resourceName then
                if DoesEntityExist(npc.Ped) then
                    SetEntityAsNoLongerNeeded(npc.Ped)
                    DeletePed(npc.Ped)
                end

                W.NpcManager.ClientPool[name] = nil
            end
        end
                
	else -- wild-core is stopping, clean everything

        for name, npc in pairs(W.NpcManager.ClientPool) do
            if DoesEntityExist(npc.Ped) then
                SetEntityAsNoLongerNeeded(npc.Ped)
                DeletePed(npc.Ped)
            end
        end
		
	end
end)