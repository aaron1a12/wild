-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

blips = json.decode(LoadResourceFile(GetCurrentResourceName(), "blips.json"))

function SetupBlips()
	for i=1, #blips do
		
		local blip = blips[i]
		
        blip.id = BlipAddForCoords(GetHashKey(blip.style), blip.coords[1], blip.coords[2], blip.coords[3])

        SetBlipSprite(blip.id, GetHashKey(blip.sprite), true)
        SetBlipScale(blip.id, 0.2)
        SetBlipName(blip.id, blip.name)
	end
end
SetupBlips()



-- Cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for i=1, #blips do
			local blip = blips[i]
            RemoveBlip(blip.id)            
        end  
    end
end)