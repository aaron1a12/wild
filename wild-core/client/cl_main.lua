-- Start
--

CONFIG = {}

local function LoadConfig()
    CONFIG = json.decode(LoadResourceFile(GetCurrentResourceName(), "config.json"))
end
LoadConfig()

--
-- Player Data
--

local playerData = nil
local _playerData = nil

RegisterNetEvent("wild:cl_onReceivePlayerData")
AddEventHandler("wild:cl_onReceivePlayerData", function(newPlayerData)
    _playerData = newPlayerData
end)

-- Synchronously loads player data (money, spawn pos, etc) from the server
function RefreshPlayerData()
    TriggerServerEvent("wild:sv_getPlayerData", GetPlayerName(PlayerId()))

    while _playerData == nil do
        Citizen.Wait(0)
    end

    playerData = _playerData
    _playerData = nil
end

-- Returns the locally cached player data.
function GetPlayerData()
    if playerData == nil then
        RefreshPlayerData()
    end 

    return playerData
end

--
-- Money NUI
--

local timeSinceShown = 0
local bIsHUDVisible = false

local function SetMoneyVisible(bVisible)
    WildUIWaitUntilReady()
    WildUI({type = "setVisibility", visible = bVisible})
    bIsHUDVisible = bVisible

    if bVisible then
        timeSinceShown = 0 
    end
end

local function SetMoneyAmount(fAmount)
    WildUIWaitUntilReady()
    WildUI({type = "setMoneyAmount", amount = fAmount})
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

function GetPlayerMoney()
    return playerData["money"]
end

function UpdateMoney(fAmount)
    local soundset_ref = "Ledger_Sounds"
    local soundset_name =  "PURCHASE"
    Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
    Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);
    
    local diff = fAmount - GetPlayerMoney()
    ShowCashPickup(diff, 2000)

    playerData["money"] = fAmount
    
    SetMoneyAmount(fAmount)
    SetMoneyVisible(true)
end

RegisterNetEvent("wild:cl_onPlayerFirstSpawn")
AddEventHandler("wild:cl_onPlayerFirstSpawn", function()
    -- Hide money
    Citizen.InvokeNative(0x4CC5F2FC1332577F, -66088566)
    -- Hide skill cards
    Citizen.InvokeNative(0x4CC5F2FC1332577F, 1058184710)

    Citizen.Wait(1000)

    -- Show the correct initial amount in NUI
    SetMoneyAmount(GetPlayerMoney()) 
end)

RegisterNetEvent("wild:cl_onUpdateMoney")
AddEventHandler("wild:cl_onUpdateMoney", function(fAmount)
    UpdateMoney(fAmount)
end)

--
--
--

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

AddEventHandler("onResourceStart", function(resource)
    Citizen.Wait(1000)
    
	if resource == GetCurrentResourceName() then
        RequestIplHash(`amb_camp_cml_story_valentine`)
        RequestIplHash(-87826930)

        RequestIplHash(286801141)
        RequestIplHash(-87826930)

        RequestImap(286801141)
        RequestImap(-87826930)

        Citizen.InvokeNative(0x59767C5A7A9AE6DA, 286801141)
        Citizen.InvokeNative(0x59767C5A7A9AE6DA, -87826930)
        
        RequestIplHash(-2016771661)

        Citizen.Wait(1000)

--        ShowText(tostring(IsIplActiveHash(`amb_camp_roa_story_pigfarm`)))
	end
end)