fx_version "adamant"
games {"rdr3"}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

client_script {
	"@wild-core/client/functions/cl_utilities.lua",
	'client/cl_itemCatalogSp.lua',
	'client/cl_carcassData.lua',
	'client/cl_definitions.lua',
	'client/cl_taskInteract.lua',
	'client/cl_inventory.lua',
	'client/cl_itemWheel.lua',
	'client/cl_satchel.lua',
	'client/cl_weaponDegradation.lua',
}

server_script {
	'server/sv_satchel.lua'
}

dependencies {
    'wild-core'
}

files
{
	"player_inventories.json",
	"itemCatalogUiData.json",
	"slot_ids.json",
	'item_textures/**/*',
	'satchel_icons/**/*',
	'custom_items.json',
	"stream/*.ytd",
	
	"streamData/**.ymt",
	"streamData/**.xml",
	"streamData/**.meta",
}

data_file 'DEFAULT_CARRIABLES_DATA_FILE' 'streamData/defaultcarriablesdata.meta'
ui_page 'html/index.html'