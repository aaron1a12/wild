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

W.Foo = 0

function W.GetFoo()
	return W.Foo
end

--
-- Configuration loading
--

W.Config = {}

local function LoadConfig()
    W.Config = json.decode(LoadResourceFile(GetCurrentResourceName(), "config.json"))	
end
LoadConfig()

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

function W.UI.OpenMenu(strMenuId, bOpen)
	if bMenuLock then
		return -- Opening too soon after closing, exit
	end

	if bOpen and currentMenu == strMenuId then
		return -- Reopening same menu, exit
	end

	if not bOpen and currentMenu == "" then
		return -- Closing menu that isn't open, ext
	end

	bMenuLock = true

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
		SetControlContext(0, `FrontendMenu`)
		SetNuiFocusKeepInput(true)

		--ClearPedTasksImmediately(PlayerPedId(), true, false)
		
		local camCoords = GetFinalRenderedCamCoord()
		local camRot = GetFinalRenderedCamRot()
		local camFov = GetFinalRenderedCamFov() - 5
	
		tempCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camCoords.x, camCoords.y, camCoords.z, camRot.x, camRot.y, camRot.z, camFov, false, 0)

		SetCamActive(tempCam, true)
		RenderScriptCams(true, true, 400, true, true, 0)

		Citizen.CreateThread(function()
			Citizen.Wait(1)
			SetNuiFocus(true)
			bMenuLock = false
		end)
	else
		currentMenu = ""

		SetNuiFocus(false)
		

		RenderScriptCams(false, true, 400, true, true, 0)
		SetPlayerControl(PlayerId(), true, 0, true)

		-- Release menu lock after fully blended out
		Citizen.CreateThread(function()
			Citizen.Wait(400)
			SetControlContext(0, prevCtrlCtx)
			SetCamActive(tempCam, false)
			DestroyCam(tempCam, true)
			bMenuLock = false
		end)
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

function W.UI.CreatePage(strMenuId, strPageId, iType, iDetailPanelSize)	
	SendNUIMessage({cmd = "createPage", menuId = strMenuId, pageId = strPageId, type = iType, detailPanelSize = iDetailPanelSize})
end

function W.UI.DestroyMenuAndData(strMenuId)	
	SendNUIMessage({cmd = "destroyMenuAndData", menuId = strMenuId})
end

function W.UI.SetMenuRootPage(strMenuId, strPageId)	
	SendNUIMessage({cmd = "setMenuRootPage", menuId = strMenuId, pageId = strPageId})
end

function W.UI.CreatePageItem(strMenuId, strPageId, strItemId, oExtraItemParams)
	SendNUIMessage({cmd = "createPageItem", menuId = strMenuId, pageId = strPageId, itemId = strItemId, extraItemParams = oExtraItemParams})
end

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

				if IsControlJustPressed(0, "INPUT_FRONTEND_NAV_DOWN") then
					local soundset_ref = "HUD_DOMINOS_SOUNDSET"
					local soundset_name =  "NAV_DOWN"
					Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
					Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);

					SendNUIMessage({cmd = "moveSelection", forward = true})
				end

				if IsControlJustPressed(0, "INPUT_FRONTEND_NAV_UP") then
					local soundset_ref = "HUD_DOMINOS_SOUNDSET"
					local soundset_name =  "NAV_UP"
					Citizen.InvokeNative(0x0F2A2175734926D8, soundset_name, soundset_ref); 
					Citizen.InvokeNative(0x67C540AA08E4A6F5, soundset_name, soundset_ref, true, 0);

					SendNUIMessage({cmd = "moveSelection", forward = false})
				end
			end
        end
        
        if IsControlJustPressed(0, "INPUT_REVEAL_HUD") then
            W.UI.SetVisible(true)
			
			-- TODO: Get current town (e.g., TOWN_BLACKWATER)
			ShowLocalInfo("Wild Server", "", 2000) 
        end

		if IsControlJustPressed(0, "INPUT_FRONTEND_CANCEL") then -- or IsControlJustPressed(0, "INPUT_QUIT")
			-- Close the open menu
			W.UI.OpenMenu(currentMenu, false)
        end
	end
end)


--
-- Prompt Management (garbage collection)
--
-- Got tired of having leftover prompts blocking everything

W.Prompts = {}

function W.Prompts.AddToGarbageCollector(promptId)
	local resourceName = GetInvokingResource()
	
	if W.Prompts[resourceName] == nil then
		W.Prompts[resourceName] = {}
	end

	table.insert(W.Prompts[resourceName], promptId)
end

-- The garbage collection
AddEventHandler('onResourceStop', function(resourceName)
	local resourcePrompts = W.Prompts[resourceName]

	if resourcePrompts == nil then
		return
	end

    -- Prompt cleanup when stopping resource
    for i = 1, #resourcePrompts do
        PromptDelete(resourcePrompts[i])
    end

	W.Prompts[resourceName] = {}
end)