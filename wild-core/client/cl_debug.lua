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

local function StartFlyMode()
    ShowHelpText("Fly mode ON", 2000)
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
        speed = speed * 4.0
    end
    impulse = impulse + vec * speed
end

local function RotateVectorYaw(vec, degrees)
    local radians = degrees * (math.pi/180)

    local x = vec.x * math.cos(radians) - vec.y * math.sin(radians);
    local y = vec.x * math.sin(radians) + vec.y * math.cos(radians);

    return vector3(x, y, vec.z)
end


AddEventHandler("onResourceStart", function(resource)
    SetPlayerControl(PlayerId(), true, 256, true)
	if resource == GetCurrentResourceName() then
        if CONFIG['debugMode'] == true then

            Citizen.CreateThread(function()
                while true do
                    Citizen.Wait(0)

                    local ped = GetPlayerPed(PlayerId())
                    local coords = GetEntityCoords(ped)

                    local x, y, z = table.unpack(coords)

                    --x = 

                    PrintText(0.01, 0.5, 0.3, false, "X:", 255, 50, 50, 255)
                    PrintText(0.025, 0.5, 0.3, false, tostring(x), 255, 255, 255, 255)

                    PrintText(0.01, 0.53, 0.3, false, "Y:", 50, 255, 50, 255)
                    PrintText(0.025, 0.53, 0.3, false, tostring(y), 255, 255, 255, 255)

                    PrintText(0.01, 0.56, 0.3, false, "Z:", 50, 50, 255, 255)
                    PrintText(0.025, 0.56, 0.3, false, tostring(z), 255, 255, 255, 255)

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
	end
end)