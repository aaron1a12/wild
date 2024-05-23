local bWheelOpen = false
local prevCtrlCtx = 0
local wheelCam = 0
local lastCloseTime = 0
local selectedEmote = nil

function PlayEmote(emoteStr)
	local ped = PlayerPedId()
	local playbackMode = 0

	if IsPedOnFoot(ped) and GetEntitySpeed(ped) == 0.0 then
		playbackMode = 2 -- full body
	end

	Citizen.InvokeNative(0xB31A277C1AC7B7FF, ped, 3, playbackMode, GetHashKey(emoteStr), 1, 1, 0, 0, 0)

	if playbackMode == 2 then
		Citizen.CreateThread(function()
			while not IsControlJustPressed(0, `INPUT_MOVE_LR`) and not IsControlJustPressed(0, `INPUT_MOVE_UD`) and not IsControlJustPressed(0, `INPUT_MOVE_LEFT_ONLY`) and not IsControlJustPressed(0, `INPUT_MOVE_UP_ONLY`) do
				Citizen.Wait(0)
			end
			ClearPedTasks(ped, false, false)
		end)
	end
end

function OpenEmoteWheel()
	if bWheelOpen then
		return
	end

	bWheelOpen = true
	prevCtrlCtx = GetCurrentControlContext(0)
	SetControlContext(5, `UI_QUICK_SELECT_COMPACT_RADIAL_MENU`)

	AnimpostfxPlay("WheelHUDIn") 

	SetNuiFocusKeepInput(true)
	SetNuiFocus(true)
	SendNUIMessage({cmd = "setVisibility", visible = true})

	EnableHudContext(`HUD_CTX_INPUT_REVEAL_HUD`)
	DisplayRadar(true)
	SetRadarZoom(0)

	openTime = GetGameTimer()
	camZoom = 10.0
end

function CloseEmoteWheel()
	bWheelOpen = false
	SetNuiFocus(false)
	SendNUIMessage({cmd = "setVisibility", visible = false})

	lastCloseTime = GetGameTimer()

	if selectedEmote ~= nil then
		PlayEmote(selectedEmote)

		-- Reset wheel
		selectedEmote = nil	
	end

	-- Crossfade into WheelHUDOut? Better than AnimpostfxStop("WheelHUDIn")
	N_0x26dd2fb0a88cc412("WheelHUDIn", "WheelHUDOut", 0, 0)

	if prevCtrlCtx ~= 0 then
		SetControlContext(5, prevCtrlCtx)
	end

	DisableHudContext(`HUD_CTX_INPUT_REVEAL_HUD`)
end

RegisterNUICallback("closeWheel", function(data, cb)
	CloseEmoteWheel()
	cb('ok')
end)

RegisterNUICallback("onWheelSelect", function(data, cb)
	if data.emote then
		selectedEmote = data.emote
	else
		selectedEmote = nil
	end

	PrepareSoundset("PAUSE_MENU_SOUNDSET", false)
	local soundId = GetSoundId()  -- creates new sound id
	PlaySoundFrontendWithSoundId(soundId, "NAV_RIGHT",	 "PAUSE_MENU_SOUNDSET", true)

	Citizen.Wait(1000)
	StopSoundWithId(soundId)
	ReleaseSoundId(soundId)
	ReleaseSoundId("PAUSE_MENU_SOUNDSET")

	cb('ok')
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if IsControlJustPressed(0, `INPUT_SPECIAL_ABILITY`) and not bWheelOpen then
			if GetGameTimer()-lastCloseTime > 201 and not IsControlPressed(0, `INPUT_OPEN_WHEEL_MENU`) then
				OpenEmoteWheel()
			end
		end

		if bWheelOpen then
			
			SetMouseCursorActiveThisFrame(true)

			N_0x066167c63111d8cf(1.0, 1, 0.0, 1, 0.9)
			
			for i=0, 12 do
				PromptDisablePromptTypeThisFrame(i)
			end

			if IsControlJustPressed(0, `INPUT_OPEN_WHEEL_MENU`) then
				CloseEmoteWheel()
			end
		end
	end
end)