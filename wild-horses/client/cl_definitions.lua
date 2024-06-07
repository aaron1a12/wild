-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

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

local _mountInfo = nil
RegisterNetEvent("wild:cl_onReceiveMountInfo", function(newMountInfo)
    _mountInfo = newMountInfo
end)

function RequestMountInfo()
    TriggerServerEvent("wild:sv_getMountInfo")

    while _mountInfo == nil do
        Citizen.Wait(0)
    end

    local mountInfo = _mountInfo
    _mountInfo = nil

    return mountInfo 
end

DecorRegister("HorseGender", 3)

function IsHorseMale(ped)
    if DecorExistOn(ped, "HorseGender") then
        local decor = DecorGetInt(ped, "HorseGender")

        if decor == 1 then
            return true
        else
            return false
        end
    end

    local fCharExp = GetCharExpression(ped, 41611)

    if fCharExp == 0.0 then
        return true
    end

    return false
end

function SetHorseGender(ped, bMale)
    local fCharExp = 1.0 -- (0.0 = male, 1.0 = female)
    local decor = 2 -- (1 = male, 2 = female )

    if bMale then
        fCharExp = 0.0
        decor = 1
    else
        -- Removes male genitals. Must call UpdatePedVariation after.
        EquipMetaPedOutfit(ped, 4223797520)
    end

    SetCharExpression(ped, 41611, fCharExp)
    DecorSetInt(ped, "HorseGender", decor)
end

function GetHorseBreedString(modelName)
    local hashName = string.upper(modelName)
    hashName = string.sub(hashName, 10)
    --return GetLocalizedStringFromHash(GetHashKey("BREED"..hashName))
    return GetStringFromHashKey(GetHashKey("BREED"..hashName))
end

function SetMountForPlayerPed(mount, playerPed)
    -- Wait until the mount has attributes
    while GetMaxAttributePoints(mount, ePedAttribute.PA_HEALTH) == 0 do
        Citizen.Wait(0)
    end

    SetMountSecurityEnabled(mount, false)
    SetPlayerOwnsMount(PlayerId(), mount)
    SetPedAsSaddleHorseForPlayer(PlayerId(), mount)
    SetPedActivePlayerHorse(PlayerId(), mount)

    --
    -- as in R* scripts (player_horse.c)
    -- 

    ClearActiveAnimalOwner(mount, 0)

    SetPedOwnsAnimal(playerPed, mount, false) -- Enables rearing
    SetPedPersonality(mount, `PLAYER_HORSE`)

    SetAnimalIsWild(mount, false)

    SetPedConfigFlag(mount, 324, true) -- Unknown condition
    SetPedConfigFlag(mount, 211, true)
    SetPedConfigFlag(mount, 208, true)
    SetPedConfigFlag(mount, 209, true)
    SetPedConfigFlag(mount, 400, true)
    SetPedConfigFlag(mount, 297, true)
    SetPedConfigFlag(mount, 136, false)
    SetPedConfigFlag(mount, 312, false)
    SetPedConfigFlag(mount, 113, false)
    SetPedConfigFlag(mount, 301, false)
    SetPedConfigFlag(mount, 277, true)
    SetPedConfigFlag(mount, 319, true)
    SetPedConfigFlag(mount, 6, true)

    SetAnimalTuningBoolParam(mount, 25, false) -- ATB_FlockEnablePavementGraph
    SetAnimalTuningBoolParam(mount, 24, false) -- ATB_FlockEnableFlee

    --
    -- Custom (not R*)
    --

    --SetPedConfigFlag(mount, 297, true) --PCF_ForceInteractionLockonOnTargetPed
    SetPedConfigFlag(mount, 300, false) -- PCF_DisablePlayerHorseLeading
    SetPedConfigFlag(mount, 312, true) -- PCF_DisableHorseGunshotFleeResponse
    --SetPedConfigFlag(mount, 442, true) -- disable flee
    --SetPedConfigFlag(mount, 444, false) -- disable flee horse by player ??
    SetPedConfigFlag(mount, 546, false) -- PCF_IgnoreOwnershipForHorseFeedAndBrush
    SetPedConfigFlag(mount, 594, false) -- Wild horse

    --
    -- Max out all ranks/points
    --

    SetAttributeBaseRank(mount, ePedAttribute.PA_HEALTH, GetMaxAttributeRank(mount, ePedAttribute.PA_HEALTH))
    SetAttributeBaseRank(mount, ePedAttribute.PA_STAMINA, GetMaxAttributeRank(mount, ePedAttribute.PA_STAMINA))
    SetAttributeBaseRank(mount, ePedAttribute.PA_SPECIALABILITY, GetMaxAttributeRank(mount, ePedAttribute.PA_SPECIALABILITY))
    SetAttributeBaseRank(mount, ePedAttribute.PA_COURAGE, GetMaxAttributeRank(mount, ePedAttribute.PA_COURAGE))
    SetAttributeBaseRank(mount, ePedAttribute.PA_AGILITY, GetMaxAttributeRank(mount, ePedAttribute.PA_AGILITY))
    SetAttributeBaseRank(mount, ePedAttribute.PA_SPEED, GetMaxAttributeRank(mount, ePedAttribute.PA_SPEED))
    SetAttributeBaseRank(mount, ePedAttribute.PA_ACCELERATION, GetMaxAttributeRank(mount, ePedAttribute.PA_ACCELERATION))
    SetAttributeBaseRank(mount, ePedAttribute.PA_BONDING, GetMaxAttributeRank(mount, ePedAttribute.PA_BONDING))
    SetAttributeBaseRank(mount, ePedAttribute.SA_BODYWEIGHT, GetMaxAttributeRank(mount, ePedAttribute.SA_BODYWEIGHT))
    SetAttributeBaseRank(mount, ePedAttribute.MTR_STRENGTH, GetMaxAttributeRank(mount, ePedAttribute.MTR_STRENGTH))
    SetAttributeBaseRank(mount, ePedAttribute.MTR_GRIT, GetMaxAttributeRank(mount, ePedAttribute.MTR_GRIT))
    SetAttributeBaseRank(mount, ePedAttribute.MTR_INSTINCT, GetMaxAttributeRank(mount, ePedAttribute.MTR_INSTINCT))
    SetAttributeBaseRank(mount, ePedAttribute.SA_DIRTINESSSKIN, 0) -- clean
    SetAttributePoints(mount, ePedAttribute.PA_HEALTH, GetMaxAttributePoints(mount, ePedAttribute.PA_HEALTH))
    SetAttributePoints(mount, ePedAttribute.PA_STAMINA, GetMaxAttributePoints(mount, ePedAttribute.PA_STAMINA))
    SetAttributePoints(mount, ePedAttribute.PA_SPECIALABILITY, GetMaxAttributePoints(mount, ePedAttribute.PA_SPECIALABILITY))
    SetAttributePoints(mount, ePedAttribute.PA_COURAGE, GetMaxAttributePoints(mount, ePedAttribute.PA_COURAGE))
    SetAttributePoints(mount, ePedAttribute.PA_AGILITY, GetMaxAttributePoints(mount, ePedAttribute.PA_AGILITY))
    SetAttributePoints(mount, ePedAttribute.PA_SPEED, GetMaxAttributePoints(mount, ePedAttribute.PA_SPEED))
    SetAttributePoints(mount, ePedAttribute.PA_ACCELERATION, GetMaxAttributePoints(mount, ePedAttribute.PA_ACCELERATION))
    SetAttributePoints(mount, ePedAttribute.PA_BONDING, GetMaxAttributePoints(mount, ePedAttribute.PA_BONDING))
    SetAttributePoints(mount, ePedAttribute.SA_BODYWEIGHT, GetMaxAttributePoints(mount, ePedAttribute.SA_BODYWEIGHT))
    SetAttributePoints(mount, ePedAttribute.MTR_STRENGTH, GetMaxAttributePoints(mount, ePedAttribute.MTR_STRENGTH))
    SetAttributePoints(mount, ePedAttribute.MTR_GRIT, GetMaxAttributePoints(mount, ePedAttribute.MTR_GRIT))
    SetAttributePoints(mount, ePedAttribute.MTR_INSTINCT, GetMaxAttributePoints(mount, ePedAttribute.MTR_INSTINCT))
    SetAttributePoints(mount, ePedAttribute.SA_DIRTINESSSKIN, 0) -- clean

    --
    -- as in R* scripts (net_stable_mount.c)
    -- 

    SetPedConfigFlag(playerPed, 561, true) -- PCF_EnableHorseCollectPlantInteractionInMP

    SetPedCanBeLassoed(mount, false)
    RequestPedVisibilityTracking(mount)
    SetPedShouldIgnoreAvoidanceVolumes(mount, 1)
    SetPedConfigFlag(mount, 400, true)
    SetPedConfigFlag(mount, 208, true)
    SetPedConfigFlag(mount, 209, true)
    SetPedConfigFlag(mount, 297, true)
    SetPedConfigFlag(mount, 277, true)
    SetPedConfigFlag(mount, 230, true)
    SetPedConfigFlag(mount, 324, true)
    SetPedConfigFlag(mount, 319, true)
    SetPedLassoHogtieFlag(mount, 0, false)

    SetPedConfigFlag(mount, 388, false) --PCF_DisableFatallyWoundedBehaviour

    SetPedShouldIgnoreAvoidanceVolumes(mount, 2)
    SetPedRelationshipGroupHash(mount, GetPedRelationshipGroupHash(playerPed))

    SetTransportConfigFlag(mount, 6, 0)
    SetTransportConfigFlag(mount, 3, 0)

    SetPlayerOwnsMount(PlayerId(), mount)
    SetPlayerMountStateActive(PlayerId(), true)
    --SetPedAsTempPlayerHorse(PlayerId(), mount)

    SetMountBondingLevel(mount, GetMaxAttributeRank(mount, ePedAttribute.PA_BONDING))
    CompendiumHorseBonding(mount, GetMaxAttributeRank(mount, ePedAttribute.PA_BONDING))
end