stableConfig = json.decode(LoadResourceFile(GetCurrentResourceName(), "stables.json"))

local stableLocations = stableConfig.stableLocations
local horseCatalog = stableConfig.horseCatalog
local saddleCatalog = stableConfig.saddleCatalog
local currentStable = nil

-- How to add mount: TriggerServerEvent("wild:sv_addMount", mountInfo)

local shoppingCart = {}
shoppingCart.name = ""
shoppingCart.model = ""
shoppingCart.price = 0.0
shoppingCart.saddle = 0
shoppingCart.saddleName = ""
shoppingCart.saddlePrice = 0.0


local previewHorse = 0
local previewMountInfo = {}

local stableCam = 0

function GetTotalCost()
    return shoppingCart.price + shoppingCart.saddlePrice
end

function UpdatePreviewHorse()
    local coords = currentStable.horseCoords

    -- Different model from shopping cart. Must delete ped and recreate
    if previewMountInfo[1] ~= shoppingCart.model or previewMountInfo[2] ~= shoppingCart.saddle then
        DeletePreviewHorse()
        previewMountInfo[1] = shoppingCart.model
        previewMountInfo[2] = shoppingCart.saddle
    end

    if previewHorse == 0 then
        local modelHash = GetHashKey(shoppingCart.model)

        RequestModel(modelHash)
        
        while not HasModelLoaded(modelHash) do
            RequestModel(modelHash)
            Citizen.Wait(0)
        end
        
        previewHorse = CreatePed(modelHash, coords[1], coords[2], coords[3]-1.1, coords[4], false, true, true)

        SetEntityInvincible(previewHorse, true)
        SetPedKeepTask(previewHorse)
        SetPedAsNoLongerNeeded(previewHorse)
        SetModelAsNoLongerNeeded(modelHash)

        EquipMetaPedOutfitPreset(previewHorse, 0, false)   

        EquipMetaPedOutfit(previewHorse, shoppingCart.saddle)

        SetHorseGender(previewHorse, false)

        --[[ -- Proof you can combine parts and there is no z-fighting or mixing
        if shoppingCart.saddle == 2670154003 then
            EquipMetaPedOutfit(previewHorse, 3307949695)
        end]]

        if shoppingCart.saddle == 4035792208 then -- Lantern
            EquipMetaPedOutfit(previewHorse, 2169370957)
        end

        UpdatePedVariation(previewHorse, false, true, true, true, false)

        --EquipMetaPedOutfitPreset(previewHorse, 0, 0)
        TaskStandStill(previewHorse, -1)
    end
end

function DeletePreviewHorse()
    DeleteEntity(previewHorse)
    previewHorse = 0
end

function UpdateUIAndHorse()
    W.UI.SetElementTextById("stableMenu", "btn_breed", "Breed: " .. shoppingCart.name)
    W.UI.SetElementTextById("stableMenu", "btn_saddle", "Saddle: " .. shoppingCart.saddleName)
    W.UI.SetElementTextById("stableMenu", "btn_buy", "PURCHASE NOW ( $" .. FormatMoney(GetTotalCost()) .. " )")
    UpdatePreviewHorse()
end

function Checkout()
    local total = GetTotalCost()

    if W.GetPlayerMoney() < total then
        ShowText("You do not have enought funds!")
    else
        TriggerServerEvent("wild:sv_giveMoney", GetPlayerName(PlayerId()), -total)
        TriggerServerEvent("wild:sv_addMount", previewMountInfo)

        CloseStable()

        PlaySound("RDRO_Poker_Sounds", "player_turn_countdown_end")

        Citizen.Wait(2000)

        ShowHelpText("Enjoy your new horse", 4000)

        Citizen.Wait(5000)

        ShowHelpText("You are now able to whistle for your horse", 5000)
    end
    
end

function SetupStables()
    for i = 1, #stableLocations do

        local location = stableLocations[i]
        location.blip = BlipAddForCoords(`BLIP_STYLE_SHOP`, location.coords[1], location.coords[2], location.coords[3])

        SetBlipSprite(location.blip, `blip_shop_horse`, true)
        SetBlipScale(location.blip, 0.2)
        SetBlipName(location.blip, "Stable")
    end

    -- Get info from the first in the catalog
    for _, horse in pairs(horseCatalog) do
        shoppingCart.name = horse.name
        shoppingCart.model = horse.model
        shoppingCart.price = horse.price
        break
    end

    for _, saddle in pairs(saddleCatalog) do
        shoppingCart.saddleName = saddle.name
        shoppingCart.saddle = saddle.outfit
        shoppingCart.saddlePrice = saddle.price
        break
    end

    W.UI.DestroyMenuAndData("stableMenu")
    Citizen.Wait(100)
    W.UI.CreateMenu("stableMenu")
    W.UI.CreatePage("stableMenu", "root", "STABLE", "Horse management", 0, 4);
    W.UI.SetMenuRootPage("stableMenu", "root");

    local btnBrowse = {}
    btnBrowse.text = "Nothing to see here";
    btnBrowse.description = "";
    btnBrowse.action = function()
    end
    W.UI.CreatePageItem("stableMenu", "root", 0, btnBrowse);

    --
    -- Buy Page
    --

    W.UI.CreatePage("stableMenu", "buy_page", "STABLE", "New Horse", 0, 4);

    local btnBreed = {}
    btnBreed.text = "Breed:";
    btnBreed.description = "";
    btnBreed.action = function()
        W.UI.GoToPage("stableMenu", "horse_catalog")
    end
    W.UI.CreatePageItem("stableMenu", "buy_page", "btn_breed", btnBreed)   --menu_stableMenu_item_btn_breed

    local btnSaddle = {}
    btnSaddle.text = "Saddle:";
    btnSaddle.description = "";
    btnSaddle.action = function()
        W.UI.GoToPage("stableMenu", "horse_saddles")
    end
    W.UI.CreatePageItem("stableMenu", "buy_page", "btn_saddle", btnSaddle)

    --

    local btnBuyNow = {}
    btnBuyNow.text = "PURCHASE NOW";
    btnBuyNow.description = "";
    btnBuyNow.action = function()
        Checkout()
    end
    W.UI.CreatePageItem("stableMenu", "buy_page", "btn_buy", btnBuyNow)

    --
    -- Catalog list
    --

    W.UI.CreatePage("stableMenu", "horse_catalog", "STABLE", "Available Horses", 0, 4);

    for _, horse in pairs(horseCatalog) do
        local params = {}
        params.text = horse.name
        params.description = 'Price: $'..FormatMoney(horse.price);
        params.action = function()
            
            shoppingCart.name = horse.name
            shoppingCart.model = horse.model
            shoppingCart.price = horse.price

            UpdateUIAndHorse()
        end
        W.UI.CreatePageItem("stableMenu", "horse_catalog", horse.name, params);
    end

    --
    -- Saddle Catalog
    --

    W.UI.CreatePage("stableMenu", "horse_saddles", "STABLE", "Available Saddles", 0, 4);

    for _, saddle in pairs(saddleCatalog) do
        local params = {}
        params.text = saddle.name
        params.description = 'Price: $'..FormatMoney(saddle.price);
        params.action = function()
            
            shoppingCart.saddleName = saddle.name
            shoppingCart.saddle = saddle.outfit
            shoppingCart.saddlePrice = saddle.price

            UpdateUIAndHorse()
        end
        W.UI.CreatePageItem("stableMenu", "horse_saddles", saddle.name, params);
    end

end

function OpenStable()
    DoScreenFadeOut(200)
    Citizen.Wait(200)
    

    local camCoords = currentStable.camCoords
    local camRot = currentStable.camRot
    stableCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camCoords[1], camCoords[2], camCoords[3], camRot[1], camRot[2], camRot[3], 40.0, false, 0)
    SetCamActive(stableCam, true)
    RenderScriptCams(true, false, 0, true, true, 0)

    local mountInfo = RequestMountInfo()

    if #mountInfo == 0 then
        
        W.UI.SetMenuRootPage("stableMenu", "buy_page");
    else
        W.UI.SetMenuRootPage("stableMenu", "root");
    end

    UpdateUIAndHorse()

    Citizen.Wait(100)
    DoScreenFadeIn(100)
    

    W.UI.OpenMenu("stableMenu", true, true)
end

function CloseStable()
    W.UI.OpenMenu("stableMenu", false, true)

    DoScreenFadeOut(200)
    Citizen.Wait(200)

    
    DeletePreviewHorse()
    RenderScriptCams(false, false, 0, true, true, 0)
    SetCamActive(stableCam, false)
    DestroyCam(stableCam, true)

    DoScreenFadeIn(100)
end

AddEventHandler("wild:cl_onMenuClosing", function(menu)
    if menu == "stableMenu" then
        CloseStable()
    end
end)

function Init()
    SetupStables()
end
Init()

local prompt = 0

Citizen.CreateThread(function()   
    while true do
        Citizen.Wait(10)
    
        local playerCoords = GetEntityCoords(PlayerPedId())
        
        local bInValidAreas = false
        local currentLocationCoords = nil

        for i = 1, #stableLocations do
            currentLocationCoords = vector3(stableLocations[i].coords[1], stableLocations[i].coords[2], stableLocations[i].coords[3])
            
            -- Squared dist for optimization
            local distSqr = GetVectorDistSqr(playerCoords, currentLocationCoords)

            if distSqr*0.1 < 1.0 then
                bInValidAreas = true
                currentStable = stableLocations[i]
                break
            end
        end

        if bInValidAreas then
        
            if prompt == 0 then -- Create prompt
                prompt = PromptRegisterBegin()
                PromptSetControlAction(prompt, `INPUT_CONTEXT_X`) -- R key
                PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", "Access Stable"))
                UiPromptSetHoldMode(prompt, 500)
                UiPromptSetType(prompt, 1) -- By setting a prompt type, we can then hide these types during special cases (conflicting prompts)
                PromptRegisterEnd(prompt)
            
                -- Useful management. Automatically deleted when restarting resource
                W.Prompts.AddToGarbageCollector(prompt)         
            end

            if UiPromptGetProgress(prompt) == 1.0 then
                PromptDelete(prompt)
                prompt = 0

                -- Action

                OpenStable()

                Citizen.Wait(2*1000) -- too soon?
            end

        elseif prompt ~=0 then
            PromptDelete(prompt)
            prompt = 0
        end
    end
end)


-- Cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for i = 1, #stableLocations do
            RemoveBlip(stableLocations[i]["blip"])            
        end  
    end
end)