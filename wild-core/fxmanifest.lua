fx_version "cerulean"
games {"rdr3"}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

client_script
{
	"client/functions/cl_dataview.lua",
	"client/functions/cl_general.lua",
	"client/cl_main.lua",
	"client/cl_debug.lua",
	"client/cl_horse.lua",
	"client/cl_loot.lua",
}

server_script
{
	"server/sv_main.lua",
	"server/sv_horse.lua"
}

files
{
	'html/**/*',
	"config.json",
	"peds.json",
	"players.json"
}

ui_page 'html/index.html'