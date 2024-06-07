-- Detect eating peaches


ePedAttribute = {
    ["PA_HEALTH"] = 0,
    ["PA_STAMINA"] = 1,
    ["PA_SPECIALABILITY"] = 2,
    ["PA_COURAGE"] = 3,
    ["PA_AGILITY"] = 4,
    ["PA_SPEED"] = 5,
    ["PA_ACCELERATION"] = 6,
    ["PA_BONDING"] = 7,
    ["SA_HUNGER"] = 8,
    ["SA_FATIGUED"] = 9,
    ["SA_INEBRIATED"] = 10,
    ["SA_POISONED"] = 11,
    ["SA_BODYHEAT"] = 12,
    ["SA_BODYWEIGHT"] = 13,
    ["SA_OVERFED"] = 14,
    ["SA_SICKNESS"] = 15,
    ["SA_DIRTINESS"] = 16,
    ["SA_DIRTINESSHAT"] = 17,
    ["MTR_STRENGTH"] = 18,
    ["MTR_GRIT"] = 19,
    ["MTR_INSTINCT"] = 20,
    ["PA_UNRULINESS"] = 21,
    ["SA_DIRTINESSSKIN"] = 22
}


Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

        if IsControlJustReleased(0, `INPUT_OPEN_WHEEL_MENU`) then
            local lastWheel = DatabindingReadDataIntFromParent(wildData, "last_quick_select_wheel")

            local item = N_0x9c409bbc492cb5b1()
            local group = GetItemGroup(item)

            if group == `CONSUMABLE` or group == `kit` then
                if lastWheel == 2 then
                    if item == `kit_horse_brush` then
                        TriggerEvent('REQUEST_BRUSH_HORSE')
                    else
                        TriggerEvent('REQUEST_FEED_HORSE', item)
                    end
                else
                    SatchelUseItem(item)
                end
            end
        end
	end
end)
