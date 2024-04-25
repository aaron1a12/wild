--
-- Newly Discovered Natives
--

-- Returns 1 or false depending if the ped's audio bank contains the specified speech line
-- Example: CanPlayAmbientSpeech(ped, "WHATS_YOUR_PROBLEM") = false when using as mary linton
-- IMPORTANT: Not reliable on remote clients when used on a player ped
function CanPlayAmbientSpeech(ped, soundName) -- ped:int, soundName:str
	return Citizen.InvokeNative(0x9D6DEC9791A4E501, ped, soundName, 0, 1)
end

-- Gets the hash for the currently playing speech line
function GetCurrentAmbientSpeech(ped) -- ped:int
	return Citizen.InvokeNative(0x4A98E228A936DBCC, ped)
end
	
-- Gets the hash for the last played speech line
function GetLastAmbientSpeech(ped) -- ped:int
	return Citizen.InvokeNative(0x6BFFB7C276866996, ped)
end

-- Seems to return horse ped when really close (facing, directly riding, etc)
function GetNearByHorse()
	return Citizen.InvokeNative(0x0501D52D24EA8934, 1, Citizen.ResultAsInteger())
end

-- Original code from https://github.com/femga/rdr3_discoveries/
function PlayAmbientSpeechFromEntity(entity_id, sound_ref_string, sound_name_string, speech_params_string, speech_line)
	local sound_name = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", sound_name_string,Citizen.ResultAsLong())
	local sound_ref  = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING",sound_ref_string,Citizen.ResultAsLong())
	local speech_params = GetHashKey(speech_params_string)
	
	local sound_name_BigInt =  DataView.ArrayBuffer(16) 
	sound_name_BigInt:SetInt64(0,sound_name)
	
	local sound_ref_BigInt =  DataView.ArrayBuffer(16)
	sound_ref_BigInt:SetInt64(0,sound_ref)
	
	local speech_params_BigInt = DataView.ArrayBuffer(16)
	speech_params_BigInt:SetInt64(0,speech_params)
	
	local struct = DataView.ArrayBuffer(128)
	struct:SetInt64(0, sound_name_BigInt:GetInt64(0)) -- speechName
	struct:SetInt64(8, sound_ref_BigInt:GetInt64(0)) -- voiceName
	struct:SetInt32(16, speech_line) -- variation
	struct:SetInt64(24, speech_params_BigInt:GetInt64(0)) -- speechParamHash
	struct:SetInt32(32, 0) -- listenerPed
	struct:SetInt32(40, 0) -- syncOverNetwork
	struct:SetInt32(48, 0) -- v7
	struct:SetInt32(56, 0) -- v8
	
	return Citizen.InvokeNative(0x8E04FEDD28D42462, entity_id, struct:Buffer());
end

--
---------------------------------------------------------------------------------------------
--

--
-- Helper functions
--

function PrintText(x, y, scale, center, text, r, g, b, a)
	local str = CreateVarString(10, "LITERAL_STRING", text)
	SetTextColor(r, g, b, a)
	BgSetTextColor(r, g, b, a)
	SetTextFontForCurrentCommand(0)
	SetTextDropshadow(2, 0, 0, 0, 200)
	SetTextScale(scale, scale)
	SetTextCentre(center)

	DisplayText(str, x, y)
end

function ShowText(text)
	Citizen.CreateThread(function()
		local timeLeft = 1.0
		
		while timeLeft > 0 do
			Citizen.Wait(0)
			PrintText(0.5, 0.9, 0.5, true, text, 255,255,255,255)
			
			timeLeft = timeLeft - GetFrameTime()
		end
	end)
end

--See for more: https://gist.github.com/nonameset/b338aab76bbaa0c4f879630a61d97122
function ShowHelpText(strMessage, durationMs)
	local str = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", strMessage, Citizen.ResultAsLong())
	
	local struct1 = DataView.ArrayBuffer(8*13)
	struct1:SetInt32(0, durationMs)
	
	local struct2 = DataView.ArrayBuffer(8*8)
	struct2:SetInt64(8*1, str)
	struct2:SetInt64(8*2, str)
	
	Citizen.InvokeNative(0x049D5C615BD38BAD, struct1:Buffer(), struct2:Buffer(), true)
end

function StringSplit(inputstr, delimiter)
	if delimiter == nil then
		delimiter = "%s"
	end
	local t={}
	for str in string.gmatch(inputstr, "([^"..delimiter.."]+)") do
			table.insert(t, str)
	end
	return t
end

function FormatMoney(fMoney)
	local strMoney = tostring(fMoney)
	local parts = StringSplit(strMoney, ".")
	local dollars = "0"
	local cents = "00"
	local retStr = ""

	if #parts > 1 then -- Have cents
		local part = parts[2]
		part = string.sub(part, 1, 2) -- truncate

		if #part == 1 then -- str length of 1
			cents = part .. "0" -- right pad zero
		else
			cents = part
		end
	end

	dollars = parts[1]
	local nDigits = #parts[1]
	local periodSize = 3

	local nPeriods = nDigits / periodSize
	local integerPart, fractionalPart = math.modf(nPeriods)
	nPeriods = integerPart

	local periodRemainder = math.fmod(nDigits, periodSize)

	local finalChars = {}
	local digitsProcessed = 0

	-- Iteract backwards
	for i = nDigits, 1, -1 do 
		local char = string.sub(dollars, i, i)
		table.insert(finalChars, char)
		digitsProcessed = digitsProcessed + 1

		local _, frac = math.modf(digitsProcessed/periodSize)
		if frac == 0.0 and periodRemainder > 0 then -- Time to add separator
			table.insert(finalChars, ',')
		end
	end

	finalChars = table.concat(finalChars, "")
	dollars = string.reverse(finalChars)
	
	return dollars .. "." .. cents
end

function ShowCashPickup(fAmount, durationMs)
	local strAmount = FormatMoney(fAmount)
	local str1 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", strAmount, Citizen.ResultAsLong())
	local str2 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", "ITEMTYPE_TEXTURES", Citizen.ResultAsLong())
	
	local charPtr0 =  DataView.ArrayBuffer(16) 
	charPtr0:SetInt64(0, str1)
	local charPtr1 =  DataView.ArrayBuffer(16) 
	charPtr1:SetInt64(0, str2)
	
	local struct1 = DataView.ArrayBuffer(128)
	struct1:SetInt32(8*0, durationMs) --duration
	struct1:SetInt64(8*1, 0) -- const char*
	struct1:SetInt64(8*2, 0) -- const char*
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
	struct2:SetInt32(8*3, `ITEMTYPE_CASH`) -- TRANSACTION_HONOR_BAD
	struct2:SetInt32(8*4, 0)
	struct2:SetInt32(8*5, `COLOR_PURE_WHITE`) --COLOR_GOLD
	struct2:SetInt32(8*6, 0) 
	struct2:SetInt32(8*7, 0) 

	--_UI_FEED_POST_SAMPLE_TOAST_RIGHT. Part of HUD_TOASTS, I believe
    	Citizen.InvokeNative(0xB249EBCB30DD88E0, struct1:Buffer(), struct2:Buffer(), 1)

	-- Could this prevent the above buffers from deleting before RAGE can use them?
	Citizen.Wait(durationMs)
end

function GetPedsInArea(coords, radius)
	local peds = {}
    
    for _, ped in ipairs(GetGamePool('CPed')) do
		local dist = GetDistanceBetweenCoords(coords, GetEntityCoords(ped), true)

		if dist < radius then
			table.insert(peds, ped)
		end
    end

    return peds
end

function GetClosestPedTo(entity, maxDist)
	local coords = GetEntityCoords(entity)
	local peds = GetPedsInArea(GetEntityCoords(entity), maxDist)
	local smallestDist = 99999999.0
	local candidate = 0

	for i = 1, #peds do 
		local dist = GetDistanceBetweenCoords(coords, GetEntityCoords(peds[i]), true)

		if dist < smallestDist and peds[i] ~= entity then
			candidate = peds[i]
		end
	end

	return candidate
end

function GetTableSize(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

function GetFirstInTable(t)
	for _, imap in pairs(all_imaps_list) do
	end
end

function DrawDebugSphere(vCenter, fRadius, iR, iG, iB, iAlpha)
	Citizen.InvokeNative(0x2A32FAA57B937173, 0x50638AB9, vCenter.x, vCenter.y, vCenter.z, 0, 0, 0, 0, 0, 0, fRadius, fRadius, fRadius, iR, iG, iB, iAlpha, 0, 0, 2, 0, 0, 0, 0)
end

--
-- Global WILD-UI Functions
-- These functions are available everywhere
--

local bWildUiReady = false

RegisterNetEvent("wild:cl_onUiPingBack")
AddEventHandler("wild:cl_onUiPingBack", function()
    bWildUiReady = true
end)

-- Ensures that the wild-ui resource has been loaded
function WildUIWaitUntilReady()
	if bWildUiReady then
		return
	else
		TriggerEvent('wild:cl_uiPing')

		while not bWildUiReady do
			Citizen.Wait(0)
		end
	end
end

-- Same as RegisterNUICallback
function WildUICallback(cbName, func)
	TriggerEvent('wild:cl_registerCallback', cbName, func)
end

-- Same as SendNUIMessage
function WildUI(messageObj)
	TriggerEvent('wild:cl_sendNuiMessage', messageObj)
end