fx_version "adamant"
games {"rdr3"}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

client_script {
	"@wild-core/client/functions/cl_utilities.lua",
	'client/cl_war.lua',
}

server_script {
	'server/sv_war.lua',
}

files
{
	"factions.json",
}

dependencies {
    'wild-core'
}