local dressingCam = 0
local previewPed = 0

local lastSelectedOutfit = nil
local editingOutfit = nil
local loadout = {}
loadout.model = "player_zero"
loadout.preset = 0
loadout.enabledDrawables = {}
loadout.voice = nil
loadout.loco = 0
loadout.onWheel = nil

local bViewingDrawables = false
local bModifyingDrawable = false
local lastSelectedDrawable = 0

local pedDrawables = json.decode(LoadResourceFile(GetCurrentResourceName(), "pedDrawables.json"))

local bShouldReloadPlayer = false

local bSkipSavingNow = false


function IsDrawableInList(t, hash)
    for _, tItem in pairs(t) do
        if tItem[1] == hash then
            return true
        end
    end

    return false
end

function RemoveDrawableFromList(t, hash)
    for i = 1, #t do
        if t[i][1] == hash then
            table.remove(t, i)
            return
        end
    end
end

function IsMetaPedUsingDrawable(ped, hash)
    local n = GetNumComponentsInPed(ped);
    
    for i=0, n-1 do
        local retval, drawable, albedo, normal, material = GetMetaPedAssetGuids(ped,  i)        
        if drawable == hash then
            return true
        end
    end 
    return false
end

function ToggleDrawable(drawable)

    local drawableDat = {
        drawable.drawable, drawable.albedo, drawable.normal, drawable.material, drawable.palette, drawable.tint0, drawable.tint1, drawable.tint2
    }

    local bEnable = true
    if IsMetaPedUsingDrawable(previewPed, drawableDat[1]) then
        bEnable = false
    end

    -- Enabling drawable

    if bEnable then
        if not IsDrawableInList(loadout.enabledDrawables, drawableDat[1]) then
            table.insert(loadout.enabledDrawables, drawableDat)
        end
    end

    -- Disabling drawable

    if not bEnable then
        RemoveDrawableFromList(loadout.enabledDrawables, drawableDat[1])
    end

    UpdatePreviewPed()
    
    local timeOut = 500
    while not bEnable == IsMetaPedUsingDrawable(previewPed, drawableDat[1]) and timeOut > 0 do
        Wait(50)
        timeOut = timeOut - 50
    end

    while bEnable == not IsMetaPedUsingDrawable(previewPed, drawableDat[1]) and timeOut > 0 do
        Wait(50)
        timeOut = timeOut - 50
    end
    
    Citizen.Wait(1)

    UpdatePrompts()

    if IsMetaPedUsingDrawable(previewPed, drawableDat[1]) then
        W.UI.SetPageItemEndHtml("clothingMenu", "drawable_list", drawableDat[1], "<tick on>")
    else
        W.UI.SetPageItemEndHtml("clothingMenu", "drawable_list", drawableDat[1], "<tick>")

        if bEnable then -- FAIL TO ENABLE DRAWABLE
            RemoveDrawableFromList(loadout.enabledDrawables, drawableDat[1])
        end
    end
end

function GetUserInputInMenu(defaultText)
    if not defaultText then defaultText = "" end
    W.UI.SetMenusVisibleAndActive(false, true)
    DisplayOnscreenKeyboard(6, "ui_outfit_name", "", defaultText, "", "", "", 32)
    
    local kbState = UpdateOnscreenKeyboard()
    while kbState == 0 do
        Wait(0)
        kbState = UpdateOnscreenKeyboard()
    end

    W.UI.SetMenusVisibleAndActive(true)
    return GetOnscreenKeyboardResult()
end

function CloneOutfit(outfitIndex)
    local inputStr = GetUserInputInMenu()

    if inputStr then
        local newOutfitIndex = W.GetPlayerOutfitCount() + 1

        local clone = W.GetPlayerOutfitAtIndex(outfitIndex)
        clone.name = inputStr
        clone.onWheel = nil

        W.ModifyPlayerOutfit(newOutfitIndex, clone)
        RepopulateOutfitList()
    end
end

function RenameOutfit(outfitIndex)    
    local outfit = W.GetPlayerOutfitAtIndex(outfitIndex)
    outfit.name = GetUserInputInMenu(outfit.name)

    if editingOutfit then
        loadout.name = outfit.name
    end
    
    W.ModifyPlayerOutfit(outfitIndex, outfit)
    --RepopulateOutfitList()
    W.UI.SetElementTextById("clothingMenu", "outfit"..tostring(outfitIndex), outfit.name)
end

function DeleteOpenOutfit()
    W.DeletePlayerOutfit(editingOutfit)
    --bSkipSavingNow
    RepopulateOutfitList()
    W.UI.GoBack()
end

function ToggleEquipOutfit(outfitIndex)
    local outfit = W.GetPlayerOutfitAtIndex(outfitIndex)
    local bOnWheel = (outfit.onWheel == 1)

    if not bOnWheel then
        local wheelCount = W.GetPlayerWheelOutfitsCount()

        if wheelCount >= 4 then
            ShowText("Too many outfits on wheel")
        else
            outfit.onWheel = 1
            W.ModifyPlayerOutfit(outfitIndex, outfit)
        end
    else
        outfit.onWheel = nil
        W.ModifyPlayerOutfit(outfitIndex, outfit)
    end

    if editingOutfit then
        loadout.onWheel = outfit.onWheel
    end

    if outfit.onWheel then    
        W.UI.SetPageItemEndHtml("clothingMenu", "outfits", "outfit"..tostring(outfitIndex), "<tick on>")
    else
        W.UI.SetPageItemEndHtml("clothingMenu", "outfits", "outfit"..tostring(outfitIndex), "")
    end
end

local promptModifyDrawable = 0
local promptCloneOutfit = 0
local promptEquipOutfit = 0
local promptRenameOutfit = 0

function CreatePrompts()
    if promptModifyDrawable ~= 0 then
        return
    end

    promptModifyDrawable = PromptRegisterBegin()
    PromptSetControlAction(promptModifyDrawable, `INPUT_GAME_MENU_OPTION`) -- space key
    PromptSetText(promptModifyDrawable, CreateVarString(10, "LITERAL_STRING", "Modify"))
    UiPromptSetEnabled(promptModifyDrawable, false)
    PromptRegisterEnd(promptModifyDrawable)
    W.Prompts.AddToGarbageCollector(promptModifyDrawable)

    promptCloneOutfit = PromptRegisterBegin()
    PromptSetControlAction(promptCloneOutfit, `INPUT_GAME_MENU_EXTRA_OPTION`) -- space key
    PromptSetText(promptCloneOutfit, CreateVarString(10, "LITERAL_STRING", "Clone into new outfit"))
    UiPromptSetEnabled(promptCloneOutfit, true)
    PromptRegisterEnd(promptCloneOutfit)
    W.Prompts.AddToGarbageCollector(promptCloneOutfit)

    promptEquipOutfit = PromptRegisterBegin()
    PromptSetControlAction(promptEquipOutfit, `INPUT_INSPECT_ZOOM`) -- space key
    PromptSetText(promptEquipOutfit, CreateVarString(10, "LITERAL_STRING", "Equip to Outfit Wheel"))
    UiPromptSetEnabled(promptEquipOutfit, true)
    PromptRegisterEnd(promptEquipOutfit)
    W.Prompts.AddToGarbageCollector(promptEquipOutfit)

    promptRenameOutfit = PromptRegisterBegin()
    PromptSetControlAction(promptRenameOutfit, `INPUT_GAME_MENU_TAB_LEFT_SECONDARY`) -- space key
    PromptSetText(promptRenameOutfit, CreateVarString(10, "LITERAL_STRING", "Rename Outfit"))
    UiPromptSetEnabled(promptRenameOutfit, true)
    PromptRegisterEnd(promptRenameOutfit)
    W.Prompts.AddToGarbageCollector(promptRenameOutfit)


    CreateThread(function()
        while promptCloneOutfit ~= 0 do
            Wait(0)
            if IsControlJustPressed(0, `INPUT_GAME_MENU_EXTRA_OPTION`) then
                CloneOutfit(lastSelectedOutfit)
            end

            if IsControlJustPressed(0, `INPUT_GAME_MENU_TAB_LEFT_SECONDARY`) then
                RenameOutfit(lastSelectedOutfit)
            end    

            if IsControlJustPressed(0, `INPUT_INSPECT_ZOOM`) then
                ToggleEquipOutfit(lastSelectedOutfit)
                PlaySound("HUD_PLAYER_MENU", "SELECT")
            end                
        end
    end)
end

function DestroyPrompts()
    W.Prompts.RemoveFromGarbageCollector(promptModifyDrawable)
    W.Prompts.RemoveFromGarbageCollector(promptCloneOutfit)
    W.Prompts.RemoveFromGarbageCollector(promptEquipOutfit)
    W.Prompts.RemoveFromGarbageCollector(promptRenameOutfit)

    PromptDelete(promptModifyDrawable)
    PromptDelete(promptCloneOutfit)
    PromptDelete(promptEquipOutfit)
    PromptDelete(promptRenameOutfit)
    promptModifyDrawable = 0
    promptCloneOutfit = 0
    promptEquipOutfit = 0
    promptRenameOutfit = 0
end

function UpdatePrompts()   
    if promptModifyDrawable == 0 then
        return
    end

    local page = W.UI.GetCurrentPage()

    if page == "drawable_list" then
        UiPromptSetVisible(promptModifyDrawable, true)

        if IsMetaPedUsingDrawable(previewPed, lastSelectedDrawable) then
            UiPromptSetEnabled(promptModifyDrawable, true)
        else
            UiPromptSetEnabled(promptModifyDrawable, false)
        end
    else
        UiPromptSetVisible(promptModifyDrawable, false)
    end

    if page == "outfits" then
        UiPromptSetVisible(promptCloneOutfit, true)
        UiPromptSetVisible(promptEquipOutfit, true)
        UiPromptSetVisible(promptRenameOutfit, true)
    else
        UiPromptSetVisible(promptCloneOutfit, false)
        UiPromptSetVisible(promptEquipOutfit, false)
        UiPromptSetVisible(promptRenameOutfit, false)
    end
end


function TestVoice(ped, voice)
    local pool = {}
	local line = ""

	if CanPlayAmbientSpeech(ped, "GREET_MALE") then table.insert(pool, "GREET_MALE") end
    if CanPlayAmbientSpeech(ped, "GREET_FEMALE") then table.insert(pool, "GREET_FEMALE") end
    if CanPlayAmbientSpeech(ped, "GREET_GENERAL_STRANGER") then table.insert(pool, "GREET_GENERAL_STRANGER") end
    if CanPlayAmbientSpeech(ped, "GREET_GENERAL_FAMILIAR") then table.insert(pool, "GREET_GENERAL_FAMILIAR") end
	if CanPlayAmbientSpeech(ped, "HOWS_IT_GOING") then table.insert(pool, "HOWS_IT_GOING") end
	if CanPlayAmbientSpeech(ped, "GREET_MORNING") then table.insert(pool, "GREET_MORNING") end
    if CanPlayAmbientSpeech(ped, "GREET_EVENING") then table.insert(pool, "GREET_EVENING") end
    if CanPlayAmbientSpeech(ped, "GET_THE_LAW") then table.insert(pool, "GET_THE_LAW") end
    if CanPlayAmbientSpeech(ped, "WHATS_YOUR_PROBLEM") then table.insert(pool, "WHATS_YOUR_PROBLEM") end
    if CanPlayAmbientSpeech(ped, "GENERIC_ANTISOCIAL_MALE_EVENT_COMMENT") then table.insert(pool, "GENERIC_ANTISOCIAL_MALE_EVENT_COMMENT") end
    if CanPlayAmbientSpeech(ped, "GENERIC_INSULT_HIGH_NEUTRAL") then table.insert(pool, "GENERIC_INSULT_HIGH_NEUTRAL") end
    if CanPlayAmbientSpeech(ped, "GENERIC_INSULT_MED_NEUTRAL") then table.insert(pool, "GENERIC_INSULT_MED_NEUTRAL") end
    if CanPlayAmbientSpeech(ped, "GENERIC_MOCK") then table.insert(pool, "GENERIC_MOCK") end
    if CanPlayAmbientSpeech(ped, "PROVOKE_GENERIC") then table.insert(pool, "PROVOKE_GENERIC") end
    if CanPlayAmbientSpeech(ped, "GET_THE_LAW") then table.insert(pool, "GET_THE_LAW") end
    if CanPlayAmbientSpeech(ped, "CHAT_1907") then table.insert(pool, "CHAT_1907") end
    if CanPlayAmbientSpeech(ped, "CHAT_BAD_WEATHER") then table.insert(pool, "CHAT_BAD_WEATHER") end
    if CanPlayAmbientSpeech(ped, "BLOCKED_GENERIC") then table.insert(pool, "BLOCKED_GENERIC") end
    if CanPlayAmbientSpeech(ped, "DONT_BE_STUPID_01") then table.insert(pool, "DONT_BE_STUPID_01") end


	-- Pick random
	if #pool > 0 then
        local random = GetRandomIntInRange(1, #pool)
		line = pool[random]
	end

    PlayAmbientSpeechFromEntity(ped, voice, line, "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
end

function OpenOutfitForEditing(index)
    loadout = W.GetPlayerOutfitAtIndex(index)
    editingOutfit = index

    local name = "Outfit "..tostring(index)
    if loadout.name then
        name = loadout.name
    end

    W.UI.EditPage("clothingMenu", "outfit_edit", "WARDROBE", name)
    W.UI.SetSwitchIndex("clothingMenu", "outfit_edit", "btnPreset", loadout.preset+1)

    local modelName = loadout.model

    -- See if we have a pretty name in our config
    for _, character in pairs(shopConfig.clothingCharacters) do
        if character.model == loadout.model then
            modelName = character.name
            break
        end
    end 

    W.UI.SetPageItemEndHtml("clothingMenu", "outfit_edit", "btnBase", modelName)

    if loadout.voice == nil then
        W.UI.SetPageItemEndHtml("clothingMenu", "outfit_edit", "btnVoice", "None")
    else
        W.UI.SetPageItemEndHtml("clothingMenu", "outfit_edit", "btnVoice", loadout.voice)
    end

    W.UI.SetSwitchIndex("clothingMenu", "outfit_edit", "btnLoco", loadout.loco)

    UpdatePreviewPed()
end

function SaveOutfit()
    if editingOutfit ~= nil then
        W.ModifyPlayerOutfit(editingOutfit, loadout)

        if W.GetPlayerCurrentOutfitIndex() == editingOutfit then
            bShouldReloadPlayer = true
        end
    end
end

function OpenDrawableForEditing(drawable)
    if not IsDrawableInList(loadout.enabledDrawables, drawable.drawable) then
        ToggleDrawable(drawable)
    end

    local drawableDat = {}

    for _, tItem in pairs(loadout.enabledDrawables) do
        if tItem[1] == drawable.drawable then
            drawableDat = tItem
        end
    end

    if drawableDat[1] == nil then
        ShowText("Error opening drawable")
        Citizen.Wait(501)
        W.UI.GoBack()
        return
    end

    W.UI.SetSwitchIndex("clothingMenu", "modify_drawable", "btnTint0", drawableDat[6])
    W.UI.SetSwitchIndex("clothingMenu", "modify_drawable", "btnTint1", drawableDat[7])
    W.UI.SetSwitchIndex("clothingMenu", "modify_drawable", "btnTint2", drawableDat[8])
end

function RepopulateOutfitList()
    W.UI.EmptyPage("clothingMenu", "outfits")
    for i=1, W.GetPlayerOutfitCount() do

        local outfit = W.GetPlayerOutfitAtIndex(i)

        local btnEditOutfit = {}

        if outfit.name then
            btnEditOutfit.text = outfit.name;
        else
            btnEditOutfit.text = "Outfit " .. tostring(i);
        end

        btnEditOutfit.description = "Select to edit outfit #"..tostring(i);
        btnEditOutfit.action = function()

            if editingOutfit ~= i then
                SaveOutfit()
            end

            W.UI.GoToPage("clothingMenu", "outfit_edit")
        end
        W.UI.CreatePageItem("clothingMenu", "outfits", "outfit"..tostring(i), btnEditOutfit);

        if outfit.onWheel == 1 then
            W.UI.SetPageItemEndHtml("clothingMenu", "outfits", "outfit"..tostring(i), "<tick on>")
        end
    end
end

function SetupDressingRoom()
    -- Found bug which results in menu not getting created while player joining the map
    -- Solution is to wait until they have spawned.
    while not W.HasPlayerSpawned() do
        Wait(0)
    end

    W.UI.DestroyMenuAndData("clothingMenu")

    Wait(10)

    --
    -- Clothing
    --

    W.UI.CreateMenu("clothingMenu")

    W.UI.CreatePage("clothingMenu", "outfits", "WARDROBE", "Select outfit to edit", 0, 4);
    W.UI.SetMenuRootPage("clothingMenu", "outfits");

    --
    -- Edit outfit page
    --
    
    W.UI.CreatePage("clothingMenu", "outfit_edit", "WARDROBE", "", 0, 4);

    local btnBase = {}
    btnBase.text = "Base:";
    btnBase.description = "Change your base character skin.";
    btnBase.action = function()
        W.UI.GoToPage("clothingMenu", "skins")
    end
    W.UI.CreatePageItem("clothingMenu", "outfit_edit", "btnBase", btnBase);

    W.UI.SetPageItemEndHtml("clothingMenu", "outfit_edit", "btnBase", "Arthur")


    --
    -- Outfit presets
    --

    local btnPreset = {}
    btnPreset.text = "Outfit Preset";
    btnPreset.description = "Experimental";
    btnPreset.action = function(value)
        loadout.preset = value
        UpdatePreviewPed()
    end

    btnPreset.switch = {
        {"No Outfit", -1}
    }

    for i = 0, 99 do
        table.insert(btnPreset.switch, {'#'..tostring(i), i})
    end

    W.UI.CreatePageItem("clothingMenu", "outfit_edit", "btnPreset", btnPreset);


    --
    -- Drawables
    --

    local btnDrawable = {}
    btnDrawable.text = "Drawable Components";
    btnDrawable.description = "Experimental";
    btnDrawable.action = function()
        W.UI.GoToPage("clothingMenu", "drawable_models")
    end
    W.UI.CreatePageItem("clothingMenu", "outfit_edit", 0, btnDrawable);


    W.UI.CreatePage("clothingMenu", "drawable_models", "DRAWABLES", "", 0, 4);

    for modelSet, drawables in pairs(pedDrawables) do
        local params = {}
        params.text = modelSet
        params.description = '';
        params.action = function()
            -- Populate the drawable page.
            W.UI.DestroyPage("clothingMenu", "drawable_list")
            Citizen.Wait(100)

            W.UI.CreatePage("clothingMenu", "drawable_list", "DRAWABLES", modelSet, 0, 4);

            for _, drawable in pairs(drawables) do
                local btnToggle = {}
                btnToggle.text = drawable.name
                btnToggle.description = tostring(drawable.drawable);
                btnToggle.action = function()
                    ToggleDrawable(drawable)
                end
                btnToggle.altAction = function()
                    bModifyingDrawable = true
                    bViewingDrawables = false

                    W.UI.EditPage("clothingMenu", "modify_drawable", "MODIFY\nDRAWABLE", drawable.name)
                    W.UI.GoToPage("clothingMenu", "modify_drawable")
                    PlaySound("HUD_SHOP_SOUNDSET", "SELECT")

                    OpenDrawableForEditing(drawable)
                end
                W.UI.CreatePageItem("clothingMenu", "drawable_list", drawable.drawable, btnToggle);

                if IsMetaPedUsingDrawable(previewPed, drawable.drawable) then
                    W.UI.SetPageItemEndHtml("clothingMenu", "drawable_list", drawable.drawable, "<tick on>")
                else
                    W.UI.SetPageItemEndHtml("clothingMenu", "drawable_list", drawable.drawable, "<tick>")
                end
            end

            W.UI.GoToPage("clothingMenu", "drawable_list")

            --
            -- Begin Modify drawable prompt 
            -- 

            bViewingDrawables = true

            -- End Modify drawable prompt 
        end

        W.UI.CreatePageItem("clothingMenu", "drawable_models", 0, params);
    end

    --
    -- Modify drawable sub page
    --

    W.UI.CreatePage("clothingMenu", "modify_drawable", "", "", 0, 4);


    local btnTint0 = {}
    btnTint0.text = "Tint 0";
    btnTint0.action = function(value)        
        for _, tItem in pairs(loadout.enabledDrawables) do
            if tItem[1] == lastSelectedDrawable then
                tItem[6] = value
            end
        end

        UpdatePreviewPed()
    end

    btnTint0.switch = {}

    for i = 0, 255 do
        table.insert(btnTint0.switch, {tostring(i), i})
    end

    W.UI.CreatePageItem("clothingMenu", "modify_drawable", "btnTint0", btnTint0);

    local btnTint1 = {}
    btnTint1.text = "Tint 1";
    btnTint1.action = function(value)        
        for _, tItem in pairs(loadout.enabledDrawables) do
            if tItem[1] == lastSelectedDrawable then
                tItem[7] = value
            end
        end

        UpdatePreviewPed()
    end

    btnTint1.switch = {}

    for i = 0, 255 do
        table.insert(btnTint1.switch, {tostring(i), i})
    end

    W.UI.CreatePageItem("clothingMenu", "modify_drawable", "btnTint1", btnTint1);

    local btnTint2 = {}
    btnTint2.text = "Tint 0";
    btnTint2.action = function(value)        
        for _, tItem in pairs(loadout.enabledDrawables) do
            if tItem[1] == lastSelectedDrawable then
                tItem[8] = value
            end
        end

        UpdatePreviewPed()
    end

    btnTint2.switch = {}

    for i = 0, 255 do
        table.insert(btnTint2.switch, {tostring(i), i})
    end

    W.UI.CreatePageItem("clothingMenu", "modify_drawable", "btnTint2", btnTint2);

    --
    -- The rest of the edit outfit page
    --

    local btnClearDrawable = {}
    btnClearDrawable.text = "Clear Drawables";
    btnClearDrawable.description = "";
    btnClearDrawable.action = function()
        loadout.enabledDrawables = {}
        UpdatePreviewPed()
    end
    W.UI.CreatePageItem("clothingMenu", "outfit_edit", 0, btnClearDrawable);

    --
    -- Voices
    --

    local btnVoice = {}
    btnVoice.text = "Override voice:";
    btnVoice.description = "Change your character voice.";
    btnVoice.action = function()
        W.UI.GoToPage("clothingMenu", "voice_list")
    end
    W.UI.CreatePageItem("clothingMenu", "outfit_edit", "btnVoice", btnVoice);
    W.UI.SetPageItemEndHtml("clothingMenu", "outfit_edit", "btnVoice", "None")

    W.UI.CreatePage("clothingMenu", "voice_list", "CHARACTER VOICE", "", 0, 4);

    for _, voice in pairs(shopConfig.characterVoices) do
        local btn = {}
        btn.text = voice
        btn.description = voice;
        btn.action = function()
            loadout.voice = voice
            SetAmbientVoiceName(previewPed, loadout.voice)

            W.UI.SetPageItemEndHtml("clothingMenu", "outfit_edit", "btnVoice", voice)

            TestVoice(previewPed, voice)
        end
        W.UI.CreatePageItem("clothingMenu", "voice_list", 0, btn);
    end

    --
    -- Locomotion
    --

    local btnLoco = {}
    btnLoco.text = "MP Walk Style";
    btnLoco.description = "Sets the ped's locomotion animations.";
    btnLoco.action = function(value)
        loadout.loco = value
        UpdatePreviewPed()
    end

    btnLoco.switch = {
        {"Default", 0},
        {"Casual", 1},
        {"Crazy", 2},
        {"Drunk", 3},
        {"Easy Rider", 4},
        {"Flamboyant", 5},
        {"Greenhorn", 6},
        {"Gunslinger", 7},
        {"Inquisitive", 8},
        {"Refined", 9},
        {"Silent Type", 10},
        {"Veteran", 11},
    }

    W.UI.CreatePageItem("clothingMenu", "outfit_edit", "btnLoco", btnLoco);


    --
    -- Delete outfit
    --

    local btnDelete = {}
    btnDelete.text = "DELETE OUTFIT";
    btnDelete.description = "No undo!";
    btnDelete.action = function()
        DeleteOpenOutfit()
    end
    W.UI.CreatePageItem("clothingMenu", "outfit_edit", "btnDelete", btnDelete);


    --
    -- Base Skin Catalog
    --

    W.UI.CreatePage("clothingMenu", "skins", "BASE SKIN", "Available characters", 0, 4);

    for _, character in pairs(shopConfig.clothingCharacters) do
        local params = {}
        params.text = character.name
        params.description = '';
        params.action = function()

            loadout.model = character.model
            DeletePreviewPed()
            UpdatePreviewPed()

            W.UI.SetPageItemEndHtml("clothingMenu", "outfit_edit", "btnBase", character.name)
            
        end
        W.UI.CreatePageItem("clothingMenu", "skins", character.model, params);
    end

    
end
SetupDressingRoom()

function UpdatePreviewPed()
    if previewPed == 0 then
        local modelHash = GetHashKey(loadout.model)

        RequestModel(modelHash)
        
        while not HasModelLoaded(modelHash) do
            RequestModel(modelHash)
            Citizen.Wait(0)
        end
        
        local position = currentStore.dressingRoom.player
        previewPed = CreatePed(modelHash, position[1], position[2], position[3]-1.0, position[4], false, true, true)
        SetRemovePedNetworked(previewPed, 1)
        --[[]]
        SetEntityInvincible(previewPed, true)
        SetPedKeepTask(previewPed)
        SetPedAsNoLongerNeeded(previewPed)
        --SetModelAsNoLongerNeeded(modelHash)

        W.SetPedOutfit(previewPed, loadout)
        
        TaskStandStill(previewPed, -1)
    else
        DeletePreviewPed()
        UpdatePreviewPed()
        --SetPedCostume(previewPed, loadout)
    end
end

function DeletePreviewPed()
    DeleteEntity(previewPed)
    previewPed = 0
end

function GoToDressingRoom()
    Citizen.Wait(401)
    W.UI.OpenMenu("storeMenu", false)
    Citizen.Wait(401) -- Wait until menu fully closed
    
    DoScreenFadeOut(200)
    Citizen.Wait(200)

    --W.SetPlayerVisible(PlayerId(), false)

    local camInfo = currentStore.dressingRoom.cam
    dressingCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camInfo[1], camInfo[2], camInfo[3], camInfo[4], 0.0, camInfo[5], 60.0, false, 0)
    SetCamActive(dressingCam, true)
    RenderScriptCams(true, false, 0, true, true, 0)

    DoScreenFadeIn(200)
    --Citizen.Wait(301) -- elapsed time since opening/closing menu must be greater 500ms
    W.UI.OpenMenu("clothingMenu", true, true)
    RepopulateOutfitList()

    -- pick off where we left
    if editingOutfit ~= nil then
        OpenOutfitForEditing(editingOutfit)
    end

    CreatePrompts()
end


function ExitDressingRoom()
    DoScreenFadeOut(200)
    Citizen.Wait(200)

    --W.SetPlayerVisible(PlayerId(), true)
    RenderScriptCams(false, false, 0, true, true, 0)
    SetCamActive(dressingCam, false)
    DestroyCam(dressingCam, true)

    DeletePreviewPed()

    if bShouldReloadPlayer then
        W.SwitchPlayerOutfitAtIndex(W.GetPlayerCurrentOutfitIndex())
    end

    DoScreenFadeIn(200)
end

AddEventHandler("wild:cl_onMenuClosing", function(menu)
    if menu == "clothingMenu" then
        SaveOutfit()
        ExitDressingRoom()

        if promptModifyDrawable ~= 0 then
            DestroyPrompts()     
        end
    end
end)

AddEventHandler("wild:cl_onMenuBack", function(menu)
    if menu == "clothingMenu" then
        if bViewingDrawables then
            bViewingDrawables = false
        end

        if bModifyingDrawable then
            bModifyingDrawable = false
            bViewingDrawables = true
        end

        if editingOutfit ~= 0 then
            SaveOutfit()
        end
    end
end)

AddEventHandler("wild:cl_onSelectPageItem", function(menu, page, item)
    if menu == "clothingMenu" then
        UpdatePrompts()
        
        if page == "drawable_list" then
            lastSelectedDrawable = tonumber(item)
        end

        if string.sub(item, 1, 6) == "outfit" and dressingCam ~= 0 then
            lastSelectedOutfit = tonumber(string.sub(item, 7, 7))

            if editingOutfit ~= lastSelectedOutfit then
                OpenOutfitForEditing(lastSelectedOutfit)
            end
        end
        
    end
end)