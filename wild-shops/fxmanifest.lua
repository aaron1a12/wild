fx_version "adamant"
games {"rdr3"}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

client_script {
	"@wild-core/client/functions/cl_dataview.lua",
	"@wild-core/client/functions/cl_general.lua",
	'client/cl_shops.lua'
}

server_script {
}

dependencies {
    'wild-core'
}