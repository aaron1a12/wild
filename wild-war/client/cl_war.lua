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
                UiPromptSetAttribute(prompt, 2, true) 
                UiPromptSetAttribute(prompt, 4, true) 
                UiPromptSetAttribute(prompt, 9, true) 
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
    W.UI.SetElementTextByClass("warMenu", "menuSubtitle", "Not in faction")

    W.UI.CreatePage("warMenu", "root", 0, 4);
    W.UI.SetMenuRootPage("warMenu", "root");

    local params = {}
    params.text = "Join a Faction";
    params.description = "Allows you to join an existing War faction.";
    W.UI.CreatePageItem("warMenu", "root", 0, params);

    local params = {}
    params.text = "Create New Faction";
    params.description = "Allows you to create a new War faction which other players can join.";
    W.UI.CreatePageItem("warMenu", "root", 0, params);

    Citizen.Wait(1000)
    
    --DestroyAllCams()

--    SetPlayerControl(PlayerId(), true, 0, true)

    --print(GetCurrentControlContext(0))

    SetControlContext(0, `OnFoot`)

    --SetControlContext(0, `OnlinePlayerMenu`)
    
    

end
OnStart()

Citizen.CreateThread(function()
    while true do    
        Citizen.Wait(0)             
        
    end     
end)


Citizen.CreateThread(function()
    if W.Config["debugMode"] == true then
        while true do    
            Citizen.Wait(0)             
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