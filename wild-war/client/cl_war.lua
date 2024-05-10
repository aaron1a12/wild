--[[
    Models: 
        Lemoyne Raiders - G_M_Y_UniExConfeds_01
        O'Driscoll Boys - G_M_M_UniDuster_01
]]

-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

-- Client copy of factions
Factions = {}
local _factions = nil
local currentFaction = nil

local bChangingFaction = false
local bPlayerSpawned = false

-- Map of faction names to relationship group hashes
FactionRelationships = {}

-- Synchronously loads faction data from the server
function RefreshFactionData()
    TriggerServerEvent("wild:sv_onLoadFactionData")

    while _factions == nil do
        Citizen.Wait(0)
    end

    Factions = _factions
    _factions = nil
end
RegisterNetEvent("wild:cl_onLoadFactionData")
AddEventHandler("wild:cl_onLoadFactionData", function(factionData)
	_factions = factionData
end)

-- TODO: Handle runtime creation (new faction creation)
function CreateRelationships()
    for factionName, factionData in pairs(Factions) do
        local safeName = tostring(math.abs(GetHashKey(factionName)))
        local _, group = AddRelationshipGroup(safeName)

        FactionRelationships[factionName] = group

        
    end

    -- Set the relationships
    for factionAName, factionA in pairs(Factions) do
        for factionBName, factionB in pairs(Factions) do

            local factionAHash = FactionRelationships[factionAName]
            local factionBHash = FactionRelationships[factionBName]

            if factionAName == factionBName then
                SetRelationshipBetweenGroups(0, factionAHash, factionBHash) -- Companion
                SetRelationshipBetweenGroups(0, factionBHash, factionAHash) -- Companion
            else
                SetRelationshipBetweenGroups(6, factionAHash, factionBHash) -- Kill on sight
            end

            -- local ped population

            if factionA.hated then
                SetRelationshipBetweenGroups(6, -1976316465, factionAHash) -- Kill on sight
            else
                SetRelationshipBetweenGroups(0, -1976316465, factionAHash) -- companion
            end
        end
    end
end

function DestroyRelationships()
    for factionName, factionData in pairs(Factions) do
        RemoveRelationshipGroup(factionData.relationshipHash)
    end    
end

function UpdateFactionMembershipStatus()
    local playerName = GetPlayerName(PlayerId())
    local foundFaction = nil

    -- Search every faction
    for factionName, faction in pairs(Factions) do
        for i = 1, #faction.players do 
            if faction.players[i] == playerName then
                foundFaction = factionName
            end
        end
    end

    if foundFaction ~= nil then
        currentFaction = foundFaction
    else
        currentFaction = nil
    end

    if currentFaction ~= nil then
        SetPedRelationshipGroupHash(PlayerPedId(), FactionRelationships[currentFaction])

        W.UI.EditPage("warMenu", "my_faction", currentFaction, "Active Member")	
        W.UI.SetMenuRootPage("warMenu", "my_faction");

        if W.UI.IsMenuOpen("warMenu") then
            W.UI.GoToPage("warMenu", "my_faction", true)
            W.UI.ClearHistory()
        end
    else
        SetPedRelationshipGroupHash(PlayerPedId(), `PLAYER`)

        W.UI.SetMenuRootPage("warMenu", "root");

        if W.UI.IsMenuOpen("warMenu") then
            W.UI.GoToPage("warMenu", "root", true)
            W.UI.ClearHistory()
        end
    end

    TriggerEvent('wild:cl_onUpdateFaction', currentFaction)
    bChangingFaction = false
end

RegisterNetEvent("wild:cl_onJoinFaction", function(factionName)
    table.insert(Factions[factionName].players, GetPlayerName(PlayerId()))

    currentFaction = factionName

    PlaySound("HUD_MP_FREE_MODE", "EVENT_AVAILABLE")
    UpdateFactionMembershipStatus()
end)


RegisterNetEvent("wild:cl_onLeaveFaction", function()
    local playerName = GetPlayerName(PlayerId())
    
    for i = 1, #Factions[currentFaction].players do 
        if Factions[currentFaction].players[i] == playerName then
            Factions[currentFaction].players[i] = nil
            currentFaction = nil
        end
    end

    PlaySound("HUD_MP_FREE_MODE", "HP_HORSE")
    UpdateFactionMembershipStatus()
end)



-- cleanup
AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
        DestroyRelationships()
    end
end)


local function TestGang()
    -- TODO: CreatePe
    ShowText("Create ped")
end

Citizen.CreateThread(function()
    while true do   
        Citizen.Wait(0)  

        if IsControlJustPressed(0, "INPUT_PLAYER_MENU") then
            local prompt = 0

            -- Create prompt
            if prompt == 0 then
                prompt = PromptRegisterBegin()
                PromptSetControlAction(prompt, GetHashKey("INPUT_PLAYER_MENU")) -- L key
                PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", "Open War Menu"))
                UiPromptSetHoldMode(prompt, 100)
                UiPromptSetAttribute(prompt, 2, true) 
                UiPromptSetAttribute(prompt, 4, true) 
                UiPromptSetAttribute(prompt, 9, true) 
                UiPromptSetAttribute(prompt, 10, true) -- kPromptAttrib_NoButtonReleaseCheck. Immediately becomes pressed
                PromptRegisterEnd(prompt)

                Citizen.CreateThread(function()
                    Citizen.Wait(100)


                    while UiPromptGetProgress(prompt) ~= 0.0 and UiPromptGetProgress(prompt) ~= 1.0 do   
                        Citizen.Wait(0)
                    end

                    if UiPromptGetProgress(prompt) == 1.0 then
                        W.UI.OpenMenu("warMenu", true)
                    end

                    PromptDelete(prompt)
                    prompt = 0
                end)
            end
        end
    end
end)

function PopulateFactionList()
    RefreshFactionData()

    for factionName, factionData in pairs(Factions) do
        local params = {}
        params.text = factionName.."s";
        params.action = function()
            if not bChangingFaction then
                bChangingFaction = true
                TriggerServerEvent("wild:sv_joinFaction", factionName)
            else
                ShowText("Cannot change faction at this time")
            end
        end

        W.UI.DestroyPageItem("warMenu", "faction_list", GetHashKey(factionName))
        W.UI.CreatePageItem("warMenu", "faction_list", GetHashKey(factionName), params);
    end
end

function SpawnFactionMember(factionName)

    local model = `S_M_M_Army_01`

    if factionName == 'Hunters' then
        model = `G_M_M_BountyHunters_01`
    end

    RequestModel(model )

	while not HasModelLoaded( model ) do
		Wait(0)
	end

    local myCoords = GetEntityCoords(PlayerPedId())
    local ped = CreatePed(model, myCoords.x + 0.5, myCoords.y, myCoords.z + 1.0, 90.0, true)
    --EquipMetaPedOutfitPreset(ped, 0, false)
    SetRandomOutfitVariation(ped, true)

    TaskWanderInArea(ped, myCoords.x, myCoords.y, myCoords.z,  5.0, 10, 10, 1)

    SetPedRelationshipGroupHash(ped, FactionRelationships[factionName])
    print(ped)
end

function onPlayerSpawn()
    bPlayerSpawned = true

    -- Assign your player ped to the appropriate group
    UpdateFactionMembershipStatus()

    ShowText(currentFaction)
end

function OnStart()
    -- Destroy existing menu (useful for when restarting resource) -- TODO: MERGE WITH PROMPT GARBAGE COLLECTOR
    W.UI.DestroyMenuAndData("warMenu")

    Citizen.Wait(1000)

    W.UI.CreateMenu("warMenu")
    

    W.UI.CreatePage("warMenu", "root", "War", "Not in faction", 0, 4); -- Update subtitle:  W.UI.SetElementTextByClass("warMenu", "menuSubtitle", "Not in faction")
    W.UI.SetMenuRootPage("warMenu", "root");

    local params = {}
    params.text = "Join a Faction";
    params.description = "Allows you to join an existing War faction.";
    params.action = function()
        PopulateFactionList()
        W.UI.GoToPage("warMenu", "faction_list")
    end

    W.UI.CreatePageItem("warMenu", "root", 0, params);

    local btnNewFactionParams = {}
    btnNewFactionParams.text = "Create New Faction";
    btnNewFactionParams.description = "Allows you to create a new War faction which other players can join.";
    btnNewFactionParams.action = function()
        ShowText("Feature not implemented.")
    end
    
    W.UI.CreatePageItem("warMenu", "root", 0, btnNewFactionParams);

    -- Faction Join Page

    W.UI.CreatePage("warMenu", "faction_list", "JOIN A FACTION", "Available factions", 0, 4);


    -- My faction page
    W.UI.CreatePage("warMenu", "my_faction", "HUNTERS", "Member", 0, 4);
    

    local btnLeave = {}
    btnLeave.text = "Leave Faction";
    btnLeave.description = "Will make you leave the current faction.";
    btnLeave.action = function()
        if currentFaction ~= nil and not bChangingFaction then
            bChangingFaction = true
            TriggerServerEvent("wild:sv_leaveFaction")
        end
    end
    W.UI.CreatePageItem("warMenu", "my_faction", 0, btnLeave);


    -- Load the data
    RefreshFactionData()
    -- Create relationship groups
    CreateRelationships()


    --[[
    for _, ped in ipairs(GetGamePool('CPed')) do
        if not IsPedAPlayer(ped) then
            DeletePed(ped)
        end
    end

    local dutchParams = {}
    dutchParams.Model = "G_M_Y_UniExConfeds_01"
    dutchParams.DefaultCoords = vector3(-128.393, -32.657, 96.175)
    dutchParams.DefaultHeading = 267.4
    dutchParams.CullMinDistance = 2.0
    dutchParams.CullMaxDistance = 5.0
    dutchParams.SaveCoordsAndHeading = false
    dutchParams.Blip = 0
    dutchParams.BlipName = "cs_dutchy"
    
    function dutchParams:onActivate(ped, bOwned)
        self.Blip = BlipAddForEntity(`BLIP_STYLE_FRIENDLY`, ped)

        SetBlipSprite(self.Blip, `blip_ambient_posse_deputy`, true)
        SetBlipScale(self.Blip, 0.2)
        SetBlipName(self.Blip, self.BlipName)

        DrawDebugSphereTimed(GetEntityCoords(ped), self.CullMinDistance, 255, 128, 64, 32, 6000)
        DrawDebugSphereTimed(GetEntityCoords(ped), self.CullMaxDistance, 255, 64, 128, 32, 6000)
    
        if bOwned then
            local coords = GetEntityCoords(ped)
            EquipMetaPedOutfitPreset(ped, 1, false)    
            --TaskWanderInArea(ped, coords.x, coords.y, coords.z,  5.0, 10, 10, 1)

            SetPedRelationshipGroupHash(ped, FactionRelationships["Lemoyne Raiders"])
            SetEntityCanBeDamagedByRelationshipGroup(ped, false, FactionRelationships["Lemoyne Raiders"])

            -- Make the ped hate the player
            --local _, ped_group = AddRelationshipGroup("insulted_ped")
            --SetRelationshipBetweenGroups(6, ped_group, GetPedRelationshipGroupHash(PlayerPedId()))
            --SetPedRelationshipGroupHash(ped, ped_group)	-- Make sure never to do this to a player ped		
            --SetPedCombatMovement(targetPed, 0)

            Citizen.InvokeNative(0x8ACC0506743A8A5C, ped, GetHashKey("SituationAllStop"), 1, -1.0)  -- apply combatstyle "SituationAllStop" for 240 seconds. Ped holds fire and prefer not move.
            SetPedCanBeIncapacitated(ped, true)


            Citizen.InvokeNative(0x1913FE4CBF41C463,ped, 40, false)
            Citizen.InvokeNative(0x1913FE4CBF41C463,ped, 274, false)
            Citizen.InvokeNative(0x1913FE4CBF41C463,ped, 569, false)
        end

        GiveWeaponCollectionToPed(self.Ped, GetDefaultPedWeaponCollection(self.Model))

        -- Disable shooting at this ped
        --SetPedConfigFlag(self.Ped, 253, true)
        --PCF_TreatNonFriendlyAsHateWhenInCombat
        --SetPedConfigFlag(self.Ped, 289, false)
        --SetPedConfigFlag(self.Ped, 254, true)
        --SetPedConfigFlag(self.Ped, 255, true)
        --SetPedConfigFlag(self.Ped, 156, true) --PCF_EnableCompanionAISupport (disables flee or agression)
    
        for i = 0, 700 do
            if i ~= 580 and i ~= 253 then
                --SetPedConfigFlag(self.Ped, i, true)
            end
        end
        
        Citizen.CreateThread(function()
            while self.Ped ~= 0 do
                Citizen.Wait(0)

                SetPedMotivation(self.Ped, 10, 1, self.Ped )
                --SetPedResetFlag(self.Ped, 32, true)

                for i = 0, 371 do
                    --SetPedResetFlag(self.Ped, i, false)
                end
            end
        end)
    end

    function dutchParams:onDeactivate()
        RemoveBlip(self.Blip)
    end

    W.NpcManager:EnsureNpcExists("dutch_at_camp", dutchParams)
    ]]

    
    if W.bPlayerSpawned and not bPlayerSpawned then
        onPlayerSpawn()
    end

end
OnStart()

AddEventHandler("wild:cl_onPlayerFirstSpawn", function()
    if not bPlayerSpawned then
        onPlayerSpawn()
    end
end)




Citizen.CreateThread(function()
    if W.Config["debugMode"] == true then
        

        while true do    
            Citizen.Wait(0)        

            local playerCoords = GetEntityCoords(GetPlayerPed(player))
            

            for _, ped in ipairs(GetGamePool('CPed')) do
                local coords = GetEntityCoords(ped)
                local dist = GetVectorDist(coords, playerCoords)
    
                if dist < 10.0 then
                    DrawTextAtCoord(coords, "Ped ID: " .. ped .. "\nRelation: " .. GetPedRelationshipGroupHash(ped), 0.25, 255, 255, 255, 255)
                end

            end


            
             -- ALT + 3
            if IsControlJustPressed(0, "INPUT_EMOTE_TWIRL_GUN_VAR_D") and IsControlPressed(0, "INPUT_HUD_SPECIAL") then
                TestGang()
            end
        end
    end       
end)

AddEventHandler('onResourceStop', function(resourceName)
end)

exports("GetPedFaction", function(ped)
    if IsPedAPlayer(ped) then
        local player = NetworkGetPlayerIndexFromPed(ped)
        local name = GetPlayerName(player)

        local foundFaction = nil

        -- Search every faction
        for factionName, faction in pairs(Factions) do
            for i = 1, #faction.players do 
                if faction.players[i] == name then
                    foundFaction = factionName
                    break
                end
            end
        end

        if foundFaction then
            return foundFaction
        end        
    end

    return nil
end)
