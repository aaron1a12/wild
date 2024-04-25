local function TestGang()
    -- TODO: CreatePed
end

AddEventHandler("wild:cl_onPlayerFirstSpawn", function()
    if CONFIG['debugMode'] == true then
        while true do          
            local playerPed = GetPlayerPed(player)
            local playerCoords = GetEntityCoords(playerPed)

             -- ALT + 3
            if IsControlJustPressed(0, "INPUT_EMOTE_TWIRL_GUN_VAR_D") and IsControlPressed(0, "INPUT_HUD_SPECIAL") then
                TestGang()
            end
        end
    end
end)