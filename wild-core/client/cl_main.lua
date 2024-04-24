-- Start
--

CONFIG = {}

local function LoadConfig()
    CONFIG = json.decode(LoadResourceFile(GetCurrentResourceName(), "config.json"))
end
LoadConfig()

--
-- Money NUI
--

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

        if bIsHUDVisible and timeSinceShown < 3.0 and IsPauseMenuActive() then
            SetMoneyVisible(false)
        end
	end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if bIsHUDVisible then
		    timeSinceShown = timeSinceShown + GetFrameTime()

            if timeSinceShown > 3.0 then
                SetMoneyVisible(false)
            end
        end
        
        if IsControlJustPressed(0, "INPUT_REVEAL_HUD") then
            SetMoneyVisible(true)
        end
	end
end)

--
-- Player Money/Loadout
--

local bPlayerSpawned = false
local playerMoney = 0.0

function GetPlayerMoney()
    return playerMoney
end

function UpdateMoney(fAmount)
    local soundset_ref = "Ledger_Sounds"
    local soundset_name =  "PURCHASE"
    Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
    Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);
    
    local diff = fAmount - playerMoney
    ShowCashPickup(diff, 2000)

    playerMoney = fAmount
    
    SetMoneyAmount(fAmount)
    SetMoneyVisible(true)
end

AddEventHandler("playerSpawned", function(spawn)
    if not bPlayerSpawned then
	    TriggerServerEvent("wild:sv_onPlayerSpawned")
        bPlayerSpawned = true
    end
end)

AddEventHandler("onResourceStart", function(resource)
	if resource == GetCurrentResourceName() then
        if not bPlayerSpawned then
            TriggerServerEvent("wild:sv_onPlayerSpawned")
            bPlayerSpawned = true
        end
	end
end)

RegisterNetEvent("wild:cl_onPlayerSpawned")
AddEventHandler("wild:cl_onPlayerSpawned", function(userData)

    -- Hide money
    Citizen.InvokeNative(0x4CC5F2FC1332577F, -66088566)
    -- Hide skill cards
    Citizen.InvokeNative(0x4CC5F2FC1332577F, 1058184710)

    Citizen.Wait(1000)

    UpdateMoney(userData["money"])   
end)

RegisterNetEvent("wild:cl_onUpdateMoney")
AddEventHandler("wild:cl_onUpdateMoney", function(fAmount)
    UpdateMoney(fAmount)
end)

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