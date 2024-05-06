NpcManager = {}
NpcManager.NetPool = {}
NpcManager.PersistentPool = {}

local function LoadPersistentPool()
    NpcManager.PersistentPool = json.decode(LoadResourceFile(GetCurrentResourceName(), "npcs.json"))
end
LoadPersistentPool()

local function SavePersistentPool()
    SaveResourceFile(GetCurrentResourceName(), "npcs.json", json.encode(NpcManager.PersistentPool), -1)
end
SavePersistentPool()

-- Fast vector dist. Avoids native invocation
function GetVectorDistSqr(a, b)
	local x = b.x-a.x
	local y = b.y-a.y
	local z = b.z-a.z

	return (x*x) + (y*y) + (z*z)
end

function GetVectorDist(a, b)
	return math.sqrt(GetVectorDistSqr(a, b));
end
  
RegisterNetEvent('wild:npcManager:sv_ensure', function(resource, name, defaultCoords, defaultHeading, saveCoordsAndHeading)
    if NpcManager.NetPool[name] == nil then 

        local coords = defaultCoords
        local heading = defaultHeading
        
        -- Load persistent data if we save coords
        if saveCoordsAndHeading then
            if NpcManager.PersistentPool[name] ~= nil then
                local persistentData = NpcManager.PersistentPool[name]
                coords = vector3(persistentData[1], persistentData[2], persistentData[3])
                heading = persistentData[4]
            end
        end

        NpcManager.NetPool[name] = {
            ["Resource"] = resource,
            ["DefaultCoords"] = defaultCoords,
            ["DefaultHeading"] = defaultHeading,
            ["SaveCoordsAndHeading"] = saveCoordsAndHeading,
            ["NetId"] = 0,
        }

        NpcManager:Reallocate()
    else
        print("Warning: did not reallocate")
    end
end) 

RegisterNetEvent('wild:npcManager:sv_updateNpc', function(name, coords, heading)
    if NpcManager.NetPool[name].SaveCoordsAndHeading then
        NpcManager.PersistentPool[name] = {coords.x, coords.y, coords.z, heading}
    end
end)

-- Called after a client deleted a ped
RegisterNetEvent('wild:npcManager:sv_getCoords', function(name)
    local coords = nil

    if NpcManager.PersistentPool[name] ~= nil then
        
        local persistentData = NpcManager.PersistentPool[name]
        coords = vector3(persistentData[1], persistentData[2], persistentData[3])
        heading = persistentData[4]
    else
        coords = NpcManager.NetPool[name].DefaultCoords
        heading = NpcManager.NetPool[name].DefaultHeading
    end

    TriggerClientEvent('wild:npcManager:cl_getCoords', source, coords, heading)
end)

-- Called after a client created a ped
RegisterNetEvent('wild:npcManager:sv_onCreatedPed', function(name, netId)
    NpcManager.NetPool[name].NetId = netId
    TriggerClientEvent('wild:npcManager:cl_onCreatedPed', -1, name, netId)
end)

-- Called after a client deleted a ped
RegisterNetEvent('wild:npcManager:sv_onDeletePed', function(name, coords, heading)
    TriggerClientEvent('wild:npcManager:cl_onDeletePed', -1, name)

    if NpcManager.NetPool[name].SaveCoordsAndHeading then
        NpcManager.PersistentPool[name] = {coords.x, coords.y, coords.z, heading}
    end
end)


local haltedCount = 0
RegisterNetEvent('wild:npcManager:sv_halted', function()
    haltedCount = haltedCount + 1
end)

-- Redistributes the assignment of specific npcs to specific client managers
-- Evenly allocated at the moment, maybe distance to npc should factor?
function NpcManager:Reallocate()   
    local players = GetPlayers()
    local nPlayers = 0

    for _, i in pairs(players) do
        nPlayers = nPlayers + 1
    end

    if nPlayers == 0 then
        -- All players have left.
        return
    end

    haltedCount = 0
    TriggerClientEvent('wild:npcManager:cl_halt', -1)

    local startTime = GetGameTimer()
    local elapsedTime = 0

    -- Wait until all clients have halted or elapsedTime passes the 5-sec timeout
    while (haltedCount < nPlayers) and (elapsedTime < 5000) do
        Citizen.Wait(0)
        elapsedTime = GetGameTimer() - startTime
    end

    -- All clients have halted or it's safe to proceed.

    local npcs = {}

    for name, npc in pairs(NpcManager.NetPool) do
        table.insert(npcs, name)
    end

    -- Calculate the shares for each player

    -- Each player will receive a "bucket" of npcs
    local shareBuckets = {}
    
    local portion = math.floor(#npcs / nPlayers)
    local remainder = math.fmod(#npcs, nPlayers)
    
    for i = 1, nPlayers do
        local share = portion
        if i <= remainder then
            share = share + 1
        end

        -- This will hold the npcs we are apportioning for this specific bucket
        local bucket = {}
  
        for i=1, share do
          table.insert(bucket, table.remove(npcs, 1))
        end

        table.insert(shareBuckets, bucket)
    end

    -- The shareBuckets array is now filled with buckets. Send them out
    -- Note: management is automatically restarted on clients

    local bucketIndex = 1

    for _, src in pairs(players) do
        TriggerClientEvent('wild:npcManager:cl_receiveBucket', src, shareBuckets[bucketIndex])
        bucketIndex = bucketIndex + 1
    end
end

-- Allows clients to request a redistribution of npc buckets for management
-- (Triggered when player spawned in the world)
RegisterNetEvent('wild:npcManager:sv_reallocate', function()
    NpcManager:Reallocate()
end)

-- Reallocate when players leave
AddEventHandler('playerDropped', function (reason)
    NpcManager:Reallocate()
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(4000)

        SavePersistentPool()
    end
end)


AddEventHandler('onResourceStop', function(resourceName)
    for name, npc in pairs(NpcManager.NetPool) do
        if npc.Resource == resourceName then
            NpcManager.NetPool[name] = nil
        end
    end
end)