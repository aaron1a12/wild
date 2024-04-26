-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

local function TestGang()
    -- TODO: CreatePed
    ShowText("Create ped")
end


local bControlPressed = false
local warMenu = nil

Citizen.CreateThread(function()
    while true do   
        Citizen.Wait(0)  

        if IsControlJustPressed(0, "INPUT_PLAYER_MENU") then
            local prompt = 0

            -- Create prompt
            if prompt == 0 then
                prompt = PromptRegisterBegin()
                PromptSetControlAction(prompt, GetHashKey("INPUT_PLAYER_MENU")) -- L key
                PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", "Open War Menu"))
                UiPromptSetHoldMode(prompt, 1000)
                UiPromptSetAttribute(prompt, 10, true) -- kPromptAttrib_NoButtonReleaseCheck. Immediately becomes pressed
                PromptRegisterEnd(prompt)

                Citizen.CreateThread(function()
                    Citizen.Wait(100)


                    while UiPromptGetProgress(prompt) ~= 0.0 and UiPromptGetProgress(prompt) ~= 1.0 do   
                        Citizen.Wait(0)
                    end

                    if UiPromptGetProgress(prompt) == 1.0 then
                        W.UI.OpenMenu("warMenu", true)
                    end

                    PromptDelete(prompt)
                    prompt = 0
                end)
            end
        end
    end
end)


local MenuBase = {}

function OnStart()
    W.UI.CreateMenu("warMenu", "War")
    --WildUISetElementTextByClass("warMenu", "menuSubtitle", "Not in faction")
end
OnStart()

Citizen.CreateThread(function()
    Citizen.Wait(1000)

    if W.Config["debugMode"] == true then
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

AddEventHandler("wild:cl_onPlayerFirstSpawn", function()
end)