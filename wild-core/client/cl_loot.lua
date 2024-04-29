-- TODO: this could be better
local function CalculateLootForPed(ped)
	math.randomseed(GetGameTimer()/7)
	local money = math.random(1, 50) / 100

	return money
end

W.Events.AddHandler(`EVENT_LOOT_COMPLETE`, function(data)
	local playerPed = GetPlayerPed(player)

	local looterPed = data[1]
	local ped = data[2]
	local success = data[3]

	if looterPed == playerPed and success == 1 then
		TriggerServerEvent("wild:sv_giveMoney", GetPlayerName(PlayerId()), CalculateLootForPed(ped))
	end
end)