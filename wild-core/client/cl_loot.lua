local function RegisterDecorTypes()
	DecorRegister("ped_looted", 2);
end
RegisterDecorTypes()

local lastLootedPed = 0

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(100)
	
	        local playerPed = GetPlayerPed(player)
	
	        if GetPedLootStatusMp(playerPed) == 1 then -- Attempting to loot
	
	            local lootTarget = GetClosestPedTo(playerPed, 1.0)
	
	            if lootTarget ~= lastLootedPed then
	                Citizen.CreateThread(function()
	                    local timeOut = 0
	    
	                    while (lootTarget ~= lastLootedPed) and timeOut < 2.0 do
	                        Citizen.Wait(0)
	                        timeOut = timeOut + GetFrameTime()
	    
	                        if IsEntityFullyLooted(lootTarget) == 1 and lootTarget ~= lastLootedPed then -- Done looting
	                            lastLootedPed = lootTarget
	                            DecorSetBool(lootTarget, "ped_looted", true)
	                            timeOut = 999.0
	                            
	                            Citizen.Wait(500)
	
	                            math.randomseed(GetGameTimer()/7)
	                            local money = math.random(1, 50) / 100

	                            TriggerServerEvent("wild:sv_giveMoney", GetPlayerName(PlayerId()), money)
	                        end
	                    end
	                end)
	            end          
	        end
	end
end)
