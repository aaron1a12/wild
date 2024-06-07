iplsToActivate = {
}

iplsToDeactivate = {
}

ipls = json.decode(LoadResourceFile(GetCurrentResourceName(), "ipls.json"))
local iplCount = 0

Citizen.CreateThread(function()
    if W.Config['debugMode'] == true then
        while true do
            Citizen.Wait(0)

            PrintText(0.01, 0.3, 0.3, false, "Active Ipls: " .. tostring(iplCount), 255, 128, 50, 255)
        end
    end
end)

function RefreshIpls()
    if W.Config['debugMode'] == true then
        ipls = json.decode(LoadResourceFile(GetCurrentResourceName(), "ipls.json"))
    end

    iplCount = 0
    local camCoords = GetGameplayCamCoord()

    iplsToActivate = ipls[1]
    iplsToDeactivate = ipls[2]

    local fastDistSqr = GetVectorDistSqr

    for i = 1, #iplsToActivate do
        local ipl = iplsToActivate[i]

        local _, position, radius = GetIplBoundingSphere(ipl)
        local dist = fastDistSqr(camCoords, position)

        if IsPositionInsideIplStreamingExtents(ipl, camCoords.x, camCoords.y, camCoords.z) == 1 and dist < 100000 then
            iplCount = iplCount + 1
            RequestIplHash(ipl)
        else
            if dist > 15000.0 then
                RemoveIplHash(ipl)
            end
        end
    end

    for i = 1, #iplsToDeactivate do
        local ipl = iplsToDeactivate[i]
        RemoveIplHash(ipl)
    end
end

CreateThread(function()
    while true do
        RefreshIpls()
        Citizen.Wait(1000 + GetRandomIntInRange(100, 5000))
    end
end)

AddEventHandler("wild:cl_onPlayerFirstSpawn", function()
    RefreshIpls()
end)