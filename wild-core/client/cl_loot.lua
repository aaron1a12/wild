-- TODO: this could be better
local function CalculateLootForPed(ped)
	math.randomseed(GetGameTimer()/7)
	local money = math.random(1, 50) / 100

	if GetEntityModel(ped) == `G_M_M_BountyHunters_01` then
		money = math.random(100, 265) / 100
	end

	return money
end

W.Events.AddHandler(`EVENT_LOOT_COMPLETE`, function(data)
	local playerPed = PlayerPedId()

	local looterPed = data[1]
	local ped = data[2]
	local success = data[3]

	if looterPed == playerPed and success == 1 then
		if GetMetaPedType(ped) ~= 3 then -- animal = 3
			TriggerServerEvent("wild:sv_giveMoney", GetPlayerName(PlayerId()), CalculateLootForPed(ped))

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