--==========================================================================================
--
-- Law/Bounty Hunters
--
--==========================================================================================

local bBountyHuntersDeployed = false
local hunters = {}
local hunterReachTimeout = 0
local hunterTimeout = 0

local _, bountyGroupHash = AddRelationshipGroup("bounty_hunter")

function SpawnBountyHunter(x, y, z)

    --
    -- Start a spawnpoint search
    --

    RequestCollisionAtCoord(x, y, z)

    local mountModel = `a_c_horse_thoroughbred_blackchestnut`

    RequestModel(mountModel)

    while not HasModelLoaded(mountModel) do
        RequestModel(mountModel)
        Citizen.Wait(0)
    end

    local mount = CreatePed(mountModel, x, y, z, 45.0, true, true, true)
    SetEntityAsMissionEntity(mount, true, true)

    SetRandomOutfitVariation(mount)
    SetPedRandomComponentVariation(mount, 1)
    EquipMetaPedOutfit(mount, 2169370957)
    UpdatePedVariation(mount, false, true, true, true, false)

    local model = `G_M_M_BountyHunters_01`

    RequestModel(model)

	while not HasModelLoaded( model ) do
		Wait(0)
	end

    local ped = CreatePedOnMount(mount, model, -1, true, true, true, true) --CreatePed(model, spawn.x + 3.5, spawn.y, spawn.z + 1.0, 90.0, true) 
    SetEntityAsMissionEntity(mount, true, true)

    SetPedRelationshipGroupHash(ped, bountyGroupHash)
    --SetPedKeepTask(ped)

    SetRandomOutfitVariation(ped, true)

    SetPedAsCop(ped)
    SetPedCombatAttributes(ped, 5, true)
    SetPedCombatAttributes(ped, 9, true)
    SetPedCombatAttributes(ped, 14, true)
    SetPedCombatStyle(ped, `Mounted_Chase`, 2, -1)

    GiveWeaponCollectionToPed(ped, GetDefaultPedWeaponCollection(model))

    SetPedConfigFlag(hunter, 279, true) --PCF_NeverLeavesGroup. Useless if not in group!
    SetPedConfigFlag(hunter, 167, true)
    
    --TaskWanderInArea(ped, x, y, z,  5.0, 10, 10, 1)
    --SetPedRelationshipGroupHash(ped, FactionRelationships[factionName])
    return ped, mount
end

RegisterCommand('end', function() 
	bBountyHuntersDeployed = false
end, false)

function DeployBountyHunters()
    if bBountyHuntersDeployed then
        return
    end
    
    bBountyHuntersDeployed = true
    ShowHelpText("Citizen alerted bounty hunters", 2000)

    local count = 5
    local distance = 200.0
    hunterReachTimeout = 60 * 1000
    hunterTimeout = 5 * 60 * 1000

    -- First, create a search center by getting a random vehicle node around the player

    local searchCenter = GetEntityForwardVector(PlayerPedId()) * distance
    searchCenter = RotateVectorYaw(searchCenter, GetRandomFloatInRange(-180.0, 180.0))
    searchCenter = searchCenter+GetEntityCoords(PlayerPedId())
    _, searchCenter = GetClosestVehicleNode(searchCenter.x, searchCenter.y, searchCenter.z, 1, 3.0, 0.0)

    DrawDebugCylinderTimed(searchCenter, 0.5, 1000.0, 255, 0, 0, 255, 5000)

    -- Delete previous search?
    SpawnpointsCancelSearch()

    -- Spawn radius (in meters)
    local spawnRadius = 10.0
    local spaceBetweenSpawns = 3.0
    local floor = GetHeightmapBottomZForPosition(searchCenter.x, searchCenter.y)
    
    SpawnpointsStartSearch(searchCenter.x, searchCenter.y, floor, spawnRadius, spawnRadius, 19, spaceBetweenSpawns, 5000, 1048576000)

    while SpawnpointsIsSearchComplete() ~= 1 do -- Must be 1, not a bool
        Citizen.Wait(0)
    end

    local nFound = SpawnpointsGetNumSearchResults()

    SetRelationshipBetweenGroups(6, bountyGroupHash, GetPedRelationshipGroupHash(PlayerPedId()))

    if nFound == 0 then -- Could not find any spawn points?
        bBountyHuntersDeployed = false    
        return 0,0
    else
        local nSpawned = 0
        for i=0, nFound do
            local x, y, z = Citizen.InvokeNative(0x280C7E3AC7F56E90, i, Citizen.PointerValueFloat(), Citizen.PointerValueFloat(), Citizen.PointerValueFloat()) 
            
            if (nSpawned < nFound) and (nSpawned < count) then
                Citizen.CreateThread(function()
                    local hunter, mount = SpawnBountyHunter(x, y, z)

                    table.insert(hunters, hunter)

                    local blip = BlipAddForEntity(`BLIP_STYLE_BOUNTY_HUNTER`, hunter)
                    SetBlipSprite(blip, `blip_ambient_bounty_hunter`, true)
                    SetBlipScale(blip, 0.2)
                    SetBlipName(blip, "Bounty Hunter")
                    BlipAddModifier(blip, `BLIP_MODIFIER_ENEMY_IS_ALERTED`)

                    local bManage = true

                    while bManage and bBountyHuntersDeployed do    
                        Citizen.Wait(100)

                        if DoesEntityExist(hunter) then
                            if IsPedDeadOrDying(hunter) or (IsPedIncapacitated(hunter) and not IsPedHogtied(hunter)) then
                                bManage = false
                            end
                        else
                            bManage = false
                        end
                    end

                    RemoveBlip(blip)
                    SetPedAsNoLongerNeeded(hunter)
                    SetPedAsNoLongerNeeded(mount)

                    for i=1, #hunters do  
                        if hunters[i] == hunter then
                            table.remove(hunters, i)
                        end
                    end
                end)
                nSpawned = nSpawned + 1
            end
        end
    end

    SpawnpointsCancelSearch()

    Citizen.Wait(2000)

    for i=1, #hunters do  
        TaskGoToEntity(hunters[i], PlayerPedId(), -1, 2.5, 1.5, 0, 0)
        --TaskCombatPed(targetPed, sourcePed, 0, 0)
    end

    -- Manage timeouts (unable to reach or lifetime too long)
    -- Also, keep count of how many are still alive to finish the wave
    while bBountyHuntersDeployed do
        Citizen.Wait(100)
        hunterReachTimeout = hunterReachTimeout - 100
        hunterTimeout = hunterTimeout - 100

        ShowText("Hunters: "..tostring(#hunters))

        local bTimeout = false
        if not bTimeout then
            if  hunterReachTimeout < 0 then
                local pedsReached = 0

                for i=1, #hunters do 
                    if IsPedInCombat(hunters[i]) then
                        pedsReached = pedsReached + 1
                    end
                end
                
                if pedsReached ~= #hunters then
                    bTimeout = true
                end
            end

            if hunterTimeout < 0 then
                bTimeout = true
            end
        end

        -- Either no hunter left or timeout
        if #hunters == 0 or bTimeout then
            bBountyHuntersDeployed = false
        end
    end
end


AddEventHandler("wild:cl_onPlayerDeath", function()
    if bBountyHuntersDeployed then
        bBountyHuntersDeployed = false
    end
end)

--==========================================================================================
--
-- Spotting
--
--==========================================================================================

local function RegisterDecorTypes()
	DecorRegister("witness_for", 3);
	DecorRegister("witness_progress", 3);
end
RegisterDecorTypes()


function ReactWithVoice(ped)
    local pool = {}
	local line = ""

	if CanPlayAmbientSpeech(ped, "PLAYER_HARMED_TOWN") then table.insert(pool, "PLAYER_HARMED_TOWN") end
	if CanPlayAmbientSpeech(ped, "GENERIC_SHOCKED_DISBELIEF") then table.insert(pool, "GENERIC_SHOCKED_DISBELIEF") end
	if CanPlayAmbientSpeech(ped, "SHAME_ON_YOU") then table.insert(pool, "SHAME_ON_YOU") end

	-- Pick random
	if #pool > 0 then
        local random = GetRandomIntInRange(1, #pool)
		line = pool[random]
	end

	W.PlayAmbientSpeech(ped, line)
end

function OnPedSeenBadPlayer(ped, playerPed)
	Citizen.CreateThread(function()

		-- Official witness
		local blip = BlipAddForEntity(`BLIP_STYLE_EYEWITNESS`, ped)
		SetBlipSprite(blip, `blip_ambient_eyewitness`, true)
		SetBlipScale(blip, 0.2)
		SetBlipName(blip, "Eye witness")
		BlipAddModifier(blip, `BLIP_MODIFIER_WITNESS_INVESTIGATING`)


		local playerCoords = GetEntityCoords(PlayerPedId())

		TaskLookAtEntity(ped, playerPed, 10000, 0, 51, 0)

		Citizen.Wait(3000)

		ClearPedTasks(ped, true, true)
		TaskReact(ped, playerPed, playerCoords.x, playerCoords.y, playerCoords.z, "TaskCombat_High", -1.0, 10.0, 4)

		Citizen.Wait(1000)

		ReactWithVoice(ped)

		Citizen.Wait(5000)

		TaskWalkAway(ped, playerPed)

		Citizen.Wait(5000)

		ClearPedTasks(ped, true, true)
		TaskFleePed(ped, playerPed, 4, 524292, -1082130432, -1, 0)

		if CanPlayAmbientSpeech(ped, "LAW_HAIL") then
			W.PlayAmbientSpeech(ped, "LAW_HAIL")
		elseif CanPlayAmbientSpeech(ped, "GET_THE_LAW") then
			W.PlayAmbientSpeech(ped, "GET_THE_LAW")
		end

		BlipRemoveModifier(blip, `BLIP_MODIFIER_WITNESS_INVESTIGATING`)
		BlipAddModifier(blip, `BLIP_MODIFIER_WITNESS_IDENTIFIED`)

		--BlipSetStyle()

		local bManage = true
		local bLawHailSuccessful = true

		while bManage do    
			Citizen.Wait(100)

			if DoesEntityExist(ped) then
				if IsPedDeadOrDying(ped) or (IsPedIncapacitated(ped) and not IsPedHogtied(ped)) then
					bLawHailSuccessful = false
					bManage = false
				end
			else
				bManage = false
			end
		end

		RemoveBlip(blip)

		if bLawHailSuccessful then			
            DeployBountyHunters()
		end
	end)
end

--
-- The following block manages player facial recognition by peds
--

Citizen.CreateThread(function()
	local DistSqr = GetVectorDistSqr

	function Dot(a, b)
		return a.x*b.x + a.y*b.y + a.z*b.z;
	end

    while true do    
        Citizen.Wait(1212)

		if W.GetPlayerHonor() > -75.0 then
			goto skip -- Skip the face recognition code if honor not so bad
		end

        if bBountyHuntersDeployed then
			goto skip
		end

		local playerPed = PlayerPedId()
		local playerCoords = GetEntityCoords(PlayerPedId())
		local playerForward = GetEntityForwardVector(playerPed)

		for _, ped in ipairs(GetGamePool('CPed')) do

			if not DecorExistOn(ped, "witness_for") then
				if DistSqr(GetEntityCoords(ped), playerCoords) < 100.0 then -- Must be at face recognition distance

					if not IsPedAPlayer(ped) and IsPedHuman(ped) then

						local dot = Dot(playerForward, GetEntityForwardVector(ped))

						if dot < 0.6 then -- Peds are almost facing opposite. Can recognize face. Could've used IsPedFacingPed :P
							
							if CanPedSeePedCached(ped,  playerPed, true) then -- optimization?

								if IsTargetPedInPerceptionArea(ped, playerPed, -1.0, -1.0, -1.0, -1.0) then -- Player is totally within sight

									-- Okay, we've passed all checks, time for an expensive trace
									if HasEntityClearLosToEntityInFront(ped,  playerPed, 17) then
										DecorSetInt(ped, "witness_for", PlayerId())
										Citizen.Wait(100)
										OnPedSeenBadPlayer(ped, playerPed)
										Citizen.Wait(10000)
									end
								end
								Citizen.Wait(1)
							end
						end

						--[[if GetIsPedInDisputeWithPed(ped, playerPed) == 1 then
							ShowText("DISPUTE")
						end]]
					end
				end
			end

		end

		::skip::
    end     
end)