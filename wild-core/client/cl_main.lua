
--
-- Player Data
--

W.PlayerData = nil
local _playerData = nil

-- Returns the locally cached player data.
function W.GetPlayerData()
    RefreshPlayerData()
    return W.PlayerData
end

function W.GetPlayerMoney()
    RefreshPlayerData()
    return W.PlayerData["money"]
end

function W.UpdatePlayerMoney(fNewTotal)
    local soundset_ref = "Ledger_Sounds"
    local soundset_name =  "PURCHASE"
    Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
    Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);
    
    local diff = fNewTotal - W.GetPlayerMoney()
    ShowCashPickup(diff, 2000)

    W.PlayerData["money"] = fNewTotal
    
    W.UI.SetMoneyAmount(fNewTotal)
    W.UI.SetVisible(true)
end

RegisterNetEvent("wild:cl_onReceivePlayerData")
AddEventHandler("wild:cl_onReceivePlayerData", function(newPlayerData)
    _playerData = newPlayerData
end)

-- Synchronously loads player data (money, spawn pos, etc) from the server
function RefreshPlayerData()
    if W.PlayerData == nil then -- TODO: Maybe include data age in W.PlayerData so we can check if outdated (1 min, 5 mins, etc.)
        TriggerServerEvent("wild:sv_getPlayerData", GetPlayerName(PlayerId()))

        while _playerData == nil do
            Citizen.Wait(0)
        end

        W.PlayerData = _playerData
        _playerData = nil
    end
end


RegisterNetEvent("wild:cl_onPlayerFirstSpawn")
AddEventHandler("wild:cl_onPlayerFirstSpawn", function()
    -- Hide money
    Citizen.InvokeNative(0x4CC5F2FC1332577F, -66088566)
    -- Hide skill cards
    Citizen.InvokeNative(0x4CC5F2FC1332577F, 1058184710)

    Citizen.Wait(1000)

    -- Show the correct initial amount in NUI
    W.UI.SetMoneyAmount(W.GetPlayerMoney()) 
end)

RegisterNetEvent("wild:cl_onUpdateMoney")
AddEventHandler("wild:cl_onUpdateMoney", function(fAmount)
    W.UpdatePlayerMoney(fAmount)
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