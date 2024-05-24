local bQuickSelectOpen = false
local currentWheel = 0

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

        if IsControlJustPressed(0, `INPUT_OPEN_WHEEL_MENU`) then
            bQuickSelectOpen = true
			currentWheel = 0
        end

        if bQuickSelectOpen then
            if IsControlJustReleased(0, `INPUT_OPEN_WHEEL_MENU`) then
                bQuickSelectOpen = false
            end

            if IsControlPressed(0, `INPUT_OPEN_WHEEL_MENU`) then
                -- Fix for abilities menu glitch while in weapon wheel
                DisableControlAction(0, `INPUT_QUICK_SHORTCUT_ABILITIES_MENU`, false)
            else
                bQuickSelectOpen = false
                EnableControlAction(0, `INPUT_QUICK_SHORTCUT_ABILITIES_MENU`, false)
            end

            if IsControlJustReleased(0, `INPUT_SELECT_NEXT_WHEEL`) then
                currentWheel = currentWheel + 1

                local bNearPlayerHorse = (GetMountOwnedByPlayer(PlayerId())==GetNearByHorse() and GetNearByHorse()~=0)

                if currentWheel == 2 and not bNearPlayerHorse then
                    currentWheel = 0
                elseif currentWheel > 2 then
                    currentWheel = 0
                end
            end

            if currentWheel == 0 then
                if W.IsResourceRunning("wild-war") then

                    local faction = exports["wild-war"]:GetPedFaction(PlayerPedId())
                    
                    local name = "No faction"
                    if faction then
                        name = faction
                    end

                    local str = CreateVarString(10, "LITERAL_STRING", text)
                    SetTextColor(255, 255, 255, 255)
                    BgSetTextColor(255, 255, 255, 255)
                    SetTextFontForCurrentCommand(6)
                    SetTextDropshadow(2, 128, 128, 128, 255)
                    SetTextScale(0.7, 0.7)
                    SetTextCentre(true)
                
                    DisplayText(name, 0.85, 0.1)
                end
            end
        end
    end
end)
