RegisterNetEvent("sv_speak")
AddEventHandler("sv_speak", function(playerPed, targetPed, bAntagonize, seed)
    TriggerClientEvent("cl_speak", -1, playerPed, targetPed, bAntagonize, seed)
end)