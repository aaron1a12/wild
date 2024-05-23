-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

shopConfig = json.decode(LoadResourceFile(GetCurrentResourceName(), "shops.json"))

wildData = DatabindingAddDataContainerFromPath("", "wild")