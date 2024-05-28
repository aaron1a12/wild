function ShowInventoryToast(item)
    local catalogItem = itemCatalogSp[item]
    local str1 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", catalogItem[1], Citizen.ResultAsLong())
	local str2 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", catalogItem[3], Citizen.ResultAsLong())

	local soundSetStr = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", "Transaction_Feed_Sounds", Citizen.ResultAsLong())
	local soundNameStr = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", "Transaction_Positive", Citizen.ResultAsLong())
	
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
	struct2:SetInt32(8*3, catalogItem[2]) -- TRANSACTION_HONOR_BAD
	struct2:SetInt32(8*4, 0)
	struct2:SetInt32(8*5, `COLOR_PURE_WHITE`) --COLOR_GOLD
	struct2:SetInt32(8*6, 0) 
	struct2:SetInt32(8*7, 0) 

    Citizen.InvokeNative(0xB249EBCB30DD88E0, struct1:Buffer(), struct2:Buffer(), 1)
end