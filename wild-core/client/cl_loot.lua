-- TODO: this could be better
local function CalculateLootForPed(ped)
	math.randomseed(GetGameTimer()/7)
	local money = math.random(1, 50) / 100

	if GetEntityModel(ped) == `G_M_M_BountyHunters_01` then
		money = math.random(100, 265) / 100
	end

	return money
end

local customLootTable = {}
local _customLootTable = json.decode(LoadResourceFile(GetCurrentResourceName(), "custom_ped_loot_table.json"))	

-- Replace all keys with hashed versions for runtime lookup
for key, tbl in pairs(_customLootTable) do
	customLootTable[GetHashKey(key)] = tbl
end

--[[RegisterCommand('ped', function() 
	local x, y, z = table.unpack(GetEntityCoords(GetPlayerPed(PlayerId()), false))

    local model = `G_M_M_BountyHunters_01`

    RequestModel(model)

    while not HasModelLoaded(model) do
        RequestModel(model)
        Citizen.Wait(0)
    end

    local ped = CreatePed(model, x, y+1.0, z, 45.0, true, true, true)
    SetEntityInvincible(ped, true)
    SetPedKeepTask(ped)
    SetPedAsNoLongerNeeded(ped)
    SetRandomOutfitVariation(ped)

    SetEntityHealth(ped, 0)
end, false)]]


AddEventHandler("EVENT_LOOT", function(data)  
	local playerPed = PlayerPedId()

	local looterPed = data[27]
    local ped = data[28]
    local pedModel = data[29]

    local nItems = data[1]
    local items = {}

	local totalMoney = 0

    for i=0, nItems-1 do
		local item = data[3+i]
		local quantity = data[14+i]

		if item == `currency_cash` then 
			-- Peds seem to have money in stacks of bills, coin purses, etc. Accumulate them here
			totalMoney = totalMoney + quantity
		else
			if W.Satchel then
				--[[local quantity = 1

				local info = DataView.ArrayBuffer(8 * 7)
				Citizen.InvokeNative(0xFE90ABBCBFDC13B2, item, info:Buffer())
				local itemGroup = info:GetInt32(16)

				if itemGroup == `ammo` then
					quantity = GetRandomIntInRange(1, 10)
				end]]

				W.Satchel.AddItem(item, quantity)
			end
		end
    end

	-- Extra items from our custom loot table

	if customLootTable[pedModel] then
		local lootTable = customLootTable[pedModel]

		for i=1, #lootTable do
			local customItem = lootTable[i]
			local itemHash = customItem[1]
			local quantity = customItem[2]
			local dropRate = customItem[3]
			if not dropRate then dropRate = 1.0 end

			if type(itemHash) == "string" then
				itemHash = GetHashKey(itemHash)
			end
			
			if type(quantity) == "table" then
				quantity = GetRandomIntInRange(quantity[1], quantity[2])
			end
			
			if GetRandomFloatInRange(0.0, 1.0) < dropRate then
				if itemHash == `currency_cash` then
					totalMoney = quantity
				else
					if W.Satchel then
						W.Satchel.AddItem(itemHash, quantity)
					end
				end
			end
		end
	end

	--RDR2 money is in cents. We use floating-point dollars.
	TriggerServerEvent("wild:sv_giveMoney", GetPlayerName(PlayerId()), totalMoney/100)
end)


AddEventHandler("EVENT_LOOT_COMPLETE", function(data)
	local playerPed = PlayerPedId()

	local looterPed = data[1]
	local ped = data[2]
	local success = data[3]

	if not IsEntityAPed(ped) then
		return
	end

	if looterPed == playerPed and success == 1 then
		if GetMetaPedType(ped) ~= 3 then -- animal = 3,  why not use GetIsAnimal()?
			-- Check for witnesses
			local playerCoords = GetEntityCoords(PlayerPedId())

			for _, witnessPed in ipairs(GetGamePool('CPed')) do
				if GetVectorDistSqr(GetEntityCoords(witnessPed), playerCoords) < 300.0 then
					if not IsPedAPlayer(witnessPed) and IsPedHuman(witnessPed) then
						if IsTargetPedInPerceptionArea(witnessPed, playerPed, -1.0, -1.0, -1.0, -1.0) then -- Player is totally within sight
							W.AddPlayerHonor(W.Config.Honor["onLootWitnessed"])
						end
					end
				end
			end
		end
	end
end)