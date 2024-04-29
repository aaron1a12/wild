local bIsFlyMode = false
local position = vector3(0.0, 0.0, 0.0)
local impulse = vector3(0.0, 0.0, 0.0)
local heading = 0

local playerPed = 0
local horsePed = 0

local baseSpeed = 0.01

local function lerp(a, b, t)
    return a + (b - a) * t
end

local prevCtrlCtx = 0
local function StartFlyMode()
    ShowHelpText("Fly mode ON", 2000)

    --prevCtrlCtx = GetCurrentControlContext(0)
    --SetControlContext(0, `FrontendMenu`)

    local soundset_ref = "Photo_Mode_Sounds"
    local soundset_name =  "lens_up"
    Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
    Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);
    
    bIsFlyMode = true

    playerPed = GetPlayerPed(PlayerId())
    horsePed = GetMount(playerPed)

    if not DoesEntityExist(horsePed) then
        horsePed = GetVehiclePedIsIn(playerPed, false)
    end
    ForceAllHeadingValuesToAlign(playerPed)
    position = GetEntityCoords(playerPed)
    heading = GetEntityHeading(playerPed)

    SetEntityInvincible(playerPed, true)
    SetEntityInvincible(horsePed, true)
    FreezeEntityPosition(playerPed, true)
    FreezeEntityPosition(horsePed, true)

    SetEntityHeading(playerPed, GetFinalRenderedCamRot(0).z)

    Citizen.CreateThread(function()
        while bIsFlyMode do
            Citizen.Wait(0)
            impulse = lerp(impulse, vector3(0.0, 0.0, 0.0), 4.0 * GetFrameTime())

            heading = GetFinalRenderedCamRot(0).z
            SetEntityHeading(playerPed, -heading)
            
            position = position + impulse

            SetEntityCoordsAndHeadingNoOffset(playerPed, position.x, position.y, position.z, heading, 1, 0)
            SetEntityCoordsAndHeadingNoOffset(horsePed, position.x, position.y, position.z, heading, 0, 0)
        end
    end)
end

local function EndFlyMode()
    ShowHelpText("Fly mode OFF", 2000)

    --SetControlContext(0, prevCtrlCtx)

    local soundset_ref = "Photo_Mode_Sounds"
    local soundset_name =  "lens_down"
    Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
    Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);

    bIsFlyMode = false

    FreezeEntityPosition(playerPed, false)
    FreezeEntityPosition(horsePed, false)

    SetEntityInvincible(playerPed, false)
    SetEntityInvincible(horsePed, false)
end

local function AddFlyImpulse(vec)
    local speed = baseSpeed

    if IsControlPressed(0, "INPUT_FRONTEND_Y") then
        speed = speed * 8.0
    end
    impulse = impulse + vec * speed
end

local function RotateVectorYaw(vec, degrees)
    local radians = degrees * (math.pi/180)

    local x = vec.x * math.cos(radians) - vec.y * math.sin(radians);
    local y = vec.x * math.sin(radians) + vec.y * math.cos(radians);

    return vector3(x, y, vec.z)
end

local imapsNear = {}
local enabledIpls = {}
local selectedIpl = 1

local function GetIplColor(hash)
    math.randomseed(hash)
    local r = math.random(0, 255)
    math.randomseed(hash+1)
    local g = math.random(0, 255)
    math.randomseed(hash+2)
    local b = math.random(0, 255)

    return r, g, b
end

-- Inspired off https://github.com/robwhitewick/Redm-ImapViewer
local function DrawNearIpls()
    local coords = GetEntityCoords(PlayerPedId(),true,true)

    for i = 1, #imapsNear do
        local hash = imapsNear[i][1]
        local imap = imapsNear[i][2]

        local imapCoords = vector3(imap['x'], imap['y'], imap['z'])

        -- Random color
        
        local red, green, blue = GetIplColor(hash)
        local alpha = 10

        local bSelected = false

        if imapsNear[selectedIpl] ~= nil then
            if imapsNear[selectedIpl][1] == hash then
                bSelected = true
                alpha = 64
            end
        end

        Citizen.InvokeNative(`DRAW_LINE` & 0xFFFFFFFF, imapCoords.x, imapCoords.y, imapCoords.z, imapCoords.x, imapCoords.y, 500.0,  red, green, blue, 255)

        local _, iplRealPos, radius = GetIplBoundingSphere(hash)

        if bSelected then
            DrawDebugSphere(iplRealPos, radius, red, green, blue, alpha)

            math.randomseed(i)
            local zRandOffset = math.random(0, 10) / 10

            local s, sx, sy = GetScreenCoordFromWorldCoord(imapCoords.x, imapCoords.y, imapCoords.z)
            if (sx > 0 and sx < 1) or (sy > 0 and sy < 1) then
                local s, sx, sy = GetScreenCoordFromWorldCoord(imapCoords.x, imapCoords.y, imapCoords.z + zRandOffset)
                if (sx > 0 and sx < 1) or (sy > 0 and sy < 1) then
                    local s, sx, sy = GetHudScreenPositionFromWorldPosition(imapCoords.x, imapCoords.y, imapCoords.z + zRandOffset)
                    PrintText(sx, sy, 0.3, true, tostring(hash), red, green, blue, 255)
                end
            end
        end

        -- Don't draw too many
        if i > 10 then
            return
        end
    end
end

local function RefreshNearIpls()
    imapsNear = {}
    local playerCoords = GetEntityCoords(GetPlayerPed(PlayerId()))
    local smallestDist = 99999999.0
    local candidate = 0

    local maxDist = W.Config['debugIplRange']

    for hash, imap in pairs(all_imaps_list) do

        local imapCoords = vector3(imap['x'], imap['y'], imap['z'])
        local dist = GetDistanceBetweenCoords(playerCoords, imapCoords, true)

        if dist < maxDist then -- and not IsIplActiveHash(hash)
            table.insert(imapsNear, {hash, imap})
        end
    end
end

local function DumpIpls()
    local hashes = {
        iplsToActivate,
        iplsToDeactivate
    }

    TriggerServerEvent("wild:sv_dumpIpls", hashes)
end

RegisterNetEvent("wild:cl_dumpIplsDone")
AddEventHandler("wild:cl_dumpIplsDone", function()
    ShowText("Saved to ipls.json")
end)

local function CycleIpl(bForward)
    if bForward then
        selectedIpl = selectedIpl + 1
    else
        selectedIpl = selectedIpl - 1
    end

    if selectedIpl > #imapsNear then
        selectedIpl = 1
    elseif selectedIpl < 1 then
        selectedIpl = #imapsNear
    end

    if imapsNear[selectedIpl] == nil then
        selectedIpl = 1
    end
end

local function ToggleIpl()
    if imapsNear[selectedIpl] == nil then
        return
    end

    local hash = imapsNear[selectedIpl][1]
    
    if hash == nil then
        return
    end

    -- Flip state
    local bEnable = not IsIplActiveHash(hash)

    if bEnable then
        for i = 1, #iplsToDeactivate do
            if iplsToDeactivate[i] == hash then
                table.remove(iplsToDeactivate, i)
            end
        end

        table.insert(iplsToActivate, hash)
        RequestIplHash(hash)
    else
        for i = 1, #iplsToActivate do
            if iplsToActivate[i] == hash then
                table.remove(iplsToActivate, i)
            end
        end

        table.insert(iplsToDeactivate, hash)
        RemoveIplHash(hash)
    end
end

AddEventHandler("wild:cl_onPlayerFirstSpawn", function()
    if W.Config['debugMode'] == true then

        W.Config['respawnDelay'] = 0

        if W.Config['debugIpl'] then
            Citizen.CreateThread(function()
                while true do
                    Citizen.Wait(1000)

                    -- Refresh near ipls
                    RefreshNearIpls()
                end
            end)
        end

        Citizen.CreateThread(function()
            while true do
                Citizen.Wait(0)

                local ped = GetPlayerPed(PlayerId())
                local coords = GetEntityCoords(ped)

                --DrawDebugSphere(coords, 40.0, 255, 0, 0, 64)

                local x, y, z = table.unpack(coords)

                --x = 

                PrintText(0.01, 0.4, 0.3, false, "X:", 255, 50, 50, 255)
                PrintText(0.025, 0.4, 0.3, false, tostring(x), 255, 255, 255, 255)

                PrintText(0.01, 0.43, 0.3, false, "Y:", 50, 255, 50, 255)
                PrintText(0.025, 0.43, 0.3, false, tostring(y), 255, 255, 255, 255)

                PrintText(0.01, 0.46, 0.3, false, "Z:", 50, 50, 255, 255)
                PrintText(0.025, 0.46, 0.3, false, tostring(z), 255, 255, 255, 255)

                PrintText(0.01, 0.49, 0.3, false, "H:", 50, 255, 255, 255)
                PrintText(0.025, 0.49, 0.3, false, tostring(GetEntityHeading(ped)), 255, 255, 255, 255)

                -- Cam

                local camCoords = GetFinalRenderedCamCoord()
                local camRot = GetFinalRenderedCamRot(0)

                PrintText(0.01, 0.55, 0.2, false, "Cam X:", 255, 50, 50, 255)
                PrintText(0.045, 0.55, 0.2, false, tostring(camCoords.x), 255, 255, 255, 255)

                PrintText(0.01, 0.57, 0.2, false, "Cam Y:", 50, 255, 50, 255)
                PrintText(0.045, 0.57, 0.2, false, tostring(camCoords.y), 255, 255, 255, 255)

                PrintText(0.01, 0.59, 0.2, false, "Cam Z:", 50, 50, 255, 255)
                PrintText(0.045, 0.59, 0.2, false, tostring(camCoords.z), 255, 255, 255, 255)

                PrintText(0.01, 0.61, 0.2, false, "Cam RX:", 255, 50, 50, 255)
                PrintText(0.045, 0.61, 0.2, false, tostring(camRot.x), 255, 255, 255, 255)

                PrintText(0.01, 0.63, 0.2, false, "Cam RY:", 50, 255, 50, 255)
                PrintText(0.045, 0.63, 0.2, false, tostring(camRot.y), 255, 255, 255, 255)

                PrintText(0.01, 0.65, 0.2, false, "Cam RZ:", 50, 50, 255, 255)
                PrintText(0.045, 0.65, 0.2, false, tostring(camRot.z), 255, 255, 255, 255)

                PrintText(0.01, 0.1, 0.3, false, "ALT + 1 : Kill self", 255, 50, 255, 255)
                

                if IsControlJustPressed(0, "INPUT_EMOTE_TWIRL_GUN_VAR_B") and IsControlPressed(0, "INPUT_HUD_SPECIAL") then
                    ApplyDamageToPed(ped, 500000, false, true, true)
                end

                if W.Config['debugIpl'] then
                    PrintText(0.01, 0.13, 0.3, false, "ALT + 2 : Save Enabled IPLs", 255, 150, 0, 255)

                    PrintText(0.01, 0.16, 0.3, false, "Active IPL:", 155, 120, 22, 255)

                    if imapsNear[selectedIpl] ~= nil then
                        local hash = imapsNear[selectedIpl][1]
                        local r, g, b = GetIplColor(hash)

                        PrintText(0.06, 0.16, 0.3, false, tostring(hash), r, g, b, 255)
                        PrintText(0.12, 0.16, 0.3, false, tostring(selectedIpl) .. " / " .. tostring(#imapsNear), 255, 255, 255, 255)

                        local state = "off" if IsIplActiveHash(hash) then state = "on" end
                        PrintText(0.16, 0.16, 0.3, false, state, 255, 255, 255, 255)
                    end

                    PrintText(0.01, 0.18, 0.2, false, "IPL Controls : Cycle (ALT + PAGE UP/DOWN), Toggle (ALT + DEL)", 155, 120, 22, 255)

                    if IsControlJustPressed(0, "INPUT_SELECT_QUICKSELECT_DUALWIELD") and IsControlPressed(0, "INPUT_HUD_SPECIAL") then
                        DumpIpls()
                    end

                    -- Cycle IPL Back ( ALT + PAGE DOWN )
                    if IsControlJustPressed(0, "INPUT_FRONTEND_LT") and IsControlPressed(0, "INPUT_HUD_SPECIAL") then
                        CycleIpl(false)
                    end

                    -- Cycle IPL Forward ( ALT + PAGE UP )
                    if IsControlJustPressed(0, "INPUT_FRONTEND_RT") and IsControlPressed(0, "INPUT_HUD_SPECIAL") then
                        CycleIpl(true)
                    end

                    -- Toggle IPL ( ALT + DEL )
                    if IsControlJustPressed(0, "INPUT_FRONTEND_DELETE") and IsControlPressed(0, "INPUT_HUD_SPECIAL") then
                        ToggleIpl()
                    end

                    -- Ipl (imap)
                    DrawNearIpls()     
                end           
                    

                -- FLY MODE

                if IsControlJustPressed(0, "INPUT_PHOTO_MODE_PC") then

                    if not bIsFlyMode then
                        StartFlyMode()
                    else
                        EndFlyMode()
                    end
                end

                if bIsFlyMode then -- FLY MODE CONTROLS
                    if IsControlPressed(0, "INPUT_COVER") then
                        AddFlyImpulse(vector3(0.0, 0.0, 1.0))
                    end

                    if IsControlPressed(0, "INPUT_ENTER") then
                        AddFlyImpulse(vector3(0.0, 0.0, -1.0))
                    end

                    if IsControlPressed(0, "INPUT_MOVE_UP_ONLY") then
                        local vec = RotateVectorYaw(vector3(0.0, 1.0, 0.0), heading)
                        AddFlyImpulse(vec)

                    end

                    if IsControlPressed(0, "INPUT_MOVE_DOWN_ONLY") then
                        local vec = RotateVectorYaw(vector3(0.0, -1.0, 0.0), heading)
                        AddFlyImpulse(vec)
                    end

                    if IsControlPressed(0, "INPUT_MOVE_LEFT_ONLY") then
                        local vec = RotateVectorYaw(vector3(-1.0, 0.0, 0.0), heading)
                        AddFlyImpulse(vec)
                    end

                    if IsControlPressed(0, "INPUT_MOVE_RIGHT_ONLY") then
                        local vec = RotateVectorYaw(vector3(1.0, 0.0, 0.0), heading)
                        AddFlyImpulse(vec)
                    end
                end -- END OF FLY MODE
            end
        end)

    end
end)