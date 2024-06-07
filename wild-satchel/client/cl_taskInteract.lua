function ChooseActionStance()
    local ped = PlayerPedId()

	if GetFirstEntityPedIsCarrying(ped) ~= 0 then
        return 1
    end

    local _, primaryWeaponHash = GetCurrentPedWeapon(ped, true, 0, false)
    local _, secondaryWeaponHash = GetCurrentPedWeapon(ped, false, 1, false)

    if primaryWeaponHash ~= `WEAPON_UNARMED` and IsWeaponTwoHanded(primaryWeaponHash)==1 then
        return 2
    end

    if primaryWeaponHash == `WEAPON_UNARMED` then
        return 0
    end

	if secondaryWeaponHash == `WEAPON_UNARMED` then
		if primaryWeaponHash == `WEAPON_UNARMED` then
			return 0
		elseif ((((IsWeaponValid(primaryWeaponHash) and IsWeaponTwoHanded(primaryWeaponHash)==1) and IsWeaponBow(primaryWeaponHash)==0) and IsPedFullyOnMount(ped, true)==0) and not (IsPedInAnyVehicle(ped, false) and IsFirstPersonCameraActive(1, 0, 0)==0)) then
			return 1
		elseif IsWeaponBinoculars(primaryWeaponHash)==1 then
			return 2
		elseif ((IsWeaponValid(primaryWeaponHash) and IsWeaponBow(primaryWeaponHash)==1) or IsWeaponLasso(primaryWeaponHash)==1) then
			return 1
		else
			return 1
        end
	elseif primaryWeaponHash == `WEAPON_UNARMED` then
		return 0
	else
		return 2
    end
	return 0
end

-- Ref: satchel_ui_event_handler.c
function PlayTaskInteract(item, interactionTypeTag)
    ped = PlayerPedId()
    tag = interactionTypeTag

    if IsItemCustom(item) then
    -- "DOCUMENT_INSPECT@PAPER_D2_H32_ROLLED_INTRO
    end

    local stance = ChooseActionStance()
    local action = 0

    function useGenericAnims()
        if stance == 0 then
            action = `USE_HANDFULL_SATCHEL_UNARMED_QUICK`
        elseif stance == 1 then
            action = `USE_HANDFULL_SATCHEL_LEFT_HAND_QUICK`
        elseif stance == 2 then
            action = `USE_HANDFULL_SATCHEL_RIFLE_QUICK`
        end
    end

    if tag == `ci_tag_smoking_cigarette` then
        if stance == 0 then
            action = `QUICK_SMOKE_CIGARETTE_RIGHT_HAND`
        elseif stance == 1 then
            action = `QUICK_SMOKE_CIGARETTE_LEFT_HAND`
        elseif stance == 2 then
            action = `QUICK_SMOKE_CIGARETTE_RIFLE`
        end
    end

    if tag == `ci_tag_smoking_cigar` then
        if stance == 0 then
            action = `QUICK_SMOKE_CIGAR_RIGHT_HAND`
        elseif stance == 1 then
            action = `QUICK_SMOKE_CIGAR_LEFT_HAND`
        elseif stance == 2 then
            action = `QUICK_SMOKE_CIGAR_RIFLE`
        end
    end

    if tag == 89124942 then
        useGenericAnims()
    end

    if tag == -1529356747 then -- unknown coffee animations
        useGenericAnims()
    end
    
    if tag == 238865292 then
        if stance == 0 then
            action = `USE_TONIC_SATCHEL_UNARMED_QUICK`
        elseif stance == 1 then
            action = `USE_TONIC_SATCHEL_LEFT_HAND_QUICK`
        elseif stance == 2 then
            action = `USE_TONIC_SATCHEL_RIFLE_QUICK`
        end
    end

    if tag == 1177617310 then
        if stance == 0 then
            action = `USE_TONIC_POTENT_SATCHEL_UNARMED_QUICK`
        elseif stance == 1 then
            action = `USE_TONIC_POTENT_SATCHEL_LEFT_HAND_QUICK`
        elseif stance == 2 then
            action = `USE_TONIC_POTENT_SATCHEL_RIFLE_QUICK`
        end
    end

    --brandy
    if tag == -273840653 then
        if stance == 0 then
            action = 36807409
        elseif stance == 1 then
            action = -45077177
        elseif stance == 2 then
            action = 1293288723
        end
    end

    -- alcohol
    if tag == 1130235258 then
        if stance == 0 then
            action = `USE_LARGE_BOTTLE_COMBAT_RIGHT_HAND`
        elseif stance == 1 then
            action = `USE_LARGE_BOTTLE_COMBAT_LEFT_HAND`
        elseif stance == 2 then
            action = `USE_LARGE_BOTTLE_COMBAT_RIFLE`
        end
    end

    -- guarma rum
    if tag == 999632878 then
        if stance == 0 then
            action = -480771797
        elseif stance == 1 then
            action = 1700817728
        elseif stance == 2 then
            action = 764367205
        end
    end
    
    -- Pocket watch
    if tag == `ci_tag_pocket_watch` then
        action = `POCKET_WATCH_INSPECT_UNHOLSTER`
    end

    if tag == `CI_TAG_APPLY_POMADE` then
        if IsMetaPedUsingComponent(ped, `HATS`) == 1 then
            action = `APPLY_POMADE_WITH_HAT`
        else
            action = `APPLY_POMADE_WITH_NO_HAT`
        end
    end

    if tag == -262371497 then
        if stance == 0 then
            action = `USE_STIMULANT_INJECTION_QUICK_RIGHT_HAND`
        elseif stance == 1 then
            action = `USE_STIMULANT_INJECTION_QUICK_LEFT_HAND`
        elseif stance == 2 then
            action = `USE_STIMULANT_INJECTION_QUICK_LEFT_HAND_RIFLE`
        end
    end

    --canned food

    if tag == 1451036371 then
        if IsPedInCombat(ped, 0) or CountPedsInCombatWithTarget(ped, 0) > 0 then
            useGenericAnims()
        else
            if stance == 0 then
                action = -1165614444
            elseif stance == 1 then
                action = 16939881
            elseif stance == 2 then
                action = 968591133
            end
        end
    end

    -- apple/fruit
    if tag == 1859991422 then 
        if IsPedInCombat(ped, 0) or CountPedsInCombatWithTarget(ped, 0) > 0 then
            useGenericAnims()
        else
            if stance == 0 then
                action = 1826089606
            elseif stance == 1 then
                action = 1964324114
            elseif stance == 2 then
                action = -654111932
            end
        end
    end

    -- carrot
    if tag == -1915958659 then 
        if IsPedInCombat(ped, 0) or CountPedsInCombatWithTarget(ped, 0) > 0 then
            useGenericAnims()
        else
            if stance == 0 then
                action = -457187977
            elseif stance == 1 then
                action = 2105609037
            elseif stance == 2 then
                action = -1595716047
            end
        end
    end

    -- bread
    if tag == 1891031775 then 
        if IsPedInCombat(ped, 0) or CountPedsInCombatWithTarget(ped, 0) > 0 then
            useGenericAnims()
        else
            if stance == 0 then
                action = -312546963
            elseif stance == 1 then
                action = -1530144981
            elseif stance == 2 then
                action = -389189374
            end
        end
    end

    -- wedge of cheese
    if tag == -809056541 then 
        if IsPedInCombat(ped, 0) or CountPedsInCombatWithTarget(ped, 0) > 0 then
            useGenericAnims()
        else
            if stance == 0 then
                action = -1846586910
            elseif stance == 1 then
                action = -1074475556
            elseif stance == 2 then
                action = 392506445
            end
        end
    end

    if not IsItemCustom(item) then
        if CanStartItemInteraction(ped, item, action, 1) == 1 then
            StartTaskItemInteraction(ped, item, action, 1, 0, -1082130432)
        end
    else
        -- Ref: generic_document_inspection.c
        action = 436157482

        --[[local struct = DataView.ArrayBuffer(256)
        struct:SetInt32(8*3, -1)
        struct:SetInt32(8*12, 4)
        struct:SetInt32(8*17, 4)
        Citizen.InvokeNative(0x0C093C1787F18519, item, struct:Buffer()) --_INVENTORY_GET_INVENTORY_ITEM_INSPECTION_INFO]]

        local model = `s_inv_pamppothorse01x`
        
        RequestModel(model)

        while not HasModelLoaded(model) do
            RequestModel(model)
            Citizen.Wait(0)
        end

        local coords = GetEntityCoords(ped)
        local itemEntity = CreateObject(model, coords.x, coords.y, coords.z-2.0, true, true, false)
        SetEntityVisible(itemEntity, false)

        --[[if HasStreamedTextureDictLoaded("inventory_items_tu") == 0 then
            RequestStreamedTextureDict("inventory_items_tu", false)
            while HasStreamedTextureDictLoaded("inventory_items_tu") == 0 do
                Citizen.Wait(0)
            end
            
        end ]]
        
        local texture = `ui_pamphlet_test`
        --RequestStreamedTextureDict("inventory_items_tu", true)

        if HasStreamedTxdLoaded(texture) == 0 then
            RequestStreamedTxd(texture, false)
            while HasStreamedTxdLoaded(texture) == 0 do
                Citizen.Wait(0)
            end
        end

        SetCustomTexturesOnObject(itemEntity, texture, 0, 0)

        N_0xcf69ea05cd9c33c9()
        TaskItemInteraction_2(ped, item, itemEntity, `PrimaryItem`,  action, 1, 0, -1.0)

        Citizen.Wait(500) -- Could've used HAS_ANIM_EVENT_FIRED but I don't know the event hash
        SetEntityVisible(itemEntity, true)

        while IsPedRunningTaskItemInteraction(ped) == 1 do
            Citizen.Wait(0)
        end

        SetModelAsNoLongerNeeded(model)
        SetStreamedTxdAsNoLongerNeeded(texture)
        SetEntityAsNoLongerNeeded(itemEntity)
        DeleteEntity(itemEntity)
    end 
end