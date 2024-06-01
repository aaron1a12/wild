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
    return GetLocalizedStringFromHash(GetHashKey("BREED"..hashName))
end