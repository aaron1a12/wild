-- Source: https://github.com/femga/rdr3_discoveries
--
-- Original credit:
--  BIG THNKS to gottfriedleibniz for this DataView in LUA
--  https://gist.github.com/gottfriedleibniz/8ff6e4f38f97dd43354a60f8494eedff

local _strblob = string.blob or function(length)
	return string.rep("\0", math.max(40 + 1, length))
end

DataView = {
	EndBig = ">",
	EndLittle = "<",
	Types = {
		Int8 = { code = "i1", size = 1 },
		Uint8 = { code = "I1", size = 1 },
		Int16 = { code = "i2", size = 2 },
		Uint16 = { code = "I2", size = 2 },
		Int32 = { code = "i4", size = 4 },
		Uint32 = { code = "I4", size = 4 },
		Int64 = { code = "i8", size = 8 },
		Uint64 = { code = "I8", size = 8 },

		LuaInt = { code = "j", size = 8 },
		UluaInt = { code = "J", size = 8 },
		LuaNum = { code = "n", size = 8},
		Float32 = { code = "f", size = 4 },
		Float64 = { code = "d", size = 8 },
		String = { code = "z", size = -1, },
	},

	FixedTypes = {
		String = { code = "c", size = -1, },
		Int = { code = "i", size = -1, },
		Uint = { code = "I", size = -1, },
	},
}
DataView.__index = DataView
local function _ib(o, l, t) return ((t.size < 0 and true) or (o + (t.size - 1) <= l)) end
local function _ef(big) return (big and DataView.EndBig) or DataView.EndLittle end
local SetFixed = nil
function DataView.ArrayBuffer(length)
	return setmetatable({
		offset = 1, length = length, blob = _strblob(length)
	}, DataView)
end
function DataView.Wrap(blob)
	return setmetatable({
		offset = 1, blob = blob, length = blob:len(),
	}, DataView)
end
function DataView:Buffer() return self.blob end
function DataView:ByteLength() return self.length end
function DataView:ByteOffset() return self.offset end
function DataView:SubView(offset)
	return setmetatable({
		offset = offset, blob = self.blob, length = self.length,
	}, DataView)
end
for label,datatype in pairs(DataView.Types) do
	DataView["Get" .. label] = function(self, offset, endian)
		local o = self.offset + offset
		if _ib(o, self.length, datatype) then
			local v,_ = string.unpack(_ef(endian) .. datatype.code, self.blob, o)
			return v
		end
		return nil
	end

	DataView["Set" .. label] = function(self, offset, value, endian)
		local o = self.offset + offset
		if _ib(o, self.length, datatype) then
			return SetFixed(self, o, value, _ef(endian) .. datatype.code)
		end
		return self
	end
	if datatype.size >= 0 and string.packsize(datatype.code) ~= datatype.size then
		local msg = "Pack size of %s (%d) does not match cached length: (%d)"
		error(msg:format(label, string.packsize(fmt[#fmt]), datatype.size))
		return nil
	end
end
for label,datatype in pairs(DataView.FixedTypes) do
	DataView["GetFixed" .. label] = function(self, offset, typelen, endian)
		local o = self.offset + offset
		if o + (typelen - 1) <= self.length then
			local code = _ef(endian) .. "c" .. tostring(typelen)
			local v,_ = string.unpack(code, self.blob, o)
			return v
		end
		return nil
	end
	DataView["SetFixed" .. label] = function(self, offset, typelen, value, endian)
		local o = self.offset + offset
		if o + (typelen - 1) <= self.length then
			local code = _ef(endian) .. "c" .. tostring(typelen)
			return SetFixed(self, o, value, code)
		end
		return self
	end
end

SetFixed = function(self, offset, value, code)
	local fmt = { }
	local values = { }
	if self.offset < offset then
		local size = offset - self.offset
		fmt[#fmt + 1] = "c" .. tostring(size)
		values[#values + 1] = self.blob:sub(self.offset, size)
	end
	fmt[#fmt + 1] = code
	values[#values + 1] = value
	local ps = string.packsize(fmt[#fmt])
	if (offset + ps) <= self.length then
		local newoff = offset + ps
		local size = self.length - newoff + 1

		fmt[#fmt + 1] = "c" .. tostring(size)
		values[#values + 1] = self.blob:sub(newoff, self.length)
	end
	self.blob = string.pack(table.concat(fmt, ""), table.unpack(values))
	self.length = self.blob:len()
	return self
end

DataStream = { }
DataStream.__index = DataStream

function DataStream.New(view)
	return setmetatable({ view = view, offset = 0, }, DataStream)
end

for label,datatype in pairs(DataView.Types) do
	DataStream[label] = function(self, endian, align)
		local o = self.offset + self.view.offset
		if not _ib(o, self.view.length, datatype) then
			return nil
		end
		local v,no = string.unpack(_ef(endian) .. datatype.code, self.view:Buffer(), o)
		if align then
			self.offset = self.offset + math.max(no - o, align)
		else
			self.offset = no - self.view.offset
		end
		return v
	end
end

-- End of DataView

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
	struct:SetInt32(40, 1) -- syncOverNetwork
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
	--Transaction_Feed_Sounds", "Transaction_Positive
	local strAmount = FormatMoney(fAmount)
	local str1 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", strAmount, Citizen.ResultAsLong())
	local str2 = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", "ITEMTYPE_TEXTURES", Citizen.ResultAsLong())

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
	struct1:SetInt32(8*0, durationMs) --duration
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

-- https://pastebin.com/h1YzycuR
local localInfoTimeLeft = -1.0
function ShowLocalInfo(strLocation, strCustomMessage, duration)	
	if localInfoTimeLeft <= -1.0 then
		Citizen.CreateThread(function()
			Citizen.Wait(200)
			while localInfoTimeLeft > -0.5 do
				Citizen.Wait(0)

				local str = CreateVarString(10, "LITERAL_STRING", text)
				SetTextColor(255, 255, 255, 255)
				BgSetTextColor(255, 255, 255, 255)
				SetTextFontForCurrentCommand(1)
				SetTextDropshadow(2, 128, 128, 128, 255)
				SetTextScale(0.7, 0.7)
				SetTextCentre(true)
			
				DisplayText(strLocation, 0.5, 0.05)

				localInfoTimeLeft = localInfoTimeLeft - GetFrameTime()
			end
			localInfoTimeLeft = -1.0
		end)
	else
		return
	end

	local struct1 = DataView.ArrayBuffer(128)
    struct1:SetInt32(0, duration);

	localInfoTimeLeft = duration / 1000

    local locationNameStr = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", "NONE", Citizen.ResultAsLong())
    local subtitleStr = 0

    if not strCustomMessage or strCustomMessage == "" or strCustomMessage == 0 then
        -- Time and temp

        local coords = GetEntityCoords(PlayerPedId())

        local hours = GetClockHours()
        local minutes = GetClockMinutes()
        local PM = "AM"

		if not ShouldUse_24HourClock() and hours == 0 then
			hours = 12
		end

        if not ShouldUse_24HourClock() and hours > 12 then
            hours = hours - 12
            PM = "PM"
        elseif ShouldUse_24HourClock() then
            PM = ""
        end

        local paddingMin = ""
        if minutes < 10 then
            paddingMin = "0"
        end

        local format = "TIME_AND_TEMP_C"
        local temperature = GetTemperatureAtCoords(coords)

        if not ShouldUseMetricTemperature() then
            format = "TIME_AND_TEMP_F"
            temperature = (temperature * (9/5)) + 32 -- convert to farenheit
        end

        local strHours = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", tostring(hours), Citizen.ResultAsLong())
        local strMinutes = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", paddingMin .. tostring(minutes) .. " ", Citizen.ResultAsLong())
        local strTemperature = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", tostring(math.floor(temperature)), Citizen.ResultAsLong())

        subtitleStr = Citizen.InvokeNative(0xFA925AC00EB830B9, 674, format, hours, strMinutes, PM, strTemperature, Citizen.ResultAsLong())        
    else
        subtitleStr = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", strCustomMessage, Citizen.ResultAsLong())
    end

    local pStr1 =  DataView.ArrayBuffer(16) 
	pStr1:SetInt64(0, locationNameStr)
    local pStr2 =  DataView.ArrayBuffer(16) 
	pStr2:SetInt64(0, subtitleStr)
   
    local struct2 = DataView.ArrayBuffer(128)
    struct2:SetInt64(0, 0);
    struct2:SetInt64(8, pStr1:GetInt64(0));
    struct2:SetInt64(16, pStr2:GetInt64(0));
    struct2:SetInt64(24, 0);
    struct2:SetInt64(32, 0);
    Citizen.InvokeNative(0xD05590C1AB38F068, struct1:Buffer(), struct2:Buffer(), 1, 1);	
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

function DrawDebugSphereTimed(vCenter, fRadius, iR, iG, iB, iAlpha, durationMs)
	Citizen.CreateThread(function()
		local timeLeft = durationMs/1000
		
		while timeLeft > 0 do
			Citizen.Wait(0)
			Citizen.InvokeNative(0x2A32FAA57B937173, 0x50638AB9, vCenter.x, vCenter.y, vCenter.z, 0, 0, 0, 0, 0, 0, fRadius, fRadius, fRadius, iR, iG, iB, iAlpha, 0, 0, 2, 0, 0, 0, 0)
			
			timeLeft = timeLeft - GetFrameTime()
		end
	end)
end

function RotateVectorYaw(vec, degrees)
    local radians = degrees * (math.pi/180)

    local x = vec.x * math.cos(radians) - vec.y * math.sin(radians);
    local y = vec.x * math.sin(radians) + vec.y * math.cos(radians);

    return vector3(x, y, vec.z)
end

function RotateVectorPitch(vec, degrees)
    local radians = degrees * (math.pi / 180)

    local x = vec.x
    local y = vec.y * math.cos(radians) - vec.z * math.sin(radians)
    local z = vec.y * math.sin(radians) + vec.z * math.cos(radians)

    return vector3(x, y, z)
end

function GetCamForward(dist)
    local camCoords = GetFinalRenderedCamCoord()
    local camRot = GetFinalRenderedCamRot(0)
    local pitch = camRot.x
    local yaw = camRot.z
    local v = vector3(0.0, 1.0, 0.0)

    v = RotateVectorPitch(v, pitch)
    v = RotateVectorYaw(v, yaw)
	v = v * dist
    v = v + camCoords
    return v
end

-- Fast vector dist. Avoids native invocation
function GetVectorDistSqr(a, b)
	local x = b.x-a.x
	local y = b.y-a.y
	local z = b.z-a.z

	return (x*x) + (y*y) + (z*z)
end

function GetVectorDist(a, b)
	return math.sqrt(GetVectorDistSqr(a, b));
end


function PlaySound(soundset_ref, soundset_name)
	local soundset_ref = soundset_ref
    local soundset_name =  soundset_name
    Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
    Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);
end

function DrawTextAtCoord(v)
    local s, sx, sy = GetScreenCoordFromWorldCoord(v.x, v.y, v.z)
    if (sx > 0 and sx < 1) and (sy > 0 and sy < 1) then
        local hudX, hudY = GetHudScreenPositionFromWorldPosition(v.x, v.y, v.z)
        PrintText(hudX, hudY, 0.3, true, tostring(hash), red, green, blue, 255)
    end
end