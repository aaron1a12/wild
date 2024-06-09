--[[
====================================================================================================

    Satchel
    =======

    Public methods:

    W.Satchel.Add(item, quantity, bNoUpdate)
    W.Satchel.Open(bShopMode)

====================================================================================================
]]

PlayerInventory = nil
_playerInventory = nil

RegisterNetEvent("wild:sv_onReceivePlayerInventory", function(newInventory)
    _playerInventory = newInventory	
end)

function RefreshPlayerInventory()
    TriggerServerEvent("wild:sv_getPlayerInventory", GetPlayerName(PlayerId()))

    while _playerInventory == nil do
        Citizen.Wait(0)
    end

    PlayerInventory = _playerInventory
    _playerInventory = nil
end

local bShopMode = false
local bSatchelOpen = false
local lastSelectedItem = 0
local bIsInspecting = false


function GetCustomInventoryWithFilter(itemArray, filter)
    filter = string.lower(filter)
    local allowedGroups = {}

    if filter == "documents" then
        allowedGroups = {`document`}
    end

    for key, value in pairs(customItemCatalog) do
        if PlayerInventory[key] then
            local bIsAllowed = false

            if filter == "all" then
                bIsAllowed = true
            else
                local group = GetHashKey(customItemCatalog[key].group)

                for i=1, #allowedGroups do
                    if allowedGroups[i] == group then
                        bIsAllowed = true 
                        break
                    end
                end
            end

            if bIsAllowed then
                table.insert(itemArray, {
                    item = key, quantity = PlayerInventory[key][1], ui = GetItemUiFallback(key), location = 0
                })
            end
        end
    end    
end


function GetItemModel(item)
	local info = NewItemInfo()

	if 0 == ItemdatabaseIsKeyValid(item, 0) then
        print("ERROR: ItemdatabaseIsKeyValid is not valid")
		return 0
    end

	if false == Citizen.InvokeNative(0xFE90ABBCBFDC13B2, item, info:Buffer()) then
        print("ERROR: ItemdatabaseFilloutItemInfo returned error")
		return 0
    end

	return info:GetInt32(32);
end

function SatchelGetItemMaxCount(item)
    -- Get the default placement for this item
    local inventoryGuid, slotId = GetItemInventoryInfo(item)
    return GetItemSlotMaxCount(item, slotId)
end
W.RegisterExport("Satchel", "GetItemMaxCount", SatchelGetItemMaxCount)

function SatchelAddItem(item, quantity, bNoUpdate)
    local customItem = nil

    if ItemdatabaseIsKeyValid(item, 0) == 0 then
        if customItemCatalog[item] then
            customItem = customItemCatalog[item]
        else
            return false
        end
    end

    if quantity < 1 then
        return false
    end

    -- Initial population of satchel should have bNoUpdate=true to avoid saving on start.
    if not(bNoUpdate == true) then
        -- Add to our inventory first
        local key = item

        -- Update current quantity

        if PlayerInventory[key] == nil then
            PlayerInventory[key] = {0, 0}
        end

        -- ...but first check if we can add it 

        -- Get the default placement for this item
        local inventoryGuid, slotId = GetItemInventoryInfo(item)
        local maxCount = GetItemSlotMaxCount(item, slotId)

        if not customItem and PlayerInventory[key][1] + quantity > maxCount then
            ShowHelpText("Satchel is full for this type of item.")
            return
        end
        
        PlayerInventory[key][1] = PlayerInventory[key][1] + quantity

        -- Do the same on the server
        TriggerServerEvent("wild:satchel:cl_add", key, quantity)
        
        ShowInventoryToast(item, quantity, true)
    end

    if not customItem then
        -- Add to native inventory
        AddItemToInventory(item, quantity)
    end

    return true
end
W.RegisterExport("Satchel", "AddItem", SatchelAddItem)

function SatchelRemoveItem(item, quantity, bSuppressUi, bNoNativeChange)
    if ItemdatabaseIsKeyValid(item, 0) == 0 and not IsItemCustom(item) then
		return false
    end

    if quantity < 1 then
        return false
    end

    function updateSatchelUi(iNewQuantity)
        if bSatchelOpen then
            if iNewQuantity > 1 then
                W.UI.SetPageItemEndHtml("satchel", "grid", "item_"..item, "<quantity>"..iNewQuantity.."</quantity>");
            else
                W.UI.SetPageItemEndHtml("satchel", "grid", "item_"..item, "");
            end
    
            if iNewQuantity < 1 then
                W.UI.DestroyPageItem("satchel", "grid", "item_"..item)
            end
        end
    end

    -- Add to our inventory first
    local key = item

    -- Update current quantity

    if PlayerInventory[key] == nil then -- might be a horse item

        local mount, mountDist = PickMountForLoad(PlayerId())

        -- Is it a carcass?

        local entityStowed = GetFirstEntityPedIsCarrying(mount)

        if DoesEntityExist(entityStowed) then
            if not (GetIsAnimal(entityStowed) == 0 and GetIsAnimal(entityStowed) == 0) then
                if IsEntityAPed(entityStowed) then
                    local carcass = GetSatchelCarcassFromPed(entityStowed)
                    if carcass == item then
                        DeleteEntity(entityStowed)
                        updateSatchelUi(0)
                        return true
                    end
                end
            end
            return false
        elseif InventoryGetInventoryItemIsAnimalPelt(item) == 1 then
            local peltQuantity = 0
            local quantityRemoved = 0

            for i = 0, 99 do
                local pelt = GetPeltFromHorse(mount, i)
                
                if pelt ~= 0 then
                    if pelt == item then
                        peltQuantity = peltQuantity + 1
                    end
                else
                    break
                end
            end

            peltQuantity = peltQuantity - quantity

            for i = 1, quantity do
                ClearPeltFromHorse(mount, item)
            end

            updateSatchelUi(peltQuantity)
            return true
        end

        return false
    end
    
    if not IsItemCustom(item) then
        -- Use the native current count as the user might have more items than the satchel supports.
        -- Ex: The ui might show 10 items but the json db might contain 100 items. It would be confusing
        -- if we sold all ten items but if the user rejoins the session it would reload the db amount (90)
        -- and show again 10 items since the satchel can cap the item count.
        PlayerInventory[key][1] = InventoryGetInventoryItemCountWithItemid(1, item, false) - quantity
    else
        PlayerInventory[key][1] = PlayerInventory[key][1] - quantity
    end

    local newQuantity = PlayerInventory[key][1]

    updateSatchelUi(newQuantity)

    -- Do the same on the server
    TriggerServerEvent("wild:satchel:cl_updateItem", key, {PlayerInventory[key][1], PlayerInventory[key][2]})

    if newQuantity < 1 then
        PlayerInventory[key] = nil
    end
    
    if not bSuppressUi then
        ShowInventoryToast(item, quantity, false)
    end

    if not (bNoNativeChange==true) then
        -- Remove from native inventory
        RemoveItemFromInventory(item, quantity)
    end

    return true
end
W.RegisterExport("Satchel", "RemoveItem", SatchelRemoveItem)


function SatchelGetItemCount(item)
    if PlayerInventory[item] then
        return PlayerInventory[item][1]
    end

    return 0
end
W.RegisterExport("Satchel", "GetItemCount", SatchelGetItemCount)


function SatchelGetItemValue(item)
    local valuePrice = 0.00;

    if not IsItemCustom(item) then
        -- See catalog_sp.ymt
        local struct = DataView.ArrayBuffer(128)
        struct:SetInt32(0, 0) -- 816454899, unknown hash, all sellable catalog items have it
        struct:SetInt32(8, 0) -- 1, quantity ?
        struct:SetInt32(16, 0) -- 1400824947, costtype hash
        struct:SetInt32(24, 0) -- 1, quantity ?
        struct:SetInt32(32, 10)
        struct:SetInt32(40, 0) -- sell award? It's CURRENCY_CASH 99% of the time
        struct:SetInt32(48, 0) -- award amount (cash amount)
        
        -- TODO: use ItemdatabaseFilloutAcquireCost for items that don't sell (weapons, peaches, etc)
        if Citizen.InvokeNative(0x7A62A2EEDE1C3766, item, `SELL_SHOP_DEFAULT`, struct:Buffer()) == 1 then 
            if struct:GetInt32(40) == `CURRENCY_CASH` then
                valuePrice = struct:GetInt32(48) / 100
            end            
        else
            -- Fetch prices from catalog?
            ---Citizen.InvokeNative(0xCFB06801F5099B25, item, `SELL_SHOP_DEFAULT`, struct:Buffer())
            --print(ItemdatabaseIsShopKeyValid(`ST_HANDHELD`))
            valuePrice = 0.02
            
        end
    else
        valuePrice = tonumber(customItemCatalog[item].value)
    end

    return valuePrice    
end
W.RegisterExport("Satchel", "GetItemValue", SatchelGetItemValue)


function SatchelGetItemGroup(item)
    if not IsItemCustom(item) then
        return GetItemGroup(item)
    else
        return GetHashKey(customItemCatalog[item].group)
    end 
end
W.RegisterExport("Satchel", "GetItemGroup", SatchelGetItemGroup)


function SatchelGetInventoryWithFilter(filter)
    filter = string.lower(filter)
    local inventory = {}
    
    if filter ~= "all" and filter ~= "weapons" and filter ~= "provisions" and filter ~= "horse food" then
        return inventory
    end

    GetCustomInventoryWithFilter(inventory, filter)
    GetInventoryWithFilter(inventory, filter)

    return inventory
end
W.RegisterExport("Satchel", "GetInventoryWithFilter", SatchelGetInventoryWithFilter)

IsHorseFood(item)




function OnStart()
    -- Make sure we start clean
    ClearInventory()

   --------------------
    W.UI.DestroyMenuAndData("satchel")

    Citizen.Wait(1000)
    W.UI.CreateMenu("satchel", true)

    W.UI.CreatePage("satchel", "grid", "Satchel", "All", 1, 4);
    W.UI.SetMenuRootPage("satchel", "grid");
    
    RefreshPlayerInventory()

    for itemHash in pairs(PlayerInventory) do
        quantity = PlayerInventory[itemHash][1]
        itemHash = tonumber(itemHash)

        SatchelAddItem(itemHash, quantity, true)
    end    

    --
    -- Runtime items. These do not save.
    --

    -- Some preliminaries
    AddItemToInventory(`KIT_HANDHELD_CATALOG`, 1)
    AddItemToInventory(-1406390556, 1) -- valuables satchel
    AddItemToInventory(-2048947027, 1) -- shaving kit
    AddItemToInventory(-1455768246, 1) -- kit satchel
    AddItemToInventory(-1733092640, 1) -- collector's bag
    AddItemToInventory(-780677328, 1) -- pocket watch
    AddItemToInventory(-2035110427, 1) -- mortar and pestle
    AddItemToInventory(-106768597, 1) -- large money satchel
    AddItemToInventory(2019377485, 1) -- camp
    --AddItemToInventory(-1838434463, 1) -- sp camp with cooking icon
    --AddItemToInventory(-1115561122, 1) -- wilderness camp
    AddItemToInventory(-1516555556, 1) -- horse brush
    AddItemToInventory(982182330, 1) -- materials satchel
    AddItemToInventory(-630557532, 1) -- materials satchel2
    AddItemToInventory(-6419100, 1) -- kit satchel 2
    AddItemToInventory(1018123892, 1) -- ingredients satchel
    AddItemToInventory(-727924611, 1) -- wardrobe for horse
    AddItemToInventory(-59585102, 1) -- tonics satchel
    AddItemToInventory(1979310863, 1) -- tonics satchel 2
    AddItemToInventory(85134332, 1) -- field 
    AddItemToInventory(856970057, 1)  -- ingredients satchel 2
    AddItemToInventory(896288156, 1) -- large ammo satchel
    AddItemToInventory(-921879912, 1) -- provisions satchel
    AddItemToInventory(273608212, 1) -- sample kit
    AddItemToInventory(1401465909, 1) -- animal field guide
    AddItemToInventory(1081037984, 1) -- key
    AddItemToInventory(1157009922, 1) -- key bunch
    AddItemToInventory(1510719693, 1) -- coffee percolator
    
    --Some fish lures (in case you want to add fishing latter)
    --[[AddItemToInventory(1380607804, 1)
    AddItemToInventory(149706141, 1)
    AddItemToInventory(1903483453, 1)
    AddItemToInventory(1059426360, 1)
    AddItemToInventory(811830793, 1)
    AddItemToInventory(488496242, 1)
    AddItemToInventory(2100131425, 1)
    AddItemToInventory(-698168422, 1)
    AddItemToInventory(-2041382104, 1)
    AddItemToInventory(-978159653, 1)
    AddItemToInventory(-1916584960, 1)
    AddItemToInventory(-1753819339, 1)
    AddItemToInventory(-1527293029, 1)]]

    -- Upgrades
    -- max: 12
    --AddItemToInventory(`UPGRADE_HEALTH_TANK_1`, 1)
    AddItemToInventory(`UPGRADE_STAMINA_TANK_1`, 12)
    AddItemToInventory(`UPGRADE_DEADEYE_TANK_1`, 12)
    AddItemToInventory(`UPGRADE_OFFHAND_HOLSTER`, 1)

    AddItemToInventory(`CLOTHING_ITEM_M_OFFHAND_000_TINT_004`, 1)    

    -- Compensate large tanks with slow recharge
    SetPlayerHealthRechargeMultiplier(PlayerId(), 0.1)
    SetPlayerStaminaRechargeMultiplier(PlayerId(), 0.1)
end
OnStart()

function CreateFilters()
    W.UI.CreatePageFilterIcons("satchel", "grid", {
        "satchel_icons/satchel_nav_kit.png", 
        "satchel_icons/satchel_nav_all.png",
        "satchel_icons/satchel_nav_provisions.png", 
        "satchel_icons/satchel_nav_animals.png",
        "satchel_icons/satchel_nav_weapons.png",
        "satchel_icons/satchel_nav_documents.png",
    })
end

local filters = {
    "All", "Provisions", "Consumables", "Hunting", "Weapons", "Documents"
}
local filterIndex = 1

local bPopulatingNow = false

AddEventHandler("wild:cl_onMenuFilter", function(menu, direction)
    
    if menu == "satchel" then

        if direction == 1 then
            filterIndex = filterIndex + 1
        else
            filterIndex = filterIndex - 1
        end

        -- clamp
        if filterIndex > #filters then
            filterIndex = 1
        elseif filterIndex < 1 then
            filterIndex = #filters
        end

        W.UI.SelectPageFilterIcon("satchel", "grid", filterIndex-1)
        W.UI.EditPage("satchel", "grid", "Satchel", filters[filterIndex])	
        
        while bPopulatingNow do
            Citizen.Wait(0)
        end

        RepopulateGrid()
    end
end)

--[[
    -- https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/ItemDatabaseItemFlags
     -- ITEM_FLAG_QUALITY_PRISTINE
]]

function RepopulateGrid()
    if bPopulatingNow then
        return
    end

    bPopulatingNow = true
    W.UI.EmptyPage("satchel", "grid")
    CreateFilters()
    W.UI.SelectPageFilterIcon("satchel", "grid", filterIndex-1)

    local gridItems = {}
    
    GetCustomInventoryWithFilter(gridItems, filters[filterIndex])
    GetInventoryWithFilter(gridItems, filters[filterIndex])

    for i=1, #gridItems do
        local gridItem = gridItems[i]

        local bSkipItem = false

        if not bSkipItem then
            local sellPrice = SatchelGetItemValue(gridItem.item);
                
            local params = {}
            params.icon = "item_textures/"..tostring(gridItem.ui.textureId)..".png";


            params.description = "Carrying "..tostring(gridItem.quantity);
            params.detail = "<h3>"..gridItem.ui.name.."</h3><p>"..gridItem.ui.description .. "\n\nSells for $"..FormatMoney(sellPrice).. "</p>";

            --[[
            local info = DataView.ArrayBuffer(8 * 7)
            Citizen.InvokeNative(0xFE90ABBCBFDC13B2, gridItem.item, info:Buffer())
            local group = info:GetInt32(16) -- weapon, provision, consumable, etc
            local category = info:GetInt32(8) -- Note that categories are actually a subset of "group"

            params.description = gridItem.item .. " | " .. category;]]
        
            --params.detail = "(1 << 5):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 5))) .. ", (1 << 9):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 9))) .. ", (1 << 10):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 10))) .. ", (1 << 11):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 11))) .. ", (1 << 12):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 12))) .. ", (1 << 13):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 13))) .. ", (1 << 14):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 14))) .. ", (1 << 15):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 15))) .. ", (1 << 16):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 16))) .. ", (1 << 17):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 17))) .. ", (1 << 18):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 18))) .. ", (1 << 19):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 19))) .. ", (1 << 20):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 20))) .. ", (1 << 21):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 21))) .. ", (1 << 25):"..tostring(InventoryIsInventoryItemFlagEnabled(gridItem.item, (1 << 25))) 

            -- useless consumable tag: 0x445e28fd
            -- 0xa91bc5e4
            --params.detail = tostring(ItemdatabaseDoesItemHaveTag(gridItem.item, 0xf47e8343, 0x42d03bde)) .. "|"..tostring(ItemdatabaseDoesItemHaveTag(gridItem.item, 0x0bf68597, 0x42d03bde));

            -- Interesting places for ref: generic_multibite_item.c, generic_single_use_item.c, generic_smoking_item.c, generic_document_inspection.c (SET_CUSTOM_TEXTURES_ON_OBJECT)
            params.action = function()  
                if bShopMode then
                    TriggerEvent('wild:cl_onSell', gridItem.item, 1)
                    SatchelRemoveItem(gridItem.item, 1, true)
                    UpdatePrompts()
                    return
                end

                SatchelUseItem(gridItem.item)         
            end
        
            W.UI.CreatePageItem("satchel", "grid", "item_"..gridItem.item, params);

            local endHtmlTags = ""

            if gridItem.quantity > 1 then
                endHtmlTags = endHtmlTags .. "<quantity>"..gridItem.quantity.."</quantity>"
            end

            if gridItem.location == 1 then
                endHtmlTags = endHtmlTags .. "<onHorse />"
            end

            W.UI.SetPageItemEndHtml("satchel", "grid", "item_"..gridItem.item, endHtmlTags);
        end
    end
    Citizen.Wait(0)
    bPopulatingNow = false
end

local promptInspect = 0
local promptDrop = 0
local promptSellAll = 0

function CreatePrompts()    
    promptInspect = PromptRegisterBegin()
    PromptSetControlAction(promptInspect, `INPUT_GAME_MENU_EXTRA_OPTION`) -- R key
    PromptSetText(promptInspect, CreateVarString(10, "LITERAL_STRING", "Inspect"))
    UiPromptSetPriority(promptInspect, 0)
    PromptRegisterEnd(promptInspect)
    W.Prompts.AddToGarbageCollector(promptInspect)

    promptDrop = PromptRegisterBegin()
    PromptSetControlAction(promptDrop, `INPUT_GAME_MENU_OPTION`) -- R key
    if not bShopMode then
        PromptSetText(promptDrop, CreateVarString(10, "LITERAL_STRING", "Drop"))
    else
--        PromptSetText(promptDrop, CreateVarString(10, "LITERAL_STRING", "Sell All"))
    end
    UiPromptSetPriority(promptDrop, 0)
    PromptRegisterEnd(promptDrop)
    W.Prompts.AddToGarbageCollector(promptDrop)
end

function DestroyPrompts()
    W.Prompts.RemoveFromGarbageCollector(promptInspect)
    W.Prompts.RemoveFromGarbageCollector(promptDrop)
    PromptDelete(promptInspect)
    PromptDelete(promptDrop)
    promptInspect = 0
    promptDrop = 0
end

function UpdatePrompts()
    local item = lastSelectedItem
    
    --if ItemdatabaseIsKeyValid(item, 0) == 0 and not IsItemCustom(item) then
		--return false
    --end

    
    if not bShopMode then

        local bInspectable = false
        local group = SatchelGetItemGroup(item)
        local tag = 0

        if ItemdatabaseIsKeyValid(item, 0) == 1 then
            tag = ItemdatabaseGetTagOfType(item, `TAG_INTERACTION_TYPE`)

            local struct = DataView.ArrayBuffer(256)
            struct:SetInt32(8*3, -1)
            struct:SetInt32(8*12, 4)
            struct:SetInt32(8*17, 4)
            Citizen.InvokeNative(0x0C093C1787F18519, lastSelectedItem, struct:Buffer()) --_INVENTORY_GET_INVENTORY_ITEM_INSPECTION_INFO

            local model = struct:GetInt32(8*0)

            if model ~= 0 then
                bInspectable = true
            else
                if group == `weapon` then
                    bInspectable = true
                end
            end

            if item == 730856618 then --seems to glitch. What other items could glitch? Manually add them here :P
                bInspectable = false
            end

            if tag == `ci_tag_pocket_watch` or group == `document` then -- pocket watch
                bInspectable = true
            end
        end

        if group == `document` then
            bInspectable = true
        end

        UiPromptSetEnabled(promptInspect, bInspectable)  
        UiPromptSetText(W.UI.GetActivePrompt(), CreateVarString(10, "LITERAL_STRING", "Use"))

        

        if IsItemUsable(item, tag) then
            UiPromptSetEnabled(W.UI.GetActivePrompt(), true)
        else
            UiPromptSetEnabled(W.UI.GetActivePrompt(), false)
        end

    else -- Shop mode
        UiPromptSetText(W.UI.GetActivePrompt(), CreateVarString(10, "LITERAL_STRING", "Sell"))

        if item == -780677328 then
            UiPromptSetEnabled(W.UI.GetActivePrompt(), false)
        else
            UiPromptSetEnabled(W.UI.GetActivePrompt(), true)
        end

        UiPromptSetVisible(promptInspect, false)  
        -- 
        UiPromptSetVisible(promptSellAll, true)

        local count = SatchelGetItemCount(item)
        local totalSale = count*SatchelGetItemValue(item)

        if count > 1 then
            UiPromptSetVisible(promptDrop, true) 
            UiPromptSetEnabled(promptDrop, true) 
            PromptSetText(promptDrop, CreateVarString(10, "LITERAL_STRING", "Sell All ($"..FormatMoney(totalSale)..")"))
        else
            UiPromptSetVisible(promptDrop, false) 
            UiPromptSetEnabled(promptDrop, false) 
        end
    end
end

AddEventHandler("wild:cl_onSelectPageItem", function(menu, page, item)
    if menu == "satchel" then
        lastSelectedItem = tonumber(string.sub(item, 6, 99))
        
        if promptInspect == 0 then -- Create promptInspect
            CreatePrompts()
        end

        UpdatePrompts()
    end
end)

function OpenSatchel(bShop)
    if bSatchelOpen then
        return false
    end

    bSatchelOpen = true

    if bShop == nil then
        bShop = false
    end
    bShopMode = bShop
    RepopulateGrid()
    W.UI.OpenMenu("satchel", true)

    return true
end
W.RegisterExport("Satchel", "Open", OpenSatchel)


AddEventHandler("wild:cl_onMenuClosing", function(menu)
    if menu == "satchel" then
        bSatchelOpen = false

        DestroyPrompts()
    end
end)

ClearPedTasks(PlayerPedId())
function SatchelInspectItem(item)
    Citizen.CreateThread(function()    
        bIsInspecting = true
        W.UI.OpenMenu("satchel", false)

        local group = SatchelGetItemGroup(item)
        tag = ItemdatabaseGetTagOfType(item, `TAG_INTERACTION_TYPE`)
        
        if tag == `ci_tag_pocket_watch` or group == `document` then
            PlayTaskInteract(item, tag)
        else
            -- Hacky way to inspect any item with a model
            
            -- Get the model for the item
            local struct = DataView.ArrayBuffer(256)
            struct:SetInt32(8*3, -1)
            struct:SetInt32(8*12, 4)
            struct:SetInt32(8*17, 4)
            Citizen.InvokeNative(0x0C093C1787F18519, item, struct:Buffer()) --_INVENTORY_GET_INVENTORY_ITEM_INSPECTION_INFO

            local model = struct:GetInt32(8*0)
            local attachBone = struct:GetInt32(8*3)
            local clipset = ReadString(struct:GetInt64(8*1)) --CLIPSET@MECH_INSPECTION@GENERIC@LH@SATCHEL
            local gripClipset = ReadString(struct:GetInt64(8*2)) --CLIPSET@MECH_INSPECTION@GENERIC@LH@GRIPS@MEDIUM_CAN
            local dynamicTextureSource = ReadString(struct:GetInt64(8*4)) 
            local bFullBody = (struct:GetInt32(8*5)==1)
            local bEnableManipulationSweeps = (struct:GetInt32(8*6)==1)
            local moveContextFlags = struct:GetInt32(8*7)

            local unkHash0 = struct:GetInt32(72)
            local unkHash1 = struct:GetInt32(80)
            --[[local cameraOverrideSettingsName = ReadString(struct:GetInt64(8*9)) 
            local cameraOverrideSettingsNameFirstPerson = ReadString(struct:GetInt64(8*10)) 
            local animationDictionary = ReadString(struct:GetInt64(8*11))]]
            --StartTaskItemInteraction(PlayerPedId(), item,  `USE_TONIC_SATCHEL_LEFT_HAND_QUICK`, 1, 0, -1)

            if model ~= 0 and IsModelValid(model) then
                StartTaskItemInteraction(PlayerPedId(), item,  `WEDGE@A4-2_B0-75_W8_H9-4_InspectY_HOLD`, 1, 0, -1082130432)
            else
                local inventoryGuid, slotId = GetItemInventoryInfo(item)
                local itemGuid = GetInventoryItemGuid(item, inventoryGuid, slotId)
                Citizen.InvokeNative(0xD61D5E1AD9876DEB, PlayerPedId(), item, itemGuid, 0, 0, 0, -1082130432)
            end

            Citizen.Wait(5000)
            ClearPedTasks(PlayerPedId())
        end
    end)
end

function IsItemUsable(item, tagCached)
    local group = SatchelGetItemGroup(item)

    if group == `consumable` then
        return true
    else
        local tag = tagCached
        if tag == nil then
            tag = ItemdatabaseGetTagOfType(item, `TAG_INTERACTION_TYPE`)
        end

        if tag==881567935 or tag==845883585 or tag==-1239610997 or tag==632545869 or tag==-793205628 or tag==1451036371 or tag==273840653 or
        tag==999632878 or tag==1130235258 or tag==-1915958659 or tag==1859991422 or tag==1891031775 or tag==-809056541 or
        tag==-262371497 or tag==1443104131 or tag==-1919515848 or tag==89124942 or tag==238865292 or tag==1177617310 then
            return true
        end
    end

    return false
end


local digestingLeft = 0
local maxDigestible = 1000.0

function StartDigestion()
    Citizen.CreateThread(function()
        while digestingLeft > 0.0 do
            Citizen.Wait(0)
            digestingLeft = digestingLeft - 10 * GetFrameTime()

            if digestingLeft > maxDigestible then
                digestingLeft = 0.0
                Wait(5000)
                PukeNow()
            end
        end
    end)
end


ClearPedTasks(PlayerPedId())
local lastSoundTime = 0

local itemBeingRemoved = 0

function SatchelUseItem(item)
    local ped = PlayerPedId()

    local interactionType = ItemdatabaseGetTagOfType(item, `TAG_INTERACTION_TYPE`)
    PlayTaskInteract(item, interactionType)

    local group = SatchelGetItemGroup(item)

    if group == `consumable` then
        Citizen.CreateThread(function()
            local timeOut = 5000
            while timeOut > 0 and not HasAnimEventFired(ped, `APPLYSTAT`) do
                Wait(0)
                timeOut = timeOut - 50
            end

            StopItemPreview() -- stops tonic flashing?

            -- APPLYSTAT event has fired or timeOut

            function PlaySoundForCore(core)
                if GetGameTimer()-lastSoundTime > 1000 then
                    lastSoundTime = GetGameTimer()
                    if GetAttributeCoreValue(ped, core) >= 100 then 
                        PlaySound("Consumption_Sounds", "Core_Full")
                    else
                        PlaySound("Consumption_Sounds", "Core_Fill_Up")
                    end
                end
            end

            local effectIds = ItemdatabaseGetEffectIds(item)

            for _, effectId in ipairs(effectIds) do
                local effect = ItemdatabaseGetEffect(effectId)

                if effect.type == `EFFECT_HEALTH` then
                    if effect.value > 10 then effect.value = 10 end
                    SetEntityHealth(ped, GetEntityHealth(ped) + effect.value*10)
                elseif effect.type == `EFFECT_DEADEYE` then
                    -- not implemented. useless anyway in mp
                elseif effect.type == `EFFECT_STAMINA` then
                    if effect.value > 10 then effect.value = 10 end
                    RestorePedStamina(ped, effect.value*10)
                elseif effect.type == `EFFECT_HEALTH_CORE` then
                    SetAttributeCoreValue(ped, ePedAttribute.PA_HEALTH, GetAttributeCoreValue(ped, ePedAttribute.PA_HEALTH) + effect.value*10)
                    PlaySoundForCore(ePedAttribute.PA_HEALTH)
                elseif effect.type == `EFFECT_DEADEYE_CORE` then
                    SetAttributeCoreValue(ped, ePedAttribute.PA_SPECIALABILITY, GetAttributeCoreValue(ped, ePedAttribute.PA_SPECIALABILITY) + effect.value*10)
                    PlaySoundForCore(ePedAttribute.PA_SPECIALABILITY)
                elseif effect.type == `EFFECT_STAMINA_CORE` then
                    SetAttributeCoreValue(ped, ePedAttribute.PA_STAMINA, GetAttributeCoreValue(ped, ePedAttribute.PA_STAMINA) + effect.value*10)
                    PlaySoundForCore(ePedAttribute.PA_STAMINA)
                elseif effect.type == `EFFECT_CALORIES` then
                    local calories = effect.value*100
                    local mealSize = calories -- not a good idea to use calorie count as sweets have a lot of them

                    if digestingLeft <= 0 then
                        digestingLeft = mealSize
                        StartDigestion()
                    else
                        digestingLeft = digestingLeft + mealSize
                    end
                else
                    if effect.type == `EFFECT_HEALTH_CORE_GOLD` then
                        SetAttributeCoreValue(ped, ePedAttribute.PA_HEALTH, 100)
                        EnableAttributeOverpower(ped, ePedAttribute.MTR_GRIT, effect.time, true)
                    elseif effect.type == `EFFECT_DEADEYE_CORE_GOLD` then
                        SetAttributeCoreValue(ped, ePedAttribute.PA_SPECIALABILITY, 100)
                        EnableAttributeOverpower(ped, ePedAttribute.MTR_INSTINCT, effect.time, true)
                    elseif effect.type == `EFFECT_STAMINA_CORE_GOLD` then
                        SetAttributeCoreValue(ped, ePedAttribute.PA_STAMINA, 100)
                        EnableAttributeOverpower(ped, ePedAttribute.MTR_STRENGTH, effect.time, true)
                    elseif effect.type == `EFFECT_HEALTH_OVERPOWERED` then
                        EnableAttributeOverpower(ped, ePedAttribute.PA_HEALTH, effect.time, true)
                        ChangeEntityHealth(ped, GetNumReservedHealth(ped), 0, 0)
                    elseif effect.type == `EFFECT_DEADEYE_OVERPOWERED` then
                        EnableAttributeOverpower(ped, ePedAttribute.PA_SPECIALABILITY, effect.time, true)
                    elseif effect.type == `EFFECT_STAMINA_OVERPOWERED` then
                        EnableAttributeOverpower(ped, ePedAttribute.PA_STAMINA, effect.time, true)
                    end

                    if effect.type == `EFFECT_HEALTH_CORE_GOLD` or effect.type == `EFFECT_DEADEYE_CORE_GOLD` or effect.type == `EFFECT_STAMINA_CORE_GOLD` then
                        PlaySound("Consumption_Sounds", "Core_Full")
                    end

                    if effect.type == `EFFECT_HEALTH_OVERPOWERED` or effect.type == `EFFECT_DEADEYE_OVERPOWERED` or effect.type == `EFFECT_STAMINA_OVERPOWERED` then
                        if not AnimpostfxIsRunning("PlayerOverpower") then AnimpostfxPlay("PlayerOverpower") end
                    end
                end

            end
        end)
    end

    -- Since we're handling EVENT_INVENTORY_ITEM_REMOVED, avoid losing the item twice
    itemBeingRemoved = item
    SatchelRemoveItem(item, 1)
end

function SatchelDropItem(item, quantity)
    SatchelRemoveItem(item, 1, false)

    local struct = DataView.ArrayBuffer(256)
    struct:SetInt32(8*3, -1)
    struct:SetInt32(8*12, 4)
    struct:SetInt32(8*17, 4)
    Citizen.InvokeNative(0x0C093C1787F18519, item, struct:Buffer()) --_INVENTORY_GET_INVENTORY_ITEM_INSPECTION_INFO

    local model = struct:GetInt32(8*0)

    if not IsModelValid(model) or quantity > 1 then
        model = `p_cs_lootsack02x`
    end

    if model ~= 0 then
        local coords = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 1.0, 0.0)

        RequestModel(model)

        while not HasModelLoaded(model) do
            RequestModel(model)
            Citizen.Wait(0)
        end

        local itemEntity = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)

        local netId = ObjToNet(itemEntity)
        SetNetworkIdExistsOnAllMachines(netId, true)
        PlaceObjectOnGroundProperly(itemEntity, true)
        SetEntityAsNoLongerNeeded(itemEntity)
        SetModelAsNoLongerNeeded(model)

        DecorSetInt(itemEntity, "item", item)
        DecorSetInt(itemEntity, "num", quantity)

        TriggerServerEvent("wild:satchel:cl_setItemPickable", netId)
    else
        ShowText("Could not drop item")
    end
end

RegisterNetEvent("wild:satchel:cl_setItemPickable", function(objNetId)
    local obj = NetToObj(objNetId)

    local timeOut = 10000
    while timeOut > 0 and not DecorExistOn(obj, "item") do
        Wait(50)
        timeOut = timeOut - 50
    end

    TaskCarriable(obj, `CARRIABLE_EGG_SMALL`, 0, 0, 512)
    SetPickupLight(obj, true)
end)

Citizen.CreateThread(function()
    while true do   
        Citizen.Wait(0)  

        if bIsInspecting then
            if IsControlJustPressed(0, `INPUT_GAME_MENU_CANCEL`) then
                ClearPedTasks(PlayerPedId())
                bIsInspecting = false
            end
        end

        if bSatchelOpen then
            if IsControlJustPressed(0, `INPUT_GAME_MENU_EXTRA_OPTION`) then
                SatchelInspectItem(lastSelectedItem)
            end

            if not bShopMode then
                if IsControlJustPressed(0, `INPUT_GAME_MENU_OPTION`) then
                    SatchelDropItem(lastSelectedItem, 1)
                end
            else
                if IsControlJustPressed(0, `INPUT_GAME_MENU_OPTION`) and UiPromptIsActive(promptDrop) then
                    -- sell all
                    local count = SatchelGetItemCount(lastSelectedItem)
                    TriggerEvent('wild:cl_onSell', lastSelectedItem, count)
                    SatchelRemoveItem(lastSelectedItem, count, true)
                end
            end
        end

        if IsControlJustPressed(0, `INPUT_OPEN_SATCHEL_MENU`) and not bOutfitLock then
            local prompt = 0

            -- Create prompt
            if prompt == 0 then
                prompt = PromptRegisterBegin()
                PromptSetControlAction(prompt, GetHashKey("INPUT_OPEN_SATCHEL_MENU")) -- L key
                PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", "Satchel"))
                UiPromptSetHoldMode(prompt, 100)
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
                        OpenSatchel()
                    end

                    PromptDelete(prompt)
                    prompt = 0

                    Citizen.Wait(1000)
                end)
            end
        end
    end
end)


-- Picking up objects in the world to place in satchel
AddEventHandler("EVENT_INVENTORY_ITEM_PICKED_UP", function(data)
    local inventoryItemHash = data[1]
    local entityPickedModel = data[2]
    local iItemWasUsed = data[3]
    local iItemWasBought = data[4]
    local entityPicked = data[5]

    SatchelAddItem(inventoryItemHash, 1)
end)


AddEventHandler("EVENT_INVENTORY_ITEM_REMOVED", function(data)
    print("native item removed...")
    local inventoryItemHash = data[1]

    if inventoryItemHash ~= itemBeingRemoved then
        SatchelRemoveItem(inventoryItemHash, 1)
    end
end)



-- Fired when the game wants information for a prompt. Use to set item names!
AddEventHandler("EVENT_ITEM_PROMPT_INFO_REQUEST", function(data)
    local entity = data[1]
    local inventoryItem = data[2]

    if entity ~= 0 then
        if not DoesEntityExist(entity) then
            return
        end

        local struct = DataView.ArrayBuffer(8*12)        
        struct:SetInt32(8*0, entity)
        struct:SetInt32(8*1, inventoryItem)
        struct:SetInt32(8*2, inventoryItem)
        struct:SetInt64(8*3, 0)
        struct:SetInt32(8*4, 0)
        struct:SetInt32(8*5, 0)
        struct:SetInt32(8*6, 1 | 2 | 16) -- enable prompt, just 3 also works
        
        -- Custom items
        if DecorExistOn(entity, "item") then
            inventoryItem = DecorGetInt(entity, "item")
            struct:SetInt32(8*1, inventoryItem)
            struct:SetInt32(8*2, inventoryItem)
            
            -- Custom prompt name for loot sack
            if GetEntityModel(entity) == `p_cs_lootsack02x` then
                struct:SetInt64(8*3, Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", "ui_loot_bag", Citizen.ResultAsLong()))
            end
        end
        
        
        Citizen.InvokeNative(0xFD41D1D4350F6413, struct:Buffer())
    end
end)

-- Triggers when skinning or looting peds
AddEventHandler("EVENT_LOOT_COMPLETE", function(data)    
	local playerPed = PlayerPedId()

	local looterPed = data[1]
	local ped = data[2]
	local success = data[3]

	if looterPed == playerPed and success == 1 then
		if GetMetaPedType(ped) == 3 then -- animal = 3

            local lootList = W.GetPedLoot(ped)

            for i=1, #lootList do
                local bSkip = false

                if InventoryGetInventoryItemIsAnimalPelt(lootList[i])==1 then
                    bSkip = true
                    if ItemdatabaseDoesItemHaveTag(lootList[i], 1422457563, 1120943070)==1 then -- small animal items seem to have this tag
                        bSkip = false
                    end
                end 
               
                if not bSkip then
                    SatchelAddItem(lootList[i], 1)
                else
                    -- At least show the toaster, just like in SP.
                    ShowInventoryToast(lootList[i], 1, true)
                end
            end
        elseif IsEntityAnObject(ped) then
            local obj = ped

            if DecorExistOn(obj, "item") then
                local inventoryItem = DecorGetInt(obj, "item")
                SatchelAddItem(inventoryItem, 1)
            end
            
		end
	end
end)

--[[

RegisterCommand('iguana', function() 
	local x, y, z = table.unpack(GetEntityCoords(GetPlayerPed(PlayerId()), false))

    local model = `A_C_Possum_01`

    RequestModel(model)

    while not HasModelLoaded(model) do
        RequestModel(model)
        Citizen.Wait(0)
    end

    local ped = CreatePed(model, x, y+1.0, z, 45.0, true, true, true)
    SetEntityInvincible(ped, true)
    SetPedKeepTask(ped)
    SetPedAsNoLongerNeeded(ped)
    SetRandomOutfitVariation(ped)

    SetEntityHealth(ped, 0)
end, false)
]]
RegisterCommand('deer', function() 
	local x, y, z = table.unpack(GetEntityCoords(GetPlayerPed(PlayerId()), false))

    local model = `A_C_deer_01`

    RequestModel(model)

    while not HasModelLoaded(model) do
        RequestModel(model)
        Citizen.Wait(0)
    end

    local ped = CreatePed(model, x, y+1.0, z, 45.0, true, true, true)
    SetEntityInvincible(ped, true)
    SetPedKeepTask(ped)
    SetPedAsNoLongerNeeded(ped)
    SetRandomOutfitVariation(ped)

    SetEntityHealth(ped, 0)
end, false)

--[[RegisterCommand('chocolate', function() 
	SatchelAddItem(`consumable_chocolate_bar`, 5)
end, false)]]
RegisterCommand('sleep', function() 
    TaskStartScenarioInPlaceHash(PlayerPedId(), `WORLD_PLAYER_SLEEP_GROUND`, -1, 1, ``, -1.0, 0)
end, false)


RegisterCommand('cleartasks', function() 
    ClearPedTasks(PlayerPedId())
end, false)

--
-- Ammo updates
-- Normally, bullets get removed from clip but not from native inventory. Here, we fix that.
--

local ammoUpdateTime = 0
local ammoUpdateWeapon = 0

local ammoUpdateQueue = {}

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if TimeSincePedLastShot(ped) < 0.025 then ------- Shot fired
            local weaponObj = GetCurrentPedWeaponEntityIndex(ped, 0)

            if DoesEntityExist(weaponObj) then
                local _, primaryWeaponHash = GetCurrentPedWeapon(ped, true, 0, false)
                local ammoType = GetCurrentPedWeaponAmmoType(ped, weaponObj)
                local ammoCount = GetPedAmmoByType(ped, ammoType)

                ammoUpdateQueue[ammoType] = ammoCount
            else
                -- Unmanaged thrown weapons.
                -- IsWeaponThrowable() == 1 then
                -- TODO: find associated ammo type for thrown weapon and update.
                -- Alternative solution: continuously monitor all ammo counts 
            end
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        for ammo, count in pairs(ammoUpdateQueue) do
            local countNow = SatchelGetItemCount(ammo)
            local nRemove = countNow-count

            if nRemove <= countNow and nRemove > 0 then
                -- Weird hacky way to sync ammo with inventory
                SatchelRemoveItem(ammo, nRemove)--, true, true)
                SatchelAddItem(ammo, nRemove)--, true, true)
            end

            ammoUpdateQueue[ammo] = nil
        end

        Wait(3210)
    end
end)