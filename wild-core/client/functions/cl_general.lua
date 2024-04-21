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
	SetTextColor(255, 255, 255, 255)
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