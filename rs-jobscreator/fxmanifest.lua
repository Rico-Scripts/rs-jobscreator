fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rs-jobscreator'
author 'RS Development'
description 'RS Jobs Creator - ESX + oxmysql + ox_lib + ox_inventory'
version '1.1.3'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/extensions.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@rs_discordlogs/server/intercept.lua',
    'server/bootstrap.lua',
    'server/interaction_patch.lua',
    'server/scanner.lua',
    'server/main.lua',
    'server/stability.lua',
    'server/points_import.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/stability.js',
    'html/extensions.js'
}

dependency 'es_extended'
dependency 'oxmysql'
dependency 'ox_lib'
dependency 'rs_discordlogs'
