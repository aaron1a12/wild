-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

-- How to get money:  W.GetPlayerMoney()
-- How to give/remove money:  TriggerServerEvent("wild:sv_giveMoney", GetPlayerName(PlayerId()), amount)

Citizen.CreateThread(function()

    -- Gun smith counter in Valentine
    local v = vector3(-281.6, 780.7, 119.5)

	while true do
		Citizen.Wait(1000)
		
        local playerPed = GetPlayerPed(player)
        local playerCoords = GetEntityCoords(playerPed)
        --ShowText("X:".. tostring(playerCoords.x).."|Y:"..tostring(playerCoords.y).."|Z:"..tostring(playerCoords.z))

        local dist = GetDistanceBetweenCoords(playerCoords, v, true)
        
        if dist < 1.0 then
            
            ShowHelpText("Press ~INPUT_ENTER~ to browse shop", 1000)
        end
	end
end)