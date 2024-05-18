local currentStore = nil
local dressingCam = 0

local previewPed = 0

local editingOutfit = nil
local loadout = {}
loadout.model = "player_zero"
loadout.preset = 0
loadout.enabledDrawables = {}
loadout.disabledDrawables = {}
loadout.voice = nil
loadout.loco = 0

local bDisablingDrawables = false

local pedDrawables = json.decode(LoadResourceFile(GetCurrentResourceName(), "pedDrawables.json"))

local bShouldReloadPlayer = false


function IsDrawableInList(t, item)
    for _, tItem in pairs(t) do
        --print("Comparing item #" .. tostring(_)..", "..tostring(tItem[1]))
        if tItem[1] == item[1] then
            return true
        end
    end

    return false
end

function RemoveDrawableFromList(t, item)
    for i = 1, #t do
        if t[i][1] == item[1] then
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
        if not IsDrawableInList(loadout.enabledDrawables, drawableDat) then
            table.insert(loadout.enabledDrawables, drawableDat)
        end

        if IsDrawableInList(loadout.disabledDrawables, drawableDat) then
            RemoveDrawableFromList(loadout.disabledDrawables, drawableDat)
        end
    end

    -- Disabling drawable

    if not bEnable then
        if not IsDrawableInList(loadout.disabledDrawables, drawableDat) then
            table.insert(loadout.disabledDrawables, drawableDat)
        end

        if IsDrawableInList(loadout.enabledDrawables, drawableDat) then
            RemoveDrawableFromList(loadout.enabledDrawables, drawableDat)
        end
    end

    UpdatePreviewPed()
    
    while not bEnable == IsMetaPedUsingDrawable(previewPed, drawableDat[1]) do
        Citizen.Wait(100)
    end

    if IsMetaPedUsingDrawable(previewPed, drawableDat[1]) then
        W.UI.SetPageItemEndHtml("clothingMenu", "drawable_list", drawableDat[1], "<tick on>")
    else
        W.UI.SetPageItemEndHtml("clothingMenu", "drawable_list", drawableDat[1], "<tick>")
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

    W.UI.EditPage("clothingMenu", "outfit_edit", "WARDROBE", "Editing Outfit "..tostring(index))
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

AddEventHandler("wild:cl_onMenuClosing", function(menu)
    SaveOutfit()
end)

function SetupStores()
    Citizen.Wait(1000)
    
    for i = 1, #shopConfig.generalStores do

        local store = shopConfig.generalStores[i]

        store.blip = BlipAddForCoords(`BLIP_STYLE_SHOP`, store.location[1], store.location[2], store.location[3])

        SetBlipSprite(store.blip, `blip_shop_store`, true)
        SetBlipScale(store.blip, 0.2)
        SetBlipName(store.blip, "General Store")
    end

    W.UI.DestroyMenuAndData("storeMenu")
    W.UI.DestroyMenuAndData("clothingMenu")
    Citizen.Wait(10)

    W.UI.CreateMenu("storeMenu")
    W.UI.CreatePage("storeMenu", "root", "GENERAL STORE", "Items and Clothing", 0, 4);
    
    W.UI.SetMenuRootPage("storeMenu", "root");

    local btnClothing = {}
    btnClothing.text = "Clothing";
    btnClothing.description = "Change your outfit or choose a new character.";
    btnClothing.action = function()
        GoToDressingRoom()
    end
    W.UI.CreatePageItem("storeMenu", "root", 0, btnClothing);

    --
    -- Clothing
    --

    W.UI.CreateMenu("clothingMenu")
    W.UI.CreatePage("clothingMenu", "outfits", "WARDROBE", "Select outfit to edit", 0, 4);
    W.UI.SetMenuRootPage("clothingMenu", "outfits");

    for i=1, 4 do
        local btnEditOutfit = {}
        btnEditOutfit.text = "Outfit " .. tostring(i);
        btnEditOutfit.description = "Select to edit outfit #"..tostring(i);
        btnEditOutfit.action = function()

            if editingOutfit ~= nil then
                SaveOutfit()
            end

            OpenOutfitForEditing(i)
            W.UI.GoToPage("clothingMenu", "outfit_edit")
        end
        W.UI.CreatePageItem("clothingMenu", "outfits", 0, btnEditOutfit);
    end

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
        bDisablingDrawables = false
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
                W.UI.CreatePageItem("clothingMenu", "drawable_list", drawable.drawable, btnToggle);

                if IsMetaPedUsingDrawable(previewPed, drawable.drawable) then
                    W.UI.SetPageItemEndHtml("clothingMenu", "drawable_list", drawable.drawable, "<tick on>")
                else
                    W.UI.SetPageItemEndHtml("clothingMenu", "drawable_list", drawable.drawable, "<tick>")
                end
            end

            W.UI.GoToPage("clothingMenu", "drawable_list")
        end

        W.UI.CreatePageItem("clothingMenu", "drawable_models", 0, params);
    end


    local btnClearDrawable = {}
    btnClearDrawable.text = "Clear Drawables";
    btnClearDrawable.description = "";
    btnClearDrawable.action = function()
        loadout.enabledDrawables = {}
        loadout.disabledDrawables = {}
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
    btnLoco.text = "Walk Style";
    btnLoco.description = "Sets the ped's locomotion animations.";
    btnLoco.action = function(value)
        loadout.loco = value
        UpdatePreviewPed()
    end

    btnLoco.switch = {
        {"No override", 0},
        {"algie", 1},
        {"angry_female", 2},
        {"arthur_healthy", 3},
        {"cowboy", 4},
        {"cowboy_f", 5},
        {"default", 6},
        {"default_female", 7},
        {"free_slave_01", 8},
        {"free_slave_02", 9},
        {"gold_panner", 10},
        {"guard_lantern", 11},
        {"injured_general", 12},
        {"john_marston", 13},
        {"lilly_millet", 14},
        {"lone_prisoner", 15},
        {"lost_man", 16},
        {"mp_ova_hunter", 17},
        {"mp_ova_hunter_female", 18},
        {"murfree", 19},
        {"old_female", 20},
        {"primate", 21},
        {"rally", 22},
        {"waiter", 23},
        {"war_veteran", 24}
    }

    W.UI.CreatePageItem("clothingMenu", "outfit_edit", "btnLoco", btnLoco);

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
SetupStores()


function OpenStore()
    W.UI.OpenMenu("storeMenu", true)
end



function UpdatePreviewPed()
    if previewPed == 0 then
        local modelHash = GetHashKey(loadout.model)

        RequestModel(modelHash)
        
        while not HasModelLoaded(modelHash) do
            RequestModel(modelHash)
            Citizen.Wait(0)
        end
        
        local position = currentStore.dressingRoom.player
        previewPed = CreatePed(modelHash, position[1], position[2], position[3]-1.0, position[4], true, true, true)
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
    W.UI.OpenMenu("storeMenu", false)
    Citizen.Wait(0)

    DoScreenFadeOut(200)
    Citizen.Wait(200)

    W.SetPlayerVisible(PlayerId(), false)


    local camInfo = currentStore.dressingRoom.cam
    dressingCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camInfo[1], camInfo[2], camInfo[3], camInfo[4], 0.0, camInfo[5], 60.0, false, 0)
    SetCamActive(dressingCam, true)
    RenderScriptCams(true, false, 0, true, true, 0)

    DoScreenFadeIn(200)
    Citizen.Wait(301) -- elapsed time since opening/closing menu must be greater 500ms
    W.UI.OpenMenu("clothingMenu", true, true)
end


function ExitDressingRoom()
    DoScreenFadeOut(200)
    Citizen.Wait(200)

    W.SetPlayerVisible(PlayerId(), true)
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
        ExitDressingRoom()
    end
end)


local promptGroup = GetRandomIntInRange(1, 0xFFFFFF)
local prompt = 0
local waitTime = 10


Citizen.CreateThread(function()   
    while true do
        Citizen.Wait(waitTime)
    
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        local bInValidAreas = false
        local currentStoreCoords = nil

        for i = 1, #shopConfig.generalStores do
            local store = shopConfig.generalStores[i]

            currentStoreCoords = vector3(store.location[1], store.location[2], store.location[3])
            
            -- Squared dist for optimization
            local distSqr = GetVectorDistSqr(playerCoords, currentStoreCoords)

            if distSqr*0.1 < 1.0 then
                bInValidAreas = true
                currentStore = store
                break
            end
        end

        if bInValidAreas then         
            if prompt == 0 then -- Create prompt
                prompt = PromptRegisterBegin()
                PromptSetControlAction(prompt, `INPUT_CONTEXT_X`) -- R key
                PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", "Catalog"))
                UiPromptSetHoldMode(prompt, 100)
                PromptSetGroup(prompt, promptGroup, 0) 
                UiPromptSetPriority(prompt, 0)
                PromptRegisterEnd(prompt)
            
                -- Useful management. Automatically deleted when restarting resource
                W.Prompts.AddToGarbageCollector(prompt)    
            end

            if W.Prompts.GetActiveGroup() == 0 then
                PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, "LITERAL_STRING", "General Store"))
            end

            if UiPromptGetProgress(prompt) == 1.0 then
                PromptDelete(prompt)
                prompt = 0

                OpenStore()
                --GoToDressingRoom()
                
                Citizen.Wait(1*1000) -- too soon?
            end

        elseif prompt ~=0 then
            PromptDelete(prompt)
            prompt = 0
            waitTime = 10
        end
    end
end)


-- Cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for i = 1, #shopConfig.generalStores do
            RemoveBlip(shopConfig.generalStores[i]["blip"])            
        end  
    end
end)