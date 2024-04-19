-- ///////////////////////////////////////////////////////////////////////////////////////////////////
-- // sv_horse.lua
-- // Purpose: restores "giddy up" and "whoa" speech lines while riding horse
-- ///////////////////////////////////////////////////////////////////////////////////////////////////

RegisterNetEvent("wild:sv_onHorseSprint")
AddEventHandler("wild:sv_onHorseSprint", function(riderPed_net)
    TriggerClientEvent("wild:cl_onHorseSprint", -1, riderPed_net)
end)

RegisterNetEvent("wild:sv_onHorseStop")
AddEventHandler("wild:sv_onHorseStop", function(riderPed_net)
    TriggerClientEvent("wild:cl_onHorseStop", -1, riderPed_net)
end)