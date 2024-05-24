fx_version "cerulean"
games {"rdr3"}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

client_script
{
	"client/functions/cl_utilities.lua",
	"client/imaps/cl_imaps.lua",
	"client/cl_w.lua",
	"client/cl_events.lua",
	"client/cl_npcManager.lua",
	"client/cl_main.lua",
	"client/cl_outfits.lua",
	"client/cl_spawn.lua",	
	"client/cl_horse.lua",
	"client/cl_loot.lua",
	"client/cl_map.lua",
	"client/cl_honor.lua",
	'client/cl_crime.lua',
	"client/cl_weaponWheel.lua",
	"client/cl_debug.lua",
}

server_script
{
	"server/sv_main.lua",
	"server/sv_horse.lua",
	"server/sv_npcManager.lua",
}

files
{
	'html/**/*',
	"ipls.json",
	"config.json",
	"peds.json",
	"players.json",
	"player_outfits.json",
	"npcs.json",
	"streamData/**.ymt",
	"streamData/**.xml",
}

data_file 'EXPRESSION_SETS_FILE' 'streamData/expression_sets.xml'
data_file 'PED_METADATA_FILE' 'streamData/metapeds.ymt'

ui_page 'html/index.html'