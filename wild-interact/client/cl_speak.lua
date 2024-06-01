-- ///////////////////////////////////////////////////////////////////////////////////////////////////
-- // cl_speak.lua
-- // Purpose: adds greet and antagonize prompts to peds
-- // TODO: Use SetAmbientVoiceName() when ped has no voice (mp_male, mp_female)
-- // TODO: Fix, 2nd antagonize is interrupted.
-- ///////////////////////////////////////////////////////////////////////////////////////////////////

W = exports["wild-core"]:Get()

--------------------
-- Begin prompt code
-- See https://gist.github.com/umaruru/1cdbfc302dda20d8c5601f0ce8f0e03c
--------------------
local greetPrompt = 0
local antagonizePrompt = 0

local function CreateUIPromptsForPed(ped)
	if greetPrompt ~= 0 or antagonizePrompt ~= 0 then
		return
	end

	local greetStr = CreateVarString(10, 'LITERAL_STRING', "Greet")
	local antagonizeStr = CreateVarString(10, 'LITERAL_STRING', "Antagonize")

	greetPrompt = PromptRegisterBegin()
	PromptSetControlAction(greetPrompt, 'INPUT_INTERACT_LOCKON_POS')
	PromptSetText(greetPrompt, greetStr)
	PromptRegisterEnd(greetPrompt)

	antagonizePrompt = PromptRegisterBegin()
	PromptSetControlAction(antagonizePrompt, 'INPUT_INTERACT_LOCKON_NEG')
	PromptSetText(antagonizePrompt, antagonizeStr)
	PromptRegisterEnd(antagonizePrompt)

	PromptSetPriority(greetPrompt, 3)
	PromptSetPriority(antagonizePrompt, 3)

	PromptSetEnabled(greetPrompt, true)
	PromptSetEnabled(antagonizePrompt, true)

	local group = PromptGetGroupIdForTargetEntity(ped)
	PromptSetGroup(greetPrompt, group, 0)
	PromptSetGroup(antagonizePrompt, group, 0)
end

local function DestroyUIPromptsForPed(ped)
	local group = PromptGetGroupIdForTargetEntity(ped)
	PromptRemoveGroup(greetPrompt, group)
	PromptRemoveGroup(antagonizePrompt, group)

	PromptDelete(greetPrompt)
	PromptDelete(antagonizePrompt)

	greetPrompt = 0
	antagonizePrompt = 0
end

AddEventHandler("onResourceStop", function(resource)
	if resource == "wild-interact" then
		-- Cleanup
		--DestroyUIPrompts()
	end
end)

------------------
-- End prompt code
-- //////////////////////////////////////////////////////////////////////////

local DECOR_IGNORING_PLAYER = "ignoring_player_"..tostring(PlayerId())
local DECOR_PLAYER_GREETED = "player_greeted_"..tostring(PlayerId())
local DECOR_PLAYER_CHAT_PROGRESS = "player_chat_progress"..tostring(PlayerId())
local DECOR_PLAYER_ANTAGONIZED = "player_antagonized"..tostring(PlayerId())
local DECOR_WAS_ANTAGONIZED = "was_antagonized"..tostring(PlayerId())

local function RegisterDecorTypes()
	DecorRegister(DECOR_IGNORING_PLAYER, 2);
	DecorRegister(DECOR_PLAYER_GREETED, 2);
	DecorRegister(DECOR_PLAYER_CHAT_PROGRESS, 3);
	DecorRegister(DECOR_PLAYER_ANTAGONIZED, 2);
	DecorRegister(DECOR_WAS_ANTAGONIZED, 2);
end
RegisterDecorTypes()

--TODO: In the future, to sync line variations we need a db like this populated.
local speech_variations = {
	[`cs_mrsadler`] = {
		["GREET_GENERAL_FAMILIAR"] = 2,
		["WHATS_YOUR_PROBLEM"] = 3,
	}
}

local function GetRandomGreetLine(sourcePed, targetPed)
	local pool = {}
	local line = ""

	if CanPlayAmbientSpeech(sourcePed, "GREET_GENERAL_FAMILIAR") then
		table.insert(pool, "GREET_GENERAL_FAMILIAR")
	end

	-- For Arthur peds
	if not CanPlayAmbientSpeech(sourcePed, "GREET_GENERAL_FAMILIAR") then
		if IsPedMale(targetPed) then
			table.insert(pool, "GREET_MALE")
		else
			table.insert(pool, "GREET_FEMALE")
		end
	end

	if CanPlayAmbientSpeech(sourcePed, "GREET_GENERAL_STRANGER")  then
		table.insert(pool, "GREET_GENERAL_STRANGER")
	end

	if CanPlayAmbientSpeech(sourcePed, "GREET_MALE") and IsPedMale(targetPed) then
		table.insert(pool, "GREET_MALE")
	end

	if CanPlayAmbientSpeech(sourcePed, "GREET_FEMALE") and not IsPedMale(targetPed) then
		table.insert(pool, "GREET_FEMALE")
	end

	if CanPlayAmbientSpeech(sourcePed, "HOWS_IT_GOING") then
		table.insert(pool, "HOWS_IT_GOING")
	end

	if GetClockHours() > 4 and GetClockHours() < 12 then
		if CanPlayAmbientSpeech(sourcePed, "GREET_MORNING") then
			table.insert(pool, "GREET_MORNING")
		end
	elseif GetClockHours() > 16 then
		if CanPlayAmbientSpeech(sourcePed, "GREET_EVENING") then
			table.insert(pool, "GREET_EVENING")
		end
	end

	-- Pick random
	if #pool > 0 then
		line = pool[math.random(#pool)]
	end

	-- Initiate a chat if already greeted
	if DecorExistOn(targetPed, DECOR_PLAYER_GREETED) and not DecorExistOn(targetPed, DECOR_PLAYER_CHAT_PROGRESS) then	
		local randomChat = GetRandomChatLine(sourcePed, targetPed)

		if randomChat ~= "NONE" then
			line = randomChat
			DecorSetInt(targetPed, DECOR_PLAYER_CHAT_PROGRESS, 0)
		end
	end
	
	if DecorExistOn(targetPed, DECOR_PLAYER_CHAT_PROGRESS) and DecorGetInt(targetPed, DECOR_PLAYER_CHAT_PROGRESS) == 1 then
		line = "GENERIC_GOODBYE"
		DecorSetInt(targetPed, DECOR_PLAYER_CHAT_PROGRESS, 2)
	end

	return line

	-- zero = random variation
	--local variation = 0

	-- To bad we don't have a native to figure out the ambient voice variations
	--if speech_variations[GetEntityModel(sourcePed)] ~= nil then
	--	local varCount = speech_variations[GetEntityModel(sourcePed)][line]	
	--	if varCount ~= nil then
	--		variation = math.random(1, varCount)
	--	end
	--end
end

local function GetRandomAntagonizeLine(sourcePed, targetPed)
	local pool = {}

	if CanPlayAmbientSpeech(sourcePed, "WHATS_YOUR_PROBLEM") then
		table.insert(pool, "WHATS_YOUR_PROBLEM")
	end

	if CanPlayAmbientSpeech(sourcePed, "INSULT_MALE_CONV_PART1") and IsPedMale(targetPed) then
		table.insert(pool, "INSULT_MALE_CONV_PART1")
	end

	if CanPlayAmbientSpeech(sourcePed, "INSULT_FEMALE_CONV_PART1") and not IsPedMale(targetPed) then
		table.insert(pool, "INSULT_FEMALE_CONV_PART1")
	end

	if CanPlayAmbientSpeech(sourcePed, "GENERIC_ANTISOCIAL_MALE_EVENT_COMMENT") then
		table.insert(pool, "GENERIC_ANTISOCIAL_MALE_EVENT_COMMENT")
	end

	if CanPlayAmbientSpeech(sourcePed, "GENERIC_INSULT_MED_NEUTRAL")  then
		table.insert(pool, "GENERIC_INSULT_MED_NEUTRAL")
	end

	if CanPlayAmbientSpeech(sourcePed, "GENERIC_INSULT_HIGH_NEUTRAL")  then
		table.insert(pool, "GENERIC_INSULT_HIGH_NEUTRAL")
	end

	if CanPlayAmbientSpeech(sourcePed, "GENERIC_MOCK") then
		table.insert(pool, "GENERIC_MOCK")
	end

	if CanPlayAmbientSpeech(sourcePed, "PROVOKE_GENERIC") then
		table.insert(pool, "PROVOKE_GENERIC")
	end

	if #pool > 0 then
		return pool[math.random(#pool)]
	else
		return "NONE"
	end
end

function GetRandomChatLine(ped, target)
	local pool = {}

	if CanPlayAmbientSpeech(ped, "CHAT_1907") then
		table.insert(pool, "CHAT_1907")
	end

	if CanPlayAmbientSpeech(ped, "CHAT_GOOD_WEATHER") then
		table.insert(pool, "CHAT_GOOD_WEATHER")
	end

	if CanPlayAmbientSpeech(ped, "CHAT_BAD_WEATHER") then
		table.insert(pool, "CHAT_BAD_WEATHER")
	end
	
	if CanPlayAmbientSpeech(ped, "CHAT_LOCAL_AREA") then
		table.insert(pool, "CHAT_LOCAL_AREA")
	end

	if CanPlayAmbientSpeech(ped, "CHAT_FLATTER") and (IsPedMale(target) ~= IsPedMale(ped)) then
		table.insert(pool, "CHAT_FLATTER")
	end

	if CanPlayAmbientSpeech(ped, "CHAT_STORY_MUD5") then
		table.insert(pool, "CHAT_STORY_MUD5")
	end

	if CanPlayAmbientSpeech(ped, "CHAT_STORY_WNT4") then
		table.insert(pool, "CHAT_STORY_WNT4")
	end

	if CanPlayAmbientSpeech(ped, "GOING_WELL") then
		table.insert(pool, "GOING_BADLY")
	end

	if CanPlayAmbientSpeech(ped, "GOING_BADLY") then
		table.insert(pool, "GOING_BADLY")
	end

	if CanPlayAmbientSpeech(ped, "COMMENT_WORKING_HARD") then
		table.insert(pool, "COMMENT_WORKING_HARD")
	end

	if #pool > 0 then
		return pool[math.random(#pool)]
	else
		return "NONE"
	end
end


local bIsFocusingOnPed = false
local focusedPed = 0

local bDisableEmoteWheel = true
local promptDisableTime = 0

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

		bIsFocusingOnPed = false
		
		-- When player is holding button to focus
		if IsPlayerFreeFocusing(PlayerId()) then
			
			-- Focused entity
			local _, entity = GetPlayerTargetEntity(PlayerId())

			if IsEntityAPed(entity) and IsPedHuman(entity) and not IsPedInCombat(GetPlayerPed(PlayerId()), entity)  then
				if not bIsFocusingOnPed then
					CreateUIPromptsForPed(entity)
				end
				bIsFocusingOnPed = true

				focusedPed = entity
								
				-- SET PLAYER PED AS "STRANGER" FOR INTERACTION
				if IsPedAPlayer(entity) then
					local name = "Stranger"

					if W.IsResourceRunning("wild-war") then
						local faction = exports["wild-war"]:GetPedFaction(entity)
						
						if faction then
							name = faction
						end
					end

					Citizen.InvokeNative(0x4A48B6E03BABB4AC, entity, name)
					Citizen.InvokeNative(0x19B14E04B009E28B, entity, name)
				end

				local playerPed = GetPlayerPed(PlayerId())

				if IsAmbientSpeechPlaying(playerPed) or IsScriptedSpeechPlaying(playerPed) then
					if UiPromptIsEnabled(greetPrompt) == 1 and promptDisableTime == 0 then
						promptDisableTime = GetGameTimer()
					end

					PromptSetEnabled(greetPrompt, false)
					PromptSetEnabled(antagonizePrompt, false)

					if GetGameTimer()-promptDisableTime > 4500 then -- Timeout. Enable prompt anyway.
						PromptSetEnabled(greetPrompt, true)
						PromptSetEnabled(antagonizePrompt, true)
					end
				else
					PromptSetEnabled(greetPrompt, true)
					PromptSetEnabled(antagonizePrompt, true)
					promptDisableTime = 0
				end

				-- R to greet, F to antagonize
				if IsControlJustPressed(0, 'INPUT_INTERACT_LOCKON_POS') or IsControlJustPressed(0, 'INPUT_INTERACT_LOCKON_NEG') then
					local bAntagonize = IsControlJustPressed(0, 'INPUT_INTERACT_LOCKON_NEG')
		
					local playerModel = GetEntityModel(playerPed)

					--[[if playerModel == -1481695040 then -- mp_female
						SetAmbientVoiceName(playerPed, "0863_A_F_M_CIV_POOR_WHITE_AVOID_01")
					end

					if playerModel == -171876066 then -- mp_male
						SetAmbientVoiceName(playerPed, "0819_A_M_M_VHTTHUG_01_WHITE_03")
					end]]

					local playerPed_net = PedToNet(playerPed)
					local targetPed_net = PedToNet(entity)

					local line = ""
					
					if not bAntagonize then
						line = GetRandomGreetLine(playerPed, entity)
					else
						line = GetRandomAntagonizeLine(playerPed, entity)
					end

					TriggerServerEvent('sv_speak', playerPed_net, targetPed_net, bAntagonize, GetGameTimer(), line)
				end
			end	

			-- Hide 'Show Info' since it doesn't work on MP
			ModifyPlayerUiPrompt(PlayerId(), 35, 0, 1)

			-- When leading, if you disable prompt type 7, there will be no option to stop leading
			-- We temporarily stop disabling from the moment the input is sent. We then wait until 
			-- the task for leading (8) stops running.
			if IsControlJustPressed(0, `INPUT_INTERACT_LEAD_ANIMAL`) and bDisableEmoteWheel then
				bDisableEmoteWheel = false

				Citizen.CreateThread(function()
					Citizen.Wait(10000)
					while not bDisableEmoteWheel do
						Citizen.Wait(0)
						if not GetIsTaskActive(playerPed, 8) then
							bDisableEmoteWheel = true
						end
					end
				end)
			end
		
			-- Hide Emote wheel 
			if not (IsEntityAPed(entity) and not IsPedHuman(entity)) then
				if bDisableEmoteWheel then
					PromptDisablePromptTypeThisFrame(7)
				end
			end
			
		end
		
		if not bIsFocusingOnPed and focusedPed ~= 0 then
			DestroyUIPromptsForPed(focusedPed)
			focusedPed = 0
		end
	end
end)

--
-- Networked events (triggered on every client)
--

RegisterNetEvent("cl_speak")
AddEventHandler("cl_speak", function(playerPed_net, targetPed_net, bAntagonize, seed, line)
	-- Theoretically, any random number generated right after should be the same on all clients
	math.randomseed(seed)

	-- Convert from network id to local
	local sourcePed = NetToPed(playerPed_net)
	local targetPed = NetToPed(targetPed_net)

	-- Fix for when not using OneSync
	if not DoesEntityExist(sourcePed) then
		return -- EXIT
	end

	if not DoesEntityExist(targetPed) then
		return -- EXIT
	end


	-- Speak
	--https://raw.githubusercontent.com/femga/rdr3_discoveries/a63669efcfea34915c53dbd29724a2a7103f822f/audio/audio_banks/audio_banks.lua
	--https://www.rdr2mods.com/wiki/speech/ambient-characters/0589_a_m_m_civ_white_13/

	PlayAmbientSpeechFromEntity(sourcePed, "", line, "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0) -- 0 = random variation (different per client)

	-- Disable auto greet for a while

	Citizen.CreateThread(function()
		local timeLeft = 10.0 -- in seconds
		
		while timeLeft > 0 do
			Citizen.Wait(0)
			Citizen.InvokeNative(0x9F9A829C6751F3C7, NetworkGetPlayerIndexFromPed(sourcePed), 31, 1) -- PLAYER_RESET_FLAG_DISABLE_AMBIENT_GREETS
			
			timeLeft = timeLeft - GetFrameTime()
		end
	end)

	while IsAmbientSpeechPlaying(sourcePed) or IsScriptedSpeechPlaying(sourcePed) do
		Citizen.Wait(0)
	end

	-- Affect honor
	if sourcePed == PlayerPedId() and not IsPedAPlayer(targetPed) and not DecorExistOn(targetPed, DECOR_IGNORING_PLAYER) then
		local amount = W.Config.Honor["onGreet"]

		if bAntagonize then
			amount = W.Config.Honor["onAntagonize"]
		end

		-- Honor change only if not in dispute
		if GetIsPedInDisputeWithPed(targetPed, sourcePed) == 0 then
			W.AddPlayerHonor(amount)
		end
	end

	if not bAntagonize then
		--
		-- Greet
		--

		if not IsPedAPlayer(targetPed) then -- NPC reaction

			if DecorExistOn(targetPed, DECOR_IGNORING_PLAYER) then
				if not DecorGetBool(targetPed, DECOR_IGNORING_PLAYER) then
					DecorSetBool(targetPed, DECOR_IGNORING_PLAYER, true)
					PlayAmbientSpeechFromEntity(targetPed, "", "IGNORING_YOU", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
				end
				return -- Exit
			end

			-- Saying hi after antagonizing?
			if DecorExistOn(targetPed, DECOR_PLAYER_ANTAGONIZED) then
				DecorSetBool(targetPed, DECOR_IGNORING_PLAYER, false)
				PlayAmbientSpeechFromEntity(targetPed, "", "PLAYER_ACTING_WEIRD", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
				return -- Exit
			end
			
			if not DecorExistOn(targetPed, DECOR_PLAYER_GREETED) then -- First hello

				PlayAmbientSpeechFromEntity(targetPed, "", "GREET_GENERAL_FAMILIAR", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
				DecorSetBool(targetPed, DECOR_PLAYER_GREETED, true)
			
			elseif DecorExistOn(targetPed, DECOR_PLAYER_CHAT_PROGRESS) and DecorGetInt(targetPed, DECOR_PLAYER_CHAT_PROGRESS) ~= 3 then -- IF CHAT INITIATED

				local chatProgress = DecorGetInt(targetPed, DECOR_PLAYER_CHAT_PROGRESS)

				if chatProgress == 0 then

					PlayAmbientSpeechFromEntity(targetPed, "", "RESPONSE_GENERIC", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
					DecorSetInt(targetPed, DECOR_PLAYER_CHAT_PROGRESS, 1)

				elseif chatProgress == 2 then

					PlayAmbientSpeechFromEntity(targetPed, "", "GENERIC_GOODBYE", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
					DecorSetInt(targetPed, DECOR_PLAYER_CHAT_PROGRESS, 3)

				end

			elseif not DecorExistOn(targetPed, DECOR_WAS_ANTAGONIZED) then -- Second Hello

				PlayAmbientSpeechFromEntity(targetPed, "", "GREET_AGAIN", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
				DecorSetBool(targetPed, DECOR_WAS_ANTAGONIZED, true)

			elseif DecorExistOn(targetPed, DECOR_WAS_ANTAGONIZED) then -- Third Hello

				PlayAmbientSpeechFromEntity(targetPed, "", "WHATS_YOUR_PROBLEM", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
				DecorSetBool(targetPed, DECOR_IGNORING_PLAYER, false)
			end
		end
	else
		--
		-- Antagonize
		--

		AddShockingEventForEntity(GetHashKey("EVENT_SHOCKING_MELEE_FIGHT"), sourcePed, 0.5, -1.0, -1.0, -1.0, -1.0, 180.0, false, false, -1, -1)

		if not IsPedAPlayer(targetPed) then -- NPC reaction
			
			if not DecorExistOn(targetPed, DECOR_PLAYER_ANTAGONIZED) then -- First antagonize

				DecorSetBool(targetPed, DECOR_PLAYER_ANTAGONIZED, true)
			
				-- Make the ped hate the player
				local _, ped_group = AddRelationshipGroup("insulted_ped")
				SetRelationshipBetweenGroups(5, ped_group, `PLAYER`)
				SetPedRelationshipGroupHash(targetPed, ped_group)	-- Make sure never to do this to a player ped		
				SetPedCombatMovement(targetPed, 3)

				-- TODO: Ped is not getting angry
				SetPedCombatAttributes(targetPed, 5, true) -- CA_ALWAYS_FIGHT
				SetPedCombatAttributes(targetPed, 21, true) -- CA_CAN_CHASE_TARGET_ON_FOOT
				SetPedCombatAttributes(targetPed, 46, false) -- CA_CAN_FIGHT_ARMED_PEDS_WHEN_NOT_ARMED
				SetPedCombatAttributes(targetPed, 50, true) -- CA_CAN_CHARGE
				SetPedCombatAttributes(targetPed, 54, false) -- CA_ALWAYS_EQUIP_BEST_WEAPON
				SetPedCombatAttributes(targetPed, 58, true) -- CA_DISABLE_FLEE_FROM_COMBAT
				SetPedCombatAttributes(targetPed, 93, true) -- CA_PREFER_MELEE
				SetPedCombatAttributes(targetPed, 114, false) -- CA_CAN_EXECUTE_TARGET
				SetPedCombatAttributes(targetPed, 125, true) -- CA_QUIT_WHEN_TARGET_FLEES_INTERACTION_FIGHT
				SetPedConfigFlag(targetPed, 249, true) -- BLOCK WEAPONSWITCH
				SetPedCombatStyleMod(targetPed, `MeleeApproach`, -1.0)
				SetPedCombatBehaviour(targetPed, -1972074710)

				Citizen.InvokeNative(0xA762C9D6CF165E0D, targetPed, "EmotionalState", "angry", 5000) 
				Citizen.InvokeNative(0xA762C9D6CF165E0D, targetPed, "MoodName", "MoodAgitated", 5000)
				Citizen.InvokeNative(0xCB9401F918CB0F75, targetPed, "IsCombat", true, 5000) 
				SetPedMotivation(targetPed, 3, 1.0, sourcePed)
						
				PlayAmbientSpeechFromEntity(targetPed, "", "GENERIC_INSULT_HIGH", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
				PlayAmbientSpeechFromEntity(targetPed, "", "GENERIC_INSULT_HIGH_NEUTRAL", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
				
				local x,y,z =  table.unpack(GetEntityCoords(sourcePed))
				TaskReact(targetPed, sourcePed, x, y, z, "DEFAULT_SHOCKED", 5.0, 10.0, 4)
				
				Citizen.Wait(3000)
		
				TaskWalkAway(targetPed, sourcePed)
		
				-- If after a moment, the player isn't looking, make the ped boast his win
				Citizen.Wait(2000)
		
				if not IsPlayerFreeFocusing( NetworkGetPlayerIndexFromPed(sourcePed) ) then
					PlayAmbientSpeechFromEntity(targetPed, "", "WON_DISPUTE_ESCALATED", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
				end			
			else -- Second antagonize
				PlayAmbientSpeechFromEntity(targetPed, "", "SICK_BASTARD", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)

				TaskCombatPed(targetPed, sourcePed, 0, 0)

				Citizen.Wait(1000)

				Citizen.CreateThread(function()
					while IsPedInCombat(targetPed) do
						
						Citizen.Wait(0)
						local _, weaponHash = GetCurrentPedWeapon(sourcePed, true, 	0, false)
						
						if weaponHash ~= `WEAPON_UNARMED` and weaponHash ~= `WEAPON_LASSO` then
							SetPedConfigFlag(targetPed, 249, false) -- ALLOW WEAPON SWITCHING
							break
						end
					end

					-- Give up, maybe player ran away
					if not IsPedInCombat(targetPed) and not IsPedDeadOrDying(targetPed) then
						PlayAmbientSpeechFromEntity(targetPed, "", "IGNORING_YOU", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
					end
				end)
			end
		end
		
	end

end)