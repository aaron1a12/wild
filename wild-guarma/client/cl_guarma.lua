-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

local purchaseLocations = {
    vector3(2703.77, -1507.5, 44.18),
    vector3(2661.78, -1544.2, 46.03),
    vector3(2444.64, -1543.7, 46.10),
    vector3(2783.5, -1489.21, 41.95),
}

local guarmaLocations = {
    vector3(1268.81, -6853.32, 43.31),
}

local ticketCost = 9.95

local stDenisCamCoords = vector3(2724.0, -1543.3, 59.2)
local stDenisCamRot = vector3(-7.3, 0.0, 45.0)

local guarmaCamCoords = vector3(1264.0, -6837.6, 46.0)
local guarmaCamRot = vector3(0.0, 0.0, -160.0)

local prompt = 0

Citizen.CreateThread(function()   
    while true do
        Citizen.Wait(10)
        

        local playerCoords = GetEntityCoords(PlayerPedId())

        local bInValidAreas = false
        local bIsInGuarmaDock = false

        for i = 1, #purchaseLocations do
            -- Squared dist for optimization
            local distSqr = GetVectorDistSqr(playerCoords, purchaseLocations[i])

            if distSqr*0.1 < 3.0 then
                bInValidAreas = true
                break
            end
        end

        for i = 1, #guarmaLocations do
            local distSqr = GetVectorDistSqr(playerCoords, guarmaLocations[i])

            if distSqr*0.1 < 3.0 then
                bInValidAreas = true
                bIsInGuarmaDock = true
                break
            end
        end

        if bInValidAreas then
        
            if prompt == 0 then -- Create prompt
                local str = "Travel to Guarma for $" .. ticketCost

                if bIsInGuarmaDock then
                    str = "Travel back for FREE"
                end

                prompt = PromptRegisterBegin()
                PromptSetControlAction(prompt, `INPUT_CONTEXT_X`) -- R key
                PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", str))
                UiPromptSetHoldMode(prompt, 2000)
                PromptRegisterEnd(prompt)
            
                -- Useful management. Automatically deleted when restarting resource
                W.Prompts.AddToGarbageCollector(prompt)         
            end

            if UiPromptGetProgress(prompt) == 1.0 then
                PromptDelete(prompt)
                prompt = 0

                if W.GetPlayerMoney() < ticketCost and not bIsInGuarmaDock then
                    ShowHelpText("You do not have enought funds!", 2000)

                    local soundset_ref = "RDRO_Poker_Sounds"
                    local soundset_name =  "player_turn_countdown_start"
                    Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
                    Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);
                else
                    ShowHelpText("Welcome aboard", 2000)

                    local soundset_ref = "RDRO_Poker_Sounds"
                    local soundset_name =  "player_turn_countdown_end"
                    Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
                    Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);

                    if not bIsInGuarmaDock then
                        TriggerServerEvent("wild:sv_giveMoney", GetPlayerName(PlayerId()), -ticketCost)
                    end

                    local targetCoords = vector3(0,0,0)

                    if not bIsInGuarmaDock then
                        targetCoords =  guarmaLocations[1]
                    else
                        targetCoords = purchaseLocations[1]
                    end

                    --
                    -- Bon voyage
                    --

                    Citizen.InvokeNative(0x1E5185B72EF5158A, "OpenWorldMusic_FastTravel_StartEvent")  -- PREPARE_MUSIC_EVENT
                    Citizen.InvokeNative(0x706D57B0F50DA710, "OpenWorldMusic_FastTravel_StartEvent")  -- TRIGGER_MUSIC_EVENT
                    
                    SetCinematicModeActive(true)

                    local camCoords = vector3(0,0,0)
                    local camRot = vector3(0,0,0)

                    if not bIsInGuarmaDock then -- Heading to Guarma                
                        camCoords = stDenisCamCoords
                        camRot = stDenisCamRot
                    else
                        camCoords = guarmaCamCoords
                        camRot = guarmaCamRot
                    end

                    local travelCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camCoords.x, camCoords.y, camCoords.z, camRot.x, camRot.y, camRot.z, 60.0, false, 0)

                    SetCamActive(travelCam, true)
                    RenderScriptCams(true, false, 0, true, true, 0)

                    Citizen.Wait(2000)
                    DoScreenFadeOut(2000)
                    Citizen.Wait(2000)
                    DoScreenFadeIn(500)

                    local label = "Traveling to Gaurma...";
                    if bIsInGuarmaDock then
                        label = "Going home...";
                    end

                    DisplayLoadingScreens(0, 0, 0, label, "Loading...", "Did you know Guarma is nowhere near Tahiti?")

                    -- Move the player
                    SetEntityCoordsAndHeading(PlayerPedId(), targetCoords.x, targetCoords.y, targetCoords.z, 0)

                    -- Move the cam as well
                    
                    if not bIsInGuarmaDock then -- Heading to Guarma                
                        SetCamCoord(travelCam, guarmaCamCoords.x, guarmaCamCoords.y, guarmaCamCoords.z)
                        SetCamRot(travelCam, guarmaCamRot.x, guarmaCamRot.y, guarmaCamRot.z)
                    else
                        SetCamCoord(travelCam, stDenisCamCoords.x, stDenisCamCoords.y, stDenisCamCoords.z)
                        SetCamRot(travelCam, stDenisCamRot.x, stDenisCamRot.y, stDenisCamRot.z)
                    end
                    
                    -- Update World
                    if not bIsInGuarmaDock then -- Heading to Guarma
                        W.SetPlayerWorld(`guarma`)
                    else --Heading back
                        W.SetPlayerWorld(`world`)
                    end

                    Citizen.Wait(3000) -- Load time

                    DoScreenFadeOut(500)
                    ShutdownLoadingScreen()

                    while GetIsLoadingScreenActive() == 1 do
                        Citizen.Wait(0)
                    end
                    
                    DoScreenFadeIn(8000)
                    RenderScriptCams(false, true, 8000, true, true, 0)

                    -- Draw black for a second (fixes broken camera at first frames)
                    Citizen.CreateThread(function()
                        local timeLeft = 2.0
                        while timeLeft > 0 do
                            Citizen.Wait(0)
                            if not HasStreamedTextureDictLoaded("generic_textures") then
                                RequestStreamedTextureDict("generic_textures", false);
                            else
                                DrawSprite("generic_textures", "inkroller_1a", 0.0, 0.0, 10.0, 10.0, 0.0, 0, 0, 0, 255, false);
                            end
                            timeLeft = timeLeft - GetFrameTime()
                        end
                    end)

                    Citizen.Wait(4000)

                    -- Release menu lock after fully blended out
                    Citizen.CreateThread(function()
                        Citizen.Wait(4000)
                        SetCamActive(tempCam, false)
                        DestroyCam(tempCam, true)
                    end)

                    SetCinematicModeActive(false)

                    Citizen.InvokeNative(0x1E5185B72EF5158A, "OpenWorldMusic_FastTravel_StopEvent")
                    Citizen.InvokeNative(0x706D57B0F50DA710, "OpenWorldMusic_FastTravel_StopEvent")

                end

                Citizen.Wait(10*1000) -- 10 sec before allow travel again
            end

        elseif prompt ~=0 then
            PromptDelete(prompt)
            prompt = 0
        end
    end
end)