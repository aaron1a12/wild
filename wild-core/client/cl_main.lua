local timeSinceShown = 0
local bIsHUDVisible = false


local function SetMoneyVisible(bVisible)
    SendNUIMessage({type = "setVisibility", visible = bVisible})
    bIsHUDVisible = bVisible

    if bVisible then
        timeSinceShown = 0 
    end
end

local function SetMoneyAmount(fAmount)
    SendNUIMessage({type = "setMoneyAmount", amount = fAmount})
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)

        if bIsHUDVisible and timeSinceShown < 10.0 and (IsRadarHidden() or IsPauseMenuActive()) then
            SetMoneyVisible(false)
        end
	end
end)



Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if bIsHUDVisible then
		    timeSinceShown = timeSinceShown + GetFrameTime()

            if timeSinceShown > 10.0 then
                SetMoneyVisible(false)
            end
        end
        
        if IsControlJustPressed(0, "INPUT_REVEAL_HUD") then
            SetMoneyVisible(true)
        end
	end
end)

local playerMoney = 0.0

RegisterNetEvent("wild:cl_onLoadMoney")
AddEventHandler("wild:cl_onLoadMoney", function(fAmount)
	playerMoney = fAmount
end)


function GetPlayerMoney()
    return playerMoney
end

local function OnStartUp()
    -- Hide money
    Citizen.InvokeNative(0x4CC5F2FC1332577F, -66088566)
    -- Hide skill cards
    Citizen.InvokeNative(0x4CC5F2FC1332577F, 1058184710)

    Citizen.Wait(1000)
    SetMoneyAmount(0.0)
end
OnStartUp()



Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1000)
		Citizen.InvokeNative(0x4B8F743A4A6D2FF8, true) -- Reveal full map
		NetworkSetFriendlyFireOption(true)
		SetRelationshipBetweenGroups(0, `PLAYER`, `PLAYER`) -- Companion

        for i,player in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(player)
            SetEntityCanBeDamagedByRelationshipGroup(ped, true, `PLAYER`)
        end
	end
end)