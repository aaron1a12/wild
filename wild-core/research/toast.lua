function PlayLowHonor()
    AnimpostfxPlay("PlayerHonorLevelBad")

	local strAmount = FormatMoney(fAmount)
	local str1 = Citizen.InvokeNative(0xFA925AC00EB830B9, 2, "PLAYER_HONOR_CHANGE_NEG", Citizen.ResultAsLong())
	local str2 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", "ITEMTYPE_TEXTURES", Citizen.ResultAsLong())

    local str3 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", "Honor_Display_Sounds", Citizen.ResultAsLong())
    local str4 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", "Honor_Decrease_Small", Citizen.ResultAsLong())
	
	local charPtr0 =  DataView.ArrayBuffer(16) 
	charPtr0:SetInt64(0, str1)
	local charPtr1 =  DataView.ArrayBuffer(16) 
	charPtr1:SetInt64(0, str2)


    local charPtr2 =  DataView.ArrayBuffer(16) 
	charPtr2:SetInt64(0, str3)

    local charPtr3 =  DataView.ArrayBuffer(16) 
	charPtr3:SetInt64(0, str4)
	
	local struct1 = DataView.ArrayBuffer(128)
	struct1:SetInt32(8*0, 1000) --duration
	struct1:SetInt64(8*1, charPtr2:GetInt64(0)) -- const char*  -- Honor_Display_Sounds
	struct1:SetInt64(8*2, charPtr3:GetInt64(0)) -- const char*  -- "Honor_Decrease_Small"
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
	struct2:SetInt64(8*1, charPtr0:GetInt64(0)) -- title
	struct2:SetInt64(8*2, charPtr1:GetInt64(0)) -- subtitle
	struct2:SetInt32(8*3, `TRANSACTION_HONOR_BAD`) -- TRANSACTION_HONOR_BAD
	struct2:SetInt32(8*4, 0) -- play sound?
	struct2:SetInt32(8*5, `COLOR_PURE_WHITE`) --COLOR_GOLD
	struct2:SetInt32(8*6, 0) 
	struct2:SetInt32(8*7, 0) 

	--_UI_FEED_POST_SAMPLE_TOAST_RIGHT. Part of HUD_TOASTS, I believe
    Citizen.InvokeNative(0xB249EBCB30DD88E0, struct1:Buffer(), struct2:Buffer(), 1)
end