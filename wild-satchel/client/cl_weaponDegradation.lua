local damageRate = 0.005
Citizen.CreateThread(function()
    local function clamp(n, min, max)
        if n > max then
            return max
        elseif n < min then
            return min
        else
            return n
        end
    end

	while true do
		Citizen.Wait(1616)

        local weaponObj = GetCurrentPedWeaponEntityIndex(PlayerPedId(), 0)

        if DoesEntityExist(weaponObj) then
            local degradation = GetWeaponDegradation(weaponObj)
            local damage = GetWeaponDamage(weaponObj)
            local dirt = GetWeaponDirt(weaponObj)
            local soot = GetWeaponSoot(weaponObj)

            degradation = clamp(degradation+damageRate, 0.0, 1.0)
            damage = clamp(damage+damageRate, 0.0, 1.0)
            dirt = clamp(dirt+damageRate, 0.0, 1.0)
            soot = clamp(soot+damageRate, 0.0, 1.0)

            SetWeaponDegradation(weaponObj, degradation)
            SetWeaponDamage(weaponObj, damage, false)
            SetWeaponDirt(weaponObj, dirt, false)
            SetWeaponSoot(weaponObj, soot, false)
        end

    end
end)

local lastSelectedItem = 0
local itemInspectionData = 0
local inventoryDataEntry = 0

local flowblock = DataView.ArrayBuffer(8 * 136)
local itemLabel = 0

function UpdateGunOilPrompt()
    local nGunOil = InventoryGetInventoryItemCountWithItemid(1, `kit_gun_oil`, false)

    if nGunOil > 0 then
        SetPedBlackboardBool(PlayerPedId(), "GENERIC_WEAPON_CLEAN_PROMPT_AVAILABLE", true, -1)
    else
        SetPedBlackboardBool(PlayerPedId(), "GENERIC_WEAPON_CLEAN_PROMPT_AVAILABLE", false, -1)
    end
end

local function UpdateStats()
	local _, weapon = GetCurrentPedWeapon(PlayerPedId(), true, 0, false);
    local itemGuid = GetInventoryItemGuid(weapon, GetWeaponInventoryGuid(), `SLOTID_WEAPON_0`)

    Citizen.InvokeNative(0x951847CEF3D829FF, inventoryDataEntry, itemGuid, PlayerPedId())

    DatabindingWriteDataHashString(itemLabel, GetHashKey( GetWeaponNameWithPermanentDegradation(lastSelectedItem, 1.0) ))
end

Citizen.CreateThread(function()

    AddItemToInventory(`kit_gun_oil`, 3)


	while true do
		Citizen.Wait(0)

        if IsUiappRunning("hud_quick_select") then
            lastSelectedItem = N_0x9c409bbc492cb5b1()
        end

        local playerPed = PlayerPedId()
        
        -- ref: generic_weapon_item.c
        if IsControlJustPressed(0, `INPUT_QUICK_SELECT_INSPECT`) then
            local itemGuid = GetInventoryItemGuid(lastSelectedItem, GetWeaponInventoryGuid(), `SLOTID_WEAPON_0`)  -- how do we know it's in slot id 0?

            if InventoryIsGuidValid(itemGuid) then
                Citizen.InvokeNative(0xD61D5E1AD9876DEB, playerPed, lastSelectedItem, itemGuid, 0, 0, 0, -1082130432)

                -- Wait until weapon is at entity 0. There should be a better way to do this.
                Citizen.Wait(400)
                
                local weaponObj = GetCurrentPedWeaponEntityIndex(playerPed, 0)
                SetWeaponLevelThreshold(weaponObj, 0.5) -- show as worn at this level?

                UpdateGunOilPrompt()

                -- Ref: generic_weapon_item.c
                flowblock:SetInt32(0, UiflowblockRequest(`PM_FLOW_WEAPON_INSPECT`))

                while UiflowblockIsLoaded(flowblock:GetInt32(0)) ~= 1 do
                    Citizen.Wait(0)
                end

                UiflowblockEnter(flowblock:GetInt32(0), 0)
                UiStateMachineCreate(-813354801, flowblock:GetInt32(0))

                itemInspectionData = DatabindingAddDataContainerFromPath("", "ItemInspection")
                DatabindingAddDataBool(itemInspectionData, "Visible", true)

                -- adds the stats to the ui
                inventoryDataEntry = Citizen.InvokeNative(0x46DB71883EE9D5AF, itemInspectionData, "stats", itemGuid, playerPed)                

                itemLabel = DatabindingAddDataHash(itemInspectionData, "itemLabel", GetHashKey( GetWeaponNameWithPermanentDegradation(lastSelectedItem, 1.0) ))

                EnableHudContext(`HUD_CTX_INSPECT_ITEM`)
            end
        end

        if IsPedRunningInspectionTask(playerPed) == 1 then
            if IsControlJustPressed(0, `INPUT_CONTEXT_X`) and GetItemInteractionPromptProgress(playerPed, `INPUT_CONTEXT_X`) == 0 then
                -- remove gun oil 
                RemoveItemFromInventory(`kit_gun_oil`, 1)
     
                UpdateGunOilPrompt()
            end

            local state = GetItemInteractionState(playerPed)
            if state == `LONGARM_CLEAN_EXIT` or state == `SHORTARM_CLEAN_EXIT` then

                local weaponObj = GetCurrentPedWeaponEntityIndex(playerPed, 0)

                SetWeaponDegradation(weaponObj, 0.0)
                SetWeaponDamage(weaponObj, 0.0, false)
                SetWeaponDirt(weaponObj, 0.0, false)
                SetWeaponSoot(weaponObj, 0.0, false)

                UpdateStats()
            end
        elseif itemInspectionData ~= 0 then
            DatabindingRemoveDataEntry(itemInspectionData)
            itemInspectionData = 0
            DisableHudContext(`HUD_CTX_INSPECT_ITEM`)

            UiStateMachineDestroy(-813354801)
            if UiflowblockIsLoaded(uiFlowBlock) == 1 then
                UiflowblockRelease(flowblock:Buffer())
            end
        end


    end
end)