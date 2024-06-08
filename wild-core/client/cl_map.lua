iplsToActivate = {
}

iplsToDeactivate = {
}

ipls = json.decode(LoadResourceFile(GetCurrentResourceName(), "ipls.json"))

function RefreshIpls()
    iplsToActivate = ipls[1]
    iplsToDeactivate = ipls[2]

    for i = 1, #iplsToActivate do
        local ipl = iplsToActivate[i]

        RequestIplHash(ipl)
    end

    for i = 1, #iplsToDeactivate do
        local ipl = iplsToDeactivate[i]
        RemoveIplHash(ipl)
    end
end

AddEventHandler("wild:cl_onPlayerFirstSpawn", function()
    RefreshIpls()
end)

CreateThread(function()
    while true do
        RefreshIpls()
        Citizen.Wait(1000 + GetRandomIntInRange(100, 5000))
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
	Citizen.Wait(1000 + GetRandomIntInRange(100, 5000))
    RefreshIpls()
end)