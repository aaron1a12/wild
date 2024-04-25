RegisterNetEvent("wild:cl_uiPing")
AddEventHandler("wild:cl_uiPing", function()
     TriggerEvent('wild:cl_onUiPingBack')
end)

RegisterNetEvent("wild:cl_sendNuiMessage")
AddEventHandler("wild:cl_sendNuiMessage", function(messageObj)
    SendNUIMessage(messageObj)
end)


RegisterNetEvent("wild:cl_registerCallback")
AddEventHandler("wild:cl_registerCallback", function(cbName, func)
    RegisterNUICallback(cbName, func)
end)