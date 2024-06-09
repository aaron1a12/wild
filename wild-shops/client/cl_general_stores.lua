
function GetItemInfo(itemStr, category)
    for i=1, #shopConfig[category] do
        if shopConfig[category][i].item == itemStr then
            return shopConfig[category][i]
        end
    end
end

function UpdateCounts(page)
    function UpdateCountForItem(itemStr)
        local item = GetHashKey(itemStr)
        local count = 0
        local max = 0
        if W.Satchel then
            count = W.Satchel.GetItemCount(item)
            max = W.Satchel.GetItemMaxCount(item)
        end
        W.UI.SetPageItemEndHtml("storeMenu", page, itemStr, tostring(count) .. "/" .. tostring(max))
    end

    for i=1, #shopConfig.guns do
        UpdateCountForItem(shopConfig.guns[i].item)
    end
    
    if page == "weapons" then
        for i=1, #shopConfig.guns do
            UpdateCountForItem(shopConfig.guns[i].item)
        end
    end

    if page == "ammo" then
        for i=1, #shopConfig.ammo do
            UpdateCountForItem(shopConfig.ammo[i].item)
        end
    end

    if page == "provisions" then
        for i=1, #shopConfig.provisions do
            UpdateCountForItem(shopConfig.provisions[i].item)
        end
    end
end

function BuyItem(itemStr, category)
    local item = GetHashKey(itemStr)
    local price = GetItemInfo(itemStr, category).price
    local count = 0
    local max = 0
    if W.Satchel then
        count = W.Satchel.GetItemCount(item)
        max = W.Satchel.GetItemMaxCount(item)

        if count < max then
            if W.GetPlayerMoney() >= price then
                TriggerServerEvent("wild:sv_giveMoney", GetPlayerName(PlayerId()), -price)

                W.Satchel.AddItem(item, 1)
                UpdateCountForItem(itemStr)
            else
                ShowText("You can't afford this item.")
            end
        else
            ShowText("You can't fit any more of this item.")
            -- Solution: see cl_satchel.lua:1205
        end
    end
end

function SetupStores()    
    for i = 1, #shopConfig.generalStores do

        local store = shopConfig.generalStores[i]

        store.blip = BlipAddForCoords(`BLIP_STYLE_SHOP`, store.location[1], store.location[2], store.location[3])

        SetBlipSprite(store.blip, `blip_shop_store`, true)
        SetBlipScale(store.blip, 0.2)
        SetBlipName(store.blip, "General Store")
    end

    W.UI.DestroyMenuAndData("storeMenu")
    Citizen.Wait(10)

    W.UI.CreateMenu("storeMenu")
    W.UI.CreatePage("storeMenu", "root", "GENERAL STORE", "Items and Clothing", 0, 4);
    
    W.UI.SetMenuRootPage("storeMenu", "root");

    local btnWeapons = {}
    btnWeapons.text = "Weapons";
    btnWeapons.description = "Buy a weapon";
    btnWeapons.action = function()
        UpdateCounts("weapons")
        W.UI.GoToPage("storeMenu", "weapons")
    end
    W.UI.CreatePageItem("storeMenu", "root", 0, btnWeapons);

    local btnAmmo = {}
    btnAmmo.text = "Ammunition";
    btnAmmo.description = "Buy ammunition for your weapons";
    btnAmmo.action = function()
        UpdateCounts("ammo")
        W.UI.GoToPage("storeMenu", "ammo")
    end
    W.UI.CreatePageItem("storeMenu", "root", 0, btnAmmo);

    local btnProvisions = {}
    btnProvisions.text = "Provisions";
    btnProvisions.description = "Buy provisions";
    btnProvisions.action = function()
        UpdateCounts("provisions")
        W.UI.GoToPage("storeMenu", "provisions")
    end
    W.UI.CreatePageItem("storeMenu", "root", 0, btnProvisions);

    local btnClothing = {}
    btnClothing.text = "Clothing";
    btnClothing.description = "Change your outfit or choose a new character.";
    btnClothing.action = function()
        GoToDressingRoom()
    end
    W.UI.CreatePageItem("storeMenu", "root", 0, btnClothing);


    --
    -- Weapons
    --

    W.UI.CreatePage("storeMenu", "weapons", "WEAPONS", "", 0, 4);

    for i=1, #shopConfig.guns do
        local item = GetHashKey(shopConfig.guns[i].item)

        local btn = {}
        btn.text = GetStringFromHashKey(item);
        btn.detail = "<h2><span style='font-weight:100;'>Price:</span> &nbsp; $"..FormatMoney(shopConfig.guns[i].price).."</h2>"
        btn.action = function()
            BuyItem(shopConfig.guns[i].item, "guns")
        end
        W.UI.CreatePageItem("storeMenu", "weapons", shopConfig.guns[i].item, btn);
    end

    
    --
    -- Ammo
    --

    W.UI.CreatePage("storeMenu", "ammo", "AMMO", "", 0, 4);

    for i=1, #shopConfig.ammo do
        local item = GetHashKey(shopConfig.ammo[i].item)

        local btn = {}
        btn.text = GetStringFromHashKey(item);
        btn.detail = "<h2><span style='font-weight:100;'>Price:</span> &nbsp; $"..FormatMoney(shopConfig.ammo[i].price).."</h2>"
        btn.action = function()
            BuyItem(shopConfig.ammo[i].item, "ammo")
        end
        W.UI.CreatePageItem("storeMenu", "ammo", shopConfig.ammo[i].item, btn);
    end

    --
    -- Provisions
    --

    W.UI.CreatePage("storeMenu", "provisions", "PROVISIONS", "", 0, 4);

    for i=1, #shopConfig.provisions do
        local item = GetHashKey(shopConfig.provisions[i].item)

        local btn = {}
        btn.text = GetStringFromHashKey(item);
        btn.detail = "<h2><span style='font-weight:100;'>Price:</span> &nbsp; $"..FormatMoney(shopConfig.provisions[i].price).."</h2>"
        btn.action = function()
            BuyItem(shopConfig.provisions[i].item, "provisions")
        end
        W.UI.CreatePageItem("storeMenu", "provisions", shopConfig.provisions[i].item, btn);
    end
end
SetupStores()

function OpenStore()
    W.UI.OpenMenu("storeMenu", true)
end

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
            waitTime = 0
            
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

            local activeGroup = DatabindingReadDataIntFromParent(wildData, "active_group")

            if activeGroup == 0 then
                PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, "LITERAL_STRING", "General Store"))
            end

            if UiPromptGetProgress(prompt) == 1.0 then
                W.Prompts.RemoveFromGarbageCollector(prompt)
                PromptDelete(prompt)
                prompt = 0

                OpenStore()
                
                Citizen.Wait(1*1000) -- too soon?
            end

        elseif prompt ~=0 then
            W.Prompts.RemoveFromGarbageCollector(prompt)
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