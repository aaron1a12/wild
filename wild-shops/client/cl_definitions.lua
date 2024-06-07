-- Resources external to wild-core need to get the same instance of W this way
W = exports["wild-core"]:Get()

AddEventHandler("wild:cl_onOutdated", function()
	W = exports["wild-core"]:Get()
end)

shopConfig = json.decode(LoadResourceFile(GetCurrentResourceName(), "shops.json"))

wildData = DatabindingGetDataContainerFromPath("wild")

currentStore = nil

AddTextEntry("ui_outfit_name", "Enter Outfit Name")