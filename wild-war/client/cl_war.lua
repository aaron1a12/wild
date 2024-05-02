-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

-- Client copy of factions
Factions = {}
local _factions = nil
local currentFaction = nil

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


RegisterNetEvent("wild:cl_onJoinFaction")
AddEventHandler("wild:cl_onJoinFaction", function(factionName)
    table.insert(Factions[factionName].players, playerName)

    currentFaction = factionName

    ShowText("Welcome to " .. currentFaction .. "!")
    PlaySound("HUD_MP_FREE_MODE", "EVENT_AVAILABLE")

    UpdateFactionMembershipStatus()
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
            else
                SetRelationshipBetweenGroups(6, factionAHash, factionBHash) -- Kill on sight
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
    else
        SetPedRelationshipGroupHash(PlayerPedId(), `PLAYER`)
    end
end

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
        params.text = factionName;
        params.action = function()
            TriggerServerEvent("wild:sv_joinFaction", factionName)
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
    SetPedOutfitPreset(ped, true, false)
    SetRandomOutfitVariation(ped, true)

    TaskWanderInArea(ped, myCoords.x, myCoords.y, myCoords.z,  5.0, 10, 10, 1)

    SetPedRelationshipGroupHash(ped, FactionRelationships[factionName])
    print(ped)
end



function OnStart()
    Citizen.Wait(1000)

    -- Load the data
    RefreshFactionData()
    -- Create relationship groups
    CreateRelationships()
    -- Assign your player ped to the appropriate group
    UpdateFactionMembershipStatus()

    ShowText(currentFaction)


    --[[
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")
    SpawnFactionMember("Lemoyne Raiders")

    Citizen.Wait(3000)
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")
    SpawnFactionMember("Hunters")

    ]]



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
        W.UI.GoToPage("warMenu", "faction_list")
        PopulateFactionList()
    end

    W.UI.CreatePageItem("warMenu", "root", 0, params);

    local btnNewFactionParams = {}
    btnNewFactionParams.text = "Create New Faction";
    btnNewFactionParams.description = "Allows you to create a new War faction which other players can join.";
    btnNewFactionParams.action = function()
        ShowText("ACTION 2")
    end
    
    W.UI.CreatePageItem("warMenu", "root", 0, btnNewFactionParams);

    -- Faction Join Page

    W.UI.CreatePage("warMenu", "faction_list", "JOIN A FACTION", "Available factions", 0, 4);
end
OnStart()

--[[W.Events.AddHandler(`EVENT_ENTITY_EXPLOSION`, function(data)
    -- Access data members like so:
    -- data[1]
    print("EVT EXPLOSION HANDLED - PED : " .. tostring(data[1]))
end)]]


Citizen.CreateThread(function()
    if W.Config["debugMode"] == true then
        while true do    
            Citizen.Wait(0)             
            local playerPed = GetPlayerPed(player)
            local playerCoords = GetEntityCoords(playerPed)
            
             -- ALT + 3
            if IsControlJustPressed(0, "INPUT_EMOTE_TWIRL_GUN_VAR_D") and IsControlPressed(0, "INPUT_HUD_SPECIAL") then
                TestGang()
            end
        end
    end       
end)

AddEventHandler('onResourceStop', function(resourceName)
end)