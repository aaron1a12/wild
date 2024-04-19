-- ///////////////////////////////////////////////////////////////////////////////////////////////////
-- // cl_speak.lua
-- // Purpose: adds greet and antagonize prompts to peds
-- // TODO: Use SetAmbientVoiceName() when ped has no voice (mp_male, mp_female)
-- ///////////////////////////////////////////////////////////////////////////////////////////////////

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

local function RegisterDecorTypes()
	DecorRegister("ignoring_player", 2);

	-- These names are actually the same ones used natively
	DecorRegister("player_greeted", 2);
	DecorRegister("player_chat_progress", 3);
	DecorRegister("player_antagonized", 2);
	DecorRegister("was_antagonized", 2);
end
RegisterDecorTypes()

--TODO: In the future, to sync line variations we need a db like this populated.
local speech_variations = {
	[`cs_mrsadler`] = {
		["GREET_GENERAL_FAMILIAR"] = 2,
		["WHATS_YOUR_PROBLEM"] = 3,
	}
}

local bIsFocusingOnPed = false
local focusedPed = 0

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
								
				-- SET PED AS "STRANGER" FOR INTERACTION
				Citizen.InvokeNative(0x4A48B6E03BABB4AC, entity, "Stranger")
				Citizen.InvokeNative(0x19B14E04B009E28B, entity, "Stranger")

				local playerPed = GetPlayerPed(PlayerId())

				if IsAmbientSpeechPlaying(playerPed) or IsScriptedSpeechPlaying(playerPed) then
					PromptSetEnabled(greetPrompt, false)
					PromptSetEnabled(antagonizePrompt, false)
				else
					PromptSetEnabled(greetPrompt, true)
					PromptSetEnabled(antagonizePrompt, true)
				end

				-- R to greet, F to antagonize
				if IsControlJustPressed(0, 'INPUT_INTERACT_LOCKON_POS') or IsControlJustPressed(0, 'INPUT_INTERACT_LOCKON_NEG') then
					local bAntagonize = IsControlJustPressed(0, 'INPUT_INTERACT_LOCKON_NEG')
		
					
					local playerPed_net = PedToNet(playerPed)
					local targetPed_net = PedToNet(entity)

					TriggerServerEvent('sv_speak', playerPed_net, targetPed_net, bAntagonize, GetGameTimer())
				end
			end	

			-- Hide 'Show Info' since it doesn't work on MP
			ModifyPlayerUiPrompt(PlayerId(), 35, 0, 1)
		
			-- Hide Emote wheel 
			if not (IsEntityAPed(entity) and not IsPedHuman(entity)) then
				PromptDisablePromptTypeThisFrame(7)
			end
			
		end
		
		if not bIsFocusingOnPed and focusedPed ~= 0 then
			DestroyUIPromptsForPed(focusedPed)
			focusedPed = 0
		end
	end
end)


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

--
-- Networked events (triggered on every client)
--

RegisterNetEvent("cl_speak")
AddEventHandler("cl_speak", function(playerPed_net, targetPed_net, bAntagonize, seed)
	-- Theoretically, any random number generated right after should be the same on all clients
	math.randomseed(seed)

	-- Convert from network id to local
	local sourcePed = NetToPed(playerPed_net)
	local targetPed = NetToPed(targetPed_net)
	
	-- Speak
	--https://raw.githubusercontent.com/femga/rdr3_discoveries/a63669efcfea34915c53dbd29724a2a7103f822f/audio/audio_banks/audio_banks.lua
	--https://www.rdr2mods.com/wiki/speech/ambient-characters/0589_a_m_m_civ_white_13/
	-- GENERIC_GOODBYE
	-- GENERIC_ANGRY_REACTION
	-- WHATS_YOUR_PROBLEM
	--PLAYER_INTERACT_POS_REPLY -- low support
	--PLAYER_LOOKING_WEIRD
	--PLAYER_ACTING_WEIRD
	--PLAYER_FOLLOWING
	--PLAYER_LOITERING
	--PLAYER_STARING
	--GREET_AGAIN
	--GREET_BLOODY
	--GREET_EVENING
	--GREET_FEMALE 
	--GREET_MALE
	--GREET_MORNING
	--GREET_SHOUTED
	--GREET_SICK
	--GREET_STRANGE_OUTFIT
	--GREET_GENERAL_FAMILIAR	
	--PROVOKE_GENERIC

	if not bAntagonize then
		--
		-- Greet
		--

		--TODO: gestures are not syncing ;-; 
		-- not working
		SetPedCanPlayAmbientAnims(sourcePed, false)
		SetPedCanPlayAmbientBaseAnims(sourcePed, false)
		SetPedCanPlayGestureAnims(sourcePed, 0, 0)

		local line = "GREET_GENERAL_FAMILIAR"

		-- For Arthur peds
		if not CanPlayAmbientSpeech(sourcePed, "GREET_GENERAL_FAMILIAR") then
			if IsPedMale(target) then
				line = "GREET_MALE"
			else
				line = "GREET_FEMALE"
			end
		end

		if CanPlayAmbientSpeech(sourcePed, "GREET_GENERAL_STRANGER") and math.random() < 0.5 then
			line = "GREET_GENERAL_STRANGER"
		end

		if CanPlayAmbientSpeech(sourcePed, "GREET_MALE") and math.random() < 0.5 and IsPedMale(targetPed) then
			line = "GREET_MALE"
		end

		if CanPlayAmbientSpeech(sourcePed, "GREET_FEMALE") and math.random() < 0.5 and not IsPedMale(targetPed) then
			line = "GREET_FEMALE"
		end

		if CanPlayAmbientSpeech(sourcePed, "HOWS_IT_GOING") and math.random() < 0.5 then
			line = "HOWS_IT_GOING"
		end

		if  math.random() < 0.5 then
			if GetClockHours() > 4 and GetClockHours() < 12 then
				if CanPlayAmbientSpeech(sourcePed, "GREET_MORNING") then
					line = "GREET_MORNING"
				end
			elseif GetClockHours() > 16 then
				if CanPlayAmbientSpeech(sourcePed, "GREET_EVENING") then
					line = "GREET_EVENING"
				end
			end
		end

		-- Randomly initiate a chat if already greeted
		if DecorExistOn(targetPed, "player_greeted") and not DecorExistOn(targetPed, "player_chat_progress") and math.random() < 0.5 then

			randomChat = GetRandomChatLine(sourcePed, targetPed)

			if randomChat ~= "NONE" then
				line = randomChat
				DecorSetInt(targetPed, "player_chat_progress", 0)
			end
		end

		if DecorExistOn(targetPed, "player_chat_progress") and DecorGetInt(targetPed, "player_chat_progress") == 1 then
			line = "GENERIC_GOODBYE"
			DecorSetInt(targetPed, "player_chat_progress", 2)
		end

		-- zero = random variation
		local variation = 0

		-- To bad we don't have a native to figure out the ambient voice variations
		if speech_variations[GetEntityModel(sourcePed)] ~= nil then
			local varCount = speech_variations[GetEntityModel(sourcePed)][line]
			
			if varCount ~= nil then
				variation = math.random(1, varCount)
			end
		end


		-- Speak
		PlayAmbientSpeechFromEntity(sourcePed, "", line, "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", variation)  --Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath | speech_params_force
		
		while IsAmbientSpeechPlaying(sourcePed) or IsScriptedSpeechPlaying(sourcePed) do
			Citizen.Wait(0)
		end

		if not IsPedAPlayer(targetPed) then -- NPC reaction

			if DecorExistOn(targetPed, "ignoring_player") then
				if not DecorGetBool(targetPed, "ignoring_player") then
					DecorSetBool(targetPed, "ignoring_player", true)
					PlayAmbientSpeechFromEntity(targetPed, "", "IGNORING_YOU", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
				end
				return -- Exit
			end

			-- Saying hi after antagonizing?
			if DecorExistOn(targetPed, "player_antagonized") then
				DecorSetBool(targetPed, "ignoring_player", false)
				PlayAmbientSpeechFromEntity(targetPed, "", "PLAYER_ACTING_WEIRD", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
				return -- Exit
			end
			
			if not DecorExistOn(targetPed, "player_greeted") then -- First hello

				PlayAmbientSpeechFromEntity(targetPed, "", "GREET_GENERAL_FAMILIAR", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
				DecorSetBool(targetPed, "player_greeted", true)
			
			elseif DecorExistOn(targetPed, "player_chat_progress") and DecorGetInt(targetPed, "player_chat_progress") ~= 3 then -- IF CHAT INITIATED

				local chatProgress = DecorGetInt(targetPed, "player_chat_progress")

				if chatProgress == 0 then

					PlayAmbientSpeechFromEntity(targetPed, "", "RESPONSE_GENERIC", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
					DecorSetInt(targetPed, "player_chat_progress", 1)

				elseif chatProgress == 2 then

					PlayAmbientSpeechFromEntity(targetPed, "", "GENERIC_GOODBYE", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
					DecorSetInt(targetPed, "player_chat_progress", 3)

				end

			elseif not DecorExistOn(targetPed, "was_antagonized") then -- Second Hello

				PlayAmbientSpeechFromEntity(targetPed, "", "GREET_AGAIN", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
				DecorSetBool(targetPed, "was_antagonized", true)

			elseif DecorExistOn(targetPed, "was_antagonized") then -- Third Hello

				PlayAmbientSpeechFromEntity(targetPed, "", "WHATS_YOUR_PROBLEM", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
				DecorSetBool(targetPed, "ignoring_player", false)
			end

		else -- Player reaction

			--PlayAmbientSpeechFromEntity(targetPed, "", "GREET_GENERAL_FAMILIAR", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
		end
	else
		--
		-- Antagonize
		--

		local line = "WHATS_YOUR_PROBLEM"

		if CanPlayAmbientSpeech(sourcePed, "INSULT_MALE_CONV_PART1") and math.random() > 0.0 then
			line = "INSULT_MALE_CONV_PART1"
		end

		if CanPlayAmbientSpeech(sourcePed, "GENERIC_ANTISOCIAL_MALE_EVENT_COMMENT") and math.random() < 0.2 then
			line = "GENERIC_ANTISOCIAL_MALE_EVENT_COMMENT"
		end

		if CanPlayAmbientSpeech(sourcePed, "GENERIC_INSULT_MED_NEUTRAL") and math.random() < 0.2 then
			line = "GENERIC_INSULT_MED_NEUTRAL"
		end

		if CanPlayAmbientSpeech(sourcePed, "GENERIC_INSULT_HIGH_NEUTRAL") and math.random() < 0.2 then
			line = "GENERIC_INSULT_HIGH_NEUTRAL"
		end

		if CanPlayAmbientSpeech(sourcePed, "GENERIC_MOCK") and math.random() < 0.2 then
			line = "GENERIC_MOCK"
		end

		-- Speak
		PlayAmbientSpeechFromEntity(sourcePed, "", line, "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
		
		while IsAmbientSpeechPlaying(sourcePed) or IsScriptedSpeechPlaying(sourcePed) do
			Citizen.Wait(0)
		end

		if not IsPedAPlayer(targetPed) then -- NPC reaction
			
			if not DecorExistOn(targetPed, "player_antagonized") then -- First antagonize

				DecorSetBool(targetPed, "player_antagonized", true)
				
				-- TODO: Ped is not getting angry
	
				SetPedConfigFlag(targetPed, 233, true) -- Config ped is enemy
				SetPedConfigFlag(targetPed, 20, true) -- PCF_KeepWeaponHolsteredUnlessFired
				
				Citizen.InvokeNative(0xA762C9D6CF165E0D, targetPed, "EmotionalState", "angry", 5000) 
				Citizen.InvokeNative(0xA762C9D6CF165E0D, targetPed, "MoodName", "MoodAgitated", 5000)
				Citizen.InvokeNative(0xCB9401F918CB0F75, targetPed, "IsCombat", true, 5000) 
				SetPedMotivation(targetPed, 2, 1.0, sourcePed)

				Citizen.InvokeNative(0x8ACC0506743A8A5C, targetPed, GetHashKey("InvestigatorChallenge"), 1, 5.0)
				SetPedCombatStyleMod(targetPed, GetHashKey("EnableSurpriseTackling"), -1.0)

				-- Make the ped hate the player
				local _, ped_group = AddRelationshipGroup("insulted_ped")
				SetRelationshipBetweenGroups(5, ped_group, `PLAYER`)
				SetPedRelationshipGroupHash(targetPed, ped_group)	-- Make sure never to do this to a player ped			
		
				AddShockingEventForEntity(GetHashKey("EVENT_SHOCKING_MELEE_FIGHT"), sourcePed, 0.5, -1.0, -1.0, -1.0, -1.0, 180.0, false, false, -1, -1)
				
				local x,y,z =  table.unpack(GetEntityCoords(sourcePed))
				TaskReact(targetPed, sourcePed, x, y, z, "DEFAULT_SHOCKED", 5.0, 10.0, 4)
		
				PlayAmbientSpeechFromEntity(targetPed, "", "GENERIC_INSULT_HIGH", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
				PlayAmbientSpeechFromEntity(targetPed, "", "GENERIC_INSULT_HIGH_NEUTRAL", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
		
				Citizen.Wait(3000)
		
				TaskWalkAway(targetPed, sourcePed)
		
				-- If after a moment, the player isn't looking, make the ped boast his win
				Citizen.Wait(2000)
		
				if not IsPlayerFreeFocusing( NetworkGetPlayerIndexFromPed(sourcePed) ) then
					PlayAmbientSpeechFromEntity(targetPed, "", "WON_DISPUTE_ESCALATED", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
					--ShowText("Give up")
				end			
			else -- Second antagonize
				PlayAmbientSpeechFromEntity(targetPed, "", "SICK_BASTARD", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)

				TaskCombatPed(targetPed, sourcePed, 0, 0)
				
				--ShowText("TaskCombatPed")
			end

		else -- Player reaction

			--PlayAmbientSpeechFromEntity(targetPed, "", "GENERIC_INSULT_HIGH", "Speech_Params_Beat_Shouted_Clear_AllowPlayAfterDeath", 0)
		end
		
	end

end)