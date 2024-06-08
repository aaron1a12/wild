
local witnessTime = 0
AddEventHandler("EVENT_CRIME_CONFIRMED", function(data) 
	local crime = data[1]
	local criminalPed = data[2]
	local witnessPed = data[3]

    if crime == `CRIME_MURDER_ANIMAL` or crime == `CRIME_MURDER_LIVESTOCK` then
        return
    end

	if criminalPed == PlayerPedId() then

        if (GetGameTimer() - witnessTime > 5000) then
            witnessTime = GetGameTimer()

            Citizen.Wait(4000)
            
			-- Affect honor
			W.AddPlayerHonor(W.Config.Honor["onKill"])

			local coords = GetEntityCoords(criminalPed)

            TriggerServerEvent("wild:sv_reportCrime", crime, PedToNet(criminalPed), PedToNet(witnessPed), coords)
        end        
	end
end)

local lastEscalatedPed = 0

AddEventHandler("EVENT_PLAYER_ESCALATED_PED", function(data) 
	local escalator = data[1]
	local ped = data[2]
		
	if escalator == PlayerPedId() then
		if ped ~= lastEscalatedPed then
			lastEscalatedPed = ped

			if GetRelationshipBetweenPeds(ped, escalator) <= 3 then
				-- Affect honor
				W.AddPlayerHonor(W.Config.Honor["onEscalate"])    
			end
		end
	end
end)

local blip = 0
local blipTime = 0

RegisterNetEvent("wild:cl_onCrimeReported", function(crime, criminalPedNet, witnessPedNet, coords)
	blipTime = GetGameTimer()

	if blip ~= 0 then -- Existing blip
		RemoveBlip(blip)
		Citizen.Wait(1000)
	else -- New blip
		Citizen.CreateThread(function()
			while GetGameTimer() - blipTime < 20000 do
				Citizen.Wait(100)
			end

			BlipRemoveModifier(blip, `BLIP_MODIFIER_WITNESS_IDENTIFIED`)
			BlipAddModifier(blip, `BLIP_MODIFIER_WITNESS_UNIDENTIFIED`)

			while GetGameTimer() - blipTime < 60000 do
				Citizen.Wait(100)
			end

			RemoveBlip(blip)
			blip = 0
			blipTime = 0
		end)
	end

	blip = BlipAddForRadius(`BLIP_STYLE_EVADE_AREA`, coords.x, coords.y, coords.z, 50.0)
	BlipAddModifier(blip, `BLIP_MODIFIER_WITNESS_IDENTIFIED`) 
end)


AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
		if blip ~= 0 then
        	RemoveBlip(blip)
		end
    end
end)