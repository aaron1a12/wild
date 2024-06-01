-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

AddEventHandler("wild:cl_onOutdated", function()
	W = exports["wild-core"]:Get()
end)


stationConfig = json.decode(LoadResourceFile(GetCurrentResourceName(), "stations.json"))

wildData = DatabindingGetDataContainerFromPath("wild")