W.Config.Honor = json.decode(LoadResourceFile(GetCurrentResourceName(), "honor.json"))	

local RPGStatusIcons = 0
local honorIcon = 0

-- Our honor system ranges from -100 to 100 while RDR2's icon state ranges
-- from 1 to 16. This converts our floating-point honor level to a HUD icon state.
function CalcHonorState(fHonor)
	local fState = (fHonor + 100.0)*0.075
	local _, fractional = math.modf(fState)

	local iState = 0

	-- Rounding
	if fractional >= 0.5 then
		iState = math.ceil(fState)
	else
		iState = math.floor(fState)
	end

	iState = iState + 1

	return iState
end

function SetupHudHonor()
	Citizen.CreateThread(function()
		while W.PlayerData == nil do
			Citizen.Wait(0)
		end
		-- Get or create the data container for rpg status icons
		RPGStatusIcons = DatabindingGetDataContainerFromPath("RPGStatusIcons")
		if RPGStatusIcons == 0 then
			RPGStatusIcons = DatabindingAddDataContainerFromPath("", "RPGStatusIcons")
		end

		honorIcon = DatabindingAddDataContainer(RPGStatusIcons, "HonorIcon")
		DatabindingAddDataInt(honorIcon, "State", CalcHonorState(W.GetPlayerHonor()))
	end)
end
SetupHudHonor()

function W.GetPlayerHonor()
    RefreshPlayerData()
    return W.PlayerData["honor"]
end

function UpdateHudHonorLevel()
	if honorIcon ~= 0 then
		local oldState = DatabindingReadDataIntFromParent(honorIcon, "State")
		local newState = CalcHonorState(W.GetPlayerHonor())
		
		-- Show the change on screen when changing state. (big change)
		if newState ~= oldState then
			EnableHudContext(`HUD_CTX_HONOR_SHOW`)
			Citizen.Wait(1000)
			DatabindingWriteDataIntFromParent(honorIcon, "State", newState)
			Citizen.Wait(3000)
			DisableHudContext(`HUD_CTX_HONOR_SHOW`)
		else
			DatabindingWriteDataIntFromParent(honorIcon, "State", newState)
		end
	end
end

local lastToastTime = 0
local timeBetweenToastsMs = 60 * 1000

function W.AddPlayerHonor(fAmount)
	local oldHonor = W.PlayerData["honor"]
	local newHonor = oldHonor + fAmount;

	if newHonor > 100.0 then
		newHonor = 100.0
	elseif newHonor < -100.0 then
		newHonor = -100.0
	end

	W.PlayerData["honor"] = newHonor
	TriggerServerEvent("wild:sv_setPlayerKeyValue", GetPlayerName(PlayerId()), "honor", newHonor)

	--
	-- Feedback
	--

	local bBigChange = false

	-- Force-show toaster if the change in honor is big.
	if math.abs(newHonor-oldHonor) >= 5.0 then
		bBigChange = true
	end

	if honorIcon ~= 0 then
		local oldState = DatabindingReadDataIntFromParent(honorIcon, "State")
		local newState = CalcHonorState(newHonor)

		if newState ~= oldState then
			bBigChange = true
		end
	end
	
	-- Don't show toaster if recently shown
	if (GetGameTimer()-lastToastTime > timeBetweenToastsMs) or bBigChange then
		-- HUD Toaster

		local honorFx = "PlayerHonorLevelGood" 
		local honorSound = "Honor_Increase_Small"
		local honorTexture = "PLAYER_HONOR_CHANGE_POS"
		local honorType = `TRANSACTION_HONOR_GOOD`
		if bBigChange then
			honorSound = "Honor_Increase_Big"
		end

		if fAmount < 0.0 then
			honorFx = "PlayerHonorLevelBad"
			honorSound = "Honor_Decrease_Small"
			honorTexture = "PLAYER_HONOR_CHANGE_NEG"
			honorType = `TRANSACTION_HONOR_BAD`
			if bBigChange then
				honorSound = "Honor_Decrease_Big"
			end
		end

		if bBigChange then
			AnimpostfxPlay(honorFx)
		end

		local str1 = Citizen.InvokeNative(0xFA925AC00EB830B9, 2, honorTexture, Citizen.ResultAsLong())
		local str2 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", "ITEMTYPE_TEXTURES", Citizen.ResultAsLong())

		local str3 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", "Honor_Display_Sounds", Citizen.ResultAsLong())
		local str4 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", honorSound, Citizen.ResultAsLong())
		
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
		struct2:SetInt32(8*3, honorType) -- TRANSACTION_HONOR_BAD
		struct2:SetInt32(8*4, 0) -- play sound?
		struct2:SetInt32(8*5, `COLOR_PURE_WHITE`) --COLOR_GOLD
		struct2:SetInt32(8*6, 0) 
		struct2:SetInt32(8*7, 0) 

		--_UI_FEED_POST_SAMPLE_TOAST_RIGHT. Part of HUD_TOASTS, I believe
		Citizen.InvokeNative(0xB249EBCB30DD88E0, struct1:Buffer(), struct2:Buffer(), 1)	

		lastToastTime = GetGameTimer()
	end

	UpdateHudHonorLevel()
end