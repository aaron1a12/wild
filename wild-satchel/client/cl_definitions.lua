-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

wildData = DatabindingGetDataContainerFromPath("wild")

itemCatalogUiData = json.decode(LoadResourceFile(GetCurrentResourceName(), "itemCatalogUiData.json"))
_customItemCatalog = json.decode(LoadResourceFile(GetCurrentResourceName(), "custom_items.json"))

customItemCatalog = {}

-- Replace all keys with hashed versions for runtime lookup
for key, value in pairs(_customItemCatalog) do
	customItemCatalog[GetHashKey(key)] = value

    -- This adds the key as the name of a built-in RDR2 string so we can access it during native prompts
    if not DoesTextLabelExist(key) then
        AddTextEntry(key, value.name)
    end
end

if not DoesTextLabelExist("ui_loot_bag") then
    AddTextEntry("ui_loot_bag", "Loot bag")
end

function IsStringNullOrEmpty(pStr)
    local ret = 0
    if pcall(function ()
        Citizen.InvokeNative(0x2CF12F9ACF18F048, pStr, Citizen.ResultAsInteger()) 
    end) then
        ret = 0
    else
        ret = 1
    end

    if ret == 1 then return true else return false end
end

function ReadString(pStr)
    Citizen.InvokeNative(0xDFFC15AA63D04AAB, pStr)
    return N_0xc59ab6a04333c502()
end

function GetItemUiData(item)
    local struct = DataView.ArrayBuffer(2048)
    struct:SetInt32(8*2, 5) 
    struct:SetInt32(8*18, 8) 

    Citizen.InvokeNative(0xB86F7CC2DC67AC60, item, struct:Buffer()) --_ITEMDATABASE_FILLOUT_UI_DATA

    local data =  {
        name = GetLocalizedStringFromHash(struct:GetInt32(0)),
        description = GetLocalizedStringFromHash(struct:GetInt32(8)),
        textureId = 0,
        textureDict = ""
    }

    local i=0
    while i < 5 do
        local offset = 24 + (i*8*3)
        
        if struct:GetUint8(offset) == 0 then
            break
        end
        if not IsStringNullOrEmpty(struct:GetInt64(offset)) then
            local texture = GetHashKey(ReadString(struct:GetInt64(offset)))
            local dict = ReadString(struct:GetInt64(offset + 8))
            local type = struct:GetInt32(offset + 16)

            if type == `inventory` then
                data.textureId = texture
                data.textureDict = dict
            end
        else
            break
        end

        i = i+1
    end

    return data
end

-- Prefers itemCatalogUiData.json for cached ui data rather than real-time.
function GetItemUiFallback(item)

    if customItemCatalog[item] then
        local customItemData = customItemCatalog[item]

        return {name=customItemData.name, description=customItemData.description, textureId=item, textureDict="inventory_items_tu"}
    end

	local catalogItem = itemCatalogUiData[item]

	if catalogItem ~= nil then
		return {name=catalogItem[1], description=catalogItem[2], textureId=catalogItem[3], textureDict=catalogItem[4]}
	else
		return GetItemUiData(item)
	end
end

function GetItemQuality(item)
    local ITEM_FLAG_LEGENDARY = (1 << 2)
    local ITEM_FLAG_QUALITY_RUINED = (1 << 27)
	local ITEM_FLAG_QUALITY_POOR = (1 << 28)
	local ITEM_FLAG_QUALITY_NORMAL = (1 << 29)
	local ITEM_FLAG_QUALITY_PRISTINE = (1 << 30)

    if InventoryIsInventoryItemFlagEnabled(item, ITEM_FLAG_QUALITY_POOR) then return 1 end
    if InventoryIsInventoryItemFlagEnabled(item, ITEM_FLAG_QUALITY_NORMAL) then return 2 end
    if InventoryIsInventoryItemFlagEnabled(item, ITEM_FLAG_QUALITY_PRISTINE) then return 3 end
    if InventoryIsInventoryItemFlagEnabled(item, ITEM_FLAG_LEGENDARY) then return 4 end
    if InventoryIsInventoryItemFlagEnabled(item, ITEM_FLAG_QUALITY_RUINED) then return 0 end
end

function ShowInventoryToast(item, quantity, bAdding)
	local itemUi = GetItemUiFallback(item)

    local str1 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", itemUi.name .. " (x"..tostring(quantity)..")", Citizen.ResultAsLong())
	local str2 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", itemUi.textureDict, Citizen.ResultAsLong())

	local soundSetStr = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", "Transaction_Feed_Sounds", Citizen.ResultAsLong())
    local soundNameStr = 0

    if not bAdding then
        soundNameStr = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", "Transaction_Negative", Citizen.ResultAsLong())
    else
        soundNameStr = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", "Transaction_Positive", Citizen.ResultAsLong())
    end
	
	local pStr1 =  DataView.ArrayBuffer(16) 
	pStr1:SetInt64(0, str1)

	local pStr2 =  DataView.ArrayBuffer(16) 
	pStr2:SetInt64(0, str2)

	local pSoundSetStr =  DataView.ArrayBuffer(16) 
	pSoundSetStr:SetInt64(0, soundSetStr)
	local pSoundNameStr =  DataView.ArrayBuffer(16) 
	pSoundNameStr:SetInt64(0, soundNameStr)
	
	local struct1 = DataView.ArrayBuffer(128)
	struct1:SetInt32(8*0, 1000) --duration
	struct1:SetInt64(8*1, pSoundSetStr:GetInt64(0)) -- const char*, Sound set, e.g., "Honor_Display_Sounds"
	struct1:SetInt64(8*2, pSoundNameStr:GetInt64(0)) -- const char*, Sound to play, e.g., "Honor_Decrease_Small"
	struct1:SetInt32(8*3, 0) --int
	struct1:SetInt32(8*4, 0) --int
	struct1:SetInt32(8*5, 0) --int
	struct1:SetInt64(8*6, 0) -- const char* 2ndSubtitle
	struct1:SetInt32(8*7, 0) --int
	struct1:SetInt32(8*8, 0) --int
	struct1:SetInt32(8*9, 0) --int
	struct1:SetInt32(8*10, 0) --int
	struct1:SetInt32(8*11, 0) --int
	struct1:SetInt32(8*12, 0) --int
	
	local struct2 = DataView.ArrayBuffer(128)
	struct2:SetInt32(8*0, 0) --unk0
	struct2:SetInt64(8*1, pStr1:GetInt64(0)) -- title
	struct2:SetInt64(8*2, pStr2:GetInt64(0)) -- subtitle
	struct2:SetInt32(8*3, itemUi.textureId) 
	struct2:SetInt32(8*4, 0)
	struct2:SetInt32(8*5, `COLOR_PURE_WHITE`) --COLOR_GOLD

    if not bAdding then
        struct2:SetInt32(8*5, `COLOR_GREYDARK`)
    end
	struct2:SetInt32(8*6, 0) 
	struct2:SetInt32(8*7, 0) 

    Citizen.InvokeNative(0xB249EBCB30DD88E0, struct1:Buffer(), struct2:Buffer(), 1)
end

function GetSatchelCarcassFromPed(ped)
    local item = 0
    local model = GetEntityModel(ped)

    if not animalCarcasses[model] then
        return 0
    end

    local damage = GetPedDamageCleanliness(ped)
    local rarity = GetAnimalRarity(ped)

    if rarity == 2 then -- legendary
        damage = 3
    end

    local carcass = animalCarcasses[model][damage+1]

    if not carcass then
        return 0
    end

    item = carcass

    local bSkinned = (IsEntityFullyLooted(ped)==1)

    if bSkinned then
        local skinnedCarcass = carcassSkinnedMapping[carcass]

        if skinnedCarcass then
            item = skinnedCarcass
        end
    end

    return item
end

local horseFood = {
    [`CONSUMABLE_HERB_COMMON_BULRUSH`] = 1,
    [`CONSUMABLE_HERB_OLEANDER_SAGE`] = 1,
    [`CONSUMABLE_HERB_PARASOL_MUSHROOM`] = 1,
    [`CONSUMABLE_HERB_HUMMINGBIRD_SAGE`] = 1,
    [`CONSUMABLE_HERB_BLACK_BERRY`] = 1,
    [`CONSUMABLE_OAT_CAKES`] = 1,
    [`CONSUMABLE_HERB_SAGE`] = 1,
    [`CONSUMABLE_CRAFTED_SUPER_MEAL`] = 1,
    [`CONSUMABLE_BEETS`] = 1,
    [`CONSUMABLE_HERB_EVERGREEN_HUCKLEBERRY`] = 1,
    [`CONSUMABLE_HERB_ENGLISH_MACE`] = 1,
    [`CONSUMABLE_HERB_BAY_BOLETE`] = 1,
    [`CONSUMABLE_PEPPERMINT`] = 1,
    [`CONSUMABLE_HERB_CHANTERELLES`] = 1,
    [`CONSUMABLE_CORN`] = 1,
    [`CONSUMABLE_HERB_RAMS_HEAD`] = 1,
    [`CONSUMABLE_SUGARCUBE`] = 1,
    [`CONSUMABLE_HERB_WINTERGREEN_BERRY`] = 1,
    [`CONSUMABLE_HERB_INDIAN_TOBACCO`] = 1,
    [`CONSUMABLE_HERB_YARROW`] = 1,
    [`CONSUMABLE_HERB_WILD_MINT`] = 1,
    [`CONSUMABLE_HERB_BURDOCK_ROOT`] = 1,
    [`CONSUMABLE_HERB_BLACK_CURRANT`] = 1,
    [`CONSUMABLE_HERB_AMERICAN_GINSENG`] = 1,
    [`CONSUMABLE_HERB_GOLDEN_CURRANT`] = 1,
    [`CONSUMABLE_HERB_VIOLET_SNOWDROP`] = 1,
    [`CONSUMABLE_HERB_RED_SAGE`] = 1,
    [`CONSUMABLE_HERB_MILKWEED`] = 1,
    [`CONSUMABLE_HERB_PRAIRIE_POPPY`] = 1,
    [`CONSUMABLE_PEACH`] = 1,
    [`CONSUMABLE_HERB_DESERT_SAGE`] = 1,
    [`CONSUMABLE_CARROT`] = 1,
    [`CONSUMABLE_HERB_OREGANO`] = 1,
    [`CONSUMABLE_HERB_RED_RASPBERRY`] = 1,
    [`CONSUMABLE_HERB_WILD_FEVERFEW`] = 1,
    [`CONSUMABLE_HERB_CURRANT`] = 1,
    [`CONSUMABLE_PEAR`] = 1,
    [`CONSUMABLE_HERB_WILD_CARROTS`] = 1,
    [`CONSUMABLE_HERB_GINSENG`] = 1,
    [`CONSUMABLE_HAYCUBE`] = 1,
    [`CONSUMABLE_APPLE`] = 1,
    [`CONSUMABLE_HERB_ALASKAN_GINSENG`] = 1,
    [`CONSUMABLE_CELERY`] = 1,
    [`CONSUMABLE_HERB_VANILLA_FLOWER`] = 1,
    [`CONSUMABLE_HERB_CREEPING_THYME`] = 1
}

function IsHorseFood(item)
    return (horseFood[item]==1)
end

function IsItemCustom(item)
    return (customItemCatalog[item])
end


function PukeNow()
    local animScene = CreateAnimScene("script@MPSTORY@MP_PoisonHerb@IG@IG1_CommonBullrush@IG1_CommonBullrush", 0, "Herb_PL", false, true)
    LoadAnimScene(animScene)

    Citizen.CreateThread(function()
        while IsAnimSceneLoaded(animScene, true, false) == 0 and IsAnimSceneMetadataLoaded(animScene, false) == 0 do
            Citizen.Wait(0)
        end
        
        if IsPedMale(PlayerPedId()) then
            SetAnimSceneEntity(animScene, "MP_Male", PlayerPedId(), 0)
        else
            SetAnimSceneEntity(animScene, "MP_Female", PlayerPedId(), 0)
        end
        
        StartAnimScene(animScene)
        
        Citizen.CreateThread(function()
            while IsAnimSceneRunning(animScene) == 1 do
                Citizen.Wait(0)
            end
        
            if IsPedMale(PlayerPedId()) then
                RemoveAnimSceneEntity(animScene, "MP_Male", PlayerPedId())
            else
                RemoveAnimSceneEntity(animScene, "MP_Female", PlayerPedId())
            end
        end)
    end)

    Citizen.Wait(2000)

    AddShockingEventForEntity(`EVENT_SHOCKING_BEAT_SURPRISING`, PlayerPedId(), 5.0, -1.0, -1.0, -1.0, -1.0, 180.0, false, false, -1, -1)
end


function ItemdatabaseGetTagOfType(item, tagType)
    local struct = DataView.ArrayBuffer(256)
    local pCount = DataView.ArrayBuffer(8)

	if Citizen.InvokeNative(0x5A11D6EEA17165B0, item, struct:Buffer(), pCount:Buffer(), 20) then   
        local count = pCount:GetInt32(0)
        for i=0, count-1 do
            if struct:GetInt32(16*i + 16) == tagType then
                return struct:GetInt32(16*i + 8)
            end
        end
    end
	return 0;
end

function ItemdatabaseGetEffectIds(item)
    local struct = DataView.ArrayBuffer(256) -- big enough for a lot of effects
    struct:SetInt32(8, 20)
    Citizen.InvokeNative(0x9379BE60DC55BBE6, item, struct:Buffer()) -- _ITEMDATABASE_FILLOUT_ITEM_EFFECT_IDS

    local effectIds = {}

    local count = struct:GetInt32(0)
    for i=0, count-1 do
        table.insert(effectIds, struct:GetInt32(16 + 8*i))
    end

    return effectIds
end

-- Ref: generic_single_use_item.c
function GetEffectTimeSeconds(fTime, iUnit)
    fTime = tonumber(fTime)/1.0

    if iUnit == 0 then
        return fTime * 0.033
    elseif iUnit == 1 then
        return fTime * 2.0
    elseif iUnit == 2 then
        return fTime * 120.0
    elseif iUnit == 3 then
        return fTime * 2880.0
    end

    return fTime
end

function ItemdatabaseGetEffect(effectId)
    local struct = DataView.ArrayBuffer(256)
    Citizen.InvokeNative(0xCF2D360D27FD1ABF, effectId, struct:Buffer()) -- ITEMDATABASE_FILLOUT_ITEM_EFFECT_ID_INFO

    local info = {}
    info.id = struct:GetInt32(0) -- f_0 | same as effectId
    info.type = struct:GetInt32(8) -- f_1 | effect kind hash. Example values: `EFFECT_HEALTH`, `EFFECT_HEALTH_CORE`, `EFFECT_HEALTH_CORE_GOLD`, `EFFECT_HEALTH_OVERPOWERED`
    info.value = struct:GetInt32(16) -- f_2 | converted into a float, usually divided by 1.0f or 2.0f. Possibly 2.0f when Arthur is sick
    info.time = struct:GetInt32(24) -- f_3 | converted into a float by scripts
    info.timeUnits = struct:GetInt32(32) -- f_4 | some enum, possible values: 0, 1, 2, 3
    info.corePercent = struct:GetFloat32(40) -- f_5 | confirmed float, usually 12.5 or 100.0
    info.durationcategory = struct:GetInt32(48) -- f_6 | category hash. effect_duration_category_none, effect_duration_category_1 through 4

    -- convenient to just do this here
    info.time = GetEffectTimeSeconds(info.time, info.timeUnits)
    return info
end


ePedAttribute = {
    ["PA_HEALTH"] = 0,
    ["PA_STAMINA"] = 1,
    ["PA_SPECIALABILITY"] = 2,
    ["PA_COURAGE"] = 3,
    ["PA_AGILITY"] = 4,
    ["PA_SPEED"] = 5,
    ["PA_ACCELERATION"] = 6,
    ["PA_BONDING"] = 7,
    ["SA_HUNGER"] = 8,
    ["SA_FATIGUED"] = 9,
    ["SA_INEBRIATED"] = 10,
    ["SA_POISONED"] = 11,
    ["SA_BODYHEAT"] = 12,
    ["SA_BODYWEIGHT"] = 13,
    ["SA_OVERFED"] = 14,
    ["SA_SICKNESS"] = 15,
    ["SA_DIRTINESS"] = 16,
    ["SA_DIRTINESSHAT"] = 17,
    ["MTR_STRENGTH"] = 18,
    ["MTR_GRIT"] = 19,
    ["MTR_INSTINCT"] = 20,
    ["PA_UNRULINESS"] = 21,
    ["SA_DIRTINESSSKIN"] = 22
}

local function RegisterDecorTypes()
	DecorRegister("item", 3);
    DecorRegister("num", 3);
end
RegisterDecorTypes()
