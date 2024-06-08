fx_version "adamant"
games {"rdr3"}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

client_script {
	"@wild-core/client/functions/cl_utilities.lua",
	'client/cl_definitions.lua',
	'client/cl_butchers.lua',
	'client/cl_dressing_room.lua',
	'client/cl_general_stores.lua'
}

server_script {
	'server/sv_shops.lua'
}

dependencies {
    'wild-core'
}

files
{
	"shops.json",
	"pedDrawables.json"
}

this_is_a_map "yes" -- set to "no" when debugging for fast reload