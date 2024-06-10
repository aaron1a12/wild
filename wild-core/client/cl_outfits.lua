--
-- Global outfit functionality
--

function GetLocoFromInt(loco)
    local locoStr = ""

    if loco == 1 then locoStr = "MP_Style_Casual" end
    if loco == 2 then locoStr = "MP_Style_Crazy" end
    if loco == 3 then locoStr = "mp_style_drunk" end
    if loco == 4 then locoStr = "MP_Style_EasyRider" end
    if loco == 5 then locoStr = "MP_Style_Flamboyant" end
    if loco == 6 then locoStr = "MP_Style_Greenhorn" end
    if loco == 7 then locoStr = "MP_Style_Gunslinger" end
    if loco == 8 then locoStr = "mp_style_inquisitive" end
    if loco == 9 then locoStr = "MP_Style_Refined" end
    if loco == 10 then locoStr = "MP_Style_SilentType" end
    if loco == 11 then locoStr = "MP_Style_Veteran" end

    return locoStr
end

function W.GetPlayerCurrentOutfit()
    RefreshPlayerData()
    local outfit = W.PlayerOutfitData["outfits"][W.PlayerData["currentOutfit"]]

    if outfit then
        return outfit
    else
        return W.PlayerOutfitData["outfits"][1]
    end
end

function W.GetPlayerCurrentOutfitIndex()
    RefreshPlayerData()
    return W.PlayerData["currentOutfit"]
end

function W.GetPlayerOutfitAtIndex(index)
    RefreshPlayerData()
    return W.PlayerOutfitData["outfits"][index]
end

function W.ModifyPlayerOutfit(index, outfit)
    local localOutfit = {}
    localOutfit.name = outfit.name
    localOutfit.model = outfit.model
    localOutfit.preset = outfit.preset
    localOutfit.voice = outfit.voice
    localOutfit.loco = outfit.loco
    localOutfit.onWheel = outfit.onWheel
    
    -- Copy the drawables
    localOutfit.enabledDrawables = {}

    for i, drawable in pairs(outfit.enabledDrawables) do
        localOutfit.enabledDrawables[i] = {drawable[1], drawable[2],  drawable[3],  drawable[4], drawable[5], drawable[6], drawable[7], drawable[8]}
    end

    W.PlayerOutfitData["outfits"][index] = localOutfit
    TriggerServerEvent("wild:sv_modifyPlayerOutfit", GetPlayerName(PlayerId()), index, localOutfit)
end

function W.DeletePlayerOutfit(index)
    W.PlayerOutfitData["outfits"][index] = nil
    table.remove(W.PlayerOutfitData["outfits"], index)

    TriggerServerEvent("wild:sv_deletePlayerOutfit", GetPlayerName(PlayerId()), index)
end

function W.SetPedOutfit(ped, outfit)
    EquipMetaPedOutfitPreset(ped, outfit.preset, false)

    ResetPedComponents(ped)

    for _, enabledDrawable in pairs(outfit.enabledDrawables) do
        SetMetaPedTag(ped, enabledDrawable[1], enabledDrawable[2],  enabledDrawable[3],  enabledDrawable[4], enabledDrawable[5], enabledDrawable[6], enabledDrawable[7], enabledDrawable[8])
    end

    while not IsPedReadyToRender(ped) do
        Wait(0)
    end
    
    N_0xaab86462966168ce(ped, true)
    UpdatePedVariation(ped, false, true, true, true, false)

    while not IsPedReadyToRender(ped) do
        Wait(0)
    end
    
    -- Voice
    W.RefreshPlayerVoice()

    SetPedBlackboardBool(ped, "MP_Style_Casual", false, -1)
    SetPedBlackboardBool(ped, "MP_Style_Crazy", false, -1)
    SetPedBlackboardBool(ped, "mp_style_drunk", false, -1)
    SetPedBlackboardBool(ped, "MP_Style_EasyRider", false, -1)
    SetPedBlackboardBool(ped, "MP_Style_Flamboyant", false, -1)
    SetPedBlackboardBool(ped, "MP_Style_Greenhorn", false, -1)
    SetPedBlackboardBool(ped, "MP_Style_Gunslinger", false, -1)
    SetPedBlackboardBool(ped, "mp_style_inquisitive", false, -1)
    SetPedBlackboardBool(ped, "MP_Style_Refined", false, -1)
    SetPedBlackboardBool(ped, "MP_Style_SilentType", false, -1)
    SetPedBlackboardBool(ped, "MP_Style_Veteran", false, -1)

    if outfit.loco ~= 0 then
        SetPedBlackboardBool(ped, GetLocoFromInt(outfit.loco), true, -1)
    else
        SetPedDesiredLocoForModel(ped, "default", true, -1) -- Does not network sync but at least allows slow walk on MP peds
    end
end

function W.GetPlayerOutfitCount()
    return #W.PlayerOutfitData["outfits"]
end

function W.GetPlayerWheelOutfitsCount()
    local count = 0
    for i=1, #W.PlayerOutfitData["outfits"] do
        local outfit = W.PlayerOutfitData["outfits"][i]
        if outfit.onWheel == 1 then
            count = count + 1
        end
    end

    return count
end

function W.SwitchPlayerOutfitAtIndex(index)
    local outfit = W.GetPlayerOutfitAtIndex(index)

    -- Update player model
    local hash = GetHashKey(outfit.model)

    RequestModel(hash)

    while not HasModelLoaded(hash) do
        RequestModel(hash)
        Wait(0)
    end
    
    SetPlayerModel(PlayerId(), hash, false)
    local newPlayerPed = PlayerPedId()

    SetModelAsNoLongerNeeded(hash)
    --ResetPedWeaponMovementClipset(playerPed)

    W.SetPedOutfit(newPlayerPed, outfit)

    W.PlayerData["currentOutfit"] = index
    TriggerServerEvent("wild:sv_setPlayerKeyValue", GetPlayerName(PlayerId()), "currentOutfit", index)

    -- For horses
    TriggerEvent('wild:cl_onNewPlayerPed')
end

function W.GetPlayerVoice()
    RefreshPlayerData()
    local outfit = W.PlayerOutfitData["outfits"][W.PlayerData["currentOutfit"]]

    if outfit then
        return outfit.voice
    else
        return 0
    end
end

function W.RefreshPlayerVoice()
    RefreshPlayerData()
    local outfit = W.PlayerOutfitData["outfits"][W.PlayerData["currentOutfit"]]

    if outfit then
        if outfit.voice ~= nil then
            local pPed = PlayerPedId()
            SetAmbientVoiceName(pPed, outfit.voice)
            --N_0xd47d47efbf103fb8(pPed, 3)
        end
    else
        return 0
    end
end

--
-- Outfit Switch Menu
--

local outfitPromptGroup = GetRandomIntInRange(1, 0xFFFFFF)
local outfitPrompts = {}
local bShowOutfitPrompt = false
local outfitPromptTimeOut = 0
local bOutfitLock = false
local cam = 0

local function ChooseCamCoords()
    local ped = PlayerPedId()
    local x1,y1,z1 = table.unpack(GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, 0.5))--table.unpack(GetEntityCoords(ped))
    local x2,y2,z2 = table.unpack(GetOffsetFromEntityInWorldCoords(ped, 1.0, 2.0, 0.5))

    local retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(StartShapeTestRay(x1, y1, z1, x2, y2, z2, -1, ped, 1))

    if hit == 1 then
        return endCoords
    else
        return vector3(x2, y2, z2)
    end
end

local function CreateOutfitPrompt(controlHash, text, outfitIndex)
    local outfitPrompt = PromptRegisterBegin()
    PromptSetControlAction(outfitPrompt, controlHash)
    PromptSetText(outfitPrompt, CreateVarString(10, "LITERAL_STRING", text))
    UiPromptSetHoldMode(outfitPrompt, 500)
    UiPromptSetPriority(outfitPrompt, 3)
    PromptSetGroup(outfitPrompt, outfitPromptGroup, 0) 
    UiPromptSetEnabled(outfitPrompt, false)
    UiPromptSetVisible(outfitPrompt, true)
    UiPromptSetAttribute(outfitPrompt, 10, true)
    PromptRegisterEnd(outfitPrompt)

    table.insert(outfitPrompts, {outfitPrompt, outfitIndex})
end

local function DeleteAllOutfitPrompts()
    for i=1, #outfitPrompts do
        PromptDelete(outfitPrompts[i][1])
    end
    outfitPrompts = {}
end

function UpdatePrompts()
    local currentOutfit = W.GetPlayerCurrentOutfitIndex()

    for i=1, #outfitPrompts do
        local associatedOutfit = outfitPrompts[i][2]
        UiPromptSetEnabled(outfitPrompts[i][1], (associatedOutfit ~= currentOutfit))
    end
end


DatabindingAddDataInt(W.DataCont, "active_group", 0)

function OpenOutfitMenu()
    bOutfitLock = true
    bShowOutfitPrompt = true
    outfitPromptTimeOut = 3000

    ModifyPlayerUiPrompt(PlayerId(), 0, 1, true)



    local controls = {`INPUT_EMOTE_DANCE`, `INPUT_EMOTE_GREET`, `INPUT_EMOTE_COMM`, `INPUT_EMOTE_TAUNT`}
    local iAddedIndex = 0

    --CreateOutfitPrompt(`INPUT_EMOTE_DANCE`, "Outfit 1")
    --CreateOutfitPrompt(`INPUT_EMOTE_GREET`, "Outfit 2")
    --CreateOutfitPrompt(`INPUT_EMOTE_COMM`, "Outfit 3")
    --CreateOutfitPrompt(`INPUT_EMOTE_TAUNT`, "Outfit 4")

    for i=1, #W.PlayerOutfitData["outfits"] do

        local outfit = W.PlayerOutfitData["outfits"][i]

        if outfit.onWheel == 1 then
            iAddedIndex = iAddedIndex + 1

            if iAddedIndex > 4 then
                break
            else
                local name = "Outfit "..tostring(iAddedIndex)

                if outfit.name then
                    name = outfit.name
                end

                CreateOutfitPrompt(controls[iAddedIndex], name, i)
            end
            
        end
    end

    UpdatePrompts()
    
    -- Write to the wild data container about this active group (fixes conflicting prompt groups)
    DatabindingWriteDataIntFromParent(W.DataCont, "active_group", outfitPromptGroup)
    
    Citizen.CreateThread(function() 
        while outfitPromptTimeOut > 0 do
            Wait(50)
            outfitPromptTimeOut = outfitPromptTimeOut - 50

            for i=1, #outfitPrompts do
                if UiPromptGetProgress(outfitPrompts[i][1]) ~= 0.0 then
                    outfitPromptTimeOut = 3000
                    break
                end
            end
        end

        bShowOutfitPrompt = false
    end)

    Citizen.CreateThread(function()
        while bShowOutfitPrompt do   
            Citizen.Wait(0)  

            PromptSetActiveGroupThisFrame(outfitPromptGroup, CreateVarString(10, "LITERAL_STRING", "Change Outfit"))            
            
            SetControlContext(4, `UI_EMOTES_RADIAL_MENU`)

            for i=1, #outfitPrompts do
                if UiPromptGetProgress(outfitPrompts[i][1]) == 1.0 then
                    UiPromptRestartModes(outfitPrompts[i][1])

                    SetEntityVisible(PlayerPedId(), false)
                    W.SwitchPlayerOutfitAtIndex(outfitPrompts[i][2])
                    UpdatePrompts()
                    Citizen.Wait(100)
                    SetEntityVisible(PlayerPedId(), true)

                    break
                end
            end

            local x,y,z = table.unpack(GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 1.0, 0.0))
            DrawLightWithRange(x,y,z,255,255,255, 5.0, 0.1)
        end

        CloseOutfitMenu()
    end)


    local camCoords = ChooseCamCoords()
    local playerCoords = GetEntityCoords(PlayerPedId())+vector3(0,0, 0.1)
    local rot = GetLookAtRotation(camCoords, playerCoords)

    cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camCoords.x, camCoords.y, camCoords.z, rot.x, rot.y, rot.z, 55.0, false, 0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true, 0)
end

function CloseOutfitMenu()
    DatabindingAddDataInt(W.DataCont, "active_group", 0)

    DeleteAllOutfitPrompts()
    bShowOutfitPrompt = false
    outfitPromptTimeOut = 0

    RenderScriptCams(false, false, 0, true, true, 0)
    SetCamActive(cam, false)
    DestroyCam(cam, true)

    Citizen.Wait(100)
    bOutfitLock = false
end

Citizen.CreateThread(function()
    while true do   
        Citizen.Wait(0)  

        if prompt ~= 0 then
            if IsControlJustPressed(0, `INPUT_RADIAL_MENU_NAV_LR`) or IsControlJustPressed(0, `INPUT_RADIAL_MENU_NAV_UD`) or IsControlJustPressed(0, `INPUT_INTERACT_LOCKON`) then
                CloseOutfitMenu()
            end
        end

        if IsControlJustPressed(0, "INPUT_OPEN_JOURNAL") and not bOutfitLock then
            local prompt = 0

            -- Create prompt
            if prompt == 0 then
                prompt = PromptRegisterBegin()
                PromptSetControlAction(prompt, GetHashKey("INPUT_OPEN_JOURNAL")) -- L key
                PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", "Outfit Menu"))
                UiPromptSetHoldMode(prompt, 750)
                UiPromptSetAttribute(prompt, 2, true) 
                UiPromptSetAttribute(prompt, 4, true) 
                UiPromptSetAttribute(prompt, 9, true) 
                UiPromptSetAttribute(prompt, 10, true) -- kPromptAttrib_NoButtonReleaseCheck. Immediately becomes pressed
                UiPromptSetAttribute(prompt, 17, true) -- kPromptAttrib_NoGroupCheck. Allows to appear in any active group
                PromptRegisterEnd(prompt)

                Citizen.CreateThread(function()
                    Citizen.Wait(100)

                    while UiPromptGetProgress(prompt) ~= 0.0 and UiPromptGetProgress(prompt) ~= 1.0 do   
                        Citizen.Wait(0)
                    end

                    if UiPromptGetProgress(prompt) == 1.0 then
                        OpenOutfitMenu()
                    end

                    PromptDelete(prompt)
                    prompt = 0

                    Citizen.Wait(1000)
                end)
            end
        end
    end
end)