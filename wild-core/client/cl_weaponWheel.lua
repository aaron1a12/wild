local bQuickSelectOpen = false
local currentWheel = 0

DatabindingAddDataInt(W.DataCont, "last_quick_select_wheel", 0)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

        -- Fix for abilities menu glitch while in weapon wheel
        if IsUiappActiveByHash(`abilities`) then
            CloseUiappByHash(`abilities`)
        end

        if IsUiappRunning("hud_quick_select") then
            
            -- Hook into the message queue for the weapon wheel
            while EventsUiIsPending(`HUD_QUICK_SELECT`) do
                local msg = DataView.ArrayBuffer(8 * 4)
                msg:SetInt32(0, 0)
                msg:SetInt32(8, 0)
                msg:SetInt32(16, 0)
                msg:SetInt32(24, 0)
    
                if (Citizen.InvokeNative(0xE24E957294241444, `hud_quick_select`, msg:Buffer()) ~= 0) then -- EVENTS_UI_GET_MESSAGE                    
                    if msg:GetInt32(0) == `ITEM_FOCUSED` then
    
                        if msg:GetInt32(8) == 1 and msg:GetInt32(16) == 813560150 then
                            currentWheel = 0 -- Weapon wheel
                        end
    
                        if msg:GetInt32(8) == 2 and msg:GetInt32(16) == -414255251 then
                            currentWheel = 1 -- Item wheel
                        end
    
                        if msg:GetInt32(8) == 3 and msg:GetInt32(16) == -1472057397 then
                            currentWheel = 2 -- Horse wheel
                        end

                        DatabindingWriteDataIntFromParent(W.DataCont, "last_quick_select_wheel", currentWheel)
                    end
                else
                    Citizen.Wait(0)
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


--
-- Rank bar
--

AddEventHandler("wild:cl_onPlayerFirstSpawn", function()
    local mpRankBar = DatabindingGetDataContainerFromPath("mp_rank_bar")
    if mpRankBar == 0 then
        mpRankBar = DatabindingAddDataContainerFromPath("", "mp_rank_bar")
    end
    
    DatabindingAddDataString(mpRankBar, "rank_header_text", GetPlayerName(PlayerId()))
    DatabindingAddDataString(mpRankBar, "rank_text", "1")
    DatabindingAddDataFloat(mpRankBar, "xp_bar_minimum", 0.0)
    DatabindingAddDataFloat(mpRankBar, "xp_bar_maximum", 100.0)
    DatabindingAddDataFloat(mpRankBar, "xp_bar_value", 55.0)
end)