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