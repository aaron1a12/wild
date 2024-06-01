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

                local item = N_0x9c409bbc492cb5b1()
                local group = GetItemGroup(item)

                if group == `CONSUMABLE` then
                    --RemoveItemFromInventory(item, 1)
                    SatchelRemoveItem(item, 1)

                    Citizen.Wait(2000)

                    AddItemToInventory(`UPGRADE_STAMINA_TANK_1`, 1)

                    SetAttributePoints(PlayerPedId(), ePedAttribute.PA_HEALTH, GetMaxAttributePoints(PlayerPedId(), ePedAttribute.PA_HEALTH))
                    SetAttributePoints(PlayerPedId(), ePedAttribute.PA_STAMINA, GetMaxAttributePoints(PlayerPedId(), ePedAttribute.PA_STAMINA))
            
                    SetAttributeCoreValue(PlayerPedId(), 0, 200)
                    SetAttributeCoreValue(PlayerPedId(), 1, 200)
                    
                    SetEntityHealth(PlayerPedId(), 200, 0)
                    RestorePedStamina(PlayerPedId(), 200.0)
                    

            		local playerPed = PlayerPedId()
            		RequestAnimDict("mech_inventory@eating@canned_food@cylinder@d8-2_h10-5")
            		while not HasAnimDictLoaded("mech_inventory@eating@canned_food@cylinder@d8-2_h10-5") do
                		Wait(100)
            		end
            		TaskPlayAnim(playerPed, "mech_inventory@eating@canned_food@cylinder@d8-2_h10-5", "left_hand", 8.0, -8.0, -1, 1 << 4 | 1 << 3 | 1 << 16, 0.0, false, 0, false, "UpperBodyFixup_filter", false)
                end
        	end
	end
end)