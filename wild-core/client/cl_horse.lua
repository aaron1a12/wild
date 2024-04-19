-- ///////////////////////////////////////////////////////////////////////////////////////////////////
-- // cl_horse.lua
-- // Purpose: restores "giddy up" and "whoa" speech lines while riding horse
-- ///////////////////////////////////////////////////////////////////////////////////////////////////

local timeSinceSpeech = 0

local CMD_SPRINT = 0
local CMD_STOP = 1
local lastCmd = -1

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
		timeSinceSpeech = timeSinceSpeech + GetFrameTime()
		
		if IsControlJustPressed(0, "INPUT_HORSE_SPRINT") or IsControlJustPressed(0, "INPUT_HORSE_STOP") then
		
			local playerPed = GetPlayerPed(PlayerId())
			local playerPed_net = PedToNet(playerPed)
			
			local IsSprinting = IsControlJustPressed(0, "INPUT_HORSE_SPRINT")
			local IsStopping = IsControlJustPressed(0, "INPUT_HORSE_STOP")
			
			if IsSprinting and (lastCmd ~= CMD_SPRINT or timeSinceSpeech > 10.0) then
				TriggerServerEvent('wild:sv_onHorseSprint', playerPed_net)
				lastCmd = CMD_SPRINT
				timeSinceSpeech = 0
			end
			
			if IsStopping and (lastCmd ~= CMD_STOP or timeSinceSpeech > 10.0) then
				TriggerServerEvent('wild:sv_onHorseStop', playerPed_net)
				lastCmd = CMD_STOP
				timeSinceSpeech = 0
			end
		end	
	end
end)

RegisterNetEvent("wild:cl_onHorseSprint")
AddEventHandler("wild:cl_onHorseSprint", function(riderPed_net)
	local riderPed = NetToPed(riderPed_net)
	PlayAmbientSpeechFromEntity(riderPed, "", "GIDDY_UP", "speech_params_force", 0)
end)

RegisterNetEvent("wild:cl_onHorseStop")
AddEventHandler("wild:cl_onHorseStop", function(riderPed_net)
	local riderPed = NetToPed(riderPed_net)
	PlayAmbientSpeechFromEntity(riderPed, "", "WHOA", "speech_params_force", 0)
end)