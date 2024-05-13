iplsToActivate = {
}

iplsToDeactivate = {
}

function RefreshIpls()
    ipls = json.decode(LoadResourceFile(GetCurrentResourceName(), "ipls.json"))

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


AddEventHandler('onResourceStart', function(resourceName)
	Citizen.Wait(1000 + GetRandomIntInRange(100, 5000))
    RefreshIpls()
end)