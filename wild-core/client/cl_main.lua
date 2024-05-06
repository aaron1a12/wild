
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
    --Sounds are now played on ShowCashPickup()
    --local soundset_ref = "Ledger_Sounds"
    --local soundset_name =  "PURCHASE"
    --Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
    --Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);
    
    local diff = fNewTotal - W.GetPlayerMoney()
    ShowCashPickup(diff, 2000)

    W.PlayerData["money"] = fNewTotal
    
    W.UI.SetMoneyAmount(fNewTotal)
    W.UI.SetVisible(true)
end

function W.GetPlayerWorld()
    RefreshPlayerData()
    return W.PlayerData["world"]
end

function W.SetPlayerWorld(worldHash)
    W.PlayerData["world"] = worldHash
    TriggerServerEvent("wild:sv_setPlayerKeyValue", GetPlayerName(PlayerId()), "world", worldHash)

    -- Update game
    if worldHash == `guarma` then
        SetGuarmaWorldhorizonActive(true)
        SetWorldWaterType(1)
        DisableFarArtificialLights(true)
        Citizen.InvokeNative(0xF01D21DF39554115, 0); 
        Citizen.InvokeNative(0xC63540AEF8384732, 0.0, 50.04, 1, 1.15, 1.28, -1082130432, 1.86, 8.1, 1);
    elseif worldHash == `world` then
        SetGuarmaWorldhorizonActive(false)
        SetWorldWaterType(0)
        DisableFarArtificialLights(false)
        Citizen.InvokeNative(0xF01D21DF39554115, 1); 
        ResetGuarmaWaterState()
    end

    SetMinimapZone(worldHash)
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


function test()
    local a = 0.22
    local b = 0.3
    local c = 0.10
    local d = 0.2
    local e = 0.01
    local f = 0.6

    a = 0.022
    b = 0.3
    c = 0.10
    d = 0.2
    e = 0.01
    f = 0.3

    SetVisualSettingFloat("Tonemapping.dark.filmic.A", a)
    SetVisualSettingFloat("Tonemapping.dark.filmic.B", b)
    SetVisualSettingFloat("Tonemapping.dark.filmic.C", c)
    SetVisualSettingFloat("Tonemapping.dark.filmic.D", d)
    SetVisualSettingFloat("Tonemapping.dark.filmic.E", e)
    SetVisualSettingFloat("Tonemapping.dark.filmic.F", f)
    SetVisualSettingFloat("Tonemapping.bright.filmic.A", a)
    SetVisualSettingFloat("Tonemapping.bright.filmic.B", b)
    SetVisualSettingFloat("Tonemapping.bright.filmic.C", c)
    SetVisualSettingFloat("Tonemapping.bright.filmic.D", d)
    SetVisualSettingFloat("Tonemapping.bright.filmic.E", e)
    SetVisualSettingFloat("Tonemapping.bright.filmic.F", f)
    SetVisualSettingFloat("sky.MoonIntensity", 0.0) 
end
test()