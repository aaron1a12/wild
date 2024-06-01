-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

itemCatalogUiData = json.decode(LoadResourceFile(GetCurrentResourceName(), "itemCatalogUiData.json"))

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
	local catalogItem = itemCatalogUiData[tostring(item)]

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

function ShowInventoryToast(item, bAdding)
	local itemUi = GetItemUiFallback(item)

    local str1 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", itemUi.name, Citizen.ResultAsLong())
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
	struct2:SetInt32(8*6, 0) 
	struct2:SetInt32(8*7, 0) 

    Citizen.InvokeNative(0xB249EBCB30DD88E0, struct1:Buffer(), struct2:Buffer(), 1)
end