-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

stationConfig = json.decode(LoadResourceFile(GetCurrentResourceName(), "stations.json"))

wildData = DatabindingGetDataContainerFromPath("wild")