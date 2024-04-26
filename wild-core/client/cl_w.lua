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

function W.UI.SetVisible(bVisible)
    W.UI.Message({type = "setVisibility", visible = bVisible})
    bIsVisible = bVisible

    if bVisible then
        timeVisible = 0 -- Reset counter
    end
end

function W.UI.IsVisible()
    return bIsVisible
end

function W.UI.SetMoneyAmount(fAmount)
    W.UI.Message({type = "setMoneyAmount", amount = fAmount})
end

function W.UI.Ping()
    SendNUIMessage({type = "ping"})
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
    SendNUIMessage({type = "createMenu", menuId = strMenuId, menuTitle = strMenuTitle})
end

function W.UI.OpenMenu(strMenuId, bOpen)
	if bOpen and currentMenu == strMenuId then
		return -- Reopening same menu, exit
	end

	if not bOpen and currentMenu == "" then
		return -- Closing menu that isn't open, ext
	end

	if not bIsVisible then -- ui not visible
		W.UI.SetVisible(true)
	end

    SendNUIMessage({type = "openMenu", menuId = strMenuId, open = bOpen})

	if bOpen then
		currentMenu = strMenuId
		--SetPlayerControl(PlayerId(), false, 0, true) -- Does not work, disables all frontend controls too\
		
		-- Zoom focus
		local forward = GetCamForward(10.0)
		SetGameplayCoordHint( forward.x,  forward.y, forward.z, -1, 2000, 2000, 0)

	else
		currentMenu = ""
		--SetPlayerControl(PlayerId(), true, 0, true)
		StopGameplayHint(true)
		StopCodeGameplayHint(true)
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
	SendNUIMessage({type = "setElementTextByClass", menuId = strMenuId, class = strClass, text = strText})
end

function W.UI.SetElementTextById(strMenuId, strId, strText)
	SendNUIMessage({type = "setElementTextById", menuId = strMenuId, id = strId, text = strText})
end

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
				
			end
        end
        
        if IsControlJustPressed(0, "INPUT_REVEAL_HUD") then
            W.UI.SetVisible(true)
        end

		if IsControlJustPressed(0, "INPUT_QUIT") then
			-- Close the open menu
			W.UI.OpenMenu(currentMenu, false)
        end
	end
end)
