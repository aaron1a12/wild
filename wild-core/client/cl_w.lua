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
local currentPageType = 0
local currentPage = ""

function W.UI.SetVisible(bVisible, bImmediately)
    W.UI.Message({cmd = "setVisibility", visible = bVisible, immediately = bImmediately})
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
function W.UI.CreateMenu(strMenuId, strMenuTitle, bCompact)
    SendNUIMessage({cmd = "createMenu", menuId = strMenuId, menuTitle = strMenuTitle, compact =  bCompact})
end

local promptMenuSelect = 0
local promptMenuBack = 0

-- Do not use this to open/close menus. Use for temporary cases
function W.UI.SetMenusVisibleAndActive(bEnable, bImmediately)
	if bEnable then
		if not bIsVisible then -- ui not visible
			W.UI.SetVisible(true)
		end

		-- RedM has a bug where if you focus the nui while running (or pressing any other control)
		-- the game never receives the key-up message and the player character will continue to run forever.
		-- A solution is to set control context to frontend (blocks movement input) and use SetMouseCursorActiveThisFrame().
		-- With SetNuiFocusKeepInput(), we'll use input from the game and only use SetNuiFocus() when entering text.

		prevCtrlCtx = GetCurrentControlContext(0)
		SetControlContext(0, `GameMenu`)
		SetNuiFocusKeepInput(true)

		UiPromptSetVisible(promptMenuSelect, true)
        UiPromptSetEnabled(promptMenuBack, true)

		Citizen.CreateThread(function()
			Citizen.Wait(1)
			SetNuiFocus(true)
		end)
	else
		if bIsVisible then -- ui visible
			W.UI.SetVisible(false, bImmediately)
		end

		SetNuiFocus(false)
		SetControlContext(0, prevCtrlCtx)

		UiPromptSetVisible(promptMenuSelect, false)
        UiPromptSetEnabled(promptMenuBack, false)
	end
end

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

    SendNUIMessage({cmd = "openMenu", menuId = strMenuId, open = bOpen})
	
	if bOpen then
		currentMenu = strMenuId

		promptMenuSelect = PromptRegisterBegin()
        PromptSetControlAction(promptMenuSelect, `INPUT_GAME_MENU_ACCEPT`)
        PromptSetText(promptMenuSelect, CreateVarString(10, "LITERAL_STRING", "Select"))
        PromptRegisterEnd(promptMenuSelect)

		promptMenuBack = PromptRegisterBegin()
        PromptSetControlAction(promptMenuBack, `INPUT_GAME_MENU_CANCEL`)
        PromptSetText(promptMenuBack, CreateVarString(10, "LITERAL_STRING", "Back"))
        PromptRegisterEnd(promptMenuBack)

		W.UI.SetMenusVisibleAndActive(true)

		Citizen.CreateThread(function()
			while currentMenu == strMenuId do
				SetGameplayCamGranularFocusThisFrame(1.0, 1, 0.0, 1, 0.9)
				DisableCinematicModeThisFrame()
				Citizen.Wait(0)
			end
			SetGameplayCamGranularFocusThisFrame(0.0, 1, 0.0, 1, 0.0)
		end)
	else
		TriggerEvent('wild:cl_onMenuClosing', currentMenu)

		currentMenu = ""

		SetNuiFocus(false)
		W.UI.SetMenusVisibleAndActive(false)
		--[[Citizen.Wait(400)

		SetControlContext(0, prevCtrlCtx)]]

		PromptDelete(promptMenuSelect)
		PromptDelete(promptMenuBack)
		promptMenuSelect = 0
		promptMenuBack = 0
	end


	if bOpen then
		PlaySound("HUD_PLAYER_MENU", "MENU_ENTER")
	else
		PlaySound("HUD_PLAYER_MENU", "MENU_CLOSE")
	end
end

function W.UI.GetActivePrompt()
	return promptMenuSelect
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

function W.UI.CreatePageFilterIcons(strMenuId, strPageId, arrIcons)
	local res = GetInvokingResource()

	for i=1, #arrIcons do
		arrIcons[i] = "https://cfx-nui-"..res.."/" .. arrIcons[i]
	end

	SendNUIMessage({cmd = "createPageFilterIcons", menuId = strMenuId, pageId = strPageId, icons = arrIcons})
end

function W.UI.SelectPageFilterIcon(strMenuId, strPageId, iIndex)	
	SendNUIMessage({cmd = "selectPageFilterIcon", menuId = strMenuId, pageId = strPageId, index = iIndex})
end

function W.UI.FeedbackFilter(bForward)	
	SendNUIMessage({cmd = "feedbackFilter", forward = bForward})
end

function W.UI.GoToPage(strMenuId, strPageId, bNoHistory)
	SendNUIMessage({cmd = "goToPage", menuId = strMenuId, pageId = strPageId, noHistory = bNoHistory})
	currentPage = strPageId
	TriggerEvent('wild:cl_onGoToPage', strMenuId, strPageId)
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

function W.UI.EmptyPage(strMenuId, strPageId)	
	SendNUIMessage({cmd = "emptyPage", menuId = strMenuId, pageId = strPageId})
end

function W.UI.SetMenuRootPage(strMenuId, strPageId)	
	SendNUIMessage({cmd = "setMenuRootPage", menuId = strMenuId, pageId = strPageId})
end

function W.UI.SetSwitchIndex(strMenuId, strPageId, strItemId, iIndex)
	strItemId = "menuItem"..strMenuId .. strItemId
	SendNUIMessage({cmd = "setSwitchIndex", menuId = strMenuId, pageId = strPageId, itemId = strItemId, index = iIndex})
end

function W.UI.IsMenuOpen(strMenuId)	
	return (currentMenu == strMenuId)
end

function W.UI.GetCurrentMenu()	
	return currentMenu
end

function W.UI.GetCurrentPage()	
	return currentPage
end

local pageItemActions = {}
local pageItemAltActions = {}
local pageItemAutoId = 0
local pageItems = {}

function W.UI.CreatePageItem(strMenuId, strPageId, strItemId, oExtraItemParams)
	if strItemId == 0 or strItemId == "" or strItemId == nil then
		strItemId = tostring(pageItemAutoId)
	end
	pageItemAutoId = pageItemAutoId + 1
	strItemId = "menuItem"..strMenuId .. strItemId

	pageItems[strItemId] = oExtraItemParams

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

	if oExtraItemParams.icon then
		oExtraItemParams.icon = "https://cfx-nui-"..GetInvokingResource().."/" .. oExtraItemParams.icon
	end

	SendNUIMessage({cmd = "createPageItem", menuId = strMenuId, pageId = strPageId, itemId = strItemId, extraItemParams = oExtraItemParams})
end


function W.UI.SetPageItemEndHtml(strMenuId, strPageId, strItemId, strHtml)
	strItemId = "menuItem"..strMenuId .. strItemId
	SendNUIMessage({cmd = "setPageItemEndHtml", menuId = strMenuId, pageId = strPageId, itemId = strItemId, html = strHtml})
end

function W.UI.DestroyPageItem(strMenuId, strPageId, strItemId)
	pageItemActions[strItemId] = nil
	pageItemAltActions[strItemId] = nil

	strItemId = "menuItem"..strMenuId .. strItemId
	pageItems[strItemId] = nil

	SendNUIMessage({cmd = "destroyPageItem", menuId = strMenuId, pageId = strPageId, itemId = strItemId})
	Citizen.Wait(0)
end


W.UI.RegisterCallback("onSelectPageItem", function(data, cb)
	local strBegin =  "menuItem"..data.menuId
	local itemId = string.sub(data.itemId, #strBegin+1, 99)
	currentPage = data.pageId

	TriggerEvent('wild:cl_onSelectPageItem', data.menuId, data.pageId, itemId)	
	
	--[[local params = pageItems[data.itemId]

	if params then
		if params.prompt then
			UiPromptSetText(promptMenuSelect, CreateVarString(10, "LITERAL_STRING", params.prompt))
		else
			UiPromptSetText(promptMenuSelect, CreateVarString(10, "LITERAL_STRING", "Select"))
		end


		if params.promptDisabled == true then
			UiPromptSetEnabled(promptMenuSelect, false)
		else
			UiPromptSetEnabled(promptMenuSelect, true)
		end		
	end]]
	
	cb('ok')
end)

W.UI.RegisterCallback("triggerSelectedItem", function(data, cb)

	local params = pageItems[data.itemId]

	if params ~= nil then

		if pageItemActions[data.itemId] ~= nil and UiPromptIsEnabled(promptMenuSelect) ~= 0 then
			if data.switchOption == nil then
				PlaySound("HUD_PLAYER_MENU", "SELECT")

				if not data.bAlt then
					pageItemActions[data.itemId]()
				elseif pageItemAltActions[data.itemId] ~= nil then
					pageItemAltActions[data.itemId]()
				end
			else
				pageItemActions[data.itemId](data.switchOption)
			end
		end
	end
	
	cb('ok')
end)

W.UI.RegisterCallback("closeAllMenus", function(data, cb)
	W.UI.OpenMenu(currentMenu, false)
	cb('ok')
end)

W.UI.RegisterCallback("playNavUpSound", function(data, cb)
	PlaySound("HUD_PLAYER_MENU", "NAV_UP")

	cb('ok')
end)

W.UI.RegisterCallback("playNavDownSound", function(data, cb)
	PlaySound("HUD_PLAYER_MENU", "NAV_DOWN")
	
	cb('ok')
end)

W.UI.RegisterCallback("playNavEnterSound", function(data, cb)
	PlaySound("HUD_PLAYER_MENU", "SELECT")

	cb('ok')
end)

W.UI.RegisterCallback("playNavBackSound", function(data, cb)
	PlaySound("HUD_PLAYER_MENU", "BACK")

	cb('ok')
end)


W.UI.RegisterCallback("onPageFinishedOpening", function(data, cb)
	currentPage = data.pageId
	currentPageType = data.pageType
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
				--HideHudAndRadarThisFrame()
				EnableHudContextThisFrame(`HUD_CTX_OUTDOOR_SHOP`)
				EnableHudContextThisFrame(`HUD_CTX_HACK_RADAR_FORCE_HIDE`)
				DisableFrontendThisFrame()
				SetMouseCursorActiveThisFrame(true)

				local bVertical = false

				if currentPageType == 1 then
					bVertical = true
				end

				if IsControlJustPressed(0, "INPUT_GAME_MENU_DOWN") then
					PlaySound("HUD_PLAYER_MENU", "NAV_DOWN")
					SendNUIMessage({cmd = "moveSelection", forward = true, vertical = bVertical})
				end

				if IsControlJustPressed(0, "INPUT_GAME_MENU_UP") then
					PlaySound("HUD_PLAYER_MENU", "NAV_UP")
					SendNUIMessage({cmd = "moveSelection", forward = false, vertical = bVertical})
				end

				if IsControlJustPressed(0, "INPUT_GAME_MENU_ACCEPT") then
					SendNUIMessage({cmd = "triggerSelectedItem"})
				end

				if IsControlJustPressed(0, "INPUT_GAME_MENU_OPTION") then
					SendNUIMessage({cmd = "triggerSelectedItemAlt"})
				end
				
				if IsControlJustPressed(0, "INPUT_GAME_MENU_LEFT") then
					if currentPageType == 0 then
						PlaySound("RDRO_Spectate_Sounds", "left_bumper")
						SendNUIMessage({cmd = "flipCurrentSwitch", forward = false})
					else
						PlaySound("HUD_PLAYER_MENU", "NAV_UP")
						SendNUIMessage({cmd = "moveSelection", forward = false})
					end
				end

				if IsControlJustPressed(0, "INPUT_GAME_MENU_RIGHT") then
					if currentPageType == 0 then
						PlaySound("RDRO_Spectate_Sounds", "right_bumper")
						SendNUIMessage({cmd = "flipCurrentSwitch", forward = true})
					else
						PlaySound("HUD_PLAYER_MENU", "NAV_DOWN")
						SendNUIMessage({cmd = "moveSelection", forward = true})
					end
				end

				if IsControlJustPressed(0, "INPUT_GAME_MENU_TAB_LEFT") then -- or IsControlJustPressed(0, "INPUT_QUIT")
					TriggerEvent('wild:cl_onMenuFilter', currentMenu, 0)
					PlaySound("RDRO_Spectate_Sounds", "left_bumper")
					W.UI.FeedbackFilter(false)
				end

				if IsControlJustPressed(0, "INPUT_GAME_MENU_TAB_RIGHT") then -- or IsControlJustPressed(0, "INPUT_QUIT")
					TriggerEvent('wild:cl_onMenuFilter', currentMenu, 1)
					PlaySound("RDRO_Spectate_Sounds", "left_bumper")
					W.UI.FeedbackFilter(true)
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

function W.GetPedLoot(ped)
	if not IsPedHuman(ped) then

		local damage = GetPedDamageCleanliness(ped)
		local quality = GetPedQuality(ped)

		if quality < 0 then
			quality = 2
		end
	
		local stars = quality+1
	
		if damage < 2 then
			stars = stars - (2-damage)
		end
	
		if stars < 1 then
			stars = 1
		end

		local lootTable = lootTableAnimal[GetEntityModel(ped)]

		-- Legendary?
		if lootTable[stars] == nil then
			stars = 3
		end

		return lootTable[stars]
	end

	return nil
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

--
-- Namespaced Exports For Resources
-- Allows you query the validity of a resource method before calling it.
--
-- Example:		if W.Satchel then
--					W.Satchel.Add("peanuts")
--				end
--
-- Important: you must handle 'wild:cl_onOutdated' event to refresh W once a new resource
-- registers. Also, if a resource ends, the registered functions will crash the Lua script until 
-- W refreshes, which could take a while. This scenario has been untested. Therefore, it is
-- probably not a good idea to use external resource calls in a loop, use DATABINDING for that.
--

local resourceNamespaces = {}
local outdatedTime = 0

function W.RegisterExport(namespace, name, method)
	if W[namespace] == nil then
		W[namespace] = {}

		local resource = GetInvokingResource()

		if resourceNamespaces[resource] == nil then
			resourceNamespaces[resource] = {}
		end

		table.insert(resourceNamespaces[resource], namespace)
	end

	W[namespace][name] = method

	-- The W object becomes outdated to other resources when modified.
	-- Notify them

	if GetGameTimer()-outdatedTime > 2000 then
		outdatedTime = GetGameTimer()

		Citizen.SetTimeout(2100, function()
			TriggerEvent('wild:cl_onOutdated')
		end)
	end
end

AddEventHandler('onResourceStop', function(resourceName)
	if resourceNamespaces[resourceName] == nil then
		return
	end

	for i=1, #resourceNamespaces[resourceName] do
		local namespace = resourceNamespaces[resourceName][i]

		W[namespace] = nil
	end

	TriggerEvent('wild:cl_onOutdated')
	collectgarbage("collect")
end)