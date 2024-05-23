--
-- W is a global variable accessible everywhere in wild-core and through
-- `exports["wild-core"]:Get()` in every other resource.
--
-- Functions in W run in the wild-core resource. Therefore, if a function
-- interacts with any wild-core variable, it should be declared inside W
-- or use the exports obj to get W variables.
--
-- Example:		W.Money = 12.0
--
--				function W.GetMoney()
--					return W.Money
--				end
--
--				OR
--
--				function GetMoney()
--					return exports["wild-core"]:Get()["Money"]
--				end
--
-- Utility or helper functions do not need to interact with W.

W = {}

exports("Get", function()
    return W
end)

--
-- Configuration loading
--

W.Config = {}

local function LoadConfig()
    W.Config = json.decode(LoadResourceFile(GetCurrentResourceName(), "config.json"))	
end
LoadConfig()

--
--
-- Experimental Shared Databinding
-- ===============================
-- Currently, accessing non-local variables every tick is very performance draining on Lua.
-- RAGE engine supports a data binding framework for synchronizing information between the 
-- game scripts and its UI. Luckily for us, we are able to exploit this system for fast 
-- variable sharing between resources. Note that the information we store here, will persist
-- throughout the lifetime of the RedM game instance. 
--
-- Usage
-- =====
-- For maximum performance, do not use W.DataCont if in a separate resource.
-- Use DatabindingGetDataContainerFromPath("wild") and store the handle locally. Its value
-- will be the same as W.DataCont.
--
-- Example: local data = DatabindingGetDataContainerFromPath("wild")
-- 			local foo = DatabindingReadDataIntFromParent(data, "foo")
--

W.DataCont = 0

function SetupDataContainer()
	local cont = DatabindingGetDataContainerFromPath("wild")

	if cont == 0 then
		-- Create new data container for data binding...
		W.DataCont = DatabindingAddDataContainerFromPath("", "wild")
	else
		-- Fetch existing data container
		W.DataCont = cont
	end
end
SetupDataContainer()

--
-- Shared NUI Functionality
--

W.UI = {}

local timeVisible = 0
local bIsVisible = false
local currentMenu = ""
local tempCam = 0
local bMenuLock = false
local prevCtrlCtx = 0
local menuOpenTime = GetGameTimer()

function W.UI.SetVisible(bVisible)
    W.UI.Message({cmd = "setVisibility", visible = bVisible})
    bIsVisible = bVisible

    if bVisible then
        timeVisible = 0 -- Reset counter
    end
end

function W.UI.IsVisible()
    return bIsVisible
end

function W.UI.SetMoneyAmount(fAmount)
    W.UI.Message({cmd = "setMoneyAmount", amount = fAmount})
end

function W.UI.Ping()
    SendNUIMessage({cmd = "ping"})
end

-- Same as SendNUIMessage
function W.UI.Message(messageObj)
	SendNUIMessage(messageObj)
end

-- Same as RegisterNUICallback
function W.UI.RegisterCallback(cbName, func)
    RegisterNUICallback(cbName, func)
end

-- Create a ui app-style menu
function W.UI.CreateMenu(strMenuId, strMenuTitle)
    SendNUIMessage({cmd = "createMenu", menuId = strMenuId, menuTitle = strMenuTitle})
end

local promptMenuSelect = 0
local promptMenuBack = 0

function W.UI.OpenMenu(strMenuId, bOpen, bNoCam)
	local now = GetGameTimer()
	if now-menuOpenTime < 500 then
		return
	end

	if bOpen and currentMenu == strMenuId then
		return -- Reopening same menu, exit
	end

	if not bOpen and currentMenu == "" then
		return -- Closing menu that isn't open, ext
	end

	menuOpenTime = now

	if not bIsVisible then -- ui not visible
		W.UI.SetVisible(true)
	end

    SendNUIMessage({cmd = "openMenu", menuId = strMenuId, open = bOpen})
	
	if bOpen then
		currentMenu = strMenuId
		-- RedM has a bug where if you focus the nui while running (or pressing any other control)
		-- the game never receives the key-up message and the player character will continue to run forever.
		-- A solution is to set control context to frontend (blocks movement input) and use SetMouseCursorActiveThisFrame().
		-- With SetNuiFocusKeepInput(), we'll use input from the game and only use SetNuiFocus() when entering text.

		prevCtrlCtx = GetCurrentControlContext(0)
		SetControlContext(0, `GameMenu`)
		SetNuiFocusKeepInput(true)

		--ClearPedTasksImmediately(PlayerPedId(), true, false)
		
		if bNoCam == false or bNoCam == nil then
			local camCoords = GetFinalRenderedCamCoord()
			local camRot = GetFinalRenderedCamRot()
			local camFov = GetFinalRenderedCamFov() - 5
		
			tempCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camCoords.x, camCoords.y, camCoords.z, camRot.x, camRot.y, camRot.z, camFov, false, 0)

			SetCamActive(tempCam, true)
			RenderScriptCams(true, true, 400, true, true, 0)
		else
			tempCam = 0
		end

		Citizen.CreateThread(function()
			Citizen.Wait(1)
			SetNuiFocus(true)
		end)

		promptMenuSelect = PromptRegisterBegin()
        PromptSetControlAction(promptMenuSelect, `INPUT_GAME_MENU_ACCEPT`)
        PromptSetText(promptMenuSelect, CreateVarString(10, "LITERAL_STRING", "Select"))
        PromptRegisterEnd(promptMenuSelect)

		promptMenuBack = PromptRegisterBegin()
        PromptSetControlAction(promptMenuBack, `INPUT_GAME_MENU_CANCEL`)
        PromptSetText(promptMenuBack, CreateVarString(10, "LITERAL_STRING", "Back"))
        PromptRegisterEnd(promptMenuBack)

	else
		TriggerEvent('wild:cl_onMenuClosing', currentMenu)

		currentMenu = ""

		SetNuiFocus(false)
		
		if tempCam ~= 0 then
			RenderScriptCams(false, true, 400, true, true, 0)
			SetPlayerControl(PlayerId(), true, 0, true)
		end

		-- Release menu lock after fully blended out
		Citizen.CreateThread(function()
			Citizen.Wait(400)
			SetControlContext(0, prevCtrlCtx)
			if tempCam ~= 0 then
				SetCamActive(tempCam, false)
				DestroyCam(tempCam, true)
			end	
		end)

		PromptDelete(promptMenuSelect)
		PromptDelete(promptMenuBack)
		promptMenuSelect = 0
		promptMenuBack = 0
	end

	local soundset_ref = "Study_Sounds"
    local soundset_name =  "show_info"

	if not bOpen then
		soundset_name =  "hide_info"
	end

    Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
    Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);
end

function W.UI.IsAnyMenuOpen()
end

function W.UI.SetElementTextByClass(strMenuId, strClass, strText)
	SendNUIMessage({cmd = "setElementTextByClass", menuId = strMenuId, class = strClass, text = strText})
end

function W.UI.SetElementTextById(strMenuId, strId, strText)
	SendNUIMessage({cmd = "setElementTextById", menuId = strMenuId, id = strId, text = strText})
end

function W.UI.CreatePage(strMenuId, strPageId, strPageTitle, strPageSubtitle, iType, iDetailPanelSize)	
	SendNUIMessage({cmd = "createPage", menuId = strMenuId, pageId = strPageId, pageTitle = strPageTitle, pageSubtitle = strPageSubtitle, type = iType, detailPanelSize = iDetailPanelSize})
end

function W.UI.EditPage(strMenuId, strPageId, strPageTitle, strPageSubtitle)	
	SendNUIMessage({cmd = "editPage", menuId = strMenuId, pageId = strPageId, pageTitle = strPageTitle, pageSubtitle = strPageSubtitle})
end

function W.UI.GoToPage(strMenuId, strPageId, bNoHistory)	
	SendNUIMessage({cmd = "goToPage", menuId = strMenuId, pageId = strPageId, noHistory = bNoHistory})
end

function W.UI.GoBack()	
	SendNUIMessage({cmd = "goBack"})
	TriggerEvent('wild:cl_onMenuBack', currentMenu)
end

function W.UI.ClearHistory()	
	SendNUIMessage({cmd = "clearHistory"})
end

function W.UI.DestroyMenuAndData(strMenuId)	
	SendNUIMessage({cmd = "destroyMenuAndData", menuId = strMenuId})
end

function W.UI.DestroyPage(strMenuId, strPageId)	
	SendNUIMessage({cmd = "destroyPage", menuId = strMenuId, pageId = strPageId})
end

function W.UI.SetMenuRootPage(strMenuId, strPageId)	
	SendNUIMessage({cmd = "setMenuRootPage", menuId = strMenuId, pageId = strPageId})
end

function W.UI.SetSwitchIndex(strMenuId, strPageId, strItemId, iIndex)
	SendNUIMessage({cmd = "setSwitchIndex", menuId = strMenuId, pageId = strPageId, itemId = strItemId, index = iIndex})
end

function W.UI.IsMenuOpen(strMenuId)	
	return (currentMenu == strMenuId)
end

function W.UI.GetCurrentMenu()	
	return currentMenu
end

local pageItemActions = {}
local pageItemAltActions = {}
local pageItemAutoId = 0

function W.UI.CreatePageItem(strMenuId, strPageId, strItemId, oExtraItemParams)
	if strItemId == 0 or strItemId == "" or strItemId == nil then
		strItemId = tostring(pageItemAutoId)
	end

	pageItemAutoId = pageItemAutoId + 1

	if oExtraItemParams.action == nil then
		pageItemActions[strItemId] = function()
			ShowText("No action assigned")
		end
	else
		pageItemActions[strItemId] = oExtraItemParams.action
	end

	if oExtraItemParams.altAction ~= nil then
		pageItemAltActions[strItemId] = oExtraItemParams.altAction
	end

	SendNUIMessage({cmd = "createPageItem", menuId = strMenuId, pageId = strPageId, itemId = strItemId, extraItemParams = oExtraItemParams})
end


function W.UI.SetPageItemEndHtml(strMenuId, strPageId, strItemId, strHtml)
	SendNUIMessage({cmd = "setPageItemEndHtml", menuId = strMenuId, pageId = strPageId, itemId = strItemId, html = strHtml})
end

function W.UI.DestroyPageItem(strMenuId, strPageId, strItemId)
	pageItemActions[strItemId] = nil
	pageItemAltActions[strItemId] = nil

	SendNUIMessage({cmd = "destroyPageItem", menuId = strMenuId, pageId = strPageId, itemId = strItemId})
	Citizen.Wait(0)
end


W.UI.RegisterCallback("onSelectPageItem", function(data, cb)
	TriggerEvent('wild:cl_onSelectPageItem', data.menuId, data.itemId)	
	cb('ok')
end)

W.UI.RegisterCallback("triggerSelectedItem", function(data, cb)
	if pageItemActions[data.itemId] ~= nil then
		if data.switchOption == nil then
			if not data.bAlt then
				pageItemActions[data.itemId]()
			elseif pageItemAltActions[data.itemId] ~= nil then
				pageItemAltActions[data.itemId]()
			end
		else
			pageItemActions[data.itemId](data.switchOption)
		end
	end
	
	cb('ok')
end)

W.UI.RegisterCallback("closeAllMenus", function(data, cb)
	W.UI.OpenMenu(currentMenu, false)
	cb('ok')
end)

W.UI.RegisterCallback("playNavUpSound", function(data, cb)
	local soundset_ref = "HUD_DOMINOS_SOUNDSET"
	local soundset_name =  "NAV_UP"
	Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
	Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);

	cb('ok')
end)

W.UI.RegisterCallback("playNavDownSound", function(data, cb)
	local soundset_ref = "HUD_DOMINOS_SOUNDSET"
	local soundset_name =  "NAV_DOWN"
	Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
	Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);
	
	cb('ok')
end)

W.UI.RegisterCallback("playNavEnterSound", function(data, cb)
	local soundset_ref = "HUD_SHOP_SOUNDSET"
	local soundset_name =  "SELECT"
	Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
	Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);

	cb('ok')
end)

W.UI.RegisterCallback("playNavBackSound", function(data, cb)
	local soundset_ref = "HUD_SHOP_SOUNDSET"
	local soundset_name =  "BACK"
	Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
	Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);

	cb('ok')
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if bIsVisible then
		    timeVisible = timeVisible + GetFrameTime()

            if (timeVisible > 3.0 or IsPauseMenuActive()) and currentMenu == "" then
				-- Hide the UI
                W.UI.SetVisible(false)				
            end

			if currentMenu ~= "" and IsPauseMenuActive() then
				-- Close the open menu
				W.UI.OpenMenu(currentMenu, false)
			end

			if currentMenu ~= "" then
				HideHudAndRadarThisFrame()
				DisableFrontendThisFrame()
				SetMouseCursorActiveThisFrame(true)

				if IsControlJustPressed(0, "INPUT_GAME_MENU_DOWN") then
					local soundset_ref = "HUD_DOMINOS_SOUNDSET"
					local soundset_name =  "NAV_DOWN"
					Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
					Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);

					SendNUIMessage({cmd = "moveSelection", forward = true})
				end

				if IsControlJustPressed(0, "INPUT_GAME_MENU_UP") then
					local soundset_ref = "HUD_DOMINOS_SOUNDSET"
					local soundset_name =  "NAV_UP"
					Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
					Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);

					SendNUIMessage({cmd = "moveSelection", forward = false})
				end

				if IsControlJustPressed(0, "INPUT_GAME_MENU_ACCEPT") then
					local soundset_ref = "HUD_SHOP_SOUNDSET"
					local soundset_name =  "SELECT"
					Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
					Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);

					SendNUIMessage({cmd = "triggerSelectedItem"})
				end

				if IsControlJustPressed(0, "INPUT_GAME_MENU_OPTION") then
					SendNUIMessage({cmd = "triggerSelectedItemAlt"})
				end
				
				if IsControlJustPressed(0, "INPUT_GAME_MENU_LEFT") then
					PlaySound("RDRO_Spectate_Sounds", "left_bumper")
					SendNUIMessage({cmd = "flipCurrentSwitch", forward = false})
				end

				if IsControlJustPressed(0, "INPUT_GAME_MENU_RIGHT") then
					PlaySound("RDRO_Spectate_Sounds", "right_bumper")
					SendNUIMessage({cmd = "flipCurrentSwitch", forward = true})
				end

				if IsControlJustPressed(0, "INPUT_GAME_MENU_CANCEL") then -- or IsControlJustPressed(0, "INPUT_QUIT")
					W.UI.GoBack()
					--W.UI.OpenMenu(currentMenu, false)
				end
			end
        end
        
        if IsControlJustPressed(0, "INPUT_REVEAL_HUD") then
            W.UI.SetVisible(true)
			
			-- TODO: Get current town (e.g., TOWN_BLACKWATER)
			ShowLocalInfo("Wild Server", "", 2000) 
        end

	end
end)

AddEventHandler("wild:cl_onPlayerDeath", function()
	if currentMenu ~= "" then
		W.UI.GoBack()
		W.UI.OpenMenu(currentMenu, false)
	end
end)

--
-- Prompt Management (garbage collection)
--
-- Got tired of having leftover prompts blocking everything

W.Prompts = {}
W.Prompts.Pool = {}

function W.Prompts.AddToGarbageCollector(promptId)
	local resourceName = GetInvokingResource()

	if resourceName == nil then
		resourceName = GetCurrentResourceName()
	end
	
	if W.Prompts.Pool[resourceName] == nil then
		W.Prompts.Pool[resourceName] = {}
	end

	table.insert(W.Prompts.Pool[resourceName], promptId)
end

function W.Prompts.RemoveFromGarbageCollector(promptId)
	local resourceName = GetInvokingResource()

	if resourceName == nil then
		resourceName = GetCurrentResourceName()
	end
	
	local resourcePrompts = W.Prompts.Pool[resourceName]
	for i = 1, #resourcePrompts do
		if resourcePrompts[i] == promptId then
			table.remove(W.Prompts.Pool[resourceName], i)
			return
		end
	end
end


-- The garbage collection
AddEventHandler('onResourceStop', function(resourceName)
	local resourcePrompts = W.Prompts.Pool[resourceName]

	if resourceName ~= GetCurrentResourceName() then
		if resourcePrompts == nil then
			return
		end
	
		-- Prompt cleanup when stopping resource
		for i = 1, #resourcePrompts do
			PromptDelete(resourcePrompts[i])
		end
	
		W.Prompts.Pool[resourceName] = {}		
	else -- wild-core is stopping, clean everything

		for _, resourcePrompts in pairs(W.Prompts.Pool) do
			for i = 1, #resourcePrompts do
				PromptDelete(resourcePrompts[i])
			end
		end
		
	end
end)

local activeGroup = 0
W.ActiveGroup = 0

function W.Prompts.GetActiveGroup()
	return activeGroup
end

function W.Prompts.SetActiveGroup(group)
	activeGroup = group
end

--
-- Model lookup
--

local PedDB = json.decode(LoadResourceFile(GetCurrentResourceName(), "peds.json"))

function W.GetPedModelName(ped)
	local key = tostring(GetEntityModel(ped))

	local model = PedDB[key]

	if model ~= nil then
		return model[1]
	end

	return ""
end

--
-- Utility
--

RegisterNetEvent("wild:cl_onPlayAmbSpeech", function(pedNet, line)
	local ped = NetToPed(pedNet)
	PlayAmbientSpeechFromEntity(ped, "", line, "speech_params_force", 0)
end)

function W.PlayAmbientSpeech(ped, speech)
	TriggerServerEvent('wild:sv_playAmbSpeech', PedToNet(ped), speech)
end


local invisiblePlayers = {}
RegisterNetEvent("wild:cl_onSetPlayerVisible", function(player, bVisible)

	NetworkConcealPlayer(player, not bVisible)
	SetPlayerInvisibleLocally(player, not bVisible)

	if invisiblePlayers[player] ~= nil and not bVisible then
		return
	end

	if not bVisible then
		Citizen.CreateThread(function()
			invisiblePlayers[player] = 1

			while invisiblePlayers[player] ~= nil do
				Citizen.Wait(0)
				SetPlayerInvisibleLocally(player, true)
			end

			NetworkConcealPlayer(player, false)
			SetPlayerInvisibleLocally(player, false)
		end)
	else
		invisiblePlayers[player] = nil
	end
	
end)

function W.SetPlayerVisible(player, bVisible)
	TriggerServerEvent('wild:sv_setPlayerVisible', player, bVisible)
end

--
-- RedM provides no way to check if a resource is running.
-- This is a simple way to register resources to check if running later.
--

local startedResources = {}

function W.RegisterResource()
	local resourceName = GetInvokingResource()
	startedResources[resourceName] = true
end

function W.IsResourceRunning(resourceName)
	return (startedResources[resourceName]==true)
end

AddEventHandler('onResourceStop', function(resourceName)
	startedResources[resourceName] = nil
end)